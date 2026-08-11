#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DOCS="$ROOT/docs"
SAMPLES=10
GATE=
VALIDATE_ONLY=0

usage() {
  cat <<'USAGE'
Usage: Scripts/benchmark_site.sh [--samples N] [--gate MS] [--validate-only]

Validates sitemap HTML, local assets, video captions, and transcripts. Without
--validate-only, it also measures warm-local TTFB, FCP, LCP, and CLS in fixed
desktop and mobile viewports. Timing fails only when --gate is supplied.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --samples)
      SAMPLES=${2:-}
      shift 2
      ;;
    --gate)
      GATE=${2:-}
      shift 2
      ;;
    --validate-only)
      VALIDATE_ONLY=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! "$SAMPLES" =~ ^[1-9][0-9]*$ ]]; then
  echo "--samples must be a positive integer" >&2
  exit 2
fi
if [[ -n "$GATE" && ! "$GATE" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "--gate must be a non-negative number of milliseconds" >&2
  exit 2
fi

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}

require_tool python3

RESULT_DIR=${OPM_BENCHMARK_OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/open-profile-manager-site.XXXXXX")}
mkdir -p "$RESULT_DIR/raw"
SITEMAP_MATRIX="$RESULT_DIR/sitemap.tsv"

python3 - "$DOCS" "$SITEMAP_MATRIX" <<'PY'
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
import json
import re
import sys
import xml.etree.ElementTree as ET

docs = Path(sys.argv[1]).resolve()
matrix = Path(sys.argv[2])
sitemap = docs / "sitemap.xml"
errors = []

try:
    root = ET.parse(sitemap).getroot()
except (ET.ParseError, OSError) as error:
    raise SystemExit(f"Invalid sitemap {sitemap}: {error}")

namespace = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9"}
locations = [node.text.strip() for node in root.findall("s:url/s:loc", namespace) if node.text]
if not locations:
    raise SystemExit("docs/sitemap.xml contains no URLs")

base_path = urlsplit(locations[0]).path
if not base_path.endswith("/"):
    base_path = base_path.rsplit("/", 1)[0] + "/"

pages = []
for location in locations:
    parsed = urlsplit(location)
    if parsed.scheme != "https" or not parsed.netloc:
        errors.append(f"Sitemap URL must be absolute HTTPS: {location}")
        continue
    path = unquote(parsed.path)
    if not path.startswith(base_path):
        errors.append(f"Sitemap URL is outside {base_path}: {location}")
        continue
    relative = path[len(base_path):]
    if path.endswith("/"):
        relative += "index.html"
    relative = relative or "index.html"
    page = (docs / relative).resolve()
    if docs not in page.parents:
        errors.append(f"Sitemap path escapes docs/: {location}")
        continue
    if page.suffix.lower() not in {".html", ".htm"} or not page.is_file():
        errors.append(f"Sitemap HTML is missing: {relative}")
        continue
    pages.append((location, relative, page))


class SiteParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids = set()
        self.local_refs = []
        self.images = []
        self.videos = []
        self.current_video = None
        self.transcripts = {}
        self.current_transcript = None
        self.transcript_depth = 0
        self.favicons = []
        self.has_csp = False

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if values.get("id"):
            self.ids.add(values["id"])
        if tag == "meta" and values.get("http-equiv", "").lower() == "content-security-policy":
            self.has_csp = True
        if tag == "link" and "icon" in values.get("rel", "").lower().split():
            self.favicons.append(values.get("href", ""))
        if tag == "img":
            self.images.append(values)
        if tag == "video":
            self.current_video = {
                "id": values.get("id", ""),
                "duration": values.get("data-duration", ""),
                "tracks": [],
            }
            self.videos.append(self.current_video)
        elif tag == "track" and self.current_video is not None:
            self.current_video["tracks"].append(values)
        if tag == "details" and values.get("data-transcript-for"):
            self.current_transcript = values["data-transcript-for"]
            self.transcript_depth = 1
            self.transcripts[self.current_transcript] = []
        elif self.current_transcript is not None:
            self.transcript_depth += 1
        for attribute in ("href", "src", "poster"):
            if values.get(attribute):
                self.local_refs.append((tag, attribute, values[attribute]))
        if values.get("srcset"):
            for candidate in values["srcset"].split(","):
                self.local_refs.append((tag, "srcset", candidate.strip().split()[0]))

    def handle_endtag(self, tag):
        if tag == "video":
            self.current_video = None
        if self.current_transcript is not None:
            self.transcript_depth -= 1
            if self.transcript_depth == 0:
                self.current_transcript = None

    def handle_data(self, data):
        if self.current_transcript is not None and data.strip():
            self.transcripts[self.current_transcript].append(data.strip())


def local_target(page, reference):
    parsed = urlsplit(reference)
    if parsed.scheme or parsed.netloc or reference.startswith("//"):
        return None
    if reference.startswith("#"):
        return ("fragment", parsed.fragment)
    path = unquote(parsed.path)
    if not path:
        return ("fragment", parsed.fragment) if parsed.fragment else None
    target = (page.parent / path).resolve()
    if docs != target and docs not in target.parents:
        return ("escape", reference)
    if target.is_dir():
        target /= "index.html"
    return ("file", target)


timestamp = re.compile(r"(?:(\d+):)?(\d{2}):(\d{2})[.](\d{3})")


def seconds(value):
    match = timestamp.fullmatch(value)
    if not match:
        raise ValueError(value)
    hours, minutes, whole_seconds, millis = match.groups()
    return int(hours or 0) * 3600 + int(minutes) * 60 + int(whole_seconds) + int(millis) / 1000


for public_url, relative, page in pages:
    parser = SiteParser()
    try:
        parser.feed(page.read_text(encoding="utf-8"))
    except (OSError, UnicodeError) as error:
        errors.append(f"Cannot parse {relative}: {error}")
        continue
    if not parser.has_csp:
        errors.append(f"Missing Content-Security-Policy in {relative}")
    if not parser.favicons:
        errors.append(f"Missing declared favicon in {relative}")
    for image in parser.images:
        if not image.get("alt"):
            errors.append(f"Image missing non-empty alt text in {relative}: {image.get('src', '<unknown>')}")
        if not image.get("width") or not image.get("height"):
            errors.append(f"Image missing intrinsic dimensions in {relative}: {image.get('src', '<unknown>')}")
    for tag, attribute, reference in parser.local_refs:
        target = local_target(page, reference)
        if target is None:
            continue
        kind, value = target
        if kind == "fragment" and value and value not in parser.ids:
            errors.append(f"Broken fragment in {relative}: {reference}")
        elif kind == "escape":
            errors.append(f"Local reference escapes docs/ in {relative}: {reference}")
        elif kind == "file" and not value.is_file():
            errors.append(f"Missing local asset in {relative}: {reference}")
    track_sources = []
    for video in parser.videos:
        video_id = video["id"]
        if not video_id or not video["duration"]:
            errors.append(f"Video lacks id/data-duration in {relative}")
            continue
        caption_tracks = [track for track in video["tracks"] if track.get("kind") == "captions"]
        if len(caption_tracks) != 1:
            errors.append(f"Video {video_id} must have exactly one captions track")
            continue
        track_source = caption_tracks[0].get("src", "")
        track_sources.append(track_source)
        track_path = (page.parent / track_source).resolve()
        try:
            content = track_path.read_text(encoding="utf-8")
        except OSError as error:
            errors.append(f"Cannot read captions for {video_id}: {error}")
            continue
        if not content.startswith("WEBVTT\n"):
            errors.append(f"Captions for {video_id} do not start with WEBVTT")
        cues = re.findall(r"(\S+)\s+-->\s+(\S+)", content)
        if not cues:
            errors.append(f"Captions for {video_id} contain no cues")
            continue
        try:
            first_start = seconds(cues[0][0])
            last_end = seconds(cues[-1][1])
            expected_duration = float(video["duration"])
        except ValueError as error:
            errors.append(f"Invalid caption timing for {video_id}: {error}")
            continue
        if first_start != 0 or abs(last_end - expected_duration) > 0.5:
            errors.append(
                f"Captions for {video_id} cover {first_start:.3f}-{last_end:.3f}s, expected 0-{expected_duration:.3f}s"
            )
        transcript = " ".join(parser.transcripts.get(video_id, []))
        if len(transcript) < 80:
            errors.append(f"Video {video_id} lacks a substantive visual transcript")
    if len(track_sources) != len(set(track_sources)):
        errors.append(f"Videos in {relative} must not share one captions file")

try:
    json.loads((docs / "site.webmanifest").read_text(encoding="utf-8"))
except (OSError, UnicodeError, json.JSONDecodeError) as error:
    errors.append(f"Invalid site.webmanifest: {error}")

if errors:
    for error in errors:
        print(f"Site validation failed: {error}", file=sys.stderr)
    raise SystemExit(1)

with matrix.open("w", encoding="utf-8") as output:
    for public_url, relative, _ in pages:
        output.write(f"{public_url}\t{relative}\n")

print(f"Site validation passed: {len(pages)} sitemap HTML page(s), local assets, captions, transcripts, favicon, and manifest")
PY

if [[ "$VALIDATE_ONLY" == 1 ]]; then
  echo "Validation evidence: $RESULT_DIR"
  exit 0
fi

for tool in agent-browser sort awk mktemp uptime; do
  require_tool "$tool"
done

SESSION="opm-site-benchmark-$$"
SERVER_PID=
BROWSER_STARTED=0

cleanup() {
  if [[ "$BROWSER_STARTED" == 1 ]]; then
    agent-browser --session "$SESSION" close >/dev/null 2>&1 || true
  fi
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    for _ in {1..20}; do
      if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
        break
      fi
      sleep 0.05
    done
    if kill -0 "$SERVER_PID" >/dev/null 2>&1; then
      kill -KILL "$SERVER_PID" >/dev/null 2>&1 || true
    fi
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

PORT=$(python3 - <<'PY'
import socket
with socket.socket() as listener:
    listener.bind(("127.0.0.1", 0))
    print(listener.getsockname()[1])
PY
)
LOCAL_ORIGIN="http://127.0.0.1:$PORT"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$DOCS" >"$RESULT_DIR/server.log" 2>&1 &
SERVER_PID=$!

sleep 0.2
if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
  echo "Loopback server did not become ready; see $RESULT_DIR/server.log" >&2
  exit 1
fi

LOAD_BEFORE=$(uptime)
PYTHON_VERSION=$(python3 --version 2>&1)
AGENT_BROWSER_VERSION=$(agent-browser --version 2>&1)
RAW_TSV="$RESULT_DIR/raw.tsv"
printf 'viewport\tpublic_url\tlocal_url\tsample\tttfb_ms\tfcp_ms\tlcp_ms\tcls\tlcp_element\tlcp_url\n' > "$RAW_TSV"

VIEWPORTS=("desktop|1440|1000" "mobile|390|844")
for viewport_spec in "${VIEWPORTS[@]}"; do
  IFS='|' read -r viewport width height <<< "$viewport_spec"
  agent-browser --session "$SESSION" set viewport "$width" "$height" >/dev/null
  BROWSER_STARTED=1
  while IFS=$'\t' read -r public_url relative; do
    local_path=${relative%index.html}
    local_url="$LOCAL_ORIGIN/$local_path"
    agent-browser --session "$SESSION" vitals "$local_url" --json >/dev/null
    for ((sample = 1; sample <= SAMPLES; sample++)); do
      raw_name=${relative//\//-}
      raw_json="$RESULT_DIR/raw/${viewport}-${sample}-${raw_name}.json"
      if ! agent-browser --session "$SESSION" vitals "$local_url" --json > "$raw_json"; then
        echo "agent-browser vitals failed for $public_url ($viewport sample $sample)" >&2
        exit 1
      fi
      python3 - "$raw_json" "$viewport" "$public_url" "$local_url" "$sample" >> "$RAW_TSV" <<'PY'
import json
import sys

raw_path, viewport, public_url, local_url, sample = sys.argv[1:]
payload = json.loads(open(raw_path, encoding="utf-8").read())
if not payload.get("success"):
    raise SystemExit(f"Unsuccessful vitals payload: {payload}")
data = payload["data"]
lcp = data.get("lcp") or {}
values = [
    viewport,
    public_url,
    local_url,
    sample,
    data.get("ttfb"),
    data.get("fcp"),
    lcp.get("startTime"),
    (data.get("cls") or {}).get("score"),
    lcp.get("element", ""),
    lcp.get("url", ""),
]
if any(value is None for value in values[4:8]):
    raise SystemExit(f"Missing required vital in {raw_path}: {data}")
print("\t".join(str(value).replace("\t", " ") for value in values))
PY
    done
  done < "$SITEMAP_MATRIX"
done

agent-browser --session "$SESSION" eval "navigator.userAgent" --json > "$RESULT_DIR/browser.json"
LOAD_AFTER=$(uptime)
SUMMARY="$RESULT_DIR/summary.md"
{
  echo "# Static-site benchmark"
  echo
  echo "- Conditions: loopback HTTP, one reused Chromium session, one unrecorded warm-up per URL/viewport"
  echo "- Samples: $SAMPLES recorded navigations per URL/viewport"
  echo "- Percentiles: nearest-rank p50 and p95"
  echo "- Viewports: desktop 1440x1000; mobile 390x844"
  echo "- Python: $PYTHON_VERSION"
  echo "- agent-browser: $AGENT_BROWSER_VERSION"
  echo "- Load before: $LOAD_BEFORE"
  echo "- Load after: $LOAD_AFTER"
  echo "- Raw samples: $RAW_TSV and raw/*.json"
  echo
  echo "| Viewport | Sitemap URL | TTFB p50/p95 (ms) | FCP p50/p95 (ms) | LCP p50/p95 (ms) | CLS p50/p95 | LCP element |"
  echo "| --- | --- | ---: | ---: | ---: | ---: | --- |"
} > "$SUMMARY"

rank50=$(( (SAMPLES * 50 + 99) / 100 ))
rank95=$(( (SAMPLES * 95 + 99) / 100 ))
GATE_FAILURES=0

percentile() {
  local group_file=$1
  local column=$2
  local rank=$3
  awk -F $'\t' -v column="$column" 'NR > 1 { print $column }' "$group_file" \
    | sort -n \
    | awk -v rank="$rank" 'NR == rank { print; exit }'
}

for viewport_spec in "${VIEWPORTS[@]}"; do
  IFS='|' read -r viewport _ _ <<< "$viewport_spec"
  while IFS=$'\t' read -r public_url _; do
    group_file="$RESULT_DIR/group.tsv"
    awk -F $'\t' -v viewport="$viewport" -v url="$public_url" \
      'NR == 1 || ($1 == viewport && $2 == url)' "$RAW_TSV" > "$group_file"
    ttfb50=$(percentile "$group_file" 5 "$rank50")
    ttfb95=$(percentile "$group_file" 5 "$rank95")
    fcp50=$(percentile "$group_file" 6 "$rank50")
    fcp95=$(percentile "$group_file" 6 "$rank95")
    lcp50=$(percentile "$group_file" 7 "$rank50")
    lcp95=$(percentile "$group_file" 7 "$rank95")
    cls50=$(percentile "$group_file" 8 "$rank50")
    cls95=$(percentile "$group_file" 8 "$rank95")
    lcp_element=$(awk -F $'\t' 'NR > 1 { count[$9]++ } END { for (value in count) print count[value], value }' "$group_file" \
      | sort -rn \
      | awk 'NR == 1 { $1=""; sub(/^ /, ""); print; exit }')
    echo "| $viewport | $public_url | $ttfb50 / $ttfb95 | $fcp50 / $fcp95 | $lcp50 / $lcp95 | $cls50 / $cls95 | $lcp_element |" >> "$SUMMARY"
    if [[ -n "$GATE" ]] && awk -v fcp="$fcp95" -v lcp="$lcp95" -v gate="$GATE" 'BEGIN { exit !((fcp >= gate) || (lcp >= gate)) }'; then
      echo "Gate failed: $viewport $public_url p95 FCP=$fcp95 ms, LCP=$lcp95 ms; both must be below $GATE ms" >&2
      GATE_FAILURES=$((GATE_FAILURES + 1))
    fi
  done < "$SITEMAP_MATRIX"
done
rm "$RESULT_DIR/group.tsv"

cat "$SUMMARY"
echo "Benchmark evidence: $RESULT_DIR"
if [[ "$GATE_FAILURES" -gt 0 ]]; then
  exit 1
fi
