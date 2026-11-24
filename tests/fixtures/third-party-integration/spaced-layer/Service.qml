import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  visible: false
  WlrLayershell . namespace: "shinigami-bar"
  WlrLayershell.layer: WlrLayer.Top
}
