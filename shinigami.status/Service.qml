pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../shinigami.state/runtime" as SuiteRuntime

// One process-wide adapter over Quattro-owned status backends. Bar views never
// instantiate their own pollers, so multiple monitors consume the same state.
Item {
  id: root

  property var shell: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var manifest: null
  SuiteRuntime.HostShell { id: suiteShell; host: root.shell }
  SuiteRuntime.Provider {
    pluginId: "shinigami.status"
    implementationVersion: "0.2.5"
    owner: root
    host: root.shell
    manifest: root.manifest
  }
  property var actionRunner: null
  property bool runtimeProbesEnabled: true

  readonly property var idleService: suiteShell.firstPartyServiceFor("omarchy.idle")
  readonly property var nightLightService: suiteShell.firstPartyServiceFor("omarchy.nightlight")
  readonly property var remoteSessionService: suiteShell.firstPartyServiceFor("omarchy.remote-session")
  readonly property var notificationService: notificationAdapter.available
    ? notificationAdapter : null
  readonly property bool idleAvailable: !!idleService
  readonly property bool notificationsAvailable: notificationAdapter.available
  readonly property bool stayAwake: idleService
    ? idleService.stayAwake === true : false
  readonly property bool notificationsSilenced: notificationService
    ? notificationService.doNotDisturb === true : false
  readonly property bool nightLightActive: !!nightLightService && nightLightService.enabled === true
  readonly property bool remoteSessionActive: !!remoteSessionService && remoteSessionService.active === true
  readonly property var remoteSessionPeers: remoteSessionService && Array.isArray(remoteSessionService.peers)
    ? remoteSessionService.peers : []

  NotificationAdapter {
    id: notificationAdapter
    omarchyPath: root.omarchyPath
  }

  onShellChanged: notificationAdapter.attachShell(suiteShell)
  Component.onCompleted: notificationAdapter.attachShell(suiteShell)
  Connections {
    target: suiteShell.scoped ? SuiteRuntime.Runtime : null
    function onRevisionChanged() { notificationAdapter.attachShell(suiteShell) }
  }

  property string recordingPid: ""
  property int recordingElapsed: 0
  property int recordingBaseElapsed: 0
  property double recordingBaseMs: 0
  property bool recordingRefreshPending: false
  readonly property bool recording: recordingPid !== ""

  property string voxtypeState: "idle"
  property string voxtypeHint: ""
  property bool voxtypeAvailable: false
  property bool voxtypeRetryEnabled: true
  readonly property bool voxtypeActive: voxtypeState === "recording"
    || voxtypeState === "transcribing"
  property bool passwordlessSudo: false
  property bool passwordlessSudoAvailable: false
  property int reminderCount: 0
  property bool remindersAvailable: false
  property string reminderTooltip: ""
  function refreshIndicators() {
    if (!runtimeProbesEnabled) return
    sudoStatus.running = true
    reminderStatus.running = true
    if (remoteSessionService && typeof remoteSessionService.refresh === "function")
      remoteSessionService.refresh()
  }

  function openReminder() {
    if (!remindersAvailable) return false
    return launch(reminderCount > 0 ? ["omarchy-reminder", "show"] : ["omarchy-reminder", "-i"])
  }

  function openPasswordlessSudo() {
    if (!passwordlessSudoAvailable) return false
    if (!passwordlessSudo) return launch([
      "omarchy-launch-floating-terminal-with-presentation", "omarchy-sudo-passwordless"
    ])
    if (sudoDisable.running) return false
    if (actionRunner && typeof actionRunner.run === "function")
      return launch(sudoDisable.command)
    sudoDisable.running = true
    return true
  }

  function toggleStayAwake() {
    if (!idleService || typeof idleService.setIdleEnabled !== "function") return false
    idleService.setIdleEnabled(stayAwake)
    return true
  }

  function toggleNotifications() {
    if (!notificationService
        || typeof notificationService.setDoNotDisturb !== "function") return false
    notificationService.setDoNotDisturb(!notificationsSilenced)
    return true
  }

  function stopRecording() {
    if (!recording) return false
    launch(["omarchy-capture-screenrecording", "--stop-recording"])
    if (runtimeProbesEnabled) recordingRetry.restart()
    return true
  }

  function openRecordingMenu() {
    return launch(["omarchy-menu", "toggle", "trigger.capture.screenrecord"])
  }

  function toggleNightLight() {
    if (!nightLightService || typeof nightLightService.setNightlight !== "function") return false
    nightLightService.setNightlight(!nightLightActive)
    return true
  }

  function openVoxtypeModel() {
    launch(["omarchy-voxtype-model"])
    return true
  }

  function openVoxtypeConfig() {
    launch(["omarchy-voxtype-config"])
    return true
  }

  function launch(command) {
    if (actionRunner && typeof actionRunner.run === "function")
      return actionRunner.run(command) !== false
    actionLauncher.command = command
    actionLauncher.startDetached()
    return true
  }

  Timer {
    interval: 60000
    running: root.runtimeProbesEnabled
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshIndicators()
  }

  Process {
    id: sudoStatus
    command: ["bash", "-c", "command -v omarchy-sudo-passwordless >/dev/null || exit 69; exec omarchy-sudo-passwordless --active"]
    onExited: function(code, exitStatus) {
      const completed = exitStatus === 0
      root.passwordlessSudo = completed && code === 0
      // Omarchy 4.5 returns 1 when passwordless sudo is inactive.
      root.passwordlessSudoAvailable = completed && (code === 0 || code === 1 || code === 3)
    }
  }

  Process {
    id: sudoDisable
    command: ["omarchy-sudo-passwordless", "--disable"]
    onExited: root.refreshIndicators()
  }

  Process {
    id: reminderStatus
    command: ["omarchy-reminder", "show", "--json"]
    stdout: StdioCollector { id: reminderOutput }
    onExited: function(code) {
      let value = null
      if (code === 0 && reminderOutput.text.length <= 32768) {
        try { value = JSON.parse(reminderOutput.text) } catch (error) {}
      }
      root.remindersAvailable = !!value && Number.isInteger(value.count) && value.count >= 0
        && typeof value.tooltip === "string"
      root.reminderCount = root.remindersAvailable ? Math.min(10000, value.count) : 0
      root.reminderTooltip = root.remindersAvailable ? value.tooltip.slice(0, 500) : ""
    }
  }

  function refreshRecording() {
    if (!runtimeProbesEnabled) return
    if (recordingProbe.running) {
      recordingRefreshPending = true
      return
    }
    recordingProbe.running = true
  }

  function setRecordingPid(value) {
    const next = String(value || "").trim()
    if (next === recordingPid) return
    recordingPid = next
    recordingElapsed = 0
    recordingBaseElapsed = 0
    recordingBaseMs = next ? Date.now() : 0
    if (!next) return
    recordingElapsedProbe.command = ["ps", "-o", "etimes=", "-p", next]
    recordingElapsedProbe.running = true
  }

  function updateRecordingElapsed() {
    if (!recording || recordingBaseMs <= 0) return
    recordingElapsed = recordingBaseElapsed
      + Math.floor((Date.now() - recordingBaseMs) / 1000)
  }

  function updateVoxtype(raw) {
    try {
      const data = JSON.parse(String(raw || "{}"))
      const next = String(data.alt || data.class || "idle")
      voxtypeState = next === "recording" || next === "transcribing"
        ? next : "idle"
      voxtypeHint = String(data.tooltip || "").split("\n")[0]
      voxtypeAvailable = true
    } catch (error) {
      voxtypeState = "idle"
      voxtypeHint = ""
    }
  }

  FileView {
    id: recordingState
    path: "/tmp/omarchy-screenrecord-filename"
    watchChanges: root.runtimeProbesEnabled
    printErrors: false
    onFileChanged: {
      reload()
      root.refreshRecording()
      recordingRetry.restart()
    }
    onLoaded: root.refreshRecording()
    onLoadFailed: root.refreshRecording()
  }

  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/omarchy-screenrecord-filename"
    watchChanges: root.runtimeProbesEnabled
    printErrors: false
    onFileChanged: { reload(); root.refreshRecording(); recordingRetry.restart() }
    onLoaded: root.refreshRecording()
    onLoadFailed: root.refreshRecording()
  }

  // Markers survive video finalization; pidwait observes exit without polling.
  Process {
    command: ["pidwait", "-p", root.recordingPid]
    running: root.runtimeProbesEnabled && root.recordingPid !== ""
    onExited: { root.refreshRecording(); recordingRetry.restart() }
  }

  Process {
    id: recordingProbe
    command: ["pgrep", "-o", "-f", "^(gpu-screen-recorder|wf-recorder)( |$)"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.setRecordingPid(text)
    }
    onExited: {
      if (!root.recordingRefreshPending) return
      root.recordingRefreshPending = false
      Qt.callLater(root.refreshRecording)
    }
  }

  Process {
    id: recordingElapsedProbe
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const seconds = Math.max(0, parseInt(String(text || "").trim()) || 0)
        root.recordingBaseElapsed = seconds
        root.recordingElapsed = seconds
        root.recordingBaseMs = Date.now()
      }
    }
  }

  Timer {
    interval: 45000
    running: root.runtimeProbesEnabled
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshRecording()
  }

  Timer {
    id: recordingRetry
    interval: 900
    onTriggered: root.refreshRecording()
  }

  Timer {
    interval: 1000
    running: root.runtimeProbesEnabled && root.recording
    repeat: true
    triggeredOnStart: true
    onTriggered: root.updateRecordingElapsed()
  }

  Process {
    id: voxtypeStatus
    command: ["bash", "-c", "if command -v omarchy-voxtype-status >/dev/null 2>&1; then exec omarchy-voxtype-status; elif command -v voxtype >/dev/null 2>&1; then exec setpriv --pdeathsig TERM voxtype status --follow --extended --format json; else exit 69; fi"]
    running: root.runtimeProbesEnabled
    stdout: SplitParser {
      onRead: function(data) { root.updateVoxtype(data) }
    }
    onExited: function(exitCode) {
      root.voxtypeRetryEnabled = exitCode !== 69
      root.voxtypeAvailable = false
      root.voxtypeState = "idle"
      root.voxtypeHint = ""
    }
  }

  Timer {
    interval: 60000
    running: root.runtimeProbesEnabled && root.voxtypeRetryEnabled && !voxtypeStatus.running
    repeat: true
    onTriggered: voxtypeStatus.running = true
  }

  Process { id: actionLauncher }
}
