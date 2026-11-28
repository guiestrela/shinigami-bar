pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "../shinigami.state/runtime" as SuiteRuntime

// One process-wide owner for display state, display mutations, and the legacy
// Omarchy monitor IPC target. The visible panel stays output-local; this
// service never creates a panel window or a second display backend.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null

  SuiteRuntime.Provider {
    pluginId: "shinigami.display-manager"
    implementationVersion: "0.0.1"
    owner: root
    host: root.shell
    manifest: root.manifest
  }

  property var bar: Qt.isQtObject(shell) && "bar" in shell ? shell.bar : null
  property var _visualBarLeases: []
  readonly property var visualBar: {
    let selected = null
    for (let index = 0; index < _visualBarLeases.length; index++) {
      const lease = _visualBarLeases[index]
      const candidate = lease && lease.hostedBar
      if (!Qt.isQtObject(candidate)) continue
      if (selected !== null && selected !== candidate) return null
      selected = candidate
    }
    return selected
  }
  readonly property bool scopedHost: Qt.isQtObject(shell) && "pluginId" in shell
  readonly property var stateService: Qt.isQtObject(shell)
    && "serviceFor" in shell ? shell.serviceFor("shinigami.state") : null

  QtObject {
    id: theme

    property bool displayManagerAutoWorkspaces: true
    property bool omarchyPerMonitorWorkspaces: false
    property bool hyprUsesLua: false
    property bool hyprDispatchModeReady: false
  }

  DisplayManagerController {
    id: controller
    theme: theme
  }

  readonly property var controllerApi: controller
  readonly property bool ready: controller !== null && controller.displayStateReady
  readonly property bool brightnessAvailable: controller.brightnessAvailable
  readonly property int brightnessPercent: Math.max(0, Math.min(100,
    Number(controller.brightnessPercent) || 0))
  readonly property string focusedMonitor: controller.focusedMonitor
    || controller.selectedMonitor || ""
  readonly property var displays: controller.displays
  readonly property int enabledDisplayCount: displays.filter(
    function(display) { return display && display.enabled === true }).length
  readonly property bool displayToggleAvailable: controller.monitors.length > 1
    && !controller.rollbackPending
  readonly property var scaleValues: ["1", "1.25", "1.6", "2", "3", "4"]
  readonly property string monitorScale: controller.previewMonitor(controller.selectedMonitor)
    ? String(controller.previewMonitor(controller.selectedMonitor).scale || "") : ""
  readonly property string internalMonitor: {
    for (const monitor of controller.monitors)
      if (/^(eDP|LVDS)/i.test(String(monitor.name || ""))) return String(monitor.name)
    return ""
  }
  readonly property string externalMonitor: {
    for (const monitor of controller.monitors) {
      const name = String(monitor.name || "")
      if (name && name !== internalMonitor) return name
    }
    return ""
  }
  readonly property bool internalEnabled: {
    for (const monitor of controller.monitors)
      if (String(monitor.name || "") === internalMonitor)
        return monitor.disabled !== true
    return false
  }
  readonly property bool mirrorEnabled: controller.monitors.some(function(monitor) {
    return monitor.mirrorOf && monitor.mirrorOf !== "none"
  })
  readonly property bool textSizeAvailable: controller.textSizeStops.length > 0
  readonly property var textSizeStops: controller.textSizeStops
  readonly property int textSizeIndex: Math.max(0, Math.min(
    textSizeStops.length - 1, Number(controller.textSizeIndex) || 0))
  readonly property real textSizePx: Number(textSizeStops[textSizeIndex]) || 0
  readonly property bool displayManagerAutoWorkspaces: theme.displayManagerAutoWorkspaces
  readonly property bool omarchyPerMonitorWorkspaces: theme.omarchyPerMonitorWorkspaces
  readonly property bool hyprDispatchModeReady: theme.hyprDispatchModeReady

  function ownSettings() {
    const host = visualBar || bar
    return host && typeof host.widgetSettings === "function"
      ? host.widgetSettings("G13", "shinigami.display-manager") : ({})
  }

  function syncAutoWorkspaces() {
    const settings = ownSettings()
    theme.displayManagerAutoWorkspaces = settings.displayManagerAutoWorkspaces !== false
  }

  function setAutoWorkspaces(enabled) {
    const state = stateService
    const next = enabled === true
    if (!Qt.isQtObject(state) || typeof state.setWidgetSetting !== "function") return false
    if (!state.setWidgetSetting("G13", "shinigami.display-manager",
        "displayManagerAutoWorkspaces", next)) return false
    theme.displayManagerAutoWorkspaces = next
    return true
  }

  function acquireVisualBar(holder, candidate) {
    if (!Qt.isQtObject(holder) || !Qt.isQtObject(candidate)) return null
    for (let index = 0; index < _visualBarLeases.length; index++) {
      const record = _visualBarLeases[index]
      if (Qt.isQtObject(record) && record.holder === holder) {
        if (record.hostedBar === candidate) return record.token
        releaseVisualBar(record.token)
        break
      }
    }
    if (_visualBarLeases.length >= 16) return null
    const token = Object.freeze({})
    const record = visualBarLeaseComponent.createObject(holder, {
      manager: root, holder: holder, hostedBar: candidate
    })
    if (!record) return null
    record.token = token
    _visualBarLeases = _visualBarLeases.concat([record])
    return token
  }

  function releaseVisualBar(token) {
    let found = null
    const next = []
    for (let index = 0; index < _visualBarLeases.length; index++) {
      const record = _visualBarLeases[index]
      if (found === null && Qt.isQtObject(record) && record.token === token)
        found = record
      else next.push(record)
    }
    if (found === null) return false
    _visualBarLeases = next
    found.manager = null
    found.destroy()
    return true
  }

  function visualBarRecordDestroyed(record) {
    if (!Qt.isQtObject(record) || _visualBarLeases.indexOf(record) < 0) return
    _visualBarLeases = _visualBarLeases.filter(function(value) {
      return value !== record
    })
  }

  function refresh() {
    if (!controller.refresh()) return false
    controller.refreshWorkspaces()
    return true
  }

  function setBrightness(value) {
    return controller.setBrightness(value)
  }

  function previewBrightness(value) {
    return controller.stageBrightness(controller.selectedMonitor, value)
  }

  function showBrightnessOsd(value) {
    const percent = Math.max(1, Math.min(100, Math.round(Number(value) || 1)))
    const payload = JSON.stringify({ icon: "brightness", value: percent })
    Quickshell.execDetached(["omarchy-shell", "osd", "show", payload])
    return true
  }

  function setScale(value) {
    const monitor = controller.previewMonitor(controller.selectedMonitor)
    const scale = Number(value)
    if (!monitor || !isFinite(scale) || scale < 0.1 || scale > 4) return false
    if (!controller.stageMonitor(controller.selectedMonitor, { scale: scale })) return false
    return controller.applyDrafts()
  }

  function setTextSize(value) {
    const px = Math.round(Number(value) || 0)
    const index = textSizeStops.indexOf(px)
    return index >= 0 && controller.setTextSize(index)
  }

  function adjustTextSize(delta) {
    const next = Math.max(0, Math.min(textSizeStops.length - 1,
      textSizeIndex + Math.sign(Number(delta) || 0)))
    return controller.setTextSize(next)
  }

  function toggleDisplay(name, enabled) {
    const target = String(name || "")
    if (!target) return false
    return enabled === true
      ? controller.enableMonitor(target, false)
      : controller.disableMonitor(target)
  }

  function normalizeScale(value) {
    const number = parseFloat(String(value || ""))
    return isFinite(number) ? String(Math.round(number * 100) / 100) : ""
  }

  function brightnessName(value) {
    const percent = Math.round(Number(value) || 0)
    if (percent >= 80) return "Bright"
    if (percent >= 45) return "Balanced"
    if (percent >= 20) return "Dim"
    return "Low light"
  }

  function summonVisiblePanel() {
    const host = visualBar || bar
    if (Qt.isQtObject(host) && typeof host.summonBarWidget === "function"
        && host.summonBarWidget("shinigami.display-manager") === true) return true
    const ownId = Qt.isQtObject(shell) && "pluginId" in shell
      ? String(shell.pluginId || "") : "shinigami.display-manager"
    return Qt.isQtObject(shell) && typeof shell.summon === "function"
      && shell.summon(ownId, "") === true
  }

  function closeVisiblePanels() {
    const host = visualBar || bar
    if (Qt.isQtObject(host) && typeof host.hideBarWidget === "function")
      host.hideBarWidget("shinigami.display-manager")
    const ownId = Qt.isQtObject(shell) && "pluginId" in shell
      ? String(shell.pluginId || "") : "shinigami.display-manager"
    if (Qt.isQtObject(shell) && typeof shell.hide === "function")
      shell.hide(ownId)
  }

  function legacyState() {
    return JSON.stringify({
      brightness: brightnessPercent,
      brightnessAvailable: brightnessAvailable,
      focusedMonitor: focusedMonitor,
      scale: monitorScale,
      displays: displays
    })
  }

  Commons.ShellIpc {
    id: legacyIpc
    enabled: Qt.isQtObject(root.shell)
    target: "omarchy.monitor"

    function brightness(percent: string): string {
      root.setBrightness(percent)
      return "got " + root.brightnessPercent
    }
    function state(): string { return root.legacyState() }
    function open() { root.summonVisiblePanel() }
    function close() { root.closeVisiblePanels() }
    function toggle() {
      const host = root.visualBar || root.bar
      if (Qt.isQtObject(host) && typeof host.isBarWidgetOpen === "function"
          && host.isBarWidgetOpen("shinigami.display-manager")) {
        root.closeVisiblePanels()
        return
      }
      root.summonVisiblePanel()
    }
    function show() { root.summonVisiblePanel() }
    function hide() { root.closeVisiblePanels() }
  }

  Process {
    id: hyprDispatchProbe
    command: ["bash", "-c", "if hyprctl dispatch 'hl.dsp' 2>&1 | grep -qi 'hl\\.dispatch'; then if [ -r \"${OMARCHY_PATH:-/usr/share/omarchy}/default/hypr/monitor-workspaces.lua\" ]; then echo lua-per-monitor; else echo lua; fi; else echo classic; fi"]
    running: Qt.isQtObject(root.shell) && !root.scopedHost
    stdout: StdioCollector {
      onStreamFinished: {
        const mode = text.trim()
        theme.hyprUsesLua = mode.indexOf("lua") === 0
        theme.omarchyPerMonitorWorkspaces = mode === "lua-per-monitor"
        theme.hyprDispatchModeReady = true
      }
    }
  }

  Connections {
    target: root.stateService
    function onConfigChanged() { root.syncAutoWorkspaces() }
  }

  visible: false
  width: 0
  height: 0

  Component {
    id: visualBarLeaseComponent
    VisualBarLease {}
  }

  Component.onCompleted: {
    syncAutoWorkspaces()
    refresh()
  }

  Component.onDestruction: {
    const leases = _visualBarLeases.slice()
    _visualBarLeases = []
    for (let index = 0; index < leases.length; index++) {
      const record = leases[index]
      if (!Qt.isQtObject(record)) continue
      record.manager = null
      record.destroy()
    }
  }
}
