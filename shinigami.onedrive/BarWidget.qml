pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import "../shinigami.state/lib/presentation" as Presentation
import "rise/v1" as RiseV1
import "components" as OneDriveComponents

// Output-local OneDrive status presentation. The process-wide coordinator and
// notification IPC live in this plugin's Service.qml; this surface only borrows
// that owner and renders one widget/panel per bar output.
Item {
  id: root

  property var bar: null
  property string moduleName: "shinigami.onedrive"
  property var settings: ({})
  property var oneDriveServiceOverride: null
  property var targetScreenOverride: null

  readonly property var coordinator: oneDriveServiceOverride !== null
    ? oneDriveServiceOverride
    : (bar && bar.shell && typeof bar.shell.serviceFor === "function"
      ? bar.shell.serviceFor("shinigami.onedrive") : null)
  readonly property var oneDriveService: coordinator ? coordinator.oneDriveService : null
  readonly property OneDriveRiseRoot oneDriveRoot:
    OneDriveRiseRoot { host: root; service: root.oneDriveService }

  Presentation.HostTokens { id: hostTokens; bar: root.bar }
  readonly property var tokens: bar && "visualTokens" in bar
    && bar.visualTokens ? bar.visualTokens : hostTokens
  readonly property color widgetInk: tokens
    && typeof tokens.widgetContentColor === "function"
    ? tokens.widgetContentColor(settings,
      bar ? bar.urgent : Commons.Color.accent)
    : (bar ? bar.urgent : Commons.Color.accent)
  readonly property color panelInk: tokens && "ink" in tokens
    ? tokens.ink : (bar ? bar.foreground : Commons.Color.foreground)

  readonly property var targetWindow: root.QsWindow && root.QsWindow.window
    ? root.QsWindow.window : null
  readonly property var targetScreen: targetScreenOverride
    || (targetWindow ? targetWindow.screen : null)
  readonly property bool oneDriveVisible: !!coordinator
    && coordinator.oneDriveVisible === true
    && coordinator.activeScreenName === (targetScreen
      ? String(targetScreen.name || "") : "")
  readonly property string oneDriveOpenTarget: coordinator
    ? String(coordinator.oneDriveOpenTarget || "") : ""

  visible: bar !== null && tokens !== null && oneDriveService !== null
  implicitWidth: visible ? actionRow.implicitWidth : 0
  implicitHeight: visible ? bar.barSize : 0

  function showTip(owner, text) {
    if (bar) bar.showTooltip(owner, text)
  }

  function hideTip(owner) {
    if (bar) bar.hideTooltip(owner)
  }

  function takeOneDriveOpenTarget() {
    if (coordinator
        && typeof coordinator.takeOneDriveOpenTarget === "function")
      return coordinator.takeOneDriveOpenTarget()
    return oneDriveOpenTarget
  }

  function openOneDrive(target) {
    if (!coordinator || !targetScreen) return false
    return coordinator.openPanel(target, targetScreen)
  }

  function closeOneDrive() {
    if (!oneDriveVisible) return false
    coordinator.close()
    if (bar && typeof bar.releasePopout === "function")
      bar.releasePopout(root)
    return true
  }

  function closeForPopoutSwitch() { return closeOneDrive() }

  // ShinigamiPanel dismisses through its owner rather than closing itself.
  function close() { return closeOneDrive() }

  function syncOneDriveOverlay() {
    if (!oneDriveVisible) {
      oneDriveOverlayLoader.source = ""
      return
    }
    oneDriveOverlayLoader.setSource(Qt.resolvedUrl("OneDriveOverlay.qml"), {
      host: Qt.binding(function() { return root }),
      anchorItem: oneDriveWidget,
      riseRoot: Qt.binding(function() { return root.oneDriveRoot }),
      oneDriveService: Qt.binding(function() { return root.oneDriveService })
    })
  }

  onOneDriveVisibleChanged: {
    if (oneDriveVisible && bar && typeof bar.requestPopout === "function")
      bar.requestPopout(root)
    syncOneDriveOverlay()
    if (!oneDriveVisible && bar && typeof bar.releasePopout === "function")
      bar.releasePopout(root)
  }
  Component.onDestruction: {
    if (oneDriveVisible) closeOneDrive()
    oneDriveOverlayLoader.source = ""
    if (bar && typeof bar.releasePopout === "function")
      bar.releasePopout(root)
  }

  Row {
    id: actionRow
    anchors.centerIn: parent

    OneDriveComponents.OneDriveWidget {
      id: oneDriveWidget
      root: oneDriveRoot
      contentColor: root.widgetInk
      showStatusBadge: root.tokens && root.tokens.v2Shell !== true
      backgroundComponent: root.tokens && (root.tokens.v2Shell === true
        || (root.bar && root.bar.vertical)) ? null : oneDrivePillV1
    }
  }

  Component {
    id: oneDrivePillV1
    Rectangle {
      width: oneDriveWidget.width
      height: root.oneDriveRoot.pillH
      radius: root.oneDriveRoot.pillRadius
      color: root.oneDriveRoot.pill
      border.color: root.oneDriveRoot.pillBorder
      border.width: root.oneDriveRoot.pillBorderW
      RiseV1.PillShadow { theme: root.oneDriveRoot }
    }
  }

  Loader { id: oneDriveOverlayLoader }
}
