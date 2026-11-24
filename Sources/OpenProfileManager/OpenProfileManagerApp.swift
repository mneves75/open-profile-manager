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
    NSWindow.allowsAutomaticWindowTabbing = false
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
      NSApplication.shared.activate()
      return
    }

    let content = ContentView(model: model)
      .frame(minWidth: 720, minHeight: 480)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 920, height: 600),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.contentViewController = NSHostingController(rootView: content)
    window.identifier = NSUserInterfaceItemIdentifier("main")
    window.isReleasedWhenClosed = false
    window.isRestorable = false
    if #available(macOS 26, *) {
      window.toolbarStyle = .unified
    } else {
      window.toolbarStyle = .unifiedCompact
    }
    window.title = L10n.string("Open Profile Manager")
    window.center()
    mainWindow = window
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate()
  }

  private func configureMainMenu(for application: NSApplication) {
    let mainMenu = NSMenu()
    mainMenu.addItem(appMenuItem())
    mainMenu.addItem(fileMenuItem())
    mainMenu.addItem(editMenuItem())
    mainMenu.addItem(profileMenuItem())
    mainMenu.addItem(viewMenuItem())
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
    let services = NSMenuItem(title: L10n.string("Services"), action: nil, keyEquivalent: "")
    services.submenu = NSMenu(title: L10n.string("Services"))
    NSApplication.shared.servicesMenu = services.submenu
    menu.addItem(services)
    menu.addItem(.separator())
    menu.addItem(
      withTitle: L10n.string("Hide Open Profile Manager"),
      action: #selector(NSApplication.hide(_:)),
      keyEquivalent: "h"
    )
    menu.addItem(
      withTitle: L10n.string("Hide Others"),
      action: #selector(NSApplication.hideOtherApplications(_:)),
      keyEquivalent: "h"
    ).keyEquivalentModifierMask = [.command, .option]
    menu.addItem(
      withTitle: L10n.string("Show All"),
      action: #selector(NSApplication.unhideAllApplications(_:)),
      keyEquivalent: ""
    )
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

  private func profileMenuItem() -> NSMenuItem {
    let item = NSMenuItem(title: L10n.string("Profile"), action: nil, keyEquivalent: "")
    let menu = NSMenu(title: L10n.string("Profile"))

    let launch = NSMenuItem(
      title: L10n.string("Launch Desktop App"),
      action: #selector(launchSelectedProfile),
      keyEquivalent: "\r"
    )
    launch.target = self
    menu.addItem(launch)

    let copyCLI = NSMenuItem(
      title: L10n.string("Copy CLI Command"),
      action: #selector(copySelectedCLICommand),
      keyEquivalent: "C"
    )
    copyCLI.keyEquivalentModifierMask = [.command, .shift]
    copyCLI.target = self
    menu.addItem(copyCLI)

    menu.addItem(.separator())

    let edit = NSMenuItem(
      title: L10n.string("Edit Profile"),
      action: #selector(editSelectedProfile),
      keyEquivalent: "e"
    )
    edit.target = self
    menu.addItem(edit)

    let installLauncher = NSMenuItem(
      title: L10n.string("Install Finder Launcher"),
      action: #selector(installSelectedLauncher),
      keyEquivalent: ""
    )
    installLauncher.target = self
    menu.addItem(installLauncher)

    menu.addItem(.separator())

    let remove = NSMenuItem(
      title: L10n.string("Remove Profile"),
      action: #selector(removeSelectedProfile),
      keyEquivalent: "\u{8}"
    )
    remove.target = self
    menu.addItem(remove)

    item.submenu = menu
    return item
  }

  private func viewMenuItem() -> NSMenuItem {
    let item = NSMenuItem(title: L10n.string("View"), action: nil, keyEquivalent: "")
    let menu = NSMenu(title: L10n.string("View"))
    let refresh = NSMenuItem(
      title: L10n.string("Refresh"),
      action: #selector(refreshStatus),
      keyEquivalent: "r"
    )
    refresh.target = self
    menu.addItem(refresh)

    let inspector = NSMenuItem(
      title: L10n.string("Show Inspector"),
      action: #selector(toggleInspector),
      keyEquivalent: "i"
    )
    inspector.keyEquivalentModifierMask = [.command, .option]
    inspector.target = self
    menu.addItem(inspector)

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
    menu.addItem(.separator())
    menu.addItem(
      withTitle: L10n.string("Bring All to Front"),
      action: #selector(NSApplication.arrangeInFront(_:)),
      keyEquivalent: ""
    )
    item.submenu = menu
    NSApplication.shared.windowsMenu = menu
    return item
  }

  private func helpMenuItem() -> NSMenuItem {
    let item = NSMenuItem(title: L10n.string("Help"), action: nil, keyEquivalent: "")
    let menu = NSMenu(title: L10n.string("Help"))
    item.submenu = menu
    NSApplication.shared.helpMenu = menu
    return item
  }

  @objc private func presentNewProfile() {
    showMainWindow()
    model.presentNewProfile()
  }

  @objc private func refreshStatus() {
    Task { await model.reload() }
  }

  @objc private func toggleInspector() {
    model.toggleInspector()
  }

  @objc private func launchSelectedProfile() {
    guard let profile = model.selectedProfile else { return }
    model.launchApp(for: profile)
  }

  @objc private func copySelectedCLICommand() {
    guard let profile = model.selectedProfile else { return }
    model.copyCLICommand(for: profile)
  }

  @objc private func editSelectedProfile() {
    guard let profile = model.selectedProfile else { return }
    model.presentEditor(for: profile)
  }

  @objc private func installSelectedLauncher() {
    guard let profile = model.selectedProfile else { return }
    model.installLauncher(for: profile)
  }

  @objc private func removeSelectedProfile() {
    guard let profile = model.selectedProfile else { return }
    model.requestRemoval(of: profile)
  }

  @objc private func showAboutPanel() {
    NSApplication.shared.orderFrontStandardAboutPanel(
      options: [.applicationName: L10n.string("Open Profile Manager")]
    )
  }
}

extension OpenProfileManagerApp: NSMenuItemValidation {
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    switch menuItem.action {
    case #selector(refreshStatus):
      !model.isRefreshing
    case #selector(toggleInspector),
      #selector(launchSelectedProfile),
      #selector(copySelectedCLICommand),
      #selector(editSelectedProfile),
      #selector(installSelectedLauncher),
      #selector(removeSelectedProfile):
      model.selectedProfile != nil
    default:
      true
    }
  }
}
