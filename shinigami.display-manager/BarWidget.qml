pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons
import qs.Ui as Ui
import "../shinigami.state/lib/presentation" as Presentation
import "rise" as Rise
import "rise/v1" as RiseV1
import "rise/v2" as RiseV2

Ui.Panel {
  id: root

  moduleName: "shinigami.display-manager"
  manageIpc: false
  Presentation.HostTokens { id: hostTokens; bar: root.bar }
  property url popupSource: Qt.resolvedUrl("BrightnessPanel.qml")
  property var monitorServiceOverride: null
  Rise.RiseRoot { id: riseRoot; host: root }
  readonly property var tokens: bar && "visualTokens" in bar
    && bar.visualTokens ? bar.visualTokens : hostTokens
  readonly property color widgetInk: tokens
    && typeof tokens.widgetContentColor === "function"
    ? tokens.widgetContentColor(settings,
      bar ? bar.urgent : Commons.Color.accent)
    : (bar ? bar.urgent : Commons.Color.accent)
  readonly property bool iconOnly: tokens.v2Shell !== true
    && setting("displayMode", "full") === "icon-only"
  readonly property string displayMode: iconOnly ? "icon" : String(
    setting("displayMode", setting("compact", false) ? "icon" : "full"))
  readonly property bool compact: displayMode === "icon"
  readonly property var monitorService: monitorServiceOverride
    || (bar && bar.shell && typeof bar.shell.serviceFor === "function"
      ? bar.shell.serviceFor("shinigami.display-manager") : null)
  property var visualBarLease: null
  property var visualBarLeaseService: null
  property real wheelAccumulator: 0
  readonly property bool monitorReady: monitorService && monitorService.ready
  readonly property bool brightnessAvailable: monitorReady
    && monitorService.brightnessAvailable
  readonly property int percent: monitorReady
    ? monitorService.brightnessPercent : 0
  readonly property int displayCount: monitorReady
    && Array.isArray(monitorService.displays) ? monitorService.displays.length : 0
  readonly property string tooltipText: !monitorReady ? "Display unavailable"
    : brightnessAvailable ? "Brightness · " + percent + "%"
    : "Display Manager · click to configure monitors"
  readonly property var panelItem: popupLoader.item
  readonly property bool panelLoaded: panelItem !== null
  readonly property var interactionTarget: actionButton

  visible: monitorReady
  implicitWidth: visible ? (bar && bar.vertical ? bar.barSize : surface.implicitWidth) : 0
  implicitHeight: visible
    ? (bar && bar.vertical ? surface.implicitHeight : bar ? bar.barSize : 28) : 0

  function setting(name, fallback) {
    const value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function childPanelWidget(pluginId) {
    const id = String(pluginId || "")
    return id === moduleName || id === "omarchy.monitor" ? root : null
  }

  function ownsPanelWidget(owner) { return owner === root }

  function adjustBrightness(delta) {
    return monitorService && monitorService.setBrightness(percent + Number(delta || 0))
  }

  function adjustBrightnessFromWheel(delta) {
    if (!brightnessAvailable) return false
    const wheel = Commons.Util.wheelSteps(wheelAccumulator, Number(delta || 0))
    wheelAccumulator = wheel.remainder
    if (wheel.steps === 0) return false
    if (!adjustBrightness(wheel.steps * 5)) return false
    if (typeof monitorService.showBrightnessOsd === "function")
      monitorService.showBrightnessOsd(monitorService.brightnessPercent)
    return true
  }

  function syncVisualBarLease() {
    if (visualBarLeaseService && visualBarLease
        && typeof visualBarLeaseService.releaseVisualBar === "function")
      visualBarLeaseService.releaseVisualBar(visualBarLease)
    visualBarLease = null
    visualBarLeaseService = null
    if (!Qt.isQtObject(bar) || !monitorService
        || typeof monitorService.acquireVisualBar !== "function") return
    const lease = monitorService.acquireVisualBar(root, bar)
    if (!lease) return
    visualBarLeaseService = monitorService
    visualBarLease = lease
  }

  function syncPanelLoader() {
    popupLoader.source = ""
    if (!opened || !monitorReady || !String(popupSource)) return
    monitorService.refresh()
    popupLoader.setSource(popupSource, {
      anchorItem: surface,
      bar: root.bar,
      ownerWidget: root,
      monitorService: monitorService
    })
  }

  onOpenedChanged: syncPanelLoader()
  onMonitorReadyChanged: syncPanelLoader()
  onPopupSourceChanged: syncPanelLoader()
  onMonitorServiceChanged: syncVisualBarLease()
  onBarChanged: syncVisualBarLease()
  Component.onCompleted: syncVisualBarLease()
  Component.onDestruction: {
    close()
    if (visualBarLeaseService && visualBarLease
        && typeof visualBarLeaseService.releaseVisualBar === "function")
      visualBarLeaseService.releaseVisualBar(visualBarLease)
    visualBarLease = null
    visualBarLeaseService = null
  }

  Loader { id: popupLoader }

  Item {
    id: surface
    anchors.centerIn: parent
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Presentation.PillSurface {
      anchors.fill: parent
      anchors.topMargin: root.bar && !root.bar.vertical
        ? Math.round((parent.height - root.tokens.pillHeight) / 2) : 0
      anchors.bottomMargin: anchors.topMargin
      visible: root.tokens.v2Shell !== true
      tokenSource: root.tokens
      bar: root.bar
      settings: root.settings
      v1AppearanceEnabled: true
    }

    Loader {
      id: content
      anchors.centerIn: parent
      active: root.visible
      sourceComponent: root.tokens.v2Shell === true ? riseV2 : riseV1
    }

    Ui.WidgetButton {
      id: actionButton
      anchors.fill: parent
      bar: root.monitorReady ? root.bar : null
      text: " "
      keepSpace: true
      horizontalMargin: 0
      verticalPadding: 0
      fixedWidth: surface.width
      fixedHeight: surface.height
      tooltipText: root.tooltipText
      onPressed: function(_button) { root.toggle() }
      onWheelMoved: function(delta) { root.adjustBrightnessFromWheel(delta) }
    }
  }

  Component {
    id: riseV1
    RiseV1.DisplayManagerWidget { root: riseRoot }
  }

  Component {
    id: riseV2
    RiseV2.DisplayManagerWidget { root: riseRoot }
  }
}
