pragma ComponentBehavior: Bound

import QtQuick

// Rise host facade for the OneDrive status widget and panel. All values are
// derived from the Shinigami bar tokens; the OneDrive coordinator is injected by
// the standalone OneDrive BarWidget.
QtObject {
  id: root

  required property var host
  required property var service
  readonly property var tokens: host && host.tokens ? host.tokens : null

  readonly property bool oneDriveVisible: !!host && host.oneDriveVisible === true
  readonly property bool modOneDrive: !!host && !!service
  readonly property real pillH: token("pillHeight", 28)
  readonly property real pillRadius: token("pillRadius", 12)
  readonly property color pill: token("pill", "transparent")
  readonly property color pillBorder: token("pillBorder", "transparent")
  readonly property real pillBorderW: token("pillBorderWidth", 0)
  readonly property color fillIdle: token("fillIdle", "transparent")
  readonly property color fillHover: token("fillHover", "transparent")
  readonly property color fillActive: token("fillActive", "transparent")
  readonly property color ink: host && host.panelInk ? host.panelInk : token("ink", "white")
  readonly property color seal: token("seal", "white")
  readonly property color sealRaw: seal
  readonly property color sumi: token("sumi", "gray")
  readonly property color sep: token("separator", "gray")
  readonly property color bg: token("paper", "black")
  readonly property color tooltipInk: token("ink", host && host.bar
    ? host.bar.foreground : "white")
  readonly property color tooltipBackground: host && host.bar
    && host.bar.background !== undefined
      ? host.bar.background : token("panelBackground", token("paper", "black"))
  readonly property string mono: host && host.bar
    ? String(host.bar.fontFamily || "") : ""
  readonly property real panelRadius: token("panelRadius", 12)
  readonly property real panelButtonRadius: token("tileRadius", 8)
  readonly property real panelOuterBorderW: token("panelBorderWidth", 0)
  readonly property color panelOuterBorderColor: token("panelBorder", "transparent")
  readonly property real tooltipRadius: token("tooltipRadius", 6)
  readonly property bool styleShadow: !!tokens && tokens.shadowEnabled === true
  readonly property string barPosition: host && host.bar
    ? String(host.bar.position || "") : "top"
  readonly property color pillShadow: token("pillShadow", "transparent")
  readonly property bool barUnlocked: false
  readonly property var oneDriveService: service

  function token(name, fallback) {
    if (!tokens) return fallback
    var value = tokens[name]
    return value === undefined || value === null ? fallback : value
  }

  function showOneDrive() {
    if (!host || typeof host.openOneDrive !== "function") return false
    return oneDriveVisible || host.openOneDrive("")
  }

  function hideOneDrive() {
    if (!host || typeof host.closeOneDrive !== "function") return false
    return host.closeOneDrive()
  }

  function toggleOneDrive() {
    return oneDriveVisible ? hideOneDrive() : showOneDrive()
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
