pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui as Ui
import "CalendarModel.js" as CalendarModel
import "../shinigami.state/lib/presentation" as Presentation

ShinigamiPanel {
  id: panel

  required property var ownerWidget
  required property var clockService
  property int monthOffset: 0
  property int selectedDay: 0
  readonly property date displayDate: clockService ? clockService.date : new Date()
  readonly property var calendarCells: CalendarModel.cells(displayDate, monthOffset)
  readonly property string monthName: CalendarModel.monthName(displayDate, monthOffset)
  readonly property string calendarYear: CalendarModel.year(displayDate, monthOffset)
  readonly property int renderedDayCount: dayRepeater.count
  readonly property date displayedMonth: CalendarModel.monthDate(displayDate, monthOffset)
  readonly property string monthStart: CalendarModel.dayKey(displayedMonth)
  readonly property string agendaDay: CalendarModel.dayKey(
    new Date(displayedMonth.getFullYear(), displayedMonth.getMonth(), Math.max(1, selectedDay)))
  readonly property var agendaEvents: loadedMonth === monthStart
    ? CalendarModel.eventsOn(events, agendaDay) : []
  property var events: []
  property string loadedMonth: ""
  property string agendaMessage: ""
  readonly property var stateService: bar && bar.shell
    && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("shinigami.state") : null
  readonly property color deepInk: stateService
    && typeof stateService.paletteColor === "function"
    ? stateService.paletteColor("color07") : controlForeground

  owner: ownerWidget
  open: ownerWidget.opened
  focusTarget: keyCatcher
  centerOnBar: true
  padding: 12
  contentWidth: fittedContentWidth(280)
  contentHeight: fittedContentHeight(content.implicitHeight)

  function previousMonth() {
    selectedDay = 1
    monthOffset--
  }
  function nextMonth() {
    selectedDay = 1
    monthOffset++
  }
  function resetToToday() {
    monthOffset = 0
    selectedDay = displayDate.getDate()
  }

  function refreshAgenda() {
    if (!open || agendaProcess.running) return
    agendaMessage = ""
    const dataHome = Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"
    const executable = dataHome + "/io.github.guiestrela.omarchy-google-calendar-clock/bin/caldir"
    const monthEnd = CalendarModel.dayKey(new Date(displayedMonth.getFullYear(),
      displayedMonth.getMonth() + 1, 0))
    agendaProcess.requestedMonth = monthStart
    agendaProcess.exec(["bash", "-c",
      'set -o pipefail; if [[ ! -x "$1" ]]; then shift; set -- caldir "$@"; fi; timeout 5s "$@" | head -c 1048577',
      "calendar-agenda", executable, "--json", "events", "--from", monthStart, "--to", monthEnd])
  }

  Component.onCompleted: {
    resetToToday()
    refreshAgenda()
  }
  onMonthStartChanged: if (open) refreshAgenda()

  Process {
    id: agendaProcess
    property string requestedMonth: ""
    stdout: StdioCollector { id: agendaOutput; waitForEnd: true }
    onExited: function(code) {
      if (requestedMonth !== panel.monthStart) {
        Qt.callLater(panel.refreshAgenda)
        return
      }
      let result = null
      if (code === 0 && agendaOutput.text.length <= 1048576) {
        try { result = JSON.parse(agendaOutput.text) } catch (error) {}
      }
      panel.loadedMonth = requestedMonth
      panel.events = Array.isArray(result) ? result.filter(function(event) {
        return event && typeof event.start === "string" && typeof event.title === "string"
      }) : []
      panel.agendaMessage = Array.isArray(result) ? "" : "Calendar data is unavailable"
    }
  }

  Ui.PanelKeyCatcher {
    id: keyCatcher
    anchors.fill: parent
    onCloseRequested: ownerWidget.close()
    onMoveRequested: function(dx, _dy) {
      if (dx < 0) panel.previousMonth()
      else if (dx > 0) panel.nextMonth()
    }
    onTabRequested: function(direction) {
      panel.ownerWidget.switchPanel(direction)
    }

    Column {
      id: content
      width: parent.width
      spacing: 10

      Item {
        width: parent.width
        height: 24

        CalendarAction {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          iconText: "‹"
          tooltipText: "Previous month"
          onClicked: panel.previousMonth()
        }

        Presentation.PanelHeading {
          anchors.centerIn: parent
          reserveLayoutWidth: true
          layoutFont: Qt.font({family: font.family, pixelSize: 12,
            weight: Font.Medium, letterSpacing: 2})
          text: panel.monthName + "  " + panel.calendarYear
          color: monthMouse.containsMouse && panel.monthOffset !== 0
            ? panel.controlAccent : panel.controlForeground
          font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family

          MouseArea {
            id: monthMouse
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            enabled: panel.monthOffset !== 0
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: panel.resetToToday()
          }
        }

        CalendarAction {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          iconText: "›"
          tooltipText: "Next month"
          onClicked: panel.nextMonth()
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: panel.dividerColor
      }

      Row {
        width: parent.width

        Repeater {
          model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]

          delegate: Item {
            required property string modelData
            required property int index
            width: content.width / 7
            height: 20

            Text {
              anchors.centerIn: parent
              text: modelData
              color: index >= 5 ? panel.controlAccent : panel.deepInk
              opacity: index >= 5 ? 0.85 : 0.7
              font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: 10
              font.letterSpacing: 2
              renderType: Text.NativeRendering
            }
          }
        }
      }

      Grid {
        columns: 7
        rowSpacing: 2
        columnSpacing: 0
        width: parent.width

        Repeater {
          id: dayRepeater
          model: panel.calendarCells

          delegate: Item {
            id: dayCell
            required property var modelData
            required property int index
            readonly property bool hasDay: modelData.day > 0
            readonly property bool today: modelData.today === true
            readonly property bool selected: hasDay && !today
              && panel.selectedDay === modelData.day
            readonly property string dateKey: hasDay ? CalendarModel.dayKey(new Date(
              panel.displayedMonth.getFullYear(), panel.displayedMonth.getMonth(), modelData.day)) : ""
            readonly property bool weekend: index % 7 >= 5
            width: content.width / 7
            height: 28

            Rectangle {
              anchors.centerIn: parent
              width: 24
              height: width
              radius: 12
              visible: dayCell.today
              color: panel.controlAccent
            }

            Rectangle {
              anchors.centerIn: parent
              width: 24
              height: width
              radius: 12
              visible: dayCell.selected
              color: "transparent"
              border.width: 1
              border.color: panel.controlAccent
            }

            Text {
              anchors.centerIn: parent
              text: dayCell.hasDay ? dayCell.modelData.day : ""
              color: dayCell.today
                ? panel.controlAccent.hsvValue < 0.5
                  ? panel.controlForeground : Commons.Color.background
                : dayCell.weekend ? panel.controlAccent : panel.controlForeground
              opacity: dayCell.hasDay ? 1 : 0.35
              font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: 12
              font.weight: dayCell.today ? Font.Medium : Font.Light
              renderType: Text.NativeRendering
            }

            Rectangle {
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 1
              anchors.horizontalCenter: parent.horizontalCenter
              width: 4
              height: width
              radius: width / 2
              color: dayCell.today ? panel.renderedSurfaceColor : panel.controlAccent
              visible: dayCell.hasDay && panel.loadedMonth === panel.monthStart
                && CalendarModel.eventsOn(panel.events, dayCell.dateKey).length > 0
            }

            MouseArea {
              anchors.fill: parent
              enabled: dayCell.hasDay
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: panel.selectedDay = dayCell.modelData.day
            }
          }
        }
      }

      Rectangle { width: parent.width; height: 1; color: panel.dividerColor }

      Item {
        width: parent.width
        height: 24

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "AGENDA · " + panel.agendaDay
          color: panel.controlMutedHigh
          font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
          font.pixelSize: 9
          font.letterSpacing: 0.5
          renderType: Text.NativeRendering
        }

        CalendarAction {
          anchors.right: parent.right
          iconText: agendaProcess.running ? "…" : "↻"
          tooltipText: "Refresh agenda"
          enabled: !agendaProcess.running
          onClicked: panel.refreshAgenda()
        }
      }

      Column {
        width: parent.width
        spacing: 4

        Repeater {
          model: panel.agendaEvents.slice(0, 4)
          delegate: Row {
            id: agendaRow
            required property var modelData
            width: parent.width
            spacing: 6

            Text {
              width: 48
              text: agendaRow.modelData.all_day ? "ALL DAY"
                : Qt.formatTime(new Date(agendaRow.modelData.start), "HH:mm")
              color: panel.controlAccent
              font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: 9
            }

            Text {
              width: agendaRow.width - 54
              text: agendaRow.modelData.title
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: panel.controlForeground
              font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: 9
            }
          }
        }

        Text {
          width: parent.width
          visible: panel.agendaEvents.length === 0
          text: agendaProcess.running ? "Loading agenda…"
            : panel.agendaMessage || "No events for this day"
          color: panel.controlMutedHigh
          font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
          font.pixelSize: 9
        }
      }
    }
  }

  component CalendarAction: Rectangle {
    id: action
    property string iconText: ""
    property string tooltipText: ""
    signal clicked()
    readonly property bool hovered: actionMouse.containsMouse
    width: 24
    height: 24
    radius: panel.controlRadius
    color: "transparent"

    Text {
      anchors.centerIn: parent
      text: action.iconText
      color: action.hovered ? panel.controlAccent : panel.controlMuted
      font.family: panel.bar ? panel.bar.fontFamily : Commons.Style.font.family
      font.pixelSize: 16
      renderType: Text.NativeRendering
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
      id: actionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: action.clicked()
    }

    Presentation.ShinigamiPillToolTip {
      panel: panel
      visible: panel.shellStyle !== "shinigami"
        && action.tooltipText !== "" && actionMouse.containsMouse
      text: action.tooltipText
    }
  }
}
