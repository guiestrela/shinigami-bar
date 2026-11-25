pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons as Commons
import "../shinigami.state/lib/presentation" as Presentation
import "rise" as Rise
import "rise/v1" as RiseV1
import "rise/v2" as RiseV2

Item {
  id: root

  property var bar: null
  property string moduleName: "shinigami.wallpaper-manager"
  property var settings: ({})
  property var quickAccessServiceOverride: null
  property var targetScreenOverride: null

  Presentation.HostTokens { id: hostTokens; bar: root.bar }
  readonly property var tokens: bar && "visualTokens" in bar && bar.visualTokens ? bar.visualTokens : hostTokens
  readonly property color widgetInk: tokens.widgetContentColor(settings,
    bar ? bar.foreground : Commons.Color.foreground)
  readonly property var picker: quickAccessServiceOverride
    || (bar && bar.shell && typeof bar.shell.serviceFor === "function"
      ? bar.shell.serviceFor("shinigami.quick-access") : null)
  readonly property var targetWindow: root.QsWindow ? root.QsWindow.window : null
  readonly property var targetScreen: targetScreenOverride
    || (targetWindow ? targetWindow.screen : null)
  readonly property string targetScreenName: targetScreen ? String(targetScreen.name || "") : ""
  readonly property bool opened: !!picker && picker.opened
    && picker.mode === "wallpaper" && picker.activeScreenName === targetScreenName

  visible: bar !== null && picker !== null
  implicitWidth: visible ? surface.implicitWidth : 0
  implicitHeight: visible ? (bar.vertical ? surface.implicitHeight : bar.barSize) : 0

  function open() {
    if (!picker) return false
    if (bar) bar.requestPopout(root, targetScreenName)
    const accepted = picker.openMode("wallpaper", targetScreen)
    if (!accepted && bar) bar.releasePopout(root, targetScreenName)
    return accepted
  }

  function close() {
    if (!opened) return false
    picker.close()
    return true
  }

  function toggle() { return opened ? close() : open() }
  function closeForPopoutSwitch() { return close() }

  function openSettings() {
    if (!bar || !targetScreenName) return false
    const provider = "io.github.guiestrela.wallpaperomarchymanager"
    if (typeof bar.summonBarWidget === "function"
        && bar.summonBarWidget(provider, targetScreenName)) return true
    return typeof bar.openConfigPage === "function"
      && bar.openConfigPage("plugins", targetScreenName)
  }

  onOpenedChanged: if (!opened && bar) bar.releasePopout(root, targetScreenName)
  Component.onDestruction: {
    close()
    if (bar) bar.releasePopout(root)
  }

  Rise.RiseRoot { id: riseRoot; host: root }

  Loader {
    id: surface
    anchors.centerIn: parent
    active: root.visible
    sourceComponent: root.tokens.v2Shell === true ? v2 : v1
  }

  Component {
    id: v1
    RiseV1.WallpaperManagerQuickWidget { root: riseRoot; screen: riseRoot.host.targetScreen }
  }

  Component {
    id: v2
    RiseV2.WallpaperManagerQuickWidget { root: riseRoot; screen: riseRoot.host.targetScreen }
  }
}
