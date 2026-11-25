#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  printf 'wallpaper tooltip regression failed: %s\n' "$*" >&2
  exit 1
}

widget="$repo_root/shinigami.wallpaper-manager/BarWidget.qml"
presentation="$repo_root/shinigami.state/lib/presentation"

[[ -s $widget ]] || fail "wallpaper BarWidget.qml is missing"

for component in ShinigamiPillToolTip.qml ShinigamiPanelToolTip.qml; do
  [[ -s "$presentation/$component" ]] || fail "canonical tooltip missing: $component"
done

rg -Fq 'import "../shinigami.state/lib/presentation" as Presentation' "$widget" \
  || fail "wallpaper does not import the canonical presentation tooltips"
rg -Fq 'readonly property var shinigamiTokens: root.barTokens' "$widget" \
  || fail "wallpaper does not expose bar tokens to tooltip hosts"
rg -Fq 'readonly property color controlForeground: root.fg' "$widget" \
  || fail "wallpaper does not expose tooltip foreground"
rg -Fq 'readonly property color controlBorderColor:' "$widget" \
  || fail "wallpaper does not expose tooltip border color"
rg -Fq 'readonly property string tooltipShellStyle:' "$widget" \
  || fail "wallpaper does not resolve V1/V2 separately"

rg -Fq 'Presentation.ShinigamiPillToolTip {' "$widget" \
  || fail "V1 pill tooltip is missing"
rg -Fq 'root.tooltipShellStyle === "shinigami"' "$widget" \
  || fail "V1 tooltip visibility is not gated"
rg -Fq 'Presentation.ShinigamiPanelToolTip {' "$widget" \
  || fail "V2 panel tooltip is missing"
rg -Fq 'root.tooltipShellStyle !== "shinigami"' "$widget" \
  || fail "V2 tooltip visibility is not gated"

if rg -Fq 'delay: 400' "$widget" || rg -Fq 'radius: 4' "$widget"; then
  fail "legacy wallpaper tooltip surface is still present"
fi

printf 'wallpaper tooltip regression passed\n'
