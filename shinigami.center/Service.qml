pragma ComponentBehavior: Bound

import QtQuick
import "../shinigami.state/runtime" as SuiteRuntime

Item {
  id: root

  property var shell: null
  property var manifest: null
  SuiteRuntime.Provider {
    pluginId: "shinigami.center"
    implementationVersion: "0.0.1"
    owner: root
    host: root.shell
    manifest: root.manifest
  }
  property bool runtimeWeatherEnabled: true

  readonly property var clock: clockState
  readonly property var weather: weatherState

  visible: false
  width: 0
  height: 0

  ClockService { id: clockState }

  WeatherService {
    id: weatherState
    enabled: root.runtimeWeatherEnabled
  }
}
