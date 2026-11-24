pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons
import "../shinigami.state/lib/presentation" as Presentation
import "rise/v1" as RiseV1
import "rise/v2" as RiseV2

Item {
  id: widgetRoot

  property var bar: null
  property string moduleName: "shinigami.indicators"
  property var settings: ({})

  Presentation.HostTokens { id: hostTokens; bar: widgetRoot.bar }
  readonly property var tokens: bar && "visualTokens" in bar && bar.visualTokens
    ? bar.visualTokens : hostTokens
  readonly property var statusService: bar && bar.shell
    && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("shinigami.status") : null
  readonly property bool modIndicators: statusService !== null
  readonly property bool barVertical: !!bar && bar.vertical
  readonly property string mono: bar ? bar.fontFamily : Commons.Style.font.family
  readonly property color ink: tokens && typeof tokens.widgetContentColor === "function"
    ? tokens.widgetContentColor(settings, bar ? bar.foreground : Commons.Color.foreground)
    : Commons.Color.foreground
  readonly property color seal: ink
  readonly property color widgetIconColor: ink
  readonly property real pillH: tokens.pillHeight
  readonly property real pillRadius: tokens.pillRadius
  readonly property color pill: tokens.pill
  readonly property color pillBorder: tokens.pillBorder
  readonly property real pillBorderW: tokens.pillBorderWidth
  readonly property bool styleShadow: tokens.shadowEnabled === true
  readonly property bool barUnlocked: false
  readonly property string barPosition: bar ? bar.position : "top"
  readonly property color pillShadow: tokens.pillShadow

  visible: !!bar && modIndicators
  implicitWidth: visible ? face.implicitWidth : 0
  implicitHeight: visible ? (barVertical ? face.implicitHeight : bar.barSize) : 0

  function widgetContentColor(groupId, fallback) {
    return ink
  }

  function showTooltip(owner, text) {
    if (bar) bar.showTooltip(owner, text)
  }

  function hideTooltip(owner) {
    if (bar) bar.hideTooltip(owner)
  }

  readonly property QtObject omarchyIndicators: QtObject {
    readonly property bool recording: !!widgetRoot.statusService && widgetRoot.statusService.recording
    readonly property bool silenced: !!widgetRoot.statusService && widgetRoot.statusService.notificationsSilenced
    readonly property bool awake: !!widgetRoot.statusService && widgetRoot.statusService.stayAwake
    readonly property bool voxtype: !!widgetRoot.statusService && widgetRoot.statusService.voxtypeActive
    readonly property bool voxtypeAvailable: !!widgetRoot.statusService && widgetRoot.statusService.voxtypeAvailable === true
    readonly property bool nightLight: !!widgetRoot.statusService && widgetRoot.statusService.nightLightActive === true
    readonly property bool nightLightAvailable: !!widgetRoot.statusService && !!widgetRoot.statusService.nightLightService
    readonly property bool remote: !!widgetRoot.statusService && widgetRoot.statusService.remoteSessionActive === true
    readonly property string remoteLabel: remote && widgetRoot.statusService.remoteSessionPeers.length
      ? "Remote session: " + widgetRoot.statusService.remoteSessionPeers.join(", ") : "Remote session"
    readonly property bool passwordless: !!widgetRoot.statusService && widgetRoot.statusService.passwordlessSudo === true
    readonly property bool passwordlessAvailable: !!widgetRoot.statusService && widgetRoot.statusService.passwordlessSudoAvailable === true
    readonly property bool reminders: !!widgetRoot.statusService && widgetRoot.statusService.reminderCount > 0
    readonly property bool remindersAvailable: !!widgetRoot.statusService && widgetRoot.statusService.remindersAvailable === true
    readonly property string reminderLabel: reminders ? widgetRoot.statusService.reminderTooltip : "Set a reminder"
    readonly property bool hasActive: recording || silenced || awake || voxtype || nightLight || remote
      || passwordless || reminders

    function activate(id, button) {
      const service = widgetRoot.statusService
      if (!service) return false
      switch (id) {
        case "ScreenRecording": return recording ? service.stopRecording() : service.openRecordingMenu()
        case "NightLight": return service.toggleNightLight()
        case "Reminder": return service.openReminder()
        case "PasswordlessSudo": return service.openPasswordlessSudo()
        case "Dnd": return service.toggleNotifications()
        case "StayAwake": return service.toggleStayAwake()
        case "Voxtype": return button === Qt.RightButton
          ? service.openVoxtypeConfig() : service.openVoxtypeModel()
      }
      return false
    }
  }

  Loader {
    id: face
    anchors.centerIn: parent
    active: widgetRoot.visible
    sourceComponent: widgetRoot.tokens.v2Shell === true ? v2 : v1
  }

  Component {
    id: v1
    RiseV1.IndicatorsWidget { root: widgetRoot }
  }

  Component {
    id: v2
    RiseV2.IndicatorsWidget { root: widgetRoot }
  }
}
