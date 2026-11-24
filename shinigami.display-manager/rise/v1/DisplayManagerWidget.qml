import QtQuick
import "../components" as CommonComponents

Item {
    id: control
    required property var root
    visible: implicitWidth > 0.5
    implicitWidth: root.modDisplayManager ? icon.implicitWidth + (root.compact ? 10 : 18) : 0
    implicitHeight: 28
    opacity: root.modDisplayManager ? 1 : 0
    readonly property string tooltipText: "Display Manager · click to configure monitors"
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    CommonComponents.IconText {
        id: icon
        objectName: "display-widget-icon"
        anchors.centerIn: parent
        text: "desktop_windows"
        color: control.root.displayManagerVisible ? control.root.seal : control.root.ink
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: 150 } }
    }
}
