pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "integration" as OneDrive

// Output-local OneDrive panel surface. It is owned by the standalone OneDrive
// plugin and follows the same one-visible-panel-per-output rule as other ports.
PanelWindow {
  id: overlay

  required property var host
  required property Item anchorItem
  required property var riseRoot
  required property var oneDriveService

  readonly property var targetScreen: host ? host.targetScreen : null
  readonly property bool validScreen: targetScreen !== null
    && String(targetScreen.name || "") !== ""
  readonly property var anchorWindow: anchorItem.QsWindow.window
  readonly property string barPosition: riseRoot.barPosition
  readonly property real barSize: host.bar ? host.bar.barSize : 0
  readonly property bool verticalBar: barPosition === "left" || barPosition === "right"
  readonly property int gap: host.tokens.v2Shell === true ? 6 : 8
  readonly property point anchorCenter: {
    void(anchorWatcher.transform)
    return anchorWindow
      ? anchorItem.mapToItem(anchorWindow.contentItem, anchorItem.width / 2, anchorItem.height / 2)
      : Qt.point(width / 2, height / 2)
  }

  screen: targetScreen
  visible: !!host && host.oneDriveVisible && validScreen
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "shinigami-onedrive"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible
    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  function initializePanel() {
    if (!visible || !panelLoader.item) return
    panelLoader.item.open(host.takeOneDriveOpenTarget())
  }

  onVisibleChanged: if (visible) Qt.callLater(initializePanel)

  Connections {
    target: overlay.host
    function onOneDriveOpenTargetChanged() {
      if (overlay.visible && overlay.host.oneDriveOpenTarget !== "")
        Qt.callLater(overlay.initializePanel)
    }
  }

  TransformWatcher {
    id: anchorWatcher
    a: overlay.anchorWindow ? overlay.anchorWindow.contentItem : null
    b: overlay.anchorItem
  }

  MouseArea {
    anchors.fill: parent
    onClicked: overlay.host.closeOneDrive()
  }

  Rectangle {
    id: card
    readonly property int margin: 8
    width: Math.max(0, Math.min(414, overlay.width - margin * 2
      - (overlay.verticalBar ? overlay.barSize + overlay.gap : 0)))
    height: Math.max(0, Math.min(
      overlay.height - margin * 2 - (overlay.verticalBar ? 0 : overlay.barSize + overlay.gap),
      panelLoader.item ? panelLoader.item.contentHeight + 24 : 0))
    x: {
      const near = overlay.barSize + overlay.gap
      if (overlay.barPosition === "left") return near
      if (overlay.barPosition === "right") return overlay.width - near - width
      return Math.round(Math.max(margin, Math.min(
        overlay.anchorCenter.x - width / 2, overlay.width - width - margin)))
    }
    y: {
      const near = overlay.barSize + overlay.gap
      if (overlay.barPosition === "top") return near
      if (overlay.barPosition === "bottom") return overlay.height - near - height
      return Math.round(Math.max(margin, Math.min(
        overlay.anchorCenter.y - height / 2, overlay.height - height - margin)))
    }
    radius: host.tokens.v2Shell === true ? riseRoot.panelRadius : riseRoot.pillRadius
    color: riseRoot.bg
    border.width: 0

    MouseArea { anchors.fill: parent }

    Loader {
      id: panelLoader
      anchors.fill: parent
      anchors.margins: 12
      sourceComponent: Component {
        OneDrive.Panel {
          theme: overlay.riseRoot
          service: overlay.oneDriveService
          onDismissRequested: overlay.host.closeOneDrive()
        }
      }
    }
  }
}
