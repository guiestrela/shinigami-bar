import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Dialogs as Dialogs
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../shinigami.state/lib/presentation" as Presentation

// Local Rise-style restyle; stock signal/click paths preserved.
// Bar icon + settings panel for the folder-backed background service.
//
// Persist through the scoped public plugin API. The shell remains the only
// configuration writer, without a subprocess and stale queued settings.
//
// The service reads the same entry back out of the scoped public bar config, so
// change reaches the wallpaper without a restart.
Panel {
  id: root
  moduleName: "shinigami.wallpaper-manager"
  ipcTarget: "shinigami.wallpaper-manager"
  manageIpc: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property bool perDisplay: setting("perDisplay", true) === true
  readonly property int intervalSec: Math.max(0, Number(setting("intervalSec", 0)) || 0)
  readonly property bool shuffleOnWake: setting("shuffleOnWake", false) === true
  // ---------------------------------------------------- per-display config

  readonly property bool perDisplayConfig: setting("perDisplayConfig", true) === true
  readonly property var displayConfig: setting("displayConfig", null)

  // Which display's settings the panel is showing. Empty means the shared
  // "all" entry, which is also what every display reads when the per-display
  // toggle is off.
  property string editing: ""

  // Must resolve exactly as editingTabLabel() does. `editing` stays empty until
  // a display tab is actually clicked, and falling back to "all" here while the
  // tab row already highlights the first display meant that a change made
  // before any click landed on the shared entry rather than on the display
  // shown as selected: the setting saved, the panel updated to match, and
  // nothing happened on screen.
  readonly property string editingKey: {
    if (!perDisplayConfig) return "all"
    var tabs = displayTabs()
    if (editing !== "" && tabs.indexOf(editing) !== -1) return editing
    return tabs.length ? tabs[0] : "all"
  }

  // The same resolution the service performs, so the panel shows what is
  // actually in effect rather than what was last typed. Legacy top-level
  // folder/recursive are the fallback, which is what makes an older settings
  // file open correctly instead of looking empty.
  function configFor(key) {
    var dc = displayConfig
    var c = (dc && typeof dc === "object" && dc[key] && typeof dc[key] === "object") ? dc[key] : null
    if (!c && dc && dc.all && typeof dc.all === "object") c = dc.all
    var pick = function(k, legacy) {
      return (c && c[k] !== undefined && c[k] !== null) ? c[k] : legacy
    }
    var mode = String(pick("mode", "shuffle"))
    var scaling = String(pick("scaling", "zoom"))
    var folder = String(pick("folder", setting("folder", "")))
    var pinned = String(pick("pinned", ""))
    if (folder.trim() === "") pinned = ""
    return {
      folder: folder,
      recursive: pick("recursive", setting("recursive", true)) === true,
      mode: mode === "single" ? "single" : "shuffle",
      pinned: pinned,
      scaling: ["zoom", "fitHeight", "fitWidth", "actual"].indexOf(scaling) !== -1 ? scaling : "zoom"
    }
  }

  readonly property var current: configFor(editingKey)
  readonly property string activeThemeFolder: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/backgrounds"

  function useActiveThemeFolder() {
    var dc = root.copyDisplayConfig()
    if (!dc[root.editingKey]) dc[root.editingKey] = root.configFor(root.editingKey)
    dc[root.editingKey].folder = root.activeThemeFolder
    // A pin from a custom directory does not belong to the newly selected folder.
    dc[root.editingKey].pinned = ""
    if (!root.persist("displayConfig", dc)) return false
    root.folderEdited = false
    // Also refresh when this same stable theme path was selected before.
    root.rescanNow()
    return true
  }

  // Writes the whole displayConfig back, because inline settings replace a key
  // rather than merging into it. Seeding from the resolved config also folds
  // any legacy top-level settings into the new shape on the first edit, which
  // is the only migration this needs.
  function copyDisplayConfig() {
    var dc = ({})
    var existing = displayConfig
    if (existing && typeof existing === "object") {
      for (var k in existing) {
        if (existing[k] && typeof existing[k] === "object") {
          var copy = ({})
          for (var f in existing[k]) copy[f] = existing[k][f]
          dc[k] = copy
        }
      }
    }
    return dc
  }

  function persistDisplay(key, value) {
    var dc = copyDisplayConfig()
    if (!dc[editingKey]) dc[editingKey] = configFor(editingKey)
    dc[editingKey][key] = value
    return persist("displayConfig", dc)
  }

  // When switching from per-display settings to one shared setting, preserve
  // the configuration currently shown in the panel. Submit both keys in one
  // inline update so a rejected write cannot leave the toggle half-applied.
  function setPerDisplayConfig(enabled) {
    enabled = enabled === true
    var updates = ({ perDisplayConfig: enabled })
    if (!enabled) {
      var dc = copyDisplayConfig()
      if (!dc.all || typeof dc.all !== "object") dc.all = configFor(editingKey)
      updates.displayConfig = dc
    }
    return persist(updates)
  }

  // Clearing a folder must also clear its pin. Otherwise the service still
  // considers the plugin active because a stale pinned path remains.
  function clearFolder() {
    var dc = copyDisplayConfig()
    if (!dc[editingKey]) dc[editingKey] = configFor(editingKey)
    dc[editingKey].folder = ""
    dc[editingKey].pinned = ""
    persist("displayConfig", dc)
  }

  readonly property var scalingOptions: [
    { key: "zoom", label: "Zoom" },
    { key: "fitHeight", label: "Fit ↕" },
    { key: "fitWidth", label: "Fit ↔" },
    { key: "actual", label: "Actual" }
  ]

  function scalingLabels() {
    var out = []
    for (var i = 0; i < scalingOptions.length; i++) out.push(scalingOptions[i].label)
    return out
  }

  function scalingLabelFor(key) {
    for (var i = 0; i < scalingOptions.length; i++)
      if (scalingOptions[i].key === key) return scalingOptions[i].label
    return "Zoom"
  }

  function scalingKeyFor(label) {
    for (var i = 0; i < scalingOptions.length; i++)
      if (scalingOptions[i].label === label) return scalingOptions[i].key
    return "zoom"
  }

  function displayTabs() {
    var out = []
    for (var i = 0; i < displays.length; i++)
      out.push(String(displays[i]))
    return out
  }

  function displayTabLabels() {
    return displayTabs()
  }

  function tabLabelToDisplay(label) {
    return String(label)
  }

  // Which group of settings is on show.
  property string tab: "displays"

  function tabLabel() {
    if (tab === "shuffling") return "Shuffling"
    return "Displays"
  }

  function editingTabLabel() {
    var tabs = displayTabs()
    return editing !== "" && tabs.indexOf(editing) !== -1 ? editing : (tabs.length ? tabs[0] : "")
  }

  // ------------------------------------------------------------- the picker

  property var pickerImages: []
  property int pickerRequestGeneration: 0
  property var activePickerRequest: null
  property var queuedPickerRequest: null
  property var pickerResultContext: null
  property string pickerOutput: ""

  // Listed by the widget rather than taken from the service's pool: the pool
  // holds only what the *service* is configured to use, and the picker has to
  // show the folder being edited, which may be a different display's.
  function loadPicker() {
    root.pickerRequestGeneration += 1
    var folder = root.safePath(root.current.folder)
    var request = {
      generation: root.pickerRequestGeneration,
      display: root.editingKey,
      folder: folder,
      recursive: root.current.recursive === true
    }
    root.pickerImages = []
    root.pickerResultContext = null
    if (folder === "") {
      root.queuedPickerRequest = null
      return
    }
    root.queuedPickerRequest = request
    if (!pickerProc.running) root.startPickerRequest(request)
  }

  function startPickerRequest(request) {
    if (!request || request.folder === "") return
    if (pickerProc.running) {
      root.queuedPickerRequest = request
      return
    }
    root.queuedPickerRequest = null
    root.activePickerRequest = request
    root.pickerOutput = ""
    var scanCommand = 'test -d "$1" || exit 0; exec timeout --kill-after=1s 15s find -P "$1" -xdev $2 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.bmp" -o -iname "*.webp" \\) -print0 2>/dev/null | LC_ALL=C grep -zav "[[:cntrl:]]" | LC_ALL=C.UTF-8 grep -zavP "[\\\\x{80}-\\\\x{9f}]" | tr "\\0" "\\n" | head -n 10000 | sort -u'
    pickerProc.command = ["bash", "-c", scanCommand,
      "wpm-picker", request.folder, request.recursive ? "-maxdepth 32" : "-maxdepth 1"]
    pickerProc.running = true
  }

  function pickerRequestIsCurrent(request) {
    if (!request || request.generation !== root.pickerRequestGeneration) return false
    var folder = root.safePath(root.current.folder)
    return folder !== "" && request.display === root.editingKey
      && request.folder === folder
      && request.recursive === (root.current.recursive === true)
  }

  function finishPickerRequest(request, text) {
    if (root.activePickerRequest && request
        && root.activePickerRequest.generation === request.generation)
      root.activePickerRequest = null

    if (root.pickerRequestIsCurrent(request)) {
      root.pickerImages = String(text || "").split(String.fromCharCode(10)).filter(function(p) { return p !== "" })
      root.pickerResultContext = request
    }

    var queued = root.queuedPickerRequest
    if (queued && root.pickerRequestIsCurrent(queued)) root.startPickerRequest(queued)
    else root.queuedPickerRequest = null
  }

  function selectPickerImage(path, request) {
    path = String(path || "")
    if (!path || !root.pickerRequestIsCurrent(request)
        || !root.pickerResultContext
        || root.pickerResultContext.generation !== request.generation
        || root.pickerImages.indexOf(path) === -1) return false
    return root.persistDisplay("pinned", path)
  }

  // Keep picker input consistent with the service. Control characters would
  // corrupt the newline-delimited result returned by find.
  function safePath(path) {
    var value = String(path || "").trim()
    if (value.length > 4096 || !value.startsWith("/") || /^[a-z][a-z0-9+.-]*:/i.test(value) || /[\u0000-\u001f\u007f-\u009f]/.test(value)) return ""
    return value
  }

  Process {
    id: pickerProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.pickerOutput = String(text || "")
    }
    onExited: function(exitCode, exitStatus) {
      var request = root.activePickerRequest
      var output = root.pickerOutput
      Qt.callLater(function() { root.finishPickerRequest(request, output) })
    }
  }

  // The picker shows the folder of whichever display is being edited, so it
  // has to reload when either changes -- not only when single mode is chosen.
  // Guarded: both fire while the component is still being built, before the
  // `current` binding has produced anything to read.
  onEditingChanged: if (current && current.mode === "single") loadPicker()
  onDisplayConfigChanged: if (current && current.mode === "single") loadPicker()

  // Read the outputs directly from Quickshell. The service also reports them
  // in its status payload, but waiting for that IPC response made the panel
  // show only the shared configuration while the service was still starting.
  readonly property var displays: {
    var out = []
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) {
      var name = String(screens[i] && screens[i].name || "")
      if (name !== "" && out.indexOf(name) === -1) out.push(name)
    }
    return out
  }

  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar && bar.fontFamily ? bar.fontFamily : Style.font.family

  // Follow the active Shinigami bar instead of the Commons control palette.
  readonly property var barTokens: bar && "visualTokens" in bar ? bar.visualTokens : null
  readonly property var shinigamiTokens: root.barTokens
  readonly property string tooltipShellStyle: root.barTokens
    && root.barTokens.shellStyle !== undefined
    ? String(root.barTokens.shellStyle) : "shinigami"
  readonly property color controlForeground: root.fg
  readonly property color controlBorderColor: root.barTokens
    && root.barTokens.separator !== undefined
    ? root.barTokens.separator : root.fg
  readonly property color controlFillColor: root.barTokens
    && root.barTokens.fillIdle !== undefined
    ? root.barTokens.fillIdle : Commons.Color.tooltip.background
  readonly property color panelAccent: barTokens ? barTokens.seal
    : (bar && bar.urgent ? bar.urgent : Commons.Color.accent)
  readonly property color panelInk: barTokens ? barTokens.ink : fg
  readonly property color panelMuted: barTokens && "sumiHi" in barTokens
    ? barTokens.sumiHi : Qt.lighter(Commons.Color.muted, 1.35)
  readonly property color panelSep: barTokens ? barTokens.separator
    : Qt.rgba(panelInk.r, panelInk.g, panelInk.b, 0.18)
  readonly property color panelFillIdle: barTokens ? barTokens.fillIdle
    : Qt.rgba(0, 0, 0, 0.12)
  readonly property color panelFillHover: barTokens ? barTokens.fillHover
    : Qt.rgba(panelAccent.r, panelAccent.g, panelAccent.b, 0.10)
  readonly property color panelFillActive: barTokens ? barTokens.fillActive
    : Qt.rgba(panelAccent.r, panelAccent.g, panelAccent.b, 0.18)
  readonly property int panelTileRadius: barTokens ? barTokens.tileRadius : 4

  // Rise-style controls that keep the stock widget's signals and click paths.
  // Every visual state is painted from the live Shinigami bar tokens.
  component RiseButton: Rectangle {
    id: riseButton

    property string text: ""
    property string iconText: ""
    property string tooltipText: ""
    property bool selected: false
    property bool active: false
    property bool hasCursor: false
    property bool focusable: false
    property bool bordered: false
    property color foreground: root.panelInk
    property color background: "transparent"
    property color accent: root.panelAccent
    property string fontFamily: root.fontFamily
    property real fontSize: Style.font.bodySmall
    property real iconSize: Style.font.icon
    property real iconRotation: 0
    property bool iconSpinning: false
    property real horizontalPadding: Style.space(12)
    property real verticalPadding: Style.space(6)
    property bool leftAlign: false
    // Explicit-width buttons can safely elide against their final width.
    // Implicit-width buttons must size from the text, or the Text width and
    // the button's implicitWidth form a binding loop that paints no label.
    property bool stretchText: false

    signal clicked()
    signal rightClicked()
    signal hovered(bool isHovered)

    readonly property bool riseHot: mouse.containsMouse || hasCursor || activeFocus
    readonly property color riseTextColor: selected || active ? accent : foreground
    readonly property real iconRoom: iconText !== ""
      ? riseIcon.implicitWidth + (text !== "" ? row.spacing : 0) : 0

    implicitWidth: row.implicitWidth + horizontalPadding * 2
    implicitHeight: Math.max(Style.space(30), row.implicitHeight + verticalPadding * 2)
    radius: root.panelTileRadius
    color: !enabled ? root.panelFillIdle
      : (selected || active) ? root.panelFillActive
      : riseHot ? root.panelFillHover
      : background.a > 0 ? background : root.panelFillIdle
    border.color: !enabled ? root.panelSep
      : (selected || active || riseHot) ? accent : root.panelSep
    border.width: 1
    opacity: enabled ? 1 : 0.5
    activeFocusOnTab: focusable

    Keys.onReturnPressed: if (focusable) riseButton.clicked()
    Keys.onEnterPressed: if (focusable) riseButton.clicked()
    Keys.onSpacePressed: if (focusable) riseButton.clicked()

    Behavior on color { ColorAnimation { duration: Style.duration(120) } }

    Presentation.ShinigamiPillToolTip {
      panel: root
      visible: root.tooltipShellStyle === "shinigami"
        && riseButton.tooltipText !== "" && mouse.containsMouse
      text: riseButton.tooltipText
    }

    Presentation.ShinigamiPanelToolTip {
      panel: root
      visible: root.tooltipShellStyle !== "shinigami"
        && riseButton.tooltipText !== "" && mouse.containsMouse
      text: riseButton.tooltipText
    }

    Row {
      id: row
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: riseButton.leftAlign ? parent.left : undefined
      anchors.leftMargin: riseButton.leftAlign ? riseButton.horizontalPadding : 0
      anchors.horizontalCenter: riseButton.leftAlign ? undefined : parent.horizontalCenter
      spacing: Style.space(6)

      Text {
        id: riseIcon
        visible: riseButton.iconText !== ""
        text: riseButton.iconText
        textFormat: Text.PlainText
        color: riseButton.riseTextColor
        font.family: riseButton.fontFamily
        font.pixelSize: riseButton.iconSize
        rotation: riseButton.iconRotation
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        visible: riseButton.text !== ""
        text: riseButton.text
        textFormat: Text.PlainText
        color: riseButton.riseTextColor
        font.family: riseButton.fontFamily
        font.pixelSize: riseButton.fontSize
        font.bold: riseButton.selected || riseButton.active
        width: riseButton.stretchText
          ? Math.max(0, Math.min(implicitWidth,
            riseButton.width - riseButton.horizontalPadding * 2 - riseButton.iconRoom))
          : implicitWidth
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: riseButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onEntered: riseButton.hovered(true)
      onExited: riseButton.hovered(false)
      onClicked: function(m) {
        if (riseButton.focusable) riseButton.forceActiveFocus()
        if (m.button === Qt.RightButton) riseButton.rightClicked()
        else riseButton.clicked()
      }
    }
  }

  component RiseButtonGroup: Row {
    id: group

    property var options: []
    property string value: ""
    property color foreground: root.panelInk
    property color accent: root.panelAccent
    property string fontFamily: root.fontFamily
    property real fontSize: Style.font.bodySmall
    property bool focusable: false
    property int cursorIndex: -1
    property int focusedIndex: -1

    signal changed(string selectedValue)
    signal hovered(int index, bool isHovered)

    spacing: Style.space(8)
    activeFocusOnTab: group.focusable

    function optionValue(o) {
      return (o && typeof o === "object") ? String(o.value) : String(o)
    }
    function optionLabel(o) {
      return (o && typeof o === "object" && o.label !== undefined) ? String(o.label) : String(o)
    }
    function optionIcon(o) {
      return (o && typeof o === "object" && o.icon) ? String(o.icon) : ""
    }
    function optionTooltip(o) {
      return (o && typeof o === "object" && o.tooltip) ? String(o.tooltip) : ""
    }
    function selectedIndex() {
      for (var i = 0; i < options.length; i++)
        if (optionValue(options[i]) === value) return i
      return -1
    }
    function activateFocused() {
      if (focusedIndex < 0 || focusedIndex >= options.length) return
      group.changed(optionValue(options[focusedIndex]))
    }

    onActiveFocusChanged: {
      focusedIndex = activeFocus ? Math.max(0, selectedIndex()) : -1
    }

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Left) {
        focusedIndex = Math.max(0, (focusedIndex < 0 ? 0 : focusedIndex) - 1)
        event.accepted = true
      } else if (event.key === Qt.Key_Right) {
        focusedIndex = Math.min(options.length - 1,
          (focusedIndex < 0 ? 0 : focusedIndex) + 1)
        event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
          || event.key === Qt.Key_Space) {
        activateFocused()
        event.accepted = true
      }
    }

    Repeater {
      model: group.options

      RiseButton {
        required property var modelData
        required property int index

        text: group.optionLabel(modelData)
        iconText: group.optionIcon(modelData)
        tooltipText: group.optionTooltip(modelData)
        selected: group.optionValue(modelData) === group.value
        hasCursor: group.cursorIndex === index
          || (group.activeFocus && group.focusedIndex === index)
        foreground: group.foreground
        accent: group.accent
        fontFamily: group.fontFamily
        fontSize: group.fontSize
        onClicked: group.changed(group.optionValue(modelData))
        onHovered: function(h) { group.hovered(index, h) }
      }
    }
  }

  component RiseToggle: Rectangle {
    id: riseToggle

    property string label: ""
    property string description: ""
    property bool checked: false
    property bool hasCursor: false
    property color foreground: root.panelInk
    property color accent: root.panelAccent
    property string fontFamily: root.fontFamily

    signal clicked()
    signal hovered(bool isHovered)

    readonly property bool riseHot: rowMouse.containsMouse || trackMouse.containsMouse || hasCursor

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(Style.space(54), labels.implicitHeight + Style.space(18))
    radius: root.panelTileRadius
    color: !enabled ? root.panelFillIdle
      : checked ? root.panelFillActive
      : riseHot ? root.panelFillHover
      : root.panelFillIdle
    border.color: !enabled ? root.panelSep
      : checked || riseHot ? accent : root.panelSep
    border.width: 1
    opacity: enabled ? 1 : 0.5
    activeFocusOnTab: true

    Behavior on color { ColorAnimation { duration: Style.duration(120) } }
    Behavior on border.color { ColorAnimation { duration: Style.duration(120) } }

    Keys.onReturnPressed: if (enabled) riseToggle.clicked()
    Keys.onEnterPressed: if (enabled) riseToggle.clicked()
    Keys.onSpacePressed: if (enabled) riseToggle.clicked()

    Column {
      id: labels
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - Style.space(80)
      spacing: Style.space(4)

      Text {
        width: parent.width
        text: riseToggle.label
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: riseToggle.foreground
        font.family: riseToggle.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        visible: riseToggle.description !== ""
        width: parent.width
        text: riseToggle.description
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: root.panelMuted
        font.family: riseToggle.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Rectangle {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(50)
      height: Style.space(22)
      radius: height / 2
      color: riseToggle.checked ? root.panelFillActive
        : (trackMouse.containsMouse || riseToggle.hasCursor)
          ? root.panelFillHover : root.panelFillIdle
      border.color: riseToggle.checked || trackMouse.containsMouse || riseToggle.hasCursor
        ? riseToggle.accent : root.panelSep
      border.width: 1

      Text {
        anchors.centerIn: parent
        text: riseToggle.checked ? "ON" : "OFF"
        color: riseToggle.checked ? riseToggle.accent : root.panelMuted
        font.family: riseToggle.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: riseToggle.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: riseToggle.hovered(true)
      onExited: riseToggle.hovered(false)
      onClicked: if (riseToggle.enabled) riseToggle.clicked()
    }

    MouseArea {
      id: trackMouse
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(50)
      height: Style.space(22)
      hoverEnabled: true
      cursorShape: riseToggle.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: riseToggle.hovered(true)
      onExited: riseToggle.hovered(false)
      onClicked: if (riseToggle.enabled) riseToggle.clicked()
    }
  }

  component RiseTextField: TextField {
    id: riseField
    foreground: root.panelInk
    accent: root.panelAccent
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    color: foreground
    selectionColor: Qt.rgba(accent.r, accent.g, accent.b, 0.35)
    selectedTextColor: foreground
    placeholderTextColor: root.panelMuted

    background: Rectangle {
      readonly property bool hot: riseField.hovered || riseField.hasCursor
      color: riseField.activeFocus ? root.panelFillActive
        : hot ? root.panelFillHover : root.panelFillIdle
      border.color: riseField.activeFocus || hot ? accent : root.panelSep
      border.width: 1
      radius: root.panelTileRadius
    }
  }

  component RiseNumberField: NumberField {
    id: riseNumber
    foreground: root.panelInk
    accent: root.panelAccent
    fontFamily: root.fontFamily
    fontSize: Style.font.bodySmall

    field.background: Rectangle {
      readonly property bool hot: fieldHover.hovered || riseNumber.hasCursor
      color: riseNumber.field.activeFocus ? root.panelFillActive
        : hot ? root.panelFillHover : root.panelFillIdle
      border.color: riseNumber.field.activeFocus || hot ? accent : root.panelSep
      border.width: 1
      radius: root.panelTileRadius

      HoverHandler {
        id: fieldHover
        onHoveredChanged: riseNumber.hovered(hovered)
      }
    }
  }

  component RiseSectionHeader: PanelSectionHeader {
    foreground: root.panelInk
    color: root.panelMuted
    fontFamily: root.fontFamily
    fontSize: Style.font.caption
  }

  component RiseSeparator: PanelSeparator {
    foreground: root.panelInk
    strength: 0.18
  }

  property int poolSize: -1
  property var screenPicks: ({})
  property var nextPicks: ({})

  property int skipped: 0

  // PluginBarApi deliberately exposes a scoped PluginShellApi, not the host's
  // registry. Read the local manifest instead of traversing a private API that
  // is not present in the third-party plugin boundary.
  property string manifestVersion: ""
  readonly property string version: manifestVersion

  FileView {
    id: manifestFile
    path: String(Qt.resolvedUrl("manifest.json")).replace(/^file:\/\//, "")
    watchChanges: false
    printErrors: false
    onLoaded: {
      try {
        var data = JSON.parse(manifestFile.text())
        root.manifestVersion = data && data.version !== undefined ? String(data.version) : ""
      } catch (e) {
        root.manifestVersion = ""
      }
    }
    onLoadFailed: root.manifestVersion = ""
  }

  // Which display keys are in play. Before the service has reported its
  // outputs -- and whenever displays share one configuration -- that is the
  // single "all" entry.
  function displayKeysInUse() {
    if (!perDisplayConfig || !displays.length) return ["all"]
    var out = []
    for (var i = 0; i < displays.length; i++) out.push(String(displays[i]))
    return out
  }

  // Whether there is a next image to fetch at all. A display in single mode
  // keeps its pinned image, so with every display pinned -- or with no folder
  // set -- the button would do nothing and is hidden instead.
  readonly property bool canAdvance: {
    var keys = displayKeysInUse()
    for (var i = 0; i < keys.length; i++) {
      var c = configFor(keys[i])
      if (c.mode === "shuffle" && String(c.folder).trim() !== "") return true
    }
    return false
  }

  readonly property bool anyFolderSet: {
    var keys = displayKeysInUse()
    for (var i = 0; i < keys.length; i++)
      if (String(configFor(keys[i]).folder).trim() !== "") return true
    return false
  }

  // Sorted, because the service reports its outputs in whatever order
  // Quickshell hands them over and a card that reorders itself between
  // restarts is hard to read.
  readonly property var nextEntries: {
    var names = []
    for (var n in nextPicks) names.push(n)
    names.sort()
    var out = []
    for (var i = 0; i < names.length; i++) {
      var p = String(nextPicks[names[i]] || "")
      if (p === "") continue
      out.push({ screen: names[i], path: p, file: p.substring(p.lastIndexOf("/") + 1) })
    }
    return out
  }

      readonly property string previewTitle: "Wallpapers" + (version === "" ? "" : " v" + version)

  // Only when there is nothing to list; otherwise the images speak for
  // themselves.
  readonly property string previewNote: {
    if (!canAdvance)
      return anyFolderSet
        ? "Every display is pinned to one image."
        : "Using the default backgrounds."
    if (!nextEntries.length) return "No images to deal yet."
    return ""
  }

  readonly property string statusLine: {
    if (settingsError !== "") return settingsError
    if (current.folder === "") return "No folder set — using the default backgrounds."
    if (poolSize < 0) return "Scanning…"
    if (poolSize === 0)
      return skipped > 0
        ? "No usable images — " + skipped + (skipped === 1 ? " file" : " files")
          + " could not be decoded."
        : "No images found in that folder."
    var line = poolSize + (poolSize === 1 ? " image" : " images") + " found."
    if (skipped > 0)
      line += " " + skipped + (skipped === 1 ? " image was" : " images were")
        + " skipped as undecodable; rescan to retry."
    return line
  }

  // ------------------------------------------------------------- persistence

  property string settingsError: ""

  function persist(key, value) {
    var api = root.bar ? root.bar.shell : null
    if (!api || typeof api.updateEntryInline !== "function") {
      root.settingsError = "Cannot save settings: the Omarchy plugin API is unavailable."
      return false
    }
    var entry = ({})
    for (var name in root.settings) entry[name] = root.settings[name]
    entry.id = root.moduleName
    if (key && typeof key === "object") {
      for (var update in key) entry[update] = key[update]
    } else {
      entry[key] = value
    }
    // The host returns false for an unchanged entry, not just a rejected write.
    if (JSON.stringify(entry) === JSON.stringify(root.settings)) {
      root.settingsError = ""
      return true
    }
    try {
      if (!api.updateEntryInline(root.moduleName, entry)) {
        root.settingsError = "Omarchy rejected the wallpaper settings."
        return false
      }
    } catch (error) {
      root.settingsError = "Could not save wallpaper settings."
      return false
    }
    root.settings = entry
    root.settingsError = ""
    refreshTimer.restart()
    return true
  }

  // ------------------------------------------------------------------ status

  // quiet leaves poolSize alone: the hover refresh below runs behind an open
  // panel, and resetting it there would flash "Scanning…" over a count that
  // was already correct.
  function refreshStatus(quiet) {
    if (statusProc.running) return
    if (quiet !== true) root.poolSize = -1
    statusProc.running = true
  }

  // No -q here: the omarchy-shell wrapper's quiet mode suppresses stdout
  // entirely, so the reply would arrive as an empty string and parse into a
  // poolSize of 0 — the panel would report "no images found" for a folder
  // that had just scanned hundreds. Quiet mode is only right for the
  // fire-and-forget calls below, whose output nobody reads.
  Process {
    id: statusProc
    command: ["omarchy-shell", "background", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw === "") return
        var data = null
        try { data = JSON.parse(raw) } catch (e) { return }
        if (!data || data.poolSize === undefined) return
        root.poolSize = Number(data.poolSize)
        root.skipped = Number(data.skipped || 0)
        root.screenPicks = data.screens || ({})
        root.nextPicks = data.next || ({})
      }
    }
  }

  // Settings land asynchronously (write -> shell.json -> service rescan), so
  // give the service a beat before asking it what it found.
  Timer {
    id: refreshTimer
    interval: 400
    repeat: false
    onTriggered: root.refreshStatus()
  }

  // ----------------------------------------------------------------- actions

  function browse() {
    root.folderEdited = false
    // Release layer-shell focus before opening the native folder dialog.
    root.close()
    folderDialog.currentFolder = Util.fileUrl(root.current.folder || Quickshell.env("HOME"))
    folderDialog.open()
  }

  function acceptFolderUrl(url) {
    var raw = String(url || "")
    if (!raw.startsWith("file:///")) return false
    var picked
    try { picked = safePath(decodeURIComponent(raw.substring(7))) }
    catch (error) { return false }
    if (!picked) return false
    root.folderEdited = false
    return root.persistDisplay("folder", picked)
  }

  Dialogs.FolderDialog {
    id: folderDialog
    title: "Choose a wallpaper folder"
    onAccepted: {
      if (!root.acceptFolderUrl(selectedFolder))
        root.settingsError = "Could not save the selected local folder."
      root.open()
    }
    onRejected: root.open()
  }

  // Quickshell.execDetached with an argv array, NOT Util.execDetached: that
  // helper takes a command *string* and wraps it in `bash -lc`, so an array
  // silently stringifies to "omarchy-shell,-q,background,next" and the button
  // does nothing.
  //
  // "next", not "shuffle": the pool is dealt from a queue that only reshuffles
  // once it empties, so this hands out the following image rather than
  // re-randomising what is left. It is a no-op when nothing shuffles.
  function nextImage() {
    Quickshell.execDetached(["omarchy-shell", "-q", "background", "next"])
    refreshTimer.restart()
  }

  function rescanNow() {
    Quickshell.execDetached(["omarchy-shell", "-q", "background", "rescan"])
    refreshTimer.restart()
  }

  // True only while the user has typed something not yet committed. Guards the
  // field's write-back so it can never resurrect a stale path.
  property bool folderEdited: false

  // The setting changes from more places than this field: the file dialog, the
  // CLI, or this same panel on another monitor. Mirror it back unless the user
  // is part-way through typing something else.
  // The folder can change from the file dialog, the CLI, or by switching to
  // another display's tab. Mirror it back unless the user is mid-edit.
  onCurrentChanged: if (!folderEdited && folderField) folderField.text = current.folder

  onOpenedChanged: if (opened) {
    folderEdited = false
    folderField.text = root.current.folder
    refreshStatus()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function isPrimaryIpcScreen(screenName, screens) {
    if (!screenName || !screens || screens.length === 0) return false
    return String(screenName) === String(screens[0].name || "")
  }

  function ownsIpcTarget() {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screen = window ? window.screen : null
    return isPrimaryIpcScreen(screen ? screen.name : "", Quickshell.screens)
  }

  // The bar is instantiated once per screen. Its own summon/hide routing selects
  // the focused screen, while this legacy IPC target is registered only once.
  ShellIpc {
    enabled: root.ownsIpcTarget()
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function next(): string { root.nextImage(); return "ok" }
    function shuffle(): string { root.nextImage(); return "ok" }
  }

  BarIconButton {
    id: button
    objectName: "wallpaper-bar-button"
    anchors.fill: parent
    bar: root.bar
    text: "󰸉"
    // Match the panel's Shinigami accent in both idle and active states.
    foreground: root.panelAccent
    activeColor: root.panelAccent
    // No tooltipText: the bar's tooltip is a single line of text, and the card
    // below shows the images instead.
    active: root.opened
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.nextImage()
      else root.toggle()
    }
  }

  // ------------------------------------------------------------ hover preview
  //
  // A card of our own rather than the bar's tooltip, which takes text and
  // nothing else. Being our own popup also keeps it out of the bar's popout
  // coordinator, which closes whatever panel is open when a new one is
  // requested -- fine for a click, wrong for a pointer merely crossing an icon.
  property bool previewShown: false

  Timer {
    id: previewDelay
    interval: 400
    repeat: false
    onTriggered: root.previewShown = button.tooltipHovered && !root.opened
  }

  Timer {
    id: previewHideDelay
    interval: 250
    repeat: false
    onTriggered: root.previewShown = !root.opened && (button.tooltipHovered || previewMouse.containsMouse)
  }

  Connections {
    target: button
    function onTooltipHoveredChanged() {
      if (!button.tooltipHovered) {
        previewDelay.stop()
        previewHideDelay.restart()
        return
      }
      previewHideDelay.stop()
      // The images go stale as soon as anything shuffles; the reply lands well
      // inside the delay below.
      root.refreshStatus(true)
      previewDelay.restart()
    }
  }

  PopupWindow {
    id: preview

    readonly property var anchorWindow: button.QsWindow ? button.QsWindow.window : null
    readonly property int gap: Style.space(6)
    readonly property string barPosition: root.bar ? root.bar.position : "top"

    visible: root.previewShown && !root.opened && !!anchorWindow
    color: "transparent"
    implicitWidth: Math.ceil(previewCard.implicitWidth)
    implicitHeight: Math.ceil(previewCard.implicitHeight)

    // The placement the bar gives its own tooltip: off the bar's inner edge,
    // centred on the icon, slid back inside the screen rather than hanging
    // over an edge.
    anchor {
      id: previewAnchor
      window: preview.anchorWindow
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1

      onAnchoring: {
        var window = preview.anchorWindow
        if (!window) return

        var w = preview.implicitWidth
        var h = preview.implicitHeight
        var localX = button.width / 2 - w / 2
        var localY = button.height + preview.gap

        if (preview.barPosition === "bottom") {
          localY = -h - preview.gap
        } else if (preview.barPosition === "left") {
          localX = button.width + preview.gap
          localY = button.height / 2 - h / 2
        } else if (preview.barPosition === "right") {
          localX = -w - preview.gap
          localY = button.height / 2 - h / 2
        }

        var point = window.contentItem.mapFromItem(button, localX, localY)
        if (preview.barPosition === "top" || preview.barPosition === "bottom")
          point.x = Math.max(preview.gap, Math.min(point.x, window.width - w - preview.gap))
        else
          point.y = Math.max(preview.gap, Math.min(point.y, window.height - h - preview.gap))

        previewAnchor.rect.x = Math.round(point.x)
        previewAnchor.rect.y = Math.round(point.y)
      }
    }

    RectangularShadow {
      anchors.fill: previewCard
      visible: !!root.barTokens && root.barTokens.shellStyle === "shinigami"
        && root.barTokens.shadowEnabled === true
      radius: previewCard.radius
      blur: 8
      spread: 0
      offset: Qt.vector2d(0, preview.barPosition === "bottom" ? -1 : 1)
      color: root.barTokens && root.barTokens.pillShadow !== undefined
        ? root.barTokens.pillShadow : "transparent"
      z: -1
    }

    BorderSurface {
      id: previewCard

      readonly property color text: root.panelInk
      readonly property color dim: root.panelMuted

      implicitWidth: previewColumn.width + contentLeftInset + contentRightInset
      implicitHeight: previewColumn.implicitHeight + contentTopInset + contentBottomInset
      padding: Style.space(10)
      color: root.barTokens ? root.barTokens.panelBackground
        : Commons.Color.tooltip.background
      borderSpec: root.barTokens
        ? Commons.Border.flat(root.barTokens.panelBorder, root.barTokens.panelBorderWidth)
        : Border.surfaceSpec("tooltip", "border", Commons.Color.tooltip.border, 1)
      radius: root.barTokens ? root.barTokens.tooltipRadius : Style.cornerRadius

      MouseArea {
        id: previewMouse
        objectName: "preview-middle-click"
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        hoverEnabled: true
        onEntered: previewHideDelay.stop()
        onExited: previewHideDelay.restart()
        onClicked: root.nextImage()
      }

      Column {
        id: previewColumn
        x: previewCard.contentLeftInset
        y: previewCard.contentTopInset
        width: Style.space(250)
        spacing: Style.space(8)

        Text {
          text: root.previewTitle
          color: previewCard.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Text {
          visible: root.previewNote !== ""
          width: parent.width
          text: root.previewNote
          color: previewCard.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          visible: root.nextEntries.length > 0
          text: "Next Images"
          color: previewCard.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: root.nextEntries

          Row {
            id: entry
            required property var modelData
            width: previewColumn.width
            spacing: Style.space(8)

            // Decoded at thumbnail size, not full resolution: a 4K wallpaper
            // decoded to fill 90 pixels would cost tens of megabytes to draw
            // something the size of a postage stamp.
            Rectangle {
              width: Style.space(90)
              height: Math.round(width * 9 / 16)
              color: "transparent"
              clip: true

              WallpaperRenderer {
                anchors.fill: parent
                sourcePath: entry.modelData.path
                fillModeName: "zoom"
                loadMedia: preview.visible
                playing: false
              }
            }

            Column {
              width: previewColumn.width - Style.space(98)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: entry.modelData.screen
                textFormat: Text.PlainText
                color: previewCard.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: entry.modelData.file
                textFormat: Text.PlainText
                color: previewCard.text
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideMiddle
              }
            }
          }
        }

        Text {
          visible: root.canAdvance
          width: parent.width
          text: "middle click to change to next image"
          color: previewCard.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    // fittedContentHeight clamps the card to the screen; the Flickable below
    // keeps the remaining controls reachable at the narrower Rise width.
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // Typing in the folder field must reach the field, not the panel's
      // single-key shortcuts.
      blocked: folderField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "n" || t === "N") root.nextImage()
        else if (t === "r" || t === "R") root.rescanNow()
        else if (t === "b" || t === "B") root.browse()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: column
          width: parent.width
          spacing: Style.space(12)

        Item {
          width: parent.width
          height: Style.space(24)

          Text {
            objectName: "wallpaper-manager-title"
            anchors.left: parent.left
            anchors.right: closeText.left
            anchors.rightMargin: Style.space(12)
            text: "Wallpapers"
            textFormat: Text.PlainText
            color: root.panelInk
            font.family: root.fontFamily
            font.pixelSize: 13
            font.letterSpacing: 2
            font.weight: Font.Medium
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }

          Text {
            id: closeText
            objectName: "wallpaper-manager-close"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "✕"
            textFormat: Text.PlainText
            color: closeMouse.containsMouse ? root.panelAccent : root.panelMuted
            font.family: root.fontFamily
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: Style.duration(120) } }

            MouseArea {
              id: closeMouse
              anchors.fill: parent
              anchors.margins: -8
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }
          }
        }

        RiseSeparator {}

        // Two groups of settings, one visible at a time. The panel outgrew a
        // single scroll of controls once displays could be configured
        // individually, and the cap on its height is a clamp rather than a
        // viewport -- content past it spills outside the border instead of
        // becoming reachable.
        RiseButtonGroup {
          width: parent.width
          options: ["Displays", "Shuffling"]
          value: root.tabLabel()
          foreground: root.panelInk
          accent: root.panelAccent
          fontFamily: root.fontFamily
          onChanged: function(v) { root.tab = String(v).toLowerCase() }
        }

        // ═══════════════════════════════════════════════════════ displays

        Column {
          visible: root.tab === "displays"
          width: parent.width
          spacing: Style.space(12)

          RiseToggle {
            width: parent.width
            label: "Configure each display separately"
            description: "Off: one configuration shared by every display."
            checked: root.perDisplayConfig
            foreground: root.panelInk
            accent: root.panelAccent
            fontFamily: root.fontFamily
            onClicked: root.setPerDisplayConfig(!root.perDisplayConfig)
          }

          RiseButtonGroup {
            visible: root.perDisplayConfig && root.displays.length > 0
            width: parent.width
            options: root.displayTabLabels()
            value: root.editingTabLabel()
            foreground: root.panelInk
            accent: root.panelAccent
            fontFamily: root.fontFamily
            onChanged: function(v) { root.editing = root.tabLabelToDisplay(v) }
          }

          Text {
            visible: !root.perDisplayConfig
            width: parent.width
            text: "All displays"
            color: root.panelMuted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          RiseToggle {
            // With each display configured separately this has no meaning:
            // every display already draws from its own folder.
            visible: !root.perDisplayConfig
            width: parent.width
            label: "Different image per display"
            description: "Off mirrors one image across every display."
            checked: root.perDisplay
            foreground: root.panelInk
            accent: root.panelAccent
            fontFamily: root.fontFamily
            onClicked: root.persist("perDisplay", !root.perDisplay)
          }

          Text {
            width: parent.width
            text: "Displays set to Single keep their image and are left alone."
            color: root.panelMuted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          RiseSectionHeader {
            text: "FOLDER"
            foreground: root.panelInk
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            RiseTextField {
              id: folderField
              width: parent.width - browseButton.implicitWidth - parent.spacing
              foreground: root.panelInk
              accent: root.panelAccent
              placeholderText: "~/Pictures/wallpapers"
              // Only a keystroke counts as an edit. Assigning text from the
              // setting must not arm the write-back.
              onTextChanged: if (activeFocus) root.folderEdited = true
              onAccepted: {
                root.folderEdited = false
                root.persistDisplay("folder", text.trim())
              }
              // editingFinished fires on any focus loss, including the panel
              // being dismissed because the file dialog took focus. Writing
              // back unconditionally there is what made Browse… look broken:
              // the field still held the old path and overwrote the one just
              // chosen.
              onEditingFinished: {
                if (!root.folderEdited) return
                root.folderEdited = false
                if (text.trim() !== root.current.folder) root.persistDisplay("folder", text.trim())
              }
            }

            RiseButton {
              id: browseButton
              text: "Browse…"
              bordered: true
              foreground: root.panelInk
              accent: root.panelAccent
              fontFamily: root.fontFamily
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.browse()
            }
          }

          RiseButton {
            objectName: "use-active-theme-folder"
            text: "Use active theme folder"
            tooltipText: root.activeThemeFolder
            bordered: true
            leftAlign: true
            stretchText: true
            width: parent.width
            foreground: root.panelInk
            accent: root.panelAccent
            fontFamily: root.fontFamily
            onClicked: root.useActiveThemeFolder()
          }

          Text {
            width: parent.width
            text: root.statusLine
            color: root.panelMuted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          RiseButton {
            visible: root.current.folder !== ""
            text: "Clear folder (use default backgrounds)"
            bordered: true
            leftAlign: true
            stretchText: true
            width: parent.width
            foreground: root.panelInk
            accent: root.panelAccent
            fontFamily: root.fontFamily
            onClicked: root.clearFolder()
          }

          RiseToggle {
            width: parent.width
            label: "Search subfolders"
            description: "Include images nested below the chosen folder."
            checked: root.current.recursive
            foreground: root.panelInk
            accent: root.panelAccent
            fontFamily: root.fontFamily
            onClicked: root.persistDisplay("recursive", !root.current.recursive)
          }

          RiseSectionHeader {
            text: "MODE"
            foreground: root.panelInk
            fontFamily: root.fontFamily
          }

          RiseButtonGroup {
            width: parent.width
            options: ["Shuffle", "Single"]
            value: root.current.mode === "single" ? "Single" : "Shuffle"
            foreground: root.panelInk
            accent: root.panelAccent
            fontFamily: root.fontFamily
            onChanged: function(v) {
              var mode = String(v).toLowerCase()
              root.persistDisplay("mode", mode)
              if (mode === "single") root.loadPicker()
            }
          }

          // The picker. Thumbnails come straight off disk, and GridView only
          // instantiates the delegates in view, so a folder of hundreds costs
          // a screenful of decodes rather than hundreds.
          Rectangle {
            visible: root.current.mode === "single"
            width: parent.width
            height: Style.space(220)
            color: "transparent"
            border.width: Style.normalBorderWidth
            border.color: root.panelSep

            GridView {
              id: picker
              anchors.fill: parent
              anchors.margins: Style.space(4)
              clip: true
              cellWidth: Math.floor((width - 1) / 3)
              cellHeight: Math.round(cellWidth * 9 / 16)
              model: root.pickerImages

              delegate: Item {
                id: pickerItem
                required property var modelData
                property var requestContext: root.pickerResultContext
                width: picker.cellWidth
                height: picker.cellHeight

                WallpaperRenderer {
                  anchors.fill: parent
                  anchors.margins: Style.space(3)
                  sourcePath: modelData
                  fillModeName: "zoom"
                  loadMedia: root.opened && root.tab === "displays" && root.current.mode === "single"
                  playing: false
                  clip: true

                  Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: Style.normalBorderWidth * 2
                    border.color: root.panelAccent
                    visible: root.current.pinned === modelData
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectPickerImage(String(modelData), pickerItem.requestContext)
                }
              }
            }
          }

          Text {
            visible: root.current.mode === "single"
            width: parent.width
            text: root.current.pinned === ""
              ? "No image chosen yet."
              : root.current.pinned.substring(root.current.pinned.lastIndexOf("/") + 1)
            textFormat: Text.PlainText
            color: root.panelMuted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideMiddle
          }

          RiseSectionHeader {
            text: "SCALING"
            foreground: root.panelInk
            fontFamily: root.fontFamily
          }

          RiseButtonGroup {
            width: parent.width
            options: root.scalingLabels()
            value: root.scalingLabelFor(root.current.scaling)
            foreground: root.panelInk
            accent: root.panelAccent
            fontFamily: root.fontFamily
            onChanged: function(v) { root.persistDisplay("scaling", root.scalingKeyFor(v)) }
          }
        }

        // ══════════════════════════════════════════════════════ shuffling

        Column {
          visible: root.tab === "shuffling"
          width: parent.width
          spacing: Style.space(12)

          RiseNumberField {
            label: "Auto-shuffle every (seconds, 0 = off)"
            value: root.intervalSec
            from: 0
            to: 86400
            stepSize: 60
            foreground: root.panelInk
            accent: root.panelAccent
            fontFamily: root.fontFamily
            onModified: function(v) { root.persist("intervalSec", v) }
          }

          RiseToggle {
            width: parent.width
            label: "Shuffle on unlock or wake"
            description: "Shuffle on wake is unavailable: Omarchy isolates lock and idle services from plugins."
            enabled: false
            checked: root.shuffleOnWake
            foreground: root.panelInk
            accent: root.panelAccent
            fontFamily: root.fontFamily
            onClicked: root.persist("shuffleOnWake", !root.shuffleOnWake)
          }

        }

        // ════════════════════════════════════════════ always visible

        RiseSeparator {}

        Row {
          width: parent.width
          spacing: Style.space(8)

          // Hidden rather than disabled when every display is pinned: there is
          // no next image to fetch, and a greyed button invites a click that
          // was never going to do anything.
          RiseButton {
            visible: root.canAdvance
            text: "Next image"
            bordered: true
            foreground: root.panelInk
            accent: root.panelAccent
            fontFamily: root.fontFamily
            onClicked: root.nextImage()
          }

          RiseButton {
            text: "Rescan"
            bordered: true
            foreground: root.panelInk
            accent: root.panelAccent
            fontFamily: root.fontFamily
            onClicked: root.rescanNow()
          }

        }

        Column {
          width: parent.width
          spacing: Style.space(2)

          Repeater {
            model: {
              var out = []
              for (var name in root.screenPicks) {
                var p = String(root.screenPicks[name] || "")
                out.push({ screen: name, file: p.substring(p.lastIndexOf("/") + 1) })
              }
              return out
            }
            Text {
              required property var modelData
              width: column.width
              text: modelData.screen + "  ·  " + modelData.file
              textFormat: Text.PlainText
              color: root.panelMuted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideMiddle
            }
          }
        }
      }
      }
    }
  }
}
