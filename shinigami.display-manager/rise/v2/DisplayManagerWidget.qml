import QtQuick

Item {
    id: control
    required property var root
    visible: root.modDisplayManager
    implicitWidth: root.modDisplayManager ? 36 : 0
    implicitHeight: 28
    readonly property color contentColor: root.widgetContentColor("G13", root.widgetIconColor)
    readonly property string tooltipText: "Display Manager · click to configure monitors"

    Text {
        anchors.centerIn: parent
        text: "󰍹"
        color: control.root.displayManagerVisible && !control.root.widgetHasFill("G13") ? control.root.seal : control.contentColor
        font.family: control.root.mono
        font.pixelSize: 14
    }
}
