pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons
import qs.Ui as Ui
import "../shinigami.state/lib/presentation" as Presentation

// One output-local surface. The Rise-derived controls stay passive; the single
// process-wide monitor service owns every state read and display mutation.
ShinigamiPanel {
  id: panel

  required property var ownerWidget
  required property var monitorService

  owner: ownerWidget
  open: ownerWidget.opened && monitorService && monitorService.ready
  focusTarget: keyCatcher
  contentWidth: fittedContentWidth(Commons.Style.space(380))
  // A Rise select expands its option list in place. Give the panel enough
  // vertical room to show it before falling back to the internal scroller.
  contentHeight: fittedContentHeight(contentColumn.implicitHeight,
    displayContent && displayContent.expandedSelectCount > 0
      ? Commons.Style.space(980) : Commons.Style.space(720))

  function refreshDisplayState() {
    return monitorService && typeof monitorService.refresh === "function"
      ? monitorService.refresh() : false
  }

  function ensureControlVisible(control) {
    if (!control || !scroller || !contentColumn) return
    const top = control.mapToItem(contentColumn, 0, 0).y
    const bottom = top + control.height
    if (top < scroller.contentY) scroller.contentY = top
    else if (bottom > scroller.contentY + scroller.height)
      scroller.contentY = bottom - scroller.height
  }

  Ui.PanelKeyCatcher {
    id: keyCatcher
    anchors.fill: parent
    onCloseRequested: panel.ownerWidget.close()
    onTabRequested: function(direction) { panel.ownerWidget.switchPanel(direction) }

    Flickable {
      id: scroller
      anchors.fill: parent
      clip: true
      contentWidth: width
      contentHeight: contentColumn.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
        id: contentColumn
        width: scroller.width
        spacing: Commons.Style.space(10)

        Row {
          width: parent.width
          spacing: Commons.Style.space(4)

          Text {
            objectName: panel.shellStyle === "shinigami"
              ? "display-v1-title" : "display-v2-title"
            width: parent.width - headerActions.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: "Display Manager"
            textFormat: Text.PlainText
            color: panel.bar ? panel.bar.foreground : Commons.Color.foreground
            font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
            font.pixelSize: 13
            font.letterSpacing: 2
            font.weight: Font.Medium
            elide: Text.ElideRight
            renderType: Text.NativeRendering
          }

          Row {
            id: headerActions
            spacing: Commons.Style.space(2)

            HeaderAction {
              objectName: panel.shellStyle === "shinigami"
                ? "display-refresh" : "display-refresh-v2"
              glyph: "\uE5D5"
              material: true
              tooltip: "Refresh display state"
              onClicked: panel.refreshDisplayState()
            }

            HeaderAction {
              objectName: panel.shellStyle === "shinigami"
                ? "display-v1-close" : "display-v2-close"
              glyph: "✕"
              tooltip: "Close"
              onClicked: panel.ownerWidget.close()
            }
          }
        }

        Ui.PanelSeparator { width: parent.width }

        DisplayManagerPanelContent {
          id: displayContent
          width: parent.width
          panel: panel
          service: panel.monitorService
        }
      }
    }
  }

  component HeaderAction: Item {
    id: action
    property string glyph: ""
    property bool material: false
    property string tooltip: ""
    signal clicked()
    implicitWidth: Commons.Style.space(28)
    implicitHeight: Commons.Style.space(28)

    Text {
      anchors.centerIn: parent
      text: action.glyph
      textFormat: Text.PlainText
      color: actionMouse.containsMouse
        ? (panel.bar ? panel.bar.urgent : Commons.Color.accent)
        : (panel.bar ? panel.bar.foreground : Commons.Color.foreground)
      font.family: action.material ? "Material Symbols Rounded"
        : panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
      font.pixelSize: action.material ? Commons.Style.font.body : 12
      renderType: Text.NativeRendering
      Behavior on color { ColorAnimation { duration: 100 } }
    }

    MouseArea {
      id: actionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: action.clicked()
    }

    Presentation.ShinigamiPanelToolTip {
      panel: panel
      visible: action.tooltip !== "" && actionMouse.containsMouse
      text: action.tooltip
    }
  }
}
