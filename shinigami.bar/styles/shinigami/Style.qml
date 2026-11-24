pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons
import "." as Shinigami

Item {
  id: root

  property var bar: null

  Shinigami.VisualTokens {
    id: tokens
    bar: root.bar
  }

  readonly property int contractVersion: 1
  readonly property string styleId: "shinigami"
  readonly property string displayName: "Shinigami"
  readonly property int sizeHorizontal: tokens.barHeight
  readonly property int sizeVertical: Commons.Style.bar.sizeVertical
  readonly property int exclusiveSizeHorizontal: tokens.exclusiveHeight
  readonly property int tooltipGap: Commons.Style.space(6)
  readonly property int colorTransitionDuration: tokens.colorDuration
  readonly property string fontFamily: tokens.fontFamily
  readonly property color foreground: tokens.ink
  readonly property color barForeground: tokens.ink
  readonly property color background: tokens.barBackground
  readonly property color urgent: tokens.seal
  readonly property var visualTokens: tokens
  readonly property Component barSurfaceComponent: barSurface
  readonly property Component tooltipSurfaceComponent: tooltipSurface

  visible: false
  width: 0
  height: 0

  Component {
    id: barSurface

    Shinigami.BarSurface { bar: root.bar }
  }

  Component {
    id: tooltipSurface

    Shinigami.TooltipSurface { bar: root.bar }
  }
}
