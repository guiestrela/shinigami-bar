pragma ComponentBehavior: Bound

import QtQuick
import "integration" as OneDrive

// Output-local OneDrive panel surface. It delegates its chrome to the same
// canonical Shinigami surface as every other panel, so V1 and V2 keep one
// border, radius, shadow and placement contract without a second visible card.
ShinigamiPanel {
  id: overlay

  required property var host
  required property var riseRoot
  required property var oneDriveService

  readonly property var targetScreen: host ? host.targetScreen : null
  readonly property bool validScreen: targetScreen !== null
    && String(targetScreen.name || "") !== ""
  readonly property string barPosition: riseRoot.barPosition

  bar: host ? host.bar : null
  owner: host
  open: !!host && host.oneDriveVisible && validScreen
  margin: 8
  contentWidth: overlay.fittedContentWidth(414)
  contentHeight: overlay.fittedContentHeight(
    panelLoader.item ? panelLoader.item.contentHeight : 0)

  function initializePanel() {
    if (!open || !panelLoader.item) return
    panelLoader.item.open(host.takeOneDriveOpenTarget())
  }

  onOpenChanged: if (open) Qt.callLater(initializePanel)

  Item {
    id: panelContent
    anchors.fill: parent

    Connections {
      target: overlay.host
      function onOneDriveOpenTargetChanged() {
        if (overlay.open && overlay.host.oneDriveOpenTarget !== "")
          Qt.callLater(overlay.initializePanel)
      }
    }

    Loader {
      id: panelLoader
      anchors.fill: parent
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
