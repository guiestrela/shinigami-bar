pragma ComponentBehavior: Bound

import QtQuick

// Rise clock presentation backed by the shared Center clock service.
QtObject {
  id: riseRoot

  required property var host
  readonly property var tokens: host && host.tokens ? host.tokens : null
  readonly property var clockService: host ? host.clock : null

  readonly property bool barVertical: !!(host && host.bar && host.bar.vertical)
  readonly property string mono: host && host.bar
    ? String(host.bar.fontFamily || "") : ""
  readonly property color ink: host && host.widgetInk ? host.widgetInk : token("ink", "white")
  readonly property color seal: host && host.widgetInk ? host.widgetInk : token("seal", "white")
  readonly property color widgetIconColor: ink
  readonly property real pillH: token("pillHeight", 28)
  readonly property real pillRadius: token("pillRadius", 12)
  readonly property color pill: token("pill", "transparent")
  readonly property color pillBorder: token("pillBorder", "transparent")
  readonly property real pillBorderW: token("pillBorderWidth", 0)
  readonly property bool styleShadow: !!tokens && tokens.shadowEnabled === true
  readonly property string barPosition: host && host.bar ? String(host.bar.position) : "top"
  readonly property color pillShadow: token("pillShadow", "transparent")
  readonly property bool barUnlocked: false
  readonly property bool clock12h: !!host && host.clock12h === true
  readonly property date clockDate: host && host.displayDate ? host.displayDate : new Date()

  function token(name, fallback) {
    if (!tokens) return fallback
    var value = tokens[name]
    return value === undefined || value === null ? fallback : value
  }


  function widgetContentColor(groupId, fallback) {
    if (!tokens || typeof tokens.widgetContentColor !== "function") return fallback
    return tokens.widgetContentColor(host ? host.childSettings(groupId) : ({}), fallback)
  }

  function widgetHasFill(groupId) {
    if (!tokens || typeof tokens.widgetHasFill !== "function") return false
    return tokens.widgetHasFill(host ? host.childSettings(groupId) : ({}))
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
