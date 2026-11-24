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
  required property var riseRoot
  required property var oneDriveService

  readonly property var targetScreen: host ? host.targetScreen : null
  readonly property bool validScreen: targetScreen !== null
    && String(targetScreen.name || "") !== ""

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

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0.035, 0.035, 0.05, 0.86)
    MouseArea {
      anchors.fill: parent
      onClicked: host.closeOneDrive()
    }
  }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Math.min(overlay.width - 48, 390)
    height: Math.min(overlay.height - 48,
      panelLoader.item ? panelLoader.item.contentHeight + 24 : 640)
    radius: riseRoot.panelRadius
    color: riseRoot.bg
    border.width: riseRoot.panelOuterBorderW
    border.color: riseRoot.panelOuterBorderColor

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
