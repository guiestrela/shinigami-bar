import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
  property var shell: null
  property var manifest: null

  IpcHandler {
    target: "shinigami-suite"
    function ping(): string { return "conflict" }
  }

  // A literal representative of the real shinigami.bar BarPanel layer.
  // The integration gate must reject it before this surface can be created.
  PanelWindow {
    visible: false
    WlrLayershell.namespace: "shinigami-bar"
    WlrLayershell.layer: WlrLayer.Top
  }
}
