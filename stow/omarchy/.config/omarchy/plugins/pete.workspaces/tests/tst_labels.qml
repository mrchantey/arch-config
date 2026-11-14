import QtQuick
import QtTest
import "../Labels.js" as Labels

TestCase {
  name: "WorkspaceLabels"

  function window(address, title, workspace, history, className) {
    return {
      address: address,
      title: title,
      workspace: { id: workspace },
      activated: false,
      lastIpcObject: { class: className || "dev.zed.Zed", focusHistoryID: history }
    }
  }

  function appName(window) {
    return Labels.appName(window, "")
  }

  function groupLabel(windows, group, recent) {
    return Labels.labelForGroup(windows, group, 10, recent || [], appName)
  }

  function test_projectName_data() {
    return [
      { tag: "file", title: "arch-config — settings.json", expected: "arch-config" },
      { tag: "no-file", title: "arch-config", expected: "arch-config" },
      { tag: "multiple-roots", title: "beet, beet_egress — main.rs", expected: "beet, beet_egress" },
      { tag: "unicode", title: "🌱 garden — seed.rs", expected: "🌱 garden" },
      { tag: "empty", title: "", expected: "" },
      { tag: "welcome", title: "Zed", expected: "" },
      { tag: "empty-project", title: "Empty Project", expected: "" },
      { tag: "controls", title: "repo\nname — file", expected: "repo name" }
    ]
  }

  function test_projectName(data) {
    compare(Labels.projectName(data.title), data.expected)
    verify(Labels.projectName("x".repeat(1000)).length <= 512)
  }

  function test_appName_data() {
    return [
      { tag: "chrome", className: "google-chrome", desktopName: "Google Chrome", expected: "Chrome" },
      { tag: "chrome-beta", className: "google-chrome-beta", desktopName: "Google Chrome (beta)", expected: "Chrome" },
      { tag: "chromium", className: "chromium", desktopName: "Chromium", expected: "Chromium" },
      { tag: "desktop-entry", className: "org.qbittorrent.qBittorrent", desktopName: "qBittorrent", expected: "qBittorrent" },
      { tag: "reverse-dns", className: "com.example.MyApp", desktopName: "", expected: "MyApp" },
      { tag: "unknown", className: "my-app", desktopName: "", expected: "My app" },
      { tag: "webapp", className: "chrome-example-Default", desktopName: "Calendar", expected: "Calendar" },
      { tag: "unmatched-webapp", className: "chrome-example-Default", desktopName: "", expected: "Chrome" },
      { tag: "controls", className: "example", desktopName: "App\nName", expected: "App Name" },
      { tag: "empty", className: "", desktopName: "", expected: "" }
    ]
  }

  function test_appName(data) {
    compare(Labels.appName({ lastIpcObject: { class: data.className } }, data.desktopName), data.expected)
    compare(Labels.appName({ lastIpcObject: { initialClass: data.className } }, data.desktopName), data.expected)
    verify(Labels.appName({}, "x".repeat(1000)).length <= 512)
  }

  function test_selection() {
    var first = window("first", "personal — notes.md", 1, 2)
    var second = window("second", "arch-config — settings.json", 1, 1)
    var browser = window("browser", "not-a-project", 1, 0, "google-chrome")
    var windows = [first, second, browser]
    compare(groupLabel(windows, 1), "arch-config")
    compare(groupLabel(windows, 1, ["first"]), "personal")
    browser.activated = true
    compare(groupLabel(windows, 1, ["browser", "first"]), "personal")
    browser.activated = false
    second.activated = true
    compare(groupLabel(windows, 1, ["first"]), "arch-config")
    compare(groupLabel(windows, 2), "")
  }

  function test_fallback() {
    var project = window("project", "beet — main.rs", 1, 3)
    var browser = window("browser", "A page title that should not appear", 1, 1, "google-chrome")
    var terminal = window("terminal", "~/me/arch-config", 1, 0, "com.mitchellh.ghostty")
    var windows = [project, browser, terminal]
    compare(groupLabel(windows, 1), "beet")
    windows = [browser, terminal]
    compare(groupLabel(windows, 1), "Ghostty")
    compare(groupLabel(windows, 1, ["browser", "terminal"]), "Chrome")
    browser.activated = true
    compare(groupLabel(windows, 1, ["terminal", "browser"]), "Chrome")
    browser.title = "An entirely different page"
    compare(groupLabel(windows, 1), "Chrome")
    browser.workspace.id = 2
    compare(groupLabel(windows, 1), "Ghostty")
    compare(groupLabel(windows, 2), "Chrome")
    compare(groupLabel([], 1), "")
    compare(groupLabel([window("welcome", "Zed", 1, 0)], 1), "Zed")
    compare(groupLabel([{ workspace: { id: 1 } }], 1), "")
  }

  function test_groupsAndClasses() {
    var secondary = window("secondary", "beet — lib.rs", 13, 0)
    compare(groupLabel([secondary], 3), "beet")
    compare(groupLabel([secondary], 1), "")
    secondary.workspace.id = -99
    compare(groupLabel([secondary], 1), "")
    var browser = window("browser", "page", 13, 0, "google-chrome")
    compare(groupLabel([browser], 3), "Chrome")
    browser.workspace.id = -99
    compare(groupLabel([browser], 1), "")
    secondary.lastIpcObject = { class: "other", initialClass: "dev.zed.Zed-Preview" }
    verify(Labels.isZed(secondary))
    secondary.lastIpcObject = { class: "not-dev.zed.Zed" }
    verify(!Labels.isZed(secondary))
  }

  function test_focusHistory() {
    var first = window("first", "personal", 1, 1)
    var second = window("second", "arch-config", 1, 0)
    var browser = window("browser", "browser", 1, 2, "google-chrome")
    var windows = [first, second, browser]
    var recent = Labels.rememberFocus(windows, [], first)
    compare(recent.join(","), "first")
    recent = Labels.rememberFocus(windows, recent, second)
    compare(recent.join(","), "second,first")
    recent = Labels.rememberFocus(windows, recent, browser)
    compare(recent.join(","), "browser,second,first")
    compare(groupLabel(windows, 1, recent), "arch-config")
    recent = Labels.rememberFocus([first, browser], recent, null)
    compare(recent.join(","), "browser,first")
    compare(groupLabel([first, browser], 1, recent), "personal")
    compare(groupLabel([browser], 1, recent), "Chrome")
  }

  function test_display() {
    compare(Labels.buttonLabel(2, "arch-config", false), "2 arch-config")
    compare(Labels.buttonLabel(1, "Chrome", false), "1 Chrome")
    compare(Labels.buttonLabel(10, "", false), "0")
    compare(Labels.buttonLabel(2, "arch-config", true), "2")
    compare(Labels.buttonLabel(1, "🌱".repeat(30), false), "1 " + "🌱".repeat(23) + "…")
    var markup = '<img src="https://example.invalid/tracker">'
    compare(Labels.safeText(markup), '‹img src="https://example.invalid/tracker"›')
    var maliciousApp = Labels.appName({}, markup)
    verify(Labels.safeText(Labels.buttonLabel(1, maliciousApp, false)).indexOf("<") === -1)
    verify(Labels.safeText("1 " + maliciousApp).indexOf("<") === -1)
  }

  QtObject {
    id: reactiveWindow
    property string address: "reactive"
    property string title: "arch-config — first.txt"
    property var workspace: ({ id: 2 })
    property var lastIpcObject: ({ class: "dev.zed.Zed", focusHistoryID: 0 })
    property bool activated: false
  }

  property var reactiveWindows: [reactiveWindow]
  readonly property string reactiveLabel: groupLabel(reactiveWindows, 2)

  function test_reactiveUpdates() {
    compare(reactiveLabel, "arch-config")
    reactiveWindow.title = "beet — second.txt"
    compare(reactiveLabel, "beet")
    reactiveWindow.title = "beet — third.txt"
    compare(reactiveLabel, "beet")
    reactiveWindow.workspace = { id: 3 }
    compare(reactiveLabel, "")
    reactiveWindow.workspace = { id: 12 }
    compare(reactiveLabel, "beet")
    var browser = window("browser", "page", 2, 0, "google-chrome")
    reactiveWindows = [reactiveWindow, browser]
    compare(reactiveLabel, "beet")
    reactiveWindows = [browser]
    compare(reactiveLabel, "Chrome")
    reactiveWindows = []
    compare(reactiveLabel, "")
    reactiveWindow.title = "arch-config — first.txt"
    reactiveWindow.workspace = { id: 2 }
    reactiveWindows = [reactiveWindow]
  }
}
