import QtQuick
import Quickshell
import "onedrive" as OneDrive

ShellRoot {
  id: root

  property int phase: 0
  property int ticks: 0
  property var targetScreen: ({ name: "target-output" })
  property var otherScreen: ({ name: "other-output" })

  function fail(message) {
    console.error("onedrive-plugin-smoke:", message)
    Qt.exit(1)
  }

  function check(condition, message) {
    if (!condition) fail(message)
  }

  QtObject {
    id: fakeShell
    function serviceFor(pluginId) {
      return pluginId === "shinigami.onedrive" ? standaloneService : null
    }
  }

  QtObject {
    id: fakeBar
    property bool vertical: false
    property int barSize: 35
    property string position: "top"
    property string fontFamily: "monospace"
    property color foreground: "#eeeeee"
    property color urgent: "#88bbee"
    property var activePopout: null
    property var shell: fakeShell
    property var visualTokens: ({
      shellStyle: "shinigami",
      v2Shell: false,
      pillHeight: 24,
      pillRadius: 12,
      pillPaddingX: 9,
      pillBorderWidth: 1,
      shadowEnabled: false,
      pill: "#332f2f",
      pillBorder: "#555050",
      pillShadow: "#000000",
      separator: "#555050",
      paper: "#111116",
      seal: "#eeeeee",
      sumi: "#999999"
    })

    function showTooltip(_owner, _text) {}
    function hideTooltip(_owner) {}
    function requestPopout(owner) { activePopout = owner }
    function releasePopout(owner) { if (activePopout === owner) activePopout = null }
    function switchPanelFrom(_owner, _direction) { return false }
    function targetBelongsToWindow(_target, _window) { return true }
  }

  OneDrive.Service {
    id: standaloneService
    pollingEnabled: false
    screenListOverride: [root.targetScreen, root.otherScreen]
  }

  Loader {
    id: otherWidget
    active: true
    sourceComponent: Component {
      OneDrive.BarWidget {
        bar: fakeBar
        settings: ({ compact: false })
        oneDriveServiceOverride: standaloneService
        targetScreenOverride: root.otherScreen
      }
    }
  }

  Timer {
    interval: 40
    repeat: true
    running: true
    onTriggered: root.tick()
  }

  function tick() {
    ticks++
    check(ticks < 40, "OneDrive output routing smoke deadline exceeded")

    if (phase === 0) {
      check(!!otherWidget.item, "BarWidget did not load")
      check(otherWidget.item.oneDriveService === standaloneService.oneDriveService,
        "BarWidget did not borrow the process-wide OneDrive adapter")
      check(!otherWidget.item.oneDriveVisible,
        "OneDrive panel started visible without an IPC target")
      check(standaloneService.openPanel("account-fixture", root.targetScreen),
        "service could not open the OneDrive panel on the target output")
      phase = 1
      return
    }

    if (phase === 1) {
      check(standaloneService.activeScreenName === "target-output",
        "service selected the wrong active output")
      check(otherWidget.item.oneDriveVisible === false,
        "non-target BarWidget exposed a duplicate OneDrive panel")
      check(standaloneService.takeOneDriveOpenTarget() === "account-fixture",
        "service did not keep the pending account target for the target output")
      check(standaloneService.oneDriveOpenTarget === "",
        "service retained a consumed account target")
      standaloneService.screenListOverride = [root.otherScreen]
      phase = 2
      return
    }

    check(standaloneService.oneDriveVisible === false,
      "removed output did not retire the OneDrive panel")
    check(otherWidget.item.oneDriveVisible === false,
      "remaining output still reports a retired panel")
    console.log("onedrive plugin smoke passed")
    Qt.exit(0)
  }
}
