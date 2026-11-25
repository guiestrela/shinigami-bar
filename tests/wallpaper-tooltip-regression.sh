#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  printf 'wallpaper tooltip regression failed: %s\n' "$*" >&2
  exit 1
}

widget="$repo_root/shinigami.wallpaper-manager/BarWidget.qml"
surface="$repo_root/shinigami.wallpaper-manager/ShinigamiPanel.qml"

[[ -s $widget ]] || fail "wallpaper BarWidget.qml is missing"
[[ -s $surface ]] || fail "wallpaper ShinigamiPanel.qml is missing"

rg -Fq 'ShinigamiPanel {' "$widget" \
  || fail "wallpaper panel does not use the Shinigami surface"
if rg -Fq 'KeyboardPanel {' "$widget"; then
  fail "wallpaper panel still uses the host KeyboardPanel surface"
fi
cmp -s "$surface" "$repo_root/shared/presentation/ShinigamiPanel.qml" \
  || fail "wallpaper ShinigamiPanel.qml drifted from the canonical surface"

# The panel must not paint its own tooltip surface. It delegates to the bar's
# canonical tooltip overlay, which supplies the shared V1/V2 appearance and
# placement.
rg -Fq 'root.bar.showTooltip(riseButton, riseButton.tooltipText)' "$widget" \
  || fail "panel tooltip is not delegated to the bar"
rg -Fq 'root.bar.hideTooltip(riseButton)' "$widget" \
  || fail "panel tooltip is not hidden on exit/click"

if rg -Fq 'ToolTip {' "$widget"; then
  fail "legacy local ToolTip surface is still present"
fi
rise_button=$(sed -n '/component RiseButton:/,/component RiseButtonGroup:/p' "$widget")
if printf '%s' "$rise_button" | rg -Fq 'RectangularShadow {'; then
  fail "panel-local tooltip shadow is still present"
fi
if rg -Fq 'tooltipBackground' "$widget" \
  || rg -Fq 'tooltipBorderColor' "$widget" \
  || rg -Fq 'tooltipCornerRadius' "$widget"; then
  fail "panel-local tooltip surface tokens are still present"
fi

printf 'wallpaper tooltip regression passed\n'
