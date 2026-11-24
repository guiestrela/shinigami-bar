pragma ComponentBehavior: Bound
import QtQuick

// Rise presentation only: no processes, service instances, or per-output IPC.
Item {
    id: widget
    required property var root
    required property var coordinator
    required property color contentColor
    property bool revealInactive: false
    property bool vertical: false
    property real iconSpacing: 4
    readonly property bool hasActive: coordinator ? coordinator.hasActive : false
    readonly property bool revealed: revealInactive || hover.hovered
    readonly property var entries: [
        {id: "ScreenRecording", glyph: "󰻂", active: coordinator.recording,
            available: false, activeLabel: "Stop recording"},
        {id: "Dnd", glyph: "󰂛", active: coordinator.silenced,
            available: true, label: "Silence notifications", activeLabel: "Allow notifications"},
        {id: "StayAwake", glyph: "", active: coordinator.awake,
            available: true, label: "Stay awake", activeLabel: "Allow idle lock"},
        {id: "Voxtype", glyph: "", active: coordinator.voxtype,
            available: false, activeLabel: "Voxtype · left: model · right: settings"}
    ]
    readonly property var displayedEntries: entries.filter(function(entry) {
        return entry.active || (revealed && entry.available)
    })
    readonly property int count: displayedEntries.length
    // Rise's existing tooltip host uses AutoText. Keep helper/peer text from
    // becoming markup there without changing other widgets' tooltip contracts.
    function plainTooltip(value) {
        return String(value).replace(/</g, "‹").replace(/>/g, "›")
    }
    // Derive size from the model, not Grid's deferred polish: a collapsed
    // ancestor must not prevent newly active icons from obtaining geometry.
    // Grid's implicitWidth includes a trailing spacing cell; constrain its
    // horizontal extent to the model width so anchors.centerIn centers the icons.
    implicitWidth: vertical ? 28 : (count > 0 ? count * 20 + (count - 1) * iconSpacing : 0)
    implicitHeight: vertical ? (count > 0 ? count * 24 + (count - 1) * iconSpacing : 0) : 28
    visible: true
    HoverHandler { id: hover }
    Grid {
        id: grid
        width: widget.vertical ? implicitWidth : widget.implicitWidth
        columns: widget.vertical ? 1 : widget.entries.length
        spacing: widget.iconSpacing
        anchors.centerIn: parent
        Repeater {
            model: widget.displayedEntries
            Item {
                id: indicator
                required property var modelData
                readonly property bool active: modelData.active
                visible: active || (widget.revealed && modelData.available)
                width: 20
                height: 24
                UiText {
                    anchors.centerIn: parent
                    text: indicator.modelData.glyph
                    textFormat: Text.PlainText
                    font.family: widget.root.mono
                    font.pixelSize: 13
                    color: widget.contentColor
                    opacity: indicator.active ? 1 : 0.45
                }
                TooltipMixin {
                    id: tip
                    root: widget.root
                    owner: indicator
                    text: widget.plainTooltip(indicator.active ? indicator.modelData.activeLabel : indicator.modelData.label)
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: indicator.modelData.id === "Voxtype"
                        ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
                    onEntered: tip.show()
                    onExited: tip.hide()
                    onClicked: function(mouse) {
                        tip.hide()
                        if (widget.coordinator) widget.coordinator.activate(indicator.modelData.id, mouse.button)
                    }
                }
            }
        }
    }
}
