#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mode=${1:---check}

case "$mode" in
  --check | --write) ;;
  *)
    printf 'Usage: %s [--check|--write]\n' "$0" >&2
    exit 2
    ;;
esac

# ShinigamiPanel retains three lifecycle timers, so it cannot enter the passive
# State presentation library. Keep its existing copies drift-checked until its
# scheduling contract can be separated without changing panel behavior.
# HostWidgetEmbed shares checked host-embedding code without a cross-plugin import.
mappings=(
  "shared/presentation/RiseTooltipMixin.qml:shinigami.center/rise/components/TooltipMixin.qml"
  "shared/presentation/RiseTooltipMixin.qml:shinigami.indicators/rise/components/TooltipMixin.qml"
  "shared/presentation/RiseTooltipMixin.qml:shinigami.onedrive/components/TooltipMixin.qml"
  "shared/presentation/RiseTooltipMixin.qml:shinigami.wallpaper-manager/rise/components/TooltipMixin.qml"
  "shared/runtime/HostWidgetEmbed.qml:shinigami.center/HostWidgetEmbed.qml"
  "shared/runtime/HostWidgetEmbed.qml:shinigami.status/HostWidgetEmbed.qml"
  "shared/runtime/HostWidgetEmbed.qml:shinigami.audio/HostWidgetEmbed.qml"
  "shared/runtime/HostWidgetEmbed.qml:shinigami.display-manager/HostWidgetEmbed.qml"
  "shared/presentation/WaterRing.qml:shinigami.cpu/WaterRing.qml"
  "shared/presentation/WaterRing.qml:shinigami.battery/WaterRing.qml"
  "shared/presentation/WaterRing.qml:shinigami.temperature/WaterRing.qml"
  "shared/presentation/ShinigamiPanel.qml:widgets/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.control-center/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.update-center/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.memory/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.cpu/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.audio/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.media/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.workspaces/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.status/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.center/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.network/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.display-manager/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.bluetooth/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.battery/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.power-profile/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.ai/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.temperature/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.gpu/ShinigamiPanel.qml"
  "shared/presentation/ShinigamiPanel.qml:shinigami.storage/ShinigamiPanel.qml"
)

failed=0
for mapping in "${mappings[@]}"; do
  source_path=${mapping%%:*}
  target_path=${mapping#*:}
  source_file="$repo_root/$source_path"
  target_file="$repo_root/$target_path"

  [[ -f $source_file ]] || {
    printf 'Missing shared source: %s\n' "$source_path" >&2
    failed=1
    continue
  }

  if [[ $mode == --write ]]; then
    install -Dm0644 -- "$source_file" "$target_file"
  elif ! cmp -s -- "$source_file" "$target_file"; then
    printf 'Vendored file drift: %s -> %s\n' "$source_path" "$target_path" >&2
    failed=1
  fi
done

(( failed == 0 )) || exit 1
printf 'Shinigami active panel vendoring %s passed\n' "${mode#--}"
