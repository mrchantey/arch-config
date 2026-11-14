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

  function test_selection() {
    var first = window("first", "personal — notes.md", 1, 2)
    var second = window("second", "arch-config — settings.json", 1, 1)
    var browser = window("browser", "not-a-project", 1, 0, "google-chrome")
    var windows = [first, second, browser]
    compare(Labels.projectForGroup(windows, 1, 10, []), "arch-config")
    compare(Labels.projectForGroup(windows, 1, 10, ["first"]), "personal")
    second.activated = true
    compare(Labels.projectForGroup(windows, 1, 10, ["first"]), "arch-config")
    compare(Labels.projectForGroup(windows, 2, 10, []), "")
  }

  function test_groupsAndClasses() {
    var secondary = window("secondary", "beet — lib.rs", 13, 0)
    compare(Labels.projectForGroup([secondary], 3, 10, []), "beet")
    compare(Labels.projectForGroup([secondary], 1, 10, []), "")
    secondary.workspace.id = -99
    compare(Labels.projectForGroup([secondary], 1, 10, []), "")
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
    compare(recent.join(","), "second,first")
    recent = Labels.rememberFocus([first, browser], recent, null)
    compare(recent.join(","), "first")
    compare(Labels.projectForGroup([first, browser], 1, 10, recent), "personal")
  }

  function test_display() {
    compare(Labels.buttonLabel(2, "arch-config", false), "2 arch-config")
    compare(Labels.buttonLabel(10, "", false), "0")
    compare(Labels.buttonLabel(2, "arch-config", true), "2")
    compare(Labels.buttonLabel(1, "🌱".repeat(30), false), "1 " + "🌱".repeat(23) + "…")
    var markup = '<img src="https://example.invalid/tracker">'
    compare(Labels.safeText(markup), '‹img src="https://example.invalid/tracker"›')
    verify(Labels.safeText(Labels.buttonLabel(1, markup, false)).indexOf("<") === -1)
    verify(Labels.safeText("1 " + markup).indexOf("<") === -1)
  }

  QtObject {
    id: reactiveWindow
    property string address: "reactive"
    property string title: "arch-config — first.txt"
    property var workspace: ({ id: 2 })
    property var lastIpcObject: ({ class: "dev.zed.Zed", focusHistoryID: 0 })
    property bool activated: false
  }

  readonly property string reactiveProject: Labels.projectForGroup([reactiveWindow], 2, 10, [])

  function test_reactiveUpdates() {
    compare(reactiveProject, "arch-config")
    reactiveWindow.title = "beet — second.txt"
    compare(reactiveProject, "beet")
    reactiveWindow.title = "beet — third.txt"
    compare(reactiveProject, "beet")
    reactiveWindow.workspace = { id: 3 }
    compare(reactiveProject, "")
    reactiveWindow.workspace = { id: 12 }
    compare(reactiveProject, "beet")
    reactiveWindow.title = "arch-config — first.txt"
    reactiveWindow.workspace = { id: 2 }
  }
}
