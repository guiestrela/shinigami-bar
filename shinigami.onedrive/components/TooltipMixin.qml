import QtQuick

Item {
    id: mixin

    required property var root
    required property Item owner
    property string text: ""
    property bool hovered: false

    function show() {
        hovered = true
        if (text && !root.barUnlocked) root.showTooltip(owner, text)
    }

    function hide() {
        hovered = false
        root.hideTooltip(owner)
    }

    onTextChanged: if (hovered) {
        if (text && !root.barUnlocked) root.showTooltip(owner, text)
        else root.hideTooltip(owner)
    }

    Connections {
        target: mixin.root
        function onBarUnlockedChanged() {
            if (mixin.root.barUnlocked) mixin.hide()
        }
    }
}
