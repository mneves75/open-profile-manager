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
    showMainWindow()
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
    window.title = L10n.string("Open Profile Manager")
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
      title: L10n.string("Open Profile Manager"),
      action: nil,
      keyEquivalent: ""
    )
    let menu = NSMenu(title: L10n.string("Open Profile Manager"))
    menu.addItem(
      withTitle: L10n.string("About Open Profile Manager"),
      action: #selector(showAboutPanel),
      keyEquivalent: ""
    )
    menu.items.last?.target = self
    menu.addItem(.separator())
    menu.addItem(
      withTitle: L10n.string("Quit Open Profile Manager"),
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    item.submenu = menu
    return item
  }

  private func fileMenuItem() -> NSMenuItem {
    let item = NSMenuItem(title: L10n.string("File"), action: nil, keyEquivalent: "")
    let menu = NSMenu(title: L10n.string("File"))
    let newProfile = NSMenuItem(
      title: L10n.string("New Profile"),
      action: #selector(presentNewProfile),
      keyEquivalent: "n"
    )
    newProfile.target = self
    menu.addItem(newProfile)
    menu.addItem(.separator())
    menu.addItem(
      withTitle: L10n.string("Close Window"),
      action: #selector(NSWindow.performClose(_:)),
      keyEquivalent: "w"
    )
    item.submenu = menu
    return item
  }

  private func editMenuItem() -> NSMenuItem {
    let item = NSMenuItem(title: L10n.string("Edit"), action: nil, keyEquivalent: "")
    let menu = NSMenu(title: L10n.string("Edit"))
    menu.addItem(withTitle: L10n.string("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
    menu.addItem(withTitle: L10n.string("Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
    menu.addItem(.separator())
    menu.addItem(
      withTitle: L10n.string("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    menu.addItem(
      withTitle: L10n.string("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    menu.addItem(
      withTitle: L10n.string("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    menu.addItem(
      withTitle: L10n.string("Select All"),
      action: #selector(NSText.selectAll(_:)),
      keyEquivalent: "a"
    )
    item.submenu = menu
    return item
  }

  private func windowMenuItem() -> NSMenuItem {
    let item = NSMenuItem(title: L10n.string("Window"), action: nil, keyEquivalent: "")
    let menu = NSMenu(title: L10n.string("Window"))
    menu.addItem(
      withTitle: L10n.string("Minimize"),
      action: #selector(NSWindow.performMiniaturize(_:)),
      keyEquivalent: "m"
    )
    menu.addItem(
      withTitle: L10n.string("Zoom"),
      action: #selector(NSWindow.performZoom(_:)),
      keyEquivalent: ""
    )
    item.submenu = menu
    NSApplication.shared.windowsMenu = menu
    return item
  }

  private func helpMenuItem() -> NSMenuItem {
    let item = NSMenuItem(title: L10n.string("Help"), action: nil, keyEquivalent: "")
    item.submenu = NSMenu(title: L10n.string("Help"))
    return item
  }

  @objc private func presentNewProfile() {
    showMainWindow()
    model.presentNewProfile()
  }

  @objc private func showAboutPanel() {
    NSApplication.shared.orderFrontStandardAboutPanel(
      options: [.applicationName: L10n.string("Open Profile Manager")]
    )
  }

}
