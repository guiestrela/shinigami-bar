pragma ComponentBehavior: Bound

import QtQuick

// Minimal Rise host facade for the wallpaper-manager presentation. The picker
// service remains owned by shinigami.quick-access.
QtObject {
  id: riseRoot

  required property var host
  readonly property var tokens: host && host.tokens ? host.tokens : null

  readonly property bool modWallpapers: !!host && host.picker !== null
  readonly property real pillH: token("pillHeight", 28)
  readonly property real pillRadius: token("pillRadius", 12)
  readonly property color pill: token("pill", "transparent")
  readonly property color pillBorder: token("pillBorder", "transparent")
  readonly property real pillBorderW: token("pillBorderWidth", 0)
  readonly property color fillIdle: token("fillIdle", "transparent")
  readonly property color ink: host && host.widgetInk ? host.widgetInk : token("ink", "white")
  readonly property color widgetIconColor: ink
  readonly property color seal: host && host.widgetInk ? host.widgetInk : token("seal", "white")
  readonly property bool wallpaperManagerVisible: !!host && host.opened
  readonly property bool styleShadow: !!tokens && tokens.shadowEnabled === true
  readonly property string barPosition: host && host.bar ? String(host.bar.position) : "top"
  readonly property color pillShadow: token("pillShadow", "transparent")
  readonly property bool barUnlocked: false

  function widgetContentColor(groupId, fallback) {
    return tokens ? tokens.widgetContentColor(host.settings, fallback) : fallback
  }

  function widgetHasFill(groupId) {
    return !!tokens && tokens.widgetHasFill(host.settings)
  }

  function token(name, fallback) {
    if (!tokens) return fallback
    var value = tokens[name]
    return value === undefined || value === null ? fallback : value
  }

  readonly property QtObject wallpaperManagerServiceApi: QtObject {
    function nextAll() {
      if (!host || !host.picker) return false
      return typeof host.picker.nextWallpaperAll === "function"
        ? host.picker.nextWallpaperAll() : false
    }
  }

  function toggleWallpaperManager(screen, owner) {
    if (host) host.toggle()
  }

  function showTooltip(owner, text) {
    if (host && host.bar && typeof host.bar.showTooltip === "function")
      host.bar.showTooltip(owner, text)
  }

  function hideTooltip(owner) {
    if (host && host.bar && typeof host.bar.hideTooltip === "function")
      host.bar.hideTooltip(owner)
  }
}
