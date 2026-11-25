pragma ComponentBehavior: Bound

import QtQuick

QtObject {
  required property var host

  readonly property bool compact: host.compact
  readonly property bool modDisplayManager: host.monitorReady
  readonly property bool displayManagerVisible: host.opened
  readonly property color ink: host.widgetInk
  readonly property color seal: host.tokens.seal || ink
  readonly property string mono: host.bar ? host.bar.fontFamily : ""
  readonly property color widgetIconColor: ink
  readonly property string tooltipText: "Display Manager · click to configure monitors"

  function widgetContentColor(groupId, fallback) {
    return host && typeof host.widgetContentColor === "function"
      ? host.widgetContentColor(groupId, fallback) : fallback
  }

  function widgetHasFill(groupId) {
    return host && typeof host.widgetHasFill === "function"
      ? host.widgetHasFill(groupId) : false
  }
}
