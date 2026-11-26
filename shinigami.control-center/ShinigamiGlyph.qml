pragma ComponentBehavior: Bound

import QtQuick

Canvas {
  id: root

  required property real size
  required property color ink
  readonly property url source: Qt.resolvedUrl("assets/shinigami-shell-transparente.svg")

  width: size
  height: size
  renderTarget: Canvas.Image

  onInkChanged: requestPaint()
  onImageLoaded: requestPaint()
  onAvailableChanged: {
    if (available) {
      loadImage(source)
      requestPaint()
    }
  }
  onPaint: {
    const ctx = getContext("2d")
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    if (!isImageLoaded(source)) return
    ctx.drawImage(source, 0, 0, width, height)
    ctx.globalCompositeOperation = "source-in"
    ctx.fillStyle = ink
    ctx.fillRect(0, 0, width, height)
  }
}
