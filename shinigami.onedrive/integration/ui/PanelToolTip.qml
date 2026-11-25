pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "." as Tokens

// Panel tooltip following the Shinigami/Rise bar surface recipe.
// Colors and radius come from the OneDrive theme facade, which is fed by the
// live Shinigami bar tokens, so the tooltip matches the bar and Rise Bar.
ToolTip {
  id: root

  readonly property var theme: Tokens.Style.theme
  property string fontFamily: theme && theme.mono ? theme.mono : Tokens.Style.font.family
  property real fontSize: 12
  readonly property color resolvedBackground: theme
    && theme.tooltipBackground !== undefined
    ? theme.tooltipBackground : Tokens.Color.tooltip.background
  readonly property color resolvedBorderColor: theme
    && theme.panelOuterBorderColor !== undefined
    ? theme.panelOuterBorderColor : Tokens.Color.tooltip.border
  readonly property real resolvedBorderWidth: theme
    && theme.panelOuterBorderW !== undefined
    ? theme.panelOuterBorderW : Tokens.Style.tooltipBorderWidth
  readonly property color resolvedTextColor: theme
    && theme.tooltipInk !== undefined
    ? theme.tooltipInk : Tokens.Color.tooltip.text
  readonly property string resolvedFontFamily: fontFamily !== "" ? fontFamily : Tokens.Style.font.family
  readonly property real resolvedRadius: theme
    && theme.tooltipRadius !== undefined
    ? theme.tooltipRadius : Tokens.Style.tooltipRadius

  delay: 320
  padding: 0

  background: Rectangle {
    color: root.resolvedBackground
    border.color: root.resolvedBorderColor
    border.width: root.resolvedBorderWidth
    radius: root.resolvedRadius
  }

  contentItem: Text {
    text: root.text
    color: root.resolvedTextColor
    font.family: root.resolvedFontFamily
    font.pixelSize: root.fontSize
    font.letterSpacing: 1
    leftPadding: root.resolvedBorderWidth + Tokens.Style.space(10)
    rightPadding: root.resolvedBorderWidth + Tokens.Style.space(10)
    topPadding: root.resolvedBorderWidth + Tokens.Style.space(4)
    bottomPadding: root.resolvedBorderWidth + Tokens.Style.space(4)
    renderType: Text.NativeRendering
  }
}
