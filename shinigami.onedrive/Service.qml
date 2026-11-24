pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../shinigami.state/runtime" as SuiteRuntime
import "integration/Model.js" as Model

// One process-wide owner for the OneDrive coordinator and its notification IPC.
// Screen-local BarWidgets are presentation only: the service selects the active
// output, so every OmaOneDrive notification maps to exactly one panel.
Item {
  id: root

  property var shell: null
  property var manifest: null
  SuiteRuntime.Provider {
    pluginId: "shinigami.onedrive"
    implementationVersion: "0.2.5"
    owner: root
    host: root.shell
    manifest: root.manifest
  }

  property bool oneDriveVisible: false
  property string oneDriveOpenTarget: ""
  property var activeScreen: null
  readonly property string activeScreenName: activeScreen
    ? String(activeScreen.name || "") : ""

  // Tests may substitute an isolated screen list; production follows the
  // public reactive Quickshell screen collection.
  property var screenListOverride: null
  readonly property var screens: screenListOverride !== null
    ? screenListOverride : Quickshell.screens

  readonly property var oneDriveService: adapter
  property alias pollingEnabled: adapter.pollingEnabled
  property alias settings: adapter.settings
  OneDriveService {
    id: adapter
    owner: root
  }

  function screenForName(value) {
    const name = String(value || "")
    if (name === "") return null
    const currentScreens = screens || []
    for (let index = 0; index < currentScreens.length; index++) {
      const candidate = currentScreens[index]
      if (candidate && String(candidate.name || "") === name) return candidate
    }
    return null
  }

  function resolveTargetScreen(preferred) {
    const preferredName = preferred ? String(preferred.name || "") : ""
    const explicit = screenForName(preferredName)
    if (explicit) return explicit
    const focusedName = Hyprland.focusedMonitor
      ? String(Hyprland.focusedMonitor.name || "") : ""
    const focused = screenForName(focusedName)
    if (focused) return focused
    const currentScreens = screens || []
    for (let index = 0; index < currentScreens.length; index++) {
      const candidate = currentScreens[index]
      if (candidate && String(candidate.name || "") !== "") return candidate
    }
    return null
  }

  function activateFocusedPopupScreen() {
    const target = resolveTargetScreen(null)
    if (!target) return false
    activeScreen = target
    return true
  }

  function activeTargetPresent() {
    if (!oneDriveVisible) return true
    return activeScreen !== null && activeScreenName !== ""
      && screenForName(activeScreenName) === activeScreen
  }

  function closeIfTargetMissing() {
    if (oneDriveVisible && !activeTargetPresent()) close()
  }

  function openPanel(target, screen) {
    const targetScreen = resolveTargetScreen(screen)
    if (!targetScreen) return false
    oneDriveOpenTarget = String(target || "")
    activeScreen = targetScreen
    oneDriveVisible = true
    return true
  }

  function takeOneDriveOpenTarget() {
    const target = oneDriveOpenTarget
    oneDriveOpenTarget = ""
    return target
  }

  function close() {
    if (!oneDriveVisible && oneDriveOpenTarget === "") return false
    oneDriveVisible = false
    oneDriveOpenTarget = ""
    activeScreen = null
    return true
  }

  function toggle(screen) {
    if (oneDriveVisible) return close()
    return openPanel("", screen)
  }

  onScreensChanged: closeIfTargetMissing()

  // OmaOneDrive notifications carry this exact target. Owning it here keeps a
  // single IPC receiver and a single coordinator for the whole process.
  IpcHandler {
    target: "io.github.salemsayed.omaonedrive"

    function open(): void { root.openPanel("") }
    function show(): void { root.openPanel("") }
    function close(): void { root.close() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle(null) }
    function refresh(): void { adapter.refresh(false) }
    function check(): void { adapter.checkQuota() }
    function fullStatus(): void { adapter.checkFullStatus() }
    function pause(): string { return adapter.pause() }
    function pauseFor(minutes: int): string { return adapter.pauseFor(minutes) }
    function resume(): string { return adapter.resume() }
    function toggleSync(): string { return adapter.toggleRunning() }
    function folder(): void { adapter.openFolder() }
    function web(): void { adapter.openWeb() }
    function resync(): void { adapter.repairResync() }
    function status(): string { return adapter.statusText }
    function accounts(): string {
      return JSON.stringify(Model.accountRows(adapter.accounts,
        adapter.selectedService))
    }
    function selectAccount(target: string): string {
      const found = Model.resolveAccountTarget(adapter.accounts, target)
      if (!found) return "unknown account: " + target
      adapter.selectAccount(found, false)
      return "ok"
    }
    function openAccount(target: string): void { root.openPanel(target) }
    function repairAccount(target: string): void {
      adapter.repairFromNotification(target)
    }
  }
}
