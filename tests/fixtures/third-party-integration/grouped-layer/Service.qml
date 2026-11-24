import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  visible: false
  WlrLayershell {
    namespace: "shinigami-bar"
    layer: WlrLayer.Top
  }
}
