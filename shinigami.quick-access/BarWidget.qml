pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons as Commons
import "../shinigami.state/lib/presentation" as Presentation

Item {
  id: root

  property var bar: null
  property string moduleName: "shinigami.quick-access"
  property var settings: ({})
  property var quickAccessServiceOverride: null
  property var targetScreenOverride: null
  property bool ownsWallpaperRequest: false
  Presentation.HostTokens { id: hostTokens; bar: root.bar }
  readonly property var tokens: bar && "visualTokens" in bar
    && bar.visualTokens ? bar.visualTokens : hostTokens
  readonly property color widgetInk: tokens
    && typeof tokens.widgetContentColor === "function"
    ? tokens.widgetContentColor(settings,
      bar ? bar.urgent : Commons.Color.accent)
    : (bar ? bar.urgent : Commons.Color.accent)
  readonly property bool iconOnly: tokens && tokens.v2Shell !== true
    && settings && settings.displayMode === "icon-only"
  readonly property string displayMode: iconOnly ? "full" : String(settings
    && settings.displayMode !== undefined ? settings.displayMode
    : (settings && settings.compact === true ? "icon" : "full"))
  readonly property bool compact: displayMode === "icon"
  readonly property bool textMode: displayMode === "text"
  readonly property var picker: quickAccessServiceOverride
    || (bar && bar.shell && typeof bar.shell.serviceFor === "function"
      ? bar.shell.serviceFor("shinigami.quick-access") : null)
  readonly property var targetWindow: root.QsWindow && root.QsWindow.window
    ? root.QsWindow.window : null
  readonly property var targetScreen: targetScreenOverride
    || (targetWindow ? targetWindow.screen : null)
  readonly property bool opened: picker && picker.opened
    && (picker.mode !== "wallpaper" || ownsWallpaperRequest)
    && picker.activeScreenName === (targetScreen ? String(targetScreen.name || "") : "")
  readonly property bool panelLoaded: opened

  visible: bar !== null && tokens !== null && picker !== null
  implicitWidth: visible ? actionRow.implicitWidth + 2 * tokens.pillPaddingX : 0
  implicitHeight: visible ? bar.barSize : 0

  function showTip(owner, text) {
    if (bar) bar.showTooltip(owner, text)
  }

  function hideTip(owner) {
    if (bar) bar.hideTooltip(owner)
  }

  function openMode(mode) {
    if (!picker) return false
    if (bar) bar.requestPopout(root)
    ownsWallpaperRequest = mode === "wallpaper"
    const accepted = picker.openMode(mode, targetScreen)
    if (!accepted) {
      ownsWallpaperRequest = false
      if (bar) bar.releasePopout(root)
    }
    return accepted
  }

  function toggleMode(mode) {
    if (!picker) return false
    if (opened && picker.mode === mode) {
      picker.close()
      return true
    }
    return openMode(mode)
  }

  function open() { return openMode("theme") }
  function close() { if (opened) picker.close() }
  function toggle() { return toggleMode("theme") }
  function closeForPopoutSwitch() { close() }

  function childPanelWidget(pluginId) {
    const id = String(pluginId || "")
    return id === "shinigami.picker" || id === "shinigami.media-browser"
      ? root : null
  }

  onOpenedChanged: {
    if (!opened) {
      ownsWallpaperRequest = false
      if (bar && typeof bar.releasePopout === "function") bar.releasePopout(root)
    }
  }
  Component.onDestruction: {
    if (bar && typeof bar.releasePopout === "function")
      bar.releasePopout(root)
    if (opened) close()
  }

  Presentation.PillSurface {
    tokenSource: root.tokens
    settings: root.settings
    v1AppearanceEnabled: true
    anchors.fill: parent
    anchors.topMargin: root.bar && !root.bar.vertical
      ? Math.round((parent.height - root.tokens.pillHeight) / 2) : 0
    anchors.bottomMargin: anchors.topMargin
    bar: root.bar
  }

  Row {
    id: actionRow
    anchors.centerIn: parent
    spacing: Commons.Style.space(4)

    ActionIcon {
      visible: root.displayMode === "full"
      icon: "collections"
      active: root.opened && root.picker.mediaMode
      tooltip: "Left: Screenshots  Right: Videos"
      onTriggered: function(button) {
        root.toggleMode(button === Qt.RightButton ? "videos" : "screenshots")
      }
    }

    ActionIcon {
      visible: root.displayMode !== "text"
      icon: "palette"
      active: root.opened && root.picker.mode === "theme"
      tooltip: "Themes"
      onTriggered: root.toggleMode("theme")
    }

    TextAction {
      visible: root.textMode
      label: "MEDIA"
      active: root.opened && root.picker.mediaMode
      tooltip: "Left: Screenshots  Right: Videos"
      onTriggered: function(button) {
        root.toggleMode(button === Qt.RightButton ? "videos" : "screenshots")
      }
    }

    TextAction {
      visible: root.textMode
      label: "THEME"
      active: root.opened && root.picker.mode === "theme"
      tooltip: "Themes"
      onTriggered: root.toggleMode("theme")
    }
  }

  component ActionIcon: Item {
    id: action
    required property string icon
    required property bool active
    required property string tooltip
    readonly property color iconColor: active ? root.widgetInk
      : Qt.rgba(root.widgetInk.r, root.widgetInk.g,
          root.widgetInk.b, 0.62)
    signal triggered(int button)

    implicitWidth: Commons.Style.space(22)
    implicitHeight: root.tokens ? root.tokens.slotHeight : Commons.Style.space(28)

    Presentation.BarGlyph {
      anchors.centerIn: parent
      text: action.icon
      optical: !root.bar || !root.bar.vertical
      color: action.iconColor
      font.pixelSize: 14
      font.weight: Font.Medium
      fill: action.active ? 1 : 0
      Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.showTip(action, action.tooltip)
      onExited: root.hideTip(action)
      onClicked: function(mouse) {
        root.hideTip(action)
        action.triggered(mouse.button)
      }
    }
  }

  component TextAction: Item {
    id: textAction

    required property string label
    required property bool active
    required property string tooltip
    signal triggered(int button)

    implicitWidth: actionLabel.implicitWidth + Commons.Style.space(4)
    implicitHeight: root.tokens
      ? root.tokens.slotHeight : Commons.Style.space(28)

    Presentation.IconText {
      id: actionLabel
      barText: true
      anchors.centerIn: parent
      text: textAction.label
      color: textAction.active ? root.widgetInk
        : Qt.rgba(root.widgetInk.r, root.widgetInk.g,
            root.widgetInk.b, 0.62)
      font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
      font.pixelSize: Commons.Style.font.caption
      font.weight: textAction.active ? Font.DemiBold : Font.Medium
      renderType: Text.NativeRendering
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.showTip(textAction, textAction.tooltip)
      onExited: root.hideTip(textAction)
      onClicked: function(mouse) {
        root.hideTip(textAction)
        textAction.triggered(mouse.button)
      }
    }
  }

}
