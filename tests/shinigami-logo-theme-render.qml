import QtQuick
import QtQuick.Window

Window {
  id: window
  visible: true
  width: 80
  height: 60
  color: "transparent"
  property var logo: null
  property int darkWaitAttempts: 0
  property int lightWaitAttempts: 0

  Loader {
    id: logoLoader
    x: 31
    y: 21
    width: 18
    height: 18
    source: "__COMPONENT_URL__"
    onLoaded: {
      window.logo = item
      window.logo.accent = "#ef4444"
      window.logo.ink = "#f4f4f5"
      darkWait.start()
    }
  }

  Timer {
    id: darkWait
    interval: 40
    repeat: true
    onTriggered: {
      if (!window.logo || !window.logo.ready) {
        window.darkWaitAttempts += 1
        if (window.darkWaitAttempts > 100) {
          console.error("theme logo did not load and paint both Qt PNG masks")
          Qt.exit(1)
        }
        return
      }
      stop()
      window.logo.grabToImage(function(result) {
        if (!result.saveToFile("__DARK_CAPTURE__")) {
          console.error("dark theme logo capture failed")
          Qt.exit(2)
          return
        }
        window.logo.accent = "#2563eb"
        window.logo.ink = "#1f2937"
        lightWait.start()
      }, Qt.size(18, 18))
    }
  }

  Timer {
    id: lightWait
    interval: 40
    repeat: true
    onTriggered: {
      window.lightWaitAttempts += 1
      if (window.lightWaitAttempts < 6) return
      stop()
      window.logo.grabToImage(function(result) {
        if (!result.saveToFile("__LIGHT_CAPTURE__")) {
          console.error("light theme logo capture failed")
          Qt.exit(3)
          return
        }
        console.log("production logo rendered in both palettes at 18x18")
        Qt.quit()
      }, Qt.size(18, 18))
    }
  }
}
