pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons
import "brightness" as Brightness

// Passive fixture host for the full Rise display content. The production
// BrightnessPanel is compiled separately in the smoke shell; this view avoids
// creating a real PanelWindow in the headless runner.
Item {
  id: root

  required property Item anchorItem
  required property var bar
  required property var ownerWidget
  required property var monitorService

  implicitWidth: Commons.Style.space(380)
  implicitHeight: content.implicitHeight + Commons.Style.space(60)
  readonly property var riseContent: displayContent

  readonly property QtObject panelFacade: QtObject {
    readonly property string shellStyle: "shinigami"
    readonly property var bar: root.bar
    readonly property var ownerWidget: root.ownerWidget
    readonly property var screen: null
    readonly property color controlForeground: root.bar
      ? root.bar.foreground : Commons.Color.foreground
    readonly property color controlMutedHigh: Commons.Util.alpha(controlForeground, 0.72)
    readonly property color controlAccent: root.bar
      ? root.bar.urgent : Commons.Color.accent
    readonly property color controlFillColor: Commons.Util.alpha(controlForeground, 0.08)
    readonly property color controlHoverFillColor: Commons.Util.alpha(controlAccent, 0.10)
    readonly property color controlActiveFillColor: Commons.Util.alpha(controlAccent, 0.18)
    readonly property color controlBorderColor: Commons.Util.alpha(controlForeground, 0.18)
    readonly property color controlHoverBorderColor: controlAccent
    readonly property color renderedSurfaceColor: Commons.Color.popups.background
    readonly property real controlBorderWidth: 1
    readonly property real controlRadius: Commons.Style.space(6)
  }

  Column {
    id: content
    width: parent.width
    spacing: Commons.Style.space(6)

    Row {
      width: parent.width
      Text {
        objectName: "display-v1-title"
        text: "Display Manager"
        color: root.panelFacade.controlForeground
        font.pixelSize: Commons.Style.font.body
      }
      Item {
        objectName: "display-refresh"
        width: 1
        height: 1
        signal clicked()
      }
      Item {
        objectName: "display-v1-close"
        width: 1
        height: 1
        signal clicked()
      }
    }

    Brightness.DisplayManagerPanelContent {
      id: displayContent
      width: parent.width
      panel: root.panelFacade
      service: root.monitorService
    }
  }

  Component.onCompleted: {
    root.bar.requestPopout(root.ownerWidget)
  }
  Component.onDestruction: {
    if (bar.activePopout === ownerWidget) bar.releasePopout(ownerWidget)
  }
}
