import QtQuick
import Quickshell
import "brightness" as Brightness

ShellRoot {
  id: root

  property int phase: 0
  property int phaseTicks: 0
  property var clickTargets: []
  property int summonCount: 0
  property bool hiddenBarWidget: false
  property var scopedVisualLease: null
  property var teardownLease: null

  function fail(message) {
    console.error("brightness plugin smoke:", message)
    Qt.exit(1)
  }

  function findObject(object, objectName) {
    if (!object || typeof object !== "object") return null
    if (object.objectName === objectName) return object
    const children = "children" in object ? object.children : []
    for (const child of children) {
      const found = findObject(child, objectName)
      if (found !== null) return found
    }
    return null
  }

  QtObject {
    id: fakeState
    signal configChanged()
    property var settings: ({ displayManagerAutoWorkspaces: true })
    function setWidgetSetting(group, module, key, value) {
      if (group !== "G13" || module !== "shinigami.display-manager") return false
      settings[key] = value
      configChanged()
      return true
    }
  }

  Item {
    id: fakeBar
    visible: false
    width: 0
    height: 0
    property bool vertical: false
    property int barSize: 35
    property int sizeHorizontal: 35
    property string position: "top"
    property string fontFamily: "monospace"
    property color foreground: "#eeeeee"
    property color background: "#111111"
    property color barForeground: foreground
    property color urgent: "#88bbee"
    property bool foregroundAnimationEnabled: false
    property var activePopout: null
    property var clickTargets: root.clickTargets
    property var shell: fakeShell

    function widgetSettings(group, module) {
      return group === "G13" && module === "shinigami.display-manager"
        ? fakeState.settings : ({})
    }
    function registerClickTarget(target) {
      if (root.clickTargets.indexOf(target) < 0)
        root.clickTargets = root.clickTargets.concat([target])
    }
    function unregisterClickTarget(target) {
      root.clickTargets = root.clickTargets.filter(item => item !== target)
    }
    function showTooltip(_target, _text) {}
    function hideTooltip(_target) {}
    function requestPopout(owner) { activePopout = owner }
    function releasePopout(owner) { if (activePopout === owner) activePopout = null }
    function switchPanelFrom(_owner, _direction) { return false }
    function targetBelongsToWindow(_target, _window) { return true }
    function isBarWidgetOpen(id) { return id === "shinigami.display-manager" && activePopout !== null }
    function summonBarWidget(id) {
      if (id !== "shinigami.display-manager") return false
      root.summonCount++
      return true
    }
    function hideBarWidget(id) {
      if (id !== "shinigami.display-manager") return false
      root.hiddenBarWidget = true
      return true
    }
    function activePopoutForScreen(_screen) { return activePopout }
    function publishConnectedPanel(_key, _screen, _x, _reveal) {}
    function clearConnectedPanel(_key) {}
  }

  QtObject {
    id: fakeShell
    property var bar: fakeBar
    function serviceFor(id) {
      if (id === "shinigami.display-manager") return sharedMonitorService
      if (id === "shinigami.state") return fakeState
      return null
    }
    function summon(_id, _payload) { return true }
    function hide(_id) { return true }
  }

  Brightness.Service {
    id: sharedMonitorService
    shell: fakeShell
    bar: fakeBar
  }

  Item { id: teardownLeaseHolder; visible: false }
  Loader {
    id: teardownServiceLoader
    active: true
    sourceComponent: Component {
      Brightness.Service {
        bar: fakeBar
      }
    }
  }

  Loader {
    id: firstLoader
    active: true
    sourceComponent: Component {
      Brightness.BarWidget {
        bar: fakeBar
        settings: ({ compact: false })
        monitorServiceOverride: sharedMonitorService
        popupSource: Qt.resolvedUrl("MonitorTestView.qml")
      }
    }
  }

  Loader {
    id: secondLoader
    active: true
    sourceComponent: Component {
      Brightness.BarWidget {
        bar: fakeBar
        settings: ({ compact: false })
        monitorServiceOverride: sharedMonitorService
        popupSource: Qt.resolvedUrl("MonitorTestView.qml")
      }
    }
  }

  Brightness.BarWidget {
    id: unavailableBrightness
    bar: fakeBar
    monitorServiceOverride: QtObject {
      readonly property bool ready: false
      readonly property bool brightnessAvailable: false
      readonly property int brightnessPercent: 0
      readonly property var displays: []
    }
  }

  Timer {
    interval: 50
    repeat: true
    running: true
    onTriggered: {
      root.phaseTicks++
      const first = firstLoader.item
      const second = secondLoader.item
      const api = sharedMonitorService.controllerApi

      if (root.phase === 0) {
        if (!first || !second || !api || !sharedMonitorService.ready
            || !teardownServiceLoader.item || !teardownServiceLoader.item.ready
            || root.phaseTicks < 3) return
        if (first.monitorService !== second.monitorService
            || first.monitorService !== sharedMonitorService
            || !first.brightnessAvailable || first.percent !== 64
            || first.displayCount !== 2 || first.implicitHeight !== 35
            || first.tooltipText !== "Display Manager · click to configure monitors"
            || unavailableBrightness.visible)
          return root.fail("shared Rise owner readiness/state/geometry")
        if (api.previewMonitors.length !== 2
            || api.previewMonitor("eDP-1") === null
            || Number(api.previewPositions["DP-1"].x) !== 1920
            || api.scalePresets.length !== 7
            || api.textSizeStops.length !== 7
            || sharedMonitorService.textSizePx !== 12)
          return root.fail("controller state facade")
        if (root.clickTargets.length !== 2
            || sharedMonitorService._visualBarLeases.length !== 2
            || sharedMonitorService.visualBar !== fakeBar)
          return root.fail("visual bar leases or click targets")
        if (!sharedMonitorService.setAutoWorkspaces(false)
            || sharedMonitorService.displayManagerAutoWorkspaces
            || !sharedMonitorService.setAutoWorkspaces(true))
          return root.fail("auto workspace setting ownership")
        if (!sharedMonitorService.summonVisiblePanel()
            || root.summonCount !== 1)
          return root.fail("visible panel summon")
        sharedMonitorService.closeVisiblePanels()
        if (!root.hiddenBarWidget) return root.fail("visible panel close")

        root.teardownLease = teardownServiceLoader.item.acquireVisualBar(
          teardownLeaseHolder, fakeBar)
        if (!root.teardownLease) return root.fail("teardown lease acquisition")
        teardownServiceLoader.active = false
        sharedMonitorService.setBrightness(72)
        root.phase++
        root.phaseTicks = 0
      } else if (root.phase === 1) {
        if (root.phaseTicks < 3) return
        if (teardownServiceLoader.item !== null)
          return root.fail("dynamic display service did not tear down")
        if (sharedMonitorService.brightnessPercent !== 72
            || api.error !== "" || api.busy || api.loading)
          return root.fail("native brightness action")
        sharedMonitorService.setTextSize(14)
        root.phase++
        root.phaseTicks = 0
      } else if (root.phase === 2) {
        if (root.phaseTicks < 3) return
        if (sharedMonitorService.textSizePx !== 14
            || sharedMonitorService.textSizeIndex !== 4
            || api.busy || api.loading)
          return root.fail("native text-size action")
        if (!api.stageMonitor("eDP-1", { scale: 1.25 })
            || !api.previewMonitor("eDP-1") || api.previewMonitor("eDP-1").scale !== 1.25
            || !api.applyDrafts())
          return root.fail("display draft staging")
        root.phase++
        root.phaseTicks = 0
      } else if (root.phase === 3) {
        if (root.phaseTicks < 3) return
        if (!api.rollbackPending || api.rollbackToken === ""
            || api.busy || api.loading)
          return root.fail("guarded display preview: pending=" + api.rollbackPending
            + " token=" + api.rollbackToken + " busy=" + api.busy
            + " loading=" + api.loading + " error=" + api.error)
        api.confirmChanges()
        root.phase++
        root.phaseTicks = 0
      } else if (root.phase === 4) {
        if (root.phaseTicks < 3) return
        if (api.rollbackPending || api.busy || api.loading
            || api.error !== "" || sharedMonitorService.monitorScale !== "1.25"
            || api.hasDrafts)
          return root.fail("confirmed display draft did not settle")
        first.open()
        second.open()
        root.phase++
        root.phaseTicks = 0
      } else if (root.phase === 5) {
        if (root.phaseTicks < 4) return
        if (!first.opened || !second.opened || !first.panelLoaded || !second.panelLoaded)
          return root.fail("one-surface display panels did not load")
        const names = [
          "display-v1-title", "display-refresh", "display-v1-close",
          "display-canvas", "display-monitor-eDP-1", "display-monitor-DP-1",
          "display-resolution", "display-position-x", "display-position-y",
          "display-scale", "display-rotation", "display-workspace-1",
          "display-mirror", "display-enable", "display-disable",
          "display-brightness", "display-brightness-readout",
          "display-text-size", "display-workspaces",
          "display-save",
        ]
        for (const name of names) {
          if (findObject(first.panelItem, name) === null)
            return root.fail("missing Rise display control: " + name)
          if (findObject(second.panelItem, name) === null)
            return root.fail("missing second-output Rise display control: " + name)
        }
        const firstRotation = findObject(first.panelItem, "display-rotation")
        const secondRotation = findObject(second.panelItem, "display-rotation")
        if (firstRotation.width < 110 || secondRotation.width < 110)
          return root.fail("display rotation text is clipped: "
            + firstRotation.width + ", " + secondRotation.width)
        for (const panelItem of [first.panelItem, second.panelItem]) {
          const readout = findObject(panelItem, "display-brightness-readout")
          if (readout.x + readout.width > panelItem.width - 2)
            return root.fail("display brightness readout overflows: "
              + readout.x + "+" + readout.width + " > " + panelItem.width)
        }
        firstRotation.expanded = true
        secondRotation.expanded = true
        if (!first.panelItem.riseContent
            || first.panelItem.riseContent.expandedSelectCount !== 1
            || !second.panelItem.riseContent
            || second.panelItem.riseContent.expandedSelectCount !== 1)
          return root.fail("expanded Rise selects were not adapted to the panel: "
            + firstRotation.expanded + "/" + secondRotation.expanded + ", "
            + (first.panelItem.riseContent
              ? first.panelItem.riseContent.expandedSelectCount : "no fixture content")
            + "/" + (second.panelItem.riseContent
              ? second.panelItem.riseContent.expandedSelectCount : "no fixture content"))
        firstRotation.expanded = false
        secondRotation.expanded = false
        if (first.panelItem.riseContent.expandedSelectCount !== 0
            || second.panelItem.riseContent.expandedSelectCount !== 0)
          return root.fail("collapsed Rise selects were not released")
        const refresh = findObject(first.panelItem, "display-refresh")
        refresh.clicked()
        root.phase++
        root.phaseTicks = 0
      } else if (root.phase === 6) {
        if (root.phaseTicks < 3) return
        first.close()
        root.phase++
        root.phaseTicks = 0
      } else if (root.phase === 7) {
        if (root.phaseTicks < 3) return
        if (first.panelLoaded)
          return root.fail("first output-local display panel did not tear down")
        second.close()
        root.phase++
        root.phaseTicks = 0
      } else {
        if (root.phaseTicks < 3) return
        if (second.panelLoaded || root.clickTargets.length !== 2
            || sharedMonitorService._visualBarLeases.length !== 2
            || fakeBar.activePopout !== null)
          return root.fail("second output-local display panel did not tear down")
        firstLoader.active = false
        secondLoader.active = false
        Qt.callLater(function() {
          if (root.clickTargets.length !== 0
              || sharedMonitorService._visualBarLeases.length !== 0)
            return root.fail("click target/visual lease destruction cleanup")
          console.log("brightness plugin smoke passed")
          Qt.quit()
        })
        stop()
      }
    }
  }
}
