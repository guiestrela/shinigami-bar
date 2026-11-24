pragma ComponentBehavior: Bound

import QtQuick
import "../logic/ClockWidgetValuesLogic.js" as ClockWidgetValuesLogic
import "../components" as CommonComponents

// Rise clock presentation adapted to Shinigami ownership: time comes from the
// already-owned ClockService, and actions are routed through the bar facade.
Item {
    id: rootMod
    required property var root
    required property color contentColor
    property var clockService: root ? root.clockService : null

    readonly property date now: root && root.clockDate ? root.clockDate : new Date()
    function pad(n) { return ClockWidgetValuesLogic.pad(rootMod, {}, n) }

    readonly property string timeStr: {
        if (rootMod.root.clock12h) {
            let h = now.getHours() % 12; if (h === 0) h = 12
            return h + ":" + pad(now.getMinutes()) + " " + (now.getHours() < 12 ? "AM" : "PM")
        }
        return pad(now.getHours()) + ":" + pad(now.getMinutes())
    }

    readonly property var months: ["January","February","March","April","May","June",
                                    "July","August","September","October","November","December"]
    readonly property var days: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    readonly property string tooltipText: days[now.getDay()] + ", " + now.getDate() + " " + months[now.getMonth()] + " " + now.getFullYear()

    implicitWidth: label.implicitWidth
    implicitHeight: 28

    CommonComponents.UiText {
        id: label
        anchors.centerIn: parent
        text: rootMod.timeStr
        color: rootMod.contentColor
        font.family: rootMod.root.mono
        font.pixelSize: 12
        font.letterSpacing: 1
    }

    CommonComponents.TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: function(e) {
            if (e.button === Qt.LeftButton) {
                if (rootMod.root.host && typeof rootMod.root.host.toggleClockFormat === "function")
                    rootMod.root.host.toggleClockFormat()
            } else if (e.button === Qt.RightButton) {
                tip.hide()
                if (rootMod.root.host && rootMod.root.host.bar
                    && typeof rootMod.root.host.bar.run === "function")
                    rootMod.root.host.bar.run("omarchy-menu-timezone")
            }
        }
    }
}
