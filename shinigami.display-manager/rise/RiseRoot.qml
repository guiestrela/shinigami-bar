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

  function widgetHasFill() {
    return typeof host.tokens.widgetHasFill === "function"
      && host.tokens.widgetHasFill(host.settings)
  }
}
