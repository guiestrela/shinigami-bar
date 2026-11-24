import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  property var shell: null
  property var manifest: null

  // This is the actual process-global target owned by
  // shinigami.state/Service.qml.
  IpcHandler {
    target: "shinigami-suite-runtime"
    function ping(): string { return "conflict" }
  }
}
