import AppKit
import SwiftUI

@main
@MainActor
final class OpenProfileManagerApp: NSObject, NSApplicationDelegate {
  private let model = AppModel()
  private var mainWindow: NSWindow?

  static func main() {
    let application = NSApplication.shared
    let delegate = OpenProfileManagerApp()
    application.delegate = delegate
    application.setActivationPolicy(.regular)
    application.run()
    withExtendedLifetime(delegate) {}
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    configureMainMenu(for: NSApplication.shared)
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(500))
      showMainWindow()
    }
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    if NSApplication.shared.windows.allSatisfy({ !$0.isVisible }) {
      showMainWindow()
    }
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      showMainWindow()
    }
    return true
  }

  func application(
    _ application: NSApplication,
    shouldSaveSecureApplicationState coder: NSCoder
  ) -> Bool {
    false
  }

  func application(
    _ application: NSApplication,
    shouldRestoreSecureApplicationState coder: NSCoder
  ) -> Bool {
    false
  }

  private func showMainWindow() {
    if let mainWindow {
      mainWindow.makeKeyAndOrderFront(nil)
      NSApplication.shared.activate(ignoringOtherApps: true)
      return
    }

    let content = ContentView(model: model)
      .frame(minWidth: 760, minHeight: 520)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 940, height: 640),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.contentViewController = NSHostingController(rootView: content)
    window.identifier = NSUserInterfaceItemIdentifier("main")
    window.isReleasedWhenClosed = false
    window.isRestorable = false
    window.title = localized("Open Profile Manager")
    window.center()
    mainWindow = window
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  private func configureMainMenu(for application: NSApplication) {
    let mainMenu = NSMenu()
    mainMenu.addItem(appMenuItem())
    mainMenu.addItem(fileMenuItem())
    mainMenu.addItem(editMenuItem())
    mainMenu.addItem(windowMenuItem())
    mainMenu.addItem(helpMenuItem())
    application.mainMenu = mainMenu
  }

  private func appMenuItem() -> NSMenuItem {
    let item = NSMenuItem(
      title: localized("Open Profile Manager"),
      action: nil,
      keyEquivalent: ""
    )
    let menu = NSMenu(title: localized("Open Profile Manager"))
    menu.addItem(
      withTitle: localized("About Open Profile Manager"),
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
      keyEquivalent: ""
    )
    menu.addItem(.separator())
    menu.addItem(
      withTitle: localized("Quit Open Profile Manager"),
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    item.submenu = menu
    return item
  }

  private func fileMenuItem() -> NSMenuItem {
    let item = NSMenuItem(title: localized("File"), action: nil, keyEquivalent: "")
    let menu = NSMenu(title: localized("File"))
    let newProfile = NSMenuItem(
      title: localized("New Profile"),
      action: #selector(presentNewProfile),
      keyEquivalent: "n"
    )
    newProfile.target = self
    menu.addItem(newProfile)
    menu.addItem(.separator())
    menu.addItem(
      withTitle: localized("Close Window"),
      action: #selector(NSWindow.performClose(_:)),
      keyEquivalent: "w"
    )
    item.submenu = menu
    return item
  }

  private func editMenuItem() -> NSMenuItem {
    let item = NSMenuItem(title: localized("Edit"), action: nil, keyEquivalent: "")
    let menu = NSMenu(title: localized("Edit"))
    menu.addItem(withTitle: localized("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
    menu.addItem(withTitle: localized("Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
    menu.addItem(.separator())
    menu.addItem(withTitle: localized("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    menu.addItem(
      withTitle: localized("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    menu.addItem(
      withTitle: localized("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    menu.addItem(
      withTitle: localized("Select All"),
      action: #selector(NSText.selectAll(_:)),
      keyEquivalent: "a"
    )
    item.submenu = menu
    return item
  }

  private func windowMenuItem() -> NSMenuItem {
    let item = NSMenuItem(title: localized("Window"), action: nil, keyEquivalent: "")
    let menu = NSMenu(title: localized("Window"))
    menu.addItem(
      withTitle: localized("Minimize"),
      action: #selector(NSWindow.performMiniaturize(_:)),
      keyEquivalent: "m"
    )
    menu.addItem(
      withTitle: localized("Zoom"),
      action: #selector(NSWindow.performZoom(_:)),
      keyEquivalent: ""
    )
    item.submenu = menu
    NSApplication.shared.windowsMenu = menu
    return item
  }

  private func helpMenuItem() -> NSMenuItem {
    let item = NSMenuItem(title: localized("Help"), action: nil, keyEquivalent: "")
    item.submenu = NSMenu(title: localized("Help"))
    return item
  }

  @objc private func presentNewProfile() {
    showMainWindow()
    model.presentNewProfile()
  }

  private func localized(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
  }
}
