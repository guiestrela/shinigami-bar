import QtQuick

Item {
    id: control
    required property var root
    visible: root.modDisplayManager
    implicitWidth: root.modDisplayManager ? 36 : 0
    implicitHeight: 28

    Text {
        anchors.centerIn: parent
        text: "󰍹"
        color: control.root.displayManagerVisible && !control.root.widgetHasFill() ? control.root.seal : control.root.ink
        font.family: control.root.mono
        font.pixelSize: 14
    }
}
