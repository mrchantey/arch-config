import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Labels.js" as Labels

// Project labels for synced workspaces (~/.config/hypr/workspaces.lua), where
// number N is workspace N on the primary monitor, N + 10 on the next and so on.
// Each button stands for the whole group, so the bar reads the same on every
// monitor and wherever focus is.
BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  // groups per monitor, matching GROUPS in workspaces.lua
  readonly property int groupCount: 10
  property var recentZedWindows: []

  function rememberFocus() {
    recentZedWindows = Labels.rememberFocus(Hyprland.toplevels.values, recentZedWindows, Hyprland.activeToplevel)
  }

  Component.onCompleted: rememberFocus()

  Connections {
    target: Hyprland
    function onActiveToplevelChanged() { root.rememberFocus() }
  }

  function groupOf(id) {
    return (id - 1) % groupCount + 1
  }

  function occupied(group) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id > 0 && groupOf(values[i].id) === group && values[i].toplevels.values.length > 0) return true
    }

    return false
  }

  function groups() {
    var groups = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      if (values[i].id < 1) continue
      var group = groupOf(values[i].id)
      if (groups.indexOf(group) === -1) groups.push(group)
    }

    groups.sort(function(left, right) { return left - right })
    return groups
  }

  // through workspaces.lua, which keeps focus on the current monitor
  function showGroup(group) {
    if (!root.bar) return
    root.bar.run("hyprctl eval " + Util.shellQuote("require(\"hypr.workspaces\").show(" + group + ")"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.groups().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.groups()

      WidgetButton {
        id: button
        required property int modelData

        readonly property string project: Labels.projectForGroup(Hyprland.toplevels.values, modelData, root.groupCount, root.recentZedWindows)
        readonly property bool occupied: root.occupied(modelData)
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id > 0 && root.groupOf(Hyprland.focusedWorkspace.id) === modelData

        bar: root.bar
        text: Labels.safeText(Labels.buttonLabel(modelData, project, root.vertical))
        tooltipText: Labels.safeText((modelData === 10 ? "0" : String(modelData)) + (project ? " " + project : ""))
        active: focused
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : (project ? -1 : Style.space(20))
        fixedHeight: root.barSize
        onPressed: function() { root.showGroup(modelData) }

        Rectangle {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottomMargin: 2
          width: parent.width - Style.space(8)
          height: Style.space(2)
          radius: height / 2
          color: button.activeColor
          visible: button.focused
        }
      }
    }
  }
}
