pragma ComponentBehavior: Bound

import QtQuick

Item {
  id: root

  property color accent: "#ed0617"
  property color ink: "#f4f4f5"
  readonly property bool ready: accentLayer.ready && inkLayer.ready

  function drawMask(canvas, maskSource, color) {
    if (!canvas.isImageLoaded(maskSource)) {
      if (!canvas.isImageLoading(maskSource) && !canvas.isImageError(maskSource))
        canvas.loadImage(maskSource, Qt.size(
          Math.max(1, Math.round(canvas.width * 3)),
          Math.max(1, Math.round(canvas.height * 3))))
      return false
    }

    const context = canvas.getContext("2d")
    context.reset()
    context.clearRect(0, 0, canvas.width, canvas.height)

    const size = Math.min(canvas.width, canvas.height)
    const x = (canvas.width - size) / 2
    const y = (canvas.height - size) / 2
    context.imageSmoothingEnabled = true
    context.drawImage(maskSource, x, y, size, size)
    context.globalCompositeOperation = "source-in"
    context.fillStyle = color
    context.fillRect(0, 0, canvas.width, canvas.height)
    context.globalCompositeOperation = "source-over"
    return true
  }

  Canvas {
    id: accentLayer
    anchors.fill: parent
    renderTarget: Canvas.Image
    renderStrategy: Canvas.Immediate
    antialiasing: true
    property url maskSource: Qt.resolvedUrl("assets/shinigami-icon-hikiryo-accent-mask.png")
    property bool ready: false

    onPaint: accentLayer.ready = root.drawMask(accentLayer,
      accentLayer.maskSource, root.accent) || accentLayer.ready
    onImageLoaded: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onMaskSourceChanged: {
      ready = false
      requestPaint()
    }
    onVisibleChanged: if (visible) requestPaint()
  }

  Canvas {
    id: inkLayer
    anchors.fill: parent
    renderTarget: Canvas.Image
    renderStrategy: Canvas.Immediate
    antialiasing: true
    property url maskSource: Qt.resolvedUrl("assets/shinigami-icon-hikiryo-ink-mask.png")
    property bool ready: false

    onPaint: inkLayer.ready = root.drawMask(inkLayer,
      inkLayer.maskSource, root.ink) || inkLayer.ready
    onImageLoaded: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onMaskSourceChanged: {
      ready = false
      requestPaint()
    }
    onVisibleChanged: if (visible) requestPaint()
  }

  onAccentChanged: accentLayer.requestPaint()
  onInkChanged: inkLayer.requestPaint()
  onWidthChanged: {
    accentLayer.requestPaint()
    inkLayer.requestPaint()
  }
  onHeightChanged: {
    accentLayer.requestPaint()
    inkLayer.requestPaint()
  }
}
