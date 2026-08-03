#!/usr/bin/env bash

opm_release_arch_label() {
  local raw=${1:-"arm64 x86_64"}
  local normalized
  local -a architecture_parts
  local has_arm64=0
  local has_x86_64=0
  local architecture

  normalized=$(printf '%s' "$raw" | tr ',' ' ')
  read -r -a architecture_parts <<< "$normalized"
  for architecture in "${architecture_parts[@]}"; do
    case "$architecture" in
      arm64) has_arm64=1 ;;
      x86_64) has_x86_64=1 ;;
    esac
  done

  if [[ "$has_arm64" == 1 && "$has_x86_64" == 1 ]]; then
    printf 'macos-universal'
  elif [[ "$has_arm64" == 1 ]]; then
    printf 'macos-arm64'
  elif [[ "$has_x86_64" == 1 ]]; then
    printf 'macos-x86_64'
  else
    printf 'macos-%s' "$(printf '%s' "$normalized" | tr ' ' '+')"
  fi
}

opm_app_zip_name() {
  local version=$1
  local architectures=${2:-"arm64 x86_64"}
  printf 'Open-Profile-Manager-%s-%s.zip' "$(opm_release_arch_label "$architectures")" "$version"
}

opm_dsym_zip_name() {
  local version=$1
  local architectures=${2:-"arm64 x86_64"}
  printf 'Open-Profile-Manager-%s-%s.dSYM.zip' \
    "$(opm_release_arch_label "$architectures")" "$version"
}

opm_checksums_name() {
  local version=$1
  printf 'Open-Profile-Manager-%s-SHA256SUMS' "$version"
}

opm_sbom_name() {
  local version=$1
  printf 'Open-Profile-Manager-%s.spdx.json' "$version"
}
