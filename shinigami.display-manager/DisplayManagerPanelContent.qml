pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons
import qs.Ui as Ui

// Rise Display Manager controls hosted by a Shinigami-owned panel surface.
// This component is deliberately passive: every state read and mutation goes
// through the single process-wide service facade.
Item {
  id: content

  required property var panel
  required property var service
  readonly property var controller: service.controllerApi
  readonly property var selectedDisplay: controller.previewMonitor(controller.selectedMonitor)
  property bool draftAutoWorkspaces: service.displayManagerAutoWorkspaces
  property var expandedSelects: []
  readonly property int expandedSelectCount: expandedSelects.length

  implicitWidth: Commons.Style.space(380)
  implicitHeight: contentColumn.implicitHeight

  function registerExpandedSelect(control) {
    if (expandedSelects.indexOf(control) < 0)
      expandedSelects = expandedSelects.concat([control])
  }

  function unregisterExpandedSelect(control) {
    expandedSelects = expandedSelects.filter(function(item) {
      return item !== control
    })
  }

  function ensureControlVisible(control) {
    if (!control || typeof panel.ensureControlVisible !== "function") return
    Qt.callLater(function() { panel.ensureControlVisible(control) })
  }

  function refresh() {
    controller.refresh()
    controller.refreshWorkspaces()
  }

  function refreshDisplayState() { return refresh() }

  function activeDisplayCount() {
    return controller.previewMonitors.filter(function(monitor) {
      return !monitor.disabled
    }).length
  }

  function mirrorTargets() {
    return controller.previewMonitors.filter(function(monitor) {
      return !monitor.disabled && monitor.name !== controller.selectedMonitor
        && (!monitor.mirrorOf || monitor.mirrorOf === "none")
    }).map(function(monitor) { return monitor.name })
  }

  function displayMode(monitor) {
    if (!monitor) return "preferred"
    if (typeof monitor.mode === "string" && monitor.mode) return monitor.mode
    const state = monitor.disabled && controller.savedDisplayStates
      ? controller.savedDisplayStates[monitor.name] || monitor : monitor
    if (!(Number(state.width) > 0 && Number(state.height) > 0
        && Number(state.refreshRate) > 0)) return "preferred"
    return state.width + "x" + state.height + "@" + Number(state.refreshRate)
  }

  function sameMode(a, b) {
    const left = String(a).trim().replace(/Hz$/i, "")
    const right = String(b).trim().replace(/Hz$/i, "")
    if (left === right) return true
    const leftParts = left.split("@")
    const rightParts = right.split("@")
    return leftParts.length === 2 && rightParts.length === 2
      && leftParts[0] === rightParts[0]
      && isFinite(Number(leftParts[1])) && isFinite(Number(rightParts[1]))
      && Math.abs(Number(leftParts[1]) - Number(rightParts[1])) < 0.05
  }

  function modeOptions(monitor) {
    const options = ["preferred"]
    if (monitor && Array.isArray(monitor.availableModes)) {
      for (const mode of monitor.availableModes)
        if (typeof mode === "string" && options.indexOf(mode) < 0) options.push(mode)
    }
    const selected = displayMode(monitor)
    if (!options.some(function(value) { return sameMode(value, selected) }))
      options.push(selected)
    return options
  }

  function modeIndex(monitor, options) {
    const selected = displayMode(monitor)
    for (let index = 0; index < options.length; index++)
      if (sameMode(options[index], selected)) return index
    return 0
  }

  function commitCanvasPosition(name, startX, startY, dx, dy, ratio) {
    const monitor = controller.previewMonitor(name)
    if (!monitor || controller.busy || controller.loading || controller.rollbackPending
        || monitor.disabled || (monitor.mirrorOf && monitor.mirrorOf !== "none")
        || !isFinite(dx) || !isFinite(dy) || !isFinite(ratio) || ratio <= 0) return false
    let x = Math.round(startX + dx / ratio)
    let y = Math.round(startY + dy / ratio)
    if (x < -32767 || x > 32767 || y < -32767 || y > 32767) return false
    const rotated = Number(monitor.transform || 0) % 2 === 1
    const width = Number(rotated ? monitor.height : monitor.width) / Number(monitor.scale || 1)
    const height = Number(rotated ? monitor.width : monitor.height) / Number(monitor.scale || 1)
    if (!isFinite(x) || !isFinite(y) || !isFinite(width) || !isFinite(height)
        || width <= 0 || height <= 0) return false

    const peers = []
    for (const other of controller.previewMonitors) {
      if (other.name === name || other.disabled
          || (other.mirrorOf && other.mirrorOf !== "none")) continue
      const position = controller.previewPositions[other.name] || other
      const otherRotated = Number(other.transform || 0) % 2 === 1
      const otherWidth = Number(otherRotated ? other.height : other.width)
        / Number(other.scale || 1)
      const otherHeight = Number(otherRotated ? other.width : other.height)
        / Number(other.scale || 1)
      const otherX = Number(position.x || 0)
      const otherY = Number(position.y || 0)
      if (!isFinite(otherX) || !isFinite(otherY) || !isFinite(otherWidth)
          || !isFinite(otherHeight) || otherWidth <= 0 || otherHeight <= 0) return false
      peers.push({ x: otherX, y: otherY, w: otherWidth, h: otherHeight })
    }

    function overlaps(px, py) {
      for (const peer of peers) {
        if (px < peer.x + peer.w && px + width > peer.x
            && py < peer.y + peer.h && py + height > peer.y) return true
      }
      return false
    }

    // Magnetic edge attachment: snap only edges with a shared passage.
    const distance = 12 / ratio
    let best = null
    function consider(px, py, adjustment) {
      if (adjustment > distance || px < -32767 || px > 32767
          || py < -32767 || py > 32767 || overlaps(px, py)) return
      if (best === null || adjustment < best.distance)
        best = { x: px, y: py, distance: adjustment }
    }
    for (const peer of peers) {
      if (y < peer.y + peer.h && y + height > peer.y) {
        const right = Math.ceil(peer.x + peer.w)
        const left = Math.floor(peer.x - width)
        consider(right, y, Math.abs(right - x))
        consider(left, y, Math.abs(left - x))
      }
      if (x < peer.x + peer.w && x + width > peer.x) {
        const bottom = Math.ceil(peer.y + peer.h)
        const top = Math.floor(peer.y - height)
        consider(x, bottom, Math.abs(bottom - y))
        consider(x, top, Math.abs(top - y))
      }
    }
    if (best !== null) {
      x = best.x
      y = best.y
    }
    if (overlaps(x, y)) {
      controller.error = "Displays cannot overlap. Place this display beside another."
      return false
    }
    return controller.stageMonitor(name, { x: x, y: y })
  }

  function applyChanges() {
    if (controller.busy || controller.loading || controller.rollbackPending) return false
    const monitor = selectedDisplay
    if (monitor && !monitor.disabled) {
      const x = xField.value
      const y = yField.value
      if ((x !== Number(monitor.x) || y !== Number(monitor.y))
          && !controller.stageMonitor(monitor.name, { x: x, y: y })) return false
    }
    if (!controller.applyDrafts()) return false
    if (draftAutoWorkspaces !== service.displayManagerAutoWorkspaces)
      return service.setAutoWorkspaces(draftAutoWorkspaces)
    return true
  }

  function disableSelectedMonitor() {
    const name = controller.selectedMonitor
    if (!name) return false
    if (panel.screen && String(panel.screen.name || "") === name) {
      // Output-local ownership: close this panel before removing its output
      // instead of trying to reparent the surface to another monitor.
      panel.ownerWidget.close()
    }
    return controller.disableMonitor(name)
  }

  function enableSelectedMonitor() {
    return controller.enableMonitor(controller.selectedMonitor, false)
  }

  Connections {
    target: content.service
    function onDisplayManagerAutoWorkspacesChanged() {
      content.draftAutoWorkspaces = service.displayManagerAutoWorkspaces
    }
  }

  Column {
    id: contentColumn
    width: parent.width
    spacing: Commons.Style.space(9)

    Item {
      width: parent.width
      height: Commons.Style.space(24)
      Text {
        objectName: panel.shellStyle === "shinigami"
          ? "display-section-v1" : "display-section-v2"
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "DISPLAYS · drag cards to arrange"
        color: panel.controlForeground
        font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
      }
    }

    Text {
      visible: controller.busy || controller.loading
      width: parent.width
      text: controller.busy ? "Applying…" : "Reading displays…"
      color: panel.controlMutedHigh
      font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
      font.pixelSize: Commons.Style.font.caption
      renderType: Text.NativeRendering
    }

    Rectangle {
      id: stage
      objectName: "display-canvas"
      width: parent.width
      height: Commons.Style.space(190)
      radius: panel.controlRadius
      color: panel.controlFillColor
      border.width: panel.controlBorderWidth
      border.color: panel.controlBorderColor
      clip: true

      readonly property var bounds: {
        const xs = [0]
        const ys = [0]
        for (const monitor of controller.previewMonitors) {
          if (monitor.disabled) continue
          const position = controller.previewPositions[monitor.name] || monitor
          const rotated = Number(monitor.transform || 0) % 2 === 1
          xs.push(Number(position.x || 0),
            Number(position.x || 0)
              + Number(rotated ? monitor.height : monitor.width)
                / Number(monitor.scale || 1))
          ys.push(Number(position.y || 0),
            Number(position.y || 0)
              + Number(rotated ? monitor.width : monitor.height)
                / Number(monitor.scale || 1))
        }
        return {
          left: Math.min.apply(null, xs),
          top: Math.min.apply(null, ys),
          right: Math.max.apply(null, xs),
          bottom: Math.max.apply(null, ys)
        }
      }
      readonly property real ratio: Math.min(
        (width - 40) / Math.max(1, bounds.right - bounds.left),
        (height - 40) / Math.max(1, bounds.bottom - bounds.top))

      Repeater {
        model: controller.previewMonitors
        delegate: Rectangle {
          id: monitorCard
          required property var modelData
          readonly property var position: controller.previewPositions[modelData.name] || modelData
          readonly property bool portrait: Number(modelData.transform || 0) % 2 === 1
          readonly property bool selected: controller.selectedMonitor === modelData.name
          x: 20 + (Number(position.x || 0) - stage.bounds.left) * stage.ratio
          y: 20 + (Number(position.y || 0) - stage.bounds.top) * stage.ratio
          width: Math.max(24, Number(portrait ? modelData.height : modelData.width)
            / Number(modelData.scale || 1) * stage.ratio)
          height: Math.max(24, Number(portrait ? modelData.width : modelData.height)
            / Number(modelData.scale || 1) * stage.ratio)
          visible: !modelData.disabled
          radius: Math.min(8, panel.controlRadius)
          color: selected ? panel.controlActiveFillColor : panel.renderedSurfaceColor
          border.width: panel.controlBorderWidth
          border.color: selected ? panel.controlAccent : panel.controlBorderColor

          Text {
            anchors.centerIn: parent
            width: parent.width - 8
            text: monitorCard.modelData.name
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            color: panel.controlForeground
            font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            elide: Text.ElideRight
            renderType: Text.NativeRendering
          }

          MouseArea {
            id: dragArea
            anchors.fill: parent
            property real originX: 0
            property real originY: 0
            property real monitorX: 0
            property real monitorY: 0
            property real dragRatio: 1
            property bool moved: false
            enabled: !controller.busy && !controller.loading
              && !controller.rollbackPending
              && (!monitorCard.modelData.mirrorOf
                || monitorCard.modelData.mirrorOf === "none")
            cursorShape: Qt.SizeAllCursor
            drag.target: monitorCard
            onPressed: {
              moved = false
              controller.selectedMonitor = monitorCard.modelData.name
              originX = monitorCard.x
              originY = monitorCard.y
              monitorX = Number(monitorCard.position.x || 0)
              monitorY = Number(monitorCard.position.y || 0)
              dragRatio = stage.ratio
            }
            function restoreBindings() {
              monitorCard.x = Qt.binding(function() {
                return 20 + (Number(monitorCard.position.x || 0)
                  - stage.bounds.left) * stage.ratio
              })
              monitorCard.y = Qt.binding(function() {
                return 20 + (Number(monitorCard.position.y || 0)
                  - stage.bounds.top) * stage.ratio
              })
            }
            onPositionChanged: if (drag.active) moved = true
            onReleased: {
              // A draft rebuild can destroy this delegate; restore bindings first.
              const name = monitorCard.modelData.name
              const dx = monitorCard.x - originX
              const dy = monitorCard.y - originY
              restoreBindings()
              if (moved) content.commitCanvasPosition(name, monitorX, monitorY,
                dx, dy, dragRatio)
            }
            onCanceled: restoreBindings()
          }
        }
      }
    }

    Row {
      objectName: "display-monitor-list"
      width: parent.width
      spacing: Commons.Style.space(5)
      Repeater {
        model: controller.previewMonitors
        delegate: ActionButton {
          required property var modelData
          objectName: "display-monitor-" + modelData.name
          label: modelData.name + (modelData.disabled ? " · OFF" : "")
          selected: modelData.name === controller.selectedMonitor
          onClicked: controller.selectedMonitor = modelData.name
        }
      }
    }

    Ui.PanelSeparator { width: parent.width }

    Text {
      width: parent.width
      text: "CONFIGURATION · " + (controller.selectedMonitor || "No monitor selected")
      color: panel.controlForeground
      font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
      font.pixelSize: Commons.Style.font.caption
      font.weight: Font.DemiBold
      renderType: Text.NativeRendering
    }

    Row {
      width: parent.width
      spacing: Commons.Style.space(8)
      enabled: !controller.busy && !controller.loading && !controller.rollbackPending
        && controller.selectedMonitor !== ""

      FieldLabel { width: Commons.Style.space(74); text: "Mode" }
      SelectField {
        id: modeField
        objectName: "display-resolution"
        width: parent.width - Commons.Style.space(82)
        model: content.modeOptions(content.selectedDisplay)
        currentIndex: content.modeIndex(content.selectedDisplay, model)
        onActivated: function(index) {
          if (content.selectedDisplay)
            controller.stageMonitor(content.selectedDisplay.name,
              { mode: String(model[index]) })
        }
      }
    }

    Row {
      width: parent.width
      spacing: Commons.Style.space(8)
      enabled: !controller.busy && !controller.loading && !controller.rollbackPending
        && !controller.displayStateSaving && controller.selectedMonitor !== ""

      FieldLabel { width: Commons.Style.space(74); text: "Position" }
      NumberField {
        id: xField
        objectName: "display-position-x"
        width: Commons.Style.space(92)
        value: content.selectedDisplay ? Number(content.selectedDisplay.x || 0) : 0
        onValueModified: function(next) {
          if (content.selectedDisplay)
            controller.stageMonitor(content.selectedDisplay.name, { x: next })
        }
      }
      NumberField {
        id: yField
        objectName: "display-position-y"
        width: Commons.Style.space(92)
        value: content.selectedDisplay ? Number(content.selectedDisplay.y || 0) : 0
        onValueModified: function(next) {
          if (content.selectedDisplay)
            controller.stageMonitor(content.selectedDisplay.name, { y: next })
        }
      }
      ActionButton {
        objectName: "display-position-apply"
        label: "Apply"
        onClicked: content.applyChanges()
      }
    }

    Row {
      width: parent.width
      spacing: Commons.Style.space(8)
      enabled: !controller.busy && !controller.loading && !controller.rollbackPending
        && controller.selectedMonitor !== ""

      FieldLabel { width: Commons.Style.space(74); text: "Scale" }
      SelectField {
        id: scaleField
        objectName: "display-scale"
        width: Commons.Style.space(92)
        model: controller.scalePresets
        currentIndex: content.selectedDisplay
          ? Math.max(0, controller.scalePresets.indexOf(
            Number(content.selectedDisplay.scale || 1))) : 0
        onActivated: function(index) {
          if (content.selectedDisplay)
            controller.stageMonitor(content.selectedDisplay.name,
              { scale: Number(model[index]) })
        }
      }
      // Keep the Rise rotation labels readable inside the 380 px Shinigami
      // panel: a width derived from the remaining row space collapses to a
      // few pixels and elides every value, including "Flipped 270°".
      FieldLabel { width: Commons.Style.space(48); text: "Rotation" }
      SelectField {
        id: rotationField
        objectName: "display-rotation"
        width: Commons.Style.space(110)
        model: ["0°", "90°", "180°", "270°", "Flipped", "Flipped 90°",
          "Flipped 180°", "Flipped 270°"]
        currentIndex: content.selectedDisplay
          ? Number(content.selectedDisplay.transform || 0) : 0
        onActivated: function(index) {
          if (content.selectedDisplay)
            controller.stageMonitor(content.selectedDisplay.name,
              { transform: index })
        }
      }
    }

    Row {
      objectName: "display-monitor-workspaces"
      visible: !service.omarchyPerMonitorWorkspaces
      enabled: !controller.busy && !controller.loading && !controller.rollbackPending
        && !controller.workspaceLoading && !controller.workspaceCommitPending
        && controller.extraQueue.length === 0 && controller.workspaceStateReady
        && content.selectedDisplay && !content.selectedDisplay.disabled
        && (!content.selectedDisplay.mirrorOf
          || content.selectedDisplay.mirrorOf === "none")
      width: parent.width
      spacing: Commons.Style.space(8)
      height: Math.max(30, workspaceButtons.implicitHeight)

      FieldLabel { width: Commons.Style.space(74); text: "Workspaces" }
      Flow {
        id: workspaceButtons
        width: parent.width - x
        spacing: Commons.Style.space(3)
        Repeater {
          model: 10
          delegate: ActionButton {
            id: workspaceButton
            required property int index
            objectName: "display-workspace-" + (index + 1)
            width: Commons.Style.space(27)
            label: String(index + 1)
            selected: controller.workspaceOwner(index + 1) === controller.selectedMonitor
            onClicked: controller.stageWorkspace(index + 1, controller.selectedMonitor)
          }
        }
      }
    }

    Row {
      objectName: "display-monitor-workspaces-native"
      visible: service.omarchyPerMonitorWorkspaces
      width: parent.width
      height: Commons.Style.space(30)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        wrapMode: Text.Wrap
        text: "Workspaces 1–10 are managed separately on each monitor by Omarchy."
        color: panel.controlMutedHigh
        font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        renderType: Text.NativeRendering
      }
    }

    Row {
      width: parent.width
      spacing: Commons.Style.space(8)
      enabled: !controller.busy && !controller.rollbackPending
        && controller.selectedMonitor !== ""

      FieldLabel { width: Commons.Style.space(74); text: "Mode" }
      ActionButton {
        id: mirrorButton
        objectName: "display-mirror"
        readonly property bool mirrorActive: Boolean(content.selectedDisplay
          && content.selectedDisplay.mirrorOf
          && content.selectedDisplay.mirrorOf !== "none")
        label: "Mirror · " + (mirrorActive ? "ON" : "OFF")
        selected: mirrorActive
        enabled: !controller.busy && !controller.loading
          && !controller.rollbackPending
          && (mirrorActive || (content.mirrorTargets().length > 0
            && content.selectedDisplay && !content.selectedDisplay.disabled))
        onClicked: controller.toggleMirror(true)
      }
      ActionButton {
        objectName: "display-enable"
        label: "Enable"
        enabled: !!content.selectedDisplay && !controller.displayStateSaving
          && !controller.busy && !controller.loading && !controller.rollbackPending
          && service.hyprDispatchModeReady
          && (service.omarchyPerMonitorWorkspaces
            || !service.displayManagerAutoWorkspaces
            || (controller.workspaceStateReady && !controller.workspaceLoading))
        onClicked: content.enableSelectedMonitor()
      }
      ActionButton {
        objectName: "display-disable"
        label: "Disable"
        enabled: controller.pendingDisableMonitor === ""
          && content.activeDisplayCount() > 1 && !controller.busy
          && !controller.rollbackPending
        onClicked: content.disableSelectedMonitor()
      }
    }

    Ui.PanelSeparator { width: parent.width }

    Row {
      width: parent.width
      spacing: Commons.Style.space(8)
      enabled: !controller.busy && !controller.loading && !controller.rollbackPending
        && controller.selectedMonitor !== ""

      FieldLabel { width: Commons.Style.space(74); text: "Brightness" }
      Ui.PanelSlider {
        id: displayBrightnessSlider
        objectName: "display-brightness"
        // The row has two gaps: one after the label and one before the
        // readout. Subtract both, plus a small inset so the final glyph is
        // not eaten by the panel border or rounded edge.
        width: parent.width - brightnessReadout.width - parent.spacing * 2
          - Commons.Style.space(74) - Commons.Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        bar: panel.bar
        minimum: 1
        maximum: 100
        step: 1
        integer: true
        trackColor: panel.controlActiveFillColor
        fillColor: panel.controlAccent
        knobColor: panel.controlAccent
        value: controller.brightnessPercent
        enabled: controller.brightnessAvailable && !controller.busy
        onMoved: function(value) { controller.stageBrightness(controller.selectedMonitor, value) }
        onReleased: function(value) { controller.setBrightness(value) }
      }
      Text {
        id: brightnessReadout
        objectName: "display-brightness-readout"
        anchors.verticalCenter: parent.verticalCenter
        text: controller.brightnessAvailable ? controller.brightnessPercent + "%" : "Unavailable"
        color: panel.controlForeground
        font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        renderType: Text.NativeRendering
      }
    }

    Row {
      width: parent.width
      spacing: Commons.Style.space(8)
      enabled: !controller.busy && !controller.loading && !controller.rollbackPending
        && controller.selectedMonitor !== ""

      FieldLabel { width: Commons.Style.space(74); text: "Text size" }
      SelectField {
        objectName: "display-text-size"
        width: parent.width - Commons.Style.space(82)
        model: controller.textSizeStops
        currentIndex: controller.textSizeIndex
        onActivated: function(index) { controller.setTextSize(index) }
      }
    }

    Row {
      width: parent.width
      spacing: Commons.Style.space(8)
      enabled: !controller.busy && !controller.loading && !controller.rollbackPending

      ToggleButton {
        id: autoWorkspaceToggle
        objectName: "display-workspaces"
        visible: !service.omarchyPerMonitorWorkspaces
        label: "Auto-bind workspaces"
        checked: content.draftAutoWorkspaces
        onToggled: function(next) { content.draftAutoWorkspaces = next }
      }
      ActionButton {
        objectName: "display-save"
        label: "Save layout"
        enabled: !controller.busy && !controller.hasDrafts
          && !controller.workspaceLoading && !controller.workspaceCommitPending
          && content.draftAutoWorkspaces === service.displayManagerAutoWorkspaces
        onClicked: controller.saveLayout()
      }
    }

    Column {
      objectName: "display-confirmation"
      visible: controller.rollbackPending
      width: parent.width
      spacing: Commons.Style.space(6)

      Text {
        objectName: "display-confirmation-countdown"
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: "Keep this configuration? Reverting in "
          + controller.rollbackSeconds + " s."
        color: panel.controlAccent
        font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        renderType: Text.NativeRendering
      }
      Row {
        spacing: Commons.Style.space(8)
        ActionButton {
          objectName: "display-keep"
          label: "Keep configuration"
          enabled: !controller.confirmationBusy
          onClicked: controller.confirmChanges()
        }
        ActionButton {
          objectName: "display-revert"
          label: "Revert now"
          enabled: !controller.confirmationBusy
          onClicked: controller.revertChanges()
        }
      }
    }

    Text {
      visible: controller.error !== "" || controller.workspaceError !== ""
      width: parent.width
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: controller.error || controller.workspaceError
      color: panel.controlAccent
      font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
      font.pixelSize: Commons.Style.font.caption
      renderType: Text.NativeRendering
    }

    Text {
      width: parent.width
      wrapMode: Text.Wrap
      text: "Layout save creates a backup before updating the managed monitors.lua block."
      color: panel.controlMutedHigh
      font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
      font.pixelSize: Commons.Style.font.caption
      renderType: Text.NativeRendering
    }
  }

  component FieldLabel: Text {
    color: panel.controlMutedHigh
    font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
    font.pixelSize: Commons.Style.font.caption
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    renderType: Text.NativeRendering
  }

  component ActionButton: Rectangle {
    id: actionButton
    property string label: ""
    property bool selected: false
    signal clicked()
    readonly property bool hovered: actionMouse.containsMouse
    implicitWidth: Math.max(Commons.Style.space(58),
      labelText.implicitWidth + Commons.Style.space(20))
    implicitHeight: Commons.Style.space(30)
    radius: panel.controlRadius
    color: selected || hovered ? panel.controlActiveFillColor : panel.controlFillColor
    border.width: panel.controlBorderWidth
    border.color: selected || hovered ? panel.controlAccent : panel.controlBorderColor
    opacity: actionButton.enabled ? 1 : 0.45

    Text {
      id: labelText
      anchors.centerIn: parent
      text: actionButton.label
      textFormat: Text.PlainText
      color: actionButton.selected || actionButton.hovered
        ? panel.controlAccent : panel.controlForeground
      font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
      font.pixelSize: Commons.Style.font.caption
      elide: Text.ElideRight
      renderType: Text.NativeRendering
    }

    MouseArea {
      id: actionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: actionButton.clicked()
    }
  }

  component ToggleButton: Rectangle {
    id: toggleButton
    property string label: ""
    property bool checked: false
    signal toggled(bool next)
    readonly property bool hovered: toggleMouse.containsMouse
    implicitWidth: Math.max(Commons.Style.space(130),
      toggleText.implicitWidth + Commons.Style.space(20))
    implicitHeight: Commons.Style.space(30)
    radius: panel.controlRadius
    color: toggleButton.checked || hovered
      ? panel.controlActiveFillColor : panel.controlFillColor
    border.width: panel.controlBorderWidth
    border.color: toggleButton.checked || hovered
      ? panel.controlAccent : panel.controlBorderColor

    Text {
      id: toggleText
      anchors.centerIn: parent
      text: toggleButton.label + (toggleButton.checked ? " · ON" : " · OFF")
      textFormat: Text.PlainText
      color: toggleButton.checked || toggleButton.hovered
        ? panel.controlAccent : panel.controlForeground
      font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
      font.pixelSize: Commons.Style.font.caption
      renderType: Text.NativeRendering
    }

    MouseArea {
      id: toggleMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: toggleButton.toggled(!toggleButton.checked)
    }
  }

  component SelectField: Item {
    id: selectField
    required property var model
    property int currentIndex: 0
    signal activated(int index)
    property bool expanded: false
    readonly property string currentText: model && currentIndex >= 0
      && currentIndex < model.length ? String(model[currentIndex]) : ""
    onExpandedChanged: {
      if (selectField.expanded) {
        content.registerExpandedSelect(selectField)
        content.ensureControlVisible(selectField)
      } else {
        content.unregisterExpandedSelect(selectField)
      }
    }
    implicitWidth: Commons.Style.space(120)
    implicitHeight: closedRow.height
      + (expanded ? optionColumn.height + Commons.Style.space(2) : 0)
    z: expanded ? 20 : 1

    Rectangle {
      id: closedRow
      width: parent.width
      height: Commons.Style.space(30)
      radius: panel.controlRadius
      color: selectField.hovered ? panel.controlHoverFillColor : panel.controlFillColor
      border.width: panel.controlBorderWidth
      border.color: selectField.hovered ? panel.controlHoverBorderColor
        : panel.controlBorderColor

      readonly property bool hovered: selectMouse.containsMouse
      Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Commons.Style.space(8)
        anchors.rightMargin: Commons.Style.space(20)
        anchors.verticalCenter: parent.verticalCenter
        text: selectField.currentText
        textFormat: Text.PlainText
        color: panel.controlForeground
        font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        elide: Text.ElideRight
        renderType: Text.NativeRendering
      }
      Text {
        anchors.right: parent.right
        anchors.rightMargin: Commons.Style.space(7)
        anchors.verticalCenter: parent.verticalCenter
        text: "▾"
        color: panel.controlAccent
        font.pixelSize: Commons.Style.font.caption
        renderType: Text.NativeRendering
      }
      MouseArea {
        id: selectMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: selectField.expanded = !selectField.expanded
      }
    }

    Column {
      id: optionColumn
      anchors.top: closedRow.bottom
      anchors.topMargin: Commons.Style.space(2)
      width: parent.width
      visible: selectField.expanded
      Repeater {
        model: selectField.model
        delegate: Rectangle {
          required property var modelData
          required property int index
          width: parent.width
          height: Commons.Style.space(26)
          radius: panel.controlRadius
          color: optionMouse.containsMouse ? panel.controlHoverFillColor
            : panel.renderedSurfaceColor
          border.width: panel.controlBorderWidth
          border.color: panel.controlBorderColor
          Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Commons.Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: String(modelData)
            textFormat: Text.PlainText
            color: panel.controlForeground
            font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            elide: Text.ElideRight
            renderType: Text.NativeRendering
          }
          MouseArea {
            id: optionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              selectField.currentIndex = index
              selectField.expanded = false
              selectField.activated(index)
            }
          }
        }
      }
    }
  }

  component NumberField: Rectangle {
    id: numberField
    property int value: 0
    signal valueModified(int next)
    implicitWidth: Commons.Style.space(92)
    implicitHeight: Commons.Style.space(30)
    radius: panel.controlRadius
    color: panel.controlFillColor
    border.width: panel.controlBorderWidth
    border.color: panel.controlBorderColor

    TextInput {
      id: numberInput
      anchors.left: parent.left
      anchors.right: decrementButton.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Commons.Style.space(6)
      horizontalAlignment: TextInput.AlignHCenter
      verticalAlignment: TextInput.AlignVCenter
      text: String(numberField.value)
      color: panel.controlForeground
      font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
      font.pixelSize: Commons.Style.font.caption
      validator: IntValidator { bottom: -32767; top: 32767 }
      selectByMouse: true
      onEditingFinished: numberField.commit()
      onActiveFocusChanged: if (!activeFocus) numberField.commit()
      Component.onCompleted: text = String(numberField.value)
    }
    Text {
      id: decrementButton
      anchors.right: incrementButton.left
      anchors.verticalCenter: parent.verticalCenter
      width: Commons.Style.space(16)
      text: "−"
      color: panel.controlAccent
      horizontalAlignment: Text.AlignHCenter
      font.pixelSize: Commons.Style.font.caption
      MouseArea {
        anchors.fill: parent
        onClicked: numberField.setValue(numberField.value - 1)
      }
    }
    Text {
      id: incrementButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Commons.Style.space(16)
      text: "+"
      color: panel.controlAccent
      horizontalAlignment: Text.AlignHCenter
      font.pixelSize: Commons.Style.font.caption
      MouseArea {
        anchors.fill: parent
        onClicked: numberField.setValue(numberField.value + 1)
      }
    }

    function setValue(next) {
      const bounded = Math.max(-32767, Math.min(32767, Math.round(Number(next) || 0)))
      numberInput.text = String(bounded)
      value = bounded
      numberField.valueModified(bounded)
    }
    function commit() {
      setValue(numberInput.text)
    }
    onValueChanged: {
      if (!numberInput.activeFocus && numberInput.text !== String(value))
        numberInput.text = String(value)
    }
  }
}
