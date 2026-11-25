pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Commons as Commons

// Rise-parity precipitation map. Esri imagery and RainViewer tiles are loaded
// lazily while the weather panel is open. Coordinates come from the existing
// weather location; no additional geocoder or location daemon is introduced.
Item {
  id: radar

  required property var hostPanel
  property real latitude: NaN
  property real longitude: NaN
  property string radarHost: "https://tilecache.rainviewer.com"
  property string radarPath: ""
  property real zoom: 7
  readonly property int minZoom: 4
  readonly property int maxZoom: 12
  readonly property int radarMaxZoom: 7
  readonly property int tileZoom: Math.floor(zoom)
  readonly property real zoomScale: Math.pow(2, zoom - tileZoom)
  readonly property bool located: isFinite(latitude) && isFinite(longitude)
  readonly property bool tilesActive: !!panel && panel.open === true && located

  implicitWidth: 276
  implicitHeight: 209

  function tileX() {
    return Math.floor((longitude + 180) / 360 * Math.pow(2, tileZoom))
  }

  function tileY() {
    const lat = Math.max(-85, Math.min(85, latitude)) * Math.PI / 180
    return Math.floor((1 - Math.log(Math.tan(lat) + 1 / Math.cos(lat)) / Math.PI)
      / 2 * Math.pow(2, tileZoom))
  }

  function pixelOffsetX() {
    return ((longitude + 180) / 360 * Math.pow(2, tileZoom) * 256)
      - tileX() * 256
  }

  function pixelOffsetY() {
    const lat = Math.max(-85, Math.min(85, latitude)) * Math.PI / 180
    const count = Math.pow(2, tileZoom)
    const worldY = (1 - Math.log(Math.tan(lat) + 1 / Math.cos(lat)) / Math.PI)
      / 2 * count * 256
    return worldY - tileY() * 256
  }

  function setZoom(value) {
    zoom = Math.max(minZoom, Math.min(maxZoom, Math.round(value * 4) / 4))
  }

  property Process metadataProcess: Process {
    id: radarMetadata
    command: ["curl", "-fsS", "--max-time", "8",
      "https://api.rainviewer.com/public/weather-maps.json"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(String(this.text || ""))
          const frames = data.radar && data.radar.past ? data.radar.past : []
          const frame = frames.length ? frames[frames.length - 1] : null
          const host = String(data.host || "")
          const path = String(frame && frame.path || "")
          if (/^https:\/\/(?:[A-Za-z0-9-]+\.)*rainviewer\.com(?::443)?$/.test(host)
              && /^\/v2\/radar\/[A-Za-z0-9_-]+$/.test(path)) {
            radar.radarHost = host
            radar.radarPath = path
          }
        } catch (_error) {}
      }
    }
  }

  Timer {
    interval: 600000
    running: radar.tilesActive && radar.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!radarMetadata.running) radarMetadata.running = true
  }

  Column {
    anchors.fill: parent
    spacing: 5

    Item {
      width: parent.width
      height: 14

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "RAINVIEWER RADAR · ESRI IMAGERY"
        color: radar.hostPanel.controlMutedHigh
        font.family: radar.hostPanel.bar ? radar.hostPanel.bar.fontFamily
          : Commons.Style.font.family
        font.pixelSize: 9
        font.letterSpacing: 1
        renderType: Text.NativeRendering
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
          text: radar.located ? "Z" + Number(radar.zoom).toFixed(2).replace(/\.00$/, "")
            : "LOCATION UNKNOWN"
          color: radar.hostPanel.controlMuted
          font.family: radar.hostPanel.bar ? radar.hostPanel.bar.fontFamily
            : Commons.Style.font.family
          font.pixelSize: 8
          renderType: Text.NativeRendering
        }

        Rectangle {
          width: 16
          height: 14
          radius: radar.hostPanel.controlRadius
          color: zoomOutMouse.containsMouse
            ? radar.hostPanel.controlHoverFillColor : radar.hostPanel.controlFillColor
          border.color: radar.hostPanel.controlBorderColor
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "−"
            color: radar.hostPanel.controlForeground
            font.family: radar.hostPanel.bar ? radar.hostPanel.bar.fontFamily
              : Commons.Style.font.family
            font.pixelSize: 11
            renderType: Text.NativeRendering
          }

          MouseArea {
            id: zoomOutMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: radar.zoom > radar.minZoom
            onClicked: radar.setZoom(radar.zoom - 0.25)
          }
        }

        Rectangle {
          width: 16
          height: 14
          radius: radar.hostPanel.controlRadius
          color: zoomInMouse.containsMouse
            ? radar.hostPanel.controlHoverFillColor : radar.hostPanel.controlFillColor
          border.color: radar.hostPanel.controlBorderColor
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "+"
            color: radar.hostPanel.controlForeground
            font.family: radar.hostPanel.bar ? radar.hostPanel.bar.fontFamily
              : Commons.Style.font.family
            font.pixelSize: 11
            renderType: Text.NativeRendering
          }

          MouseArea {
            id: zoomInMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: radar.zoom < radar.maxZoom
            onClicked: radar.setZoom(radar.zoom + 0.25)
          }
        }
      }
    }

    Rectangle {
      width: parent.width
      height: 190
      radius: radar.hostPanel.controlRadius
      clip: true
      color: radar.hostPanel.renderedSurfaceColor
      border.color: radar.hostPanel.controlBorderColor
      border.width: 1

      Text {
        anchors.centerIn: parent
        visible: !radar.located
        text: "Weather location is unavailable"
        color: radar.hostPanel.controlMuted
        font.family: radar.hostPanel.bar ? radar.hostPanel.bar.fontFamily
          : Commons.Style.font.family
        font.pixelSize: 9
        renderType: Text.NativeRendering
      }

      Item {
        anchors.centerIn: parent
        width: 768
        height: 768
        visible: radar.located

        Repeater {
          model: radar.tilesActive ? 9 : 0

          delegate: Item {
            required property int index
            readonly property int dx: index % 3 - 1
            readonly property int dy: Math.floor(index / 3) - 1
            readonly property int count: Math.pow(2, radar.tileZoom)
            readonly property int tx: ((radar.tileX() + dx) % count + count) % count
            readonly property int ty: radar.tileY() + dy
            x: 384 + (dx * 256 - radar.pixelOffsetX()) * radar.zoomScale
            y: 384 + (dy * 256 - radar.pixelOffsetY()) * radar.zoomScale
            width: 256 * radar.zoomScale
            height: 256 * radar.zoomScale
            visible: ty >= 0 && ty < count

            Image {
              anchors.fill: parent
              source: radar.tilesActive && parent.visible
                ? "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/"
                  + radar.tileZoom + "/" + parent.ty + "/" + parent.tx : ""
              asynchronous: true
              cache: true
              fillMode: Image.Stretch
            }

            Image {
              anchors.fill: parent
              visible: radar.radarPath !== "" && radar.zoom <= radar.radarMaxZoom
              source: !radar.tilesActive || radar.radarPath === "" ? ""
                : radar.radarHost + radar.radarPath
                  + "/512/" + radar.tileZoom + "/" + parent.tx + "/" + parent.ty
                  + "/2/1_1.png"
              asynchronous: true
              cache: true
              opacity: 0.58
              fillMode: Image.Stretch
            }
          }
        }

        Rectangle {
          anchors.centerIn: parent
          width: 8
          height: 8
          radius: 4
          color: radar.hostPanel.controlAccent
          border.color: radar.hostPanel.renderedSurfaceColor
          border.width: 2
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onWheel: function(event) {
          radar.setZoom(radar.zoom + (event.angleDelta.y > 0 ? 0.25 : -0.25))
          event.accepted = true
        }
      }
    }
  }
}
