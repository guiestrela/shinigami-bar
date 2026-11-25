#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/tests/lib/baselines.sh"
source "$repo_root/tests/lib/qs-runner.sh"
source "$repo_root/tests/lib/host-diagnostics.sh"
shinigami_load_omarchy_baseline
omarchy_path=$OMARCHY_PATH
quickshell_bin=${QUICKSHELL_BIN:-/usr/bin/quickshell}
tmpdir=$(mktemp -d /tmp/shinigami-onedrive-plugin.XXXXXX)
trap 'rm -rf -- "$tmpdir"' EXIT

fail() {
  printf 'onedrive plugin regression failed: %s\n' "$*" >&2
  exit 1
}

[[ -d $omarchy_path/shell ]] || fail "Omarchy shell not found: $omarchy_path/shell"
[[ -x $quickshell_bin ]] || fail "Quickshell not found: $quickshell_bin"

mkdir -p "$tmpdir/runtime" "$tmpdir/fixtures"
chmod 700 "$tmpdir/runtime"
shinigami_stage_suite_runtime "$repo_root" "$tmpdir"
cp -a -- "$repo_root/shinigami.onedrive" "$tmpdir/onedrive"
cp -a -- "$omarchy_path/shell/Commons" "$tmpdir/Commons"
cp -a -- "$omarchy_path/shell/Ui" "$tmpdir/Ui"
install -m 0644 "$repo_root/tests/onedrive-plugin-smoke.qml" "$tmpdir/shell.qml"

set +e
output=$(timeout 12 env \
  QT_QPA_PLATFORM=offscreen \
  WAYLAND_DISPLAY= \
  XDG_RUNTIME_DIR="$tmpdir/runtime" \
  QML_IMPORT_PATH="$omarchy_path/shell${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" \
  QML2_IMPORT_PATH="$omarchy_path/shell${QML2_IMPORT_PATH:+:$QML_IMPORT_PATH}" \
  "$quickshell_bin" -p "$tmpdir" 2>&1)
rc=$?
set -e

printf '%s\n' "$output"
[[ $rc -eq 0 ]] || fail "component smoke exited $rc"
grep -F 'onedrive plugin smoke passed' <<<"$output" >/dev/null \
  || fail "success marker missing"
if grep -Eq 'TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign|Internal error' \
    <<<"$output"; then
  fail "component smoke emitted a QML runtime error"
fi

plugin="$repo_root/shinigami.onedrive"
manifest="$plugin/manifest.json"
service="$plugin/Service.qml"
bar_widget="$plugin/BarWidget.qml"
suite="$repo_root/contracts/plugin-suite-v1.json"
boundary="$repo_root/contracts/backend-boundary-v1.json"
runtime="$repo_root/shinigami.state/runtime/Runtime.qml"
version=$(<"$repo_root/VERSION")

jq -e --arg version "$version" '
  .schemaVersion == 1 and .id == "shinigami.onedrive" and .version == $version
  and (.kinds == ["bar-widget", "service"])
  and .keepLoaded == true
  and .entryPoints.barWidget == "BarWidget.qml"
  and .entryPoints.service == "Service.qml"
  and .barWidget.defaultSection == "right"
  and (.["x-shinigami"].suiteId == "hancore.shibumi")
  and (.["x-shinigami"].role == "onedrive")
  and (.["x-shinigami"].requires == ["shinigami.state"])
' "$manifest" >/dev/null || fail "standalone OneDrive manifest shape drifted"

for entry in BarWidget.qml Service.qml OneDriveService.qml OneDriveOverlay.qml \
  OneDriveRiseRoot.qml; do
  [[ -s "$plugin/$entry" ]] || fail "OneDrive entry point missing: $entry"
done

jq -e '
  .suiteId == "hancore.shibumi"
  and ([.plugins[] | select(.id == "shinigami.onedrive")] | length) == 1
  and ([.profiles[] | select(.id == "default")
        | select(([.install[] | select(. == "shinigami.onedrive")] | length) == 1)
        | select(([.layout.right[] | select(. == "shinigami.onedrive")] | length) == 1)
       ] | length) == 1
' "$suite" >/dev/null || fail "OneDrive is not a default standalone suite widget"

if jq -e '.profiles[] | select(.id == "default")
  | .enableServices[] | select(. == "shinigami.onedrive")' "$suite" >/dev/null; then
  fail "keepLoaded OneDrive service was duplicated in enableServices"
fi

jq -e '
  ([.capabilities[] | select(.id == "onedrive" and .owner == "shinigami.onedrive")] | length) == 1
  and ([.commandRules[] | select(.capability == "onedrive" and .owner != "shinigami.onedrive")] | length) == 0
' "$boundary" >/dev/null || fail "backend boundary does not assign OneDrive ownership"

rg -Fq 'import "../shinigami.state/runtime" as SuiteRuntime' "$service" \
  || fail "OneDrive service does not join the shared runtime"
rg -Fq 'pluginId: "shinigami.onedrive"' "$service" \
  || fail "OneDrive service does not register its own provider"
rg -Fq "implementationVersion: \"$version\"" "$service" \
  || fail "OneDrive provider version does not match the suite version"
rg -Fq '"shinigami.onedrive"' "$runtime" \
  || fail "shared runtime does not admit the OneDrive provider"
rg -Fq 'serviceFor("shinigami.onedrive")' "$bar_widget" \
  || fail "OneDrive widget does not borrow the process-wide service"
rg -Fq 'property alias pollingEnabled: adapter.pollingEnabled' "$service" \
  || fail "OneDrive service cannot receive host polling settings"
rg -Fq 'property alias settings: adapter.settings' "$service" \
  || fail "OneDrive service cannot receive host widget settings"
rg -Fq 'readonly property color tooltipInk: token("ink", host && host.bar' \
  "$plugin/OneDriveRiseRoot.qml" \
  || fail "OneDrive panel tooltip text does not follow the bar ink token"
rg -Fq 'text: Tokens.Style.theme.tooltipInk' \
  "$plugin/integration/ui/Color.qml" \
  || fail "OneDrive panel tooltip colors do not follow the Shinigami bar tokens"
rg -Fq 'readonly property real tooltipRadius: token("tooltipRadius", 6)' \
  "$plugin/OneDriveRiseRoot.qml" \
  || fail "OneDrive tooltip radius does not come from the bar tokens"
rg -Fq '? Tokens.Style.theme.tooltipRadius : Tokens.Style.tooltipRadius' \
  "$plugin/integration/ui/PanelToolTip.qml" \
  || fail "OneDrive panel tooltip frame does not use the bar tooltip radius"
rg -Fq '? Tokens.Style.theme.panelOuterBorderW : Tokens.Style.tooltipBorderWidth' \
  "$plugin/integration/ui/PanelToolTip.qml" \
  || fail "OneDrive panel tooltip frame does not use the bar border width"
rg -Fq 'id: headerActions' "$plugin/integration/Panel.qml" \
  || fail "OneDrive panel has no header action row"
rg -Fq 'tooltipText: "Close"' "$plugin/integration/Panel.qml" \
  || fail "OneDrive panel has no close action"

receiver_count=$(rg -l -F 'target: "io.github.salemsayed.omaonedrive"' \
  "$repo_root"/shinigami.*/*.qml | wc -l)
[[ $receiver_count -eq 1 ]] || fail "OmaOneDrive IPC does not have exactly one receiver"
rg -Fq 'target: "io.github.salemsayed.omaonedrive"' "$service" \
  || fail "the sole OneDrive IPC receiver is not owned by shinigami.onedrive"
for function_name in open show close hide toggle refresh check fullStatus pause \
  pauseFor resume toggleSync folder web resync status accounts selectAccount \
  openAccount repairAccount; do
  rg -q "function ${function_name}\(" "$service" \
    || fail "OneDrive IPC function missing: $function_name"
done

for function_name in screenForName resolveTargetScreen activateFocusedPopupScreen \
  activeTargetPresent closeIfTargetMissing openPanel takeOneDriveOpenTarget close \
  toggle; do
  rg -q "function ${function_name}\(" "$service" \
    || fail "OneDrive output routing function missing: $function_name"
done
rg -Fq 'coordinator.activeScreenName === (targetScreen' "$bar_widget" \
  || fail "OneDrive widget does not derive visibility from the active output"
rg -Fq 'bar.requestPopout(root)' "$bar_widget" \
  || fail "OneDrive widget does not join the bar popout owner"
rg -Fq 'bar.releasePopout(root)' "$bar_widget" \
  || fail "OneDrive widget does not release its popout lease"

if rg -q 'Presentation\.PillSurface' "$bar_widget"; then
  fail "OneDrive still adds an outer standalone pill around its glyph"
fi
if rg -Fq 'oneDrivePillV2' "$bar_widget"; then
  fail "OneDrive still paints a V2 pill that belongs to the slot owner"
fi
rg -Fq 'backgroundComponent: root.tokens && (root.tokens.v2Shell === true' \
    "$bar_widget" \
  || fail "OneDrive lost its Rise V1 pill ownership gate"
rg -Fq '|| (root.bar && root.bar.vertical)) ? null : oneDrivePillV1' \
    "$bar_widget" \
  || fail "OneDrive V1 pill is not disabled in V2 and vertical bars"
rg -Fq 'id: oneDrivePillV1' "$bar_widget" \
  || fail "OneDrive lost Rise's single V1 background pill"
rg -Fq 'RiseV1.PillShadow { theme: root.oneDriveRoot }' "$bar_widget" \
  || fail "OneDrive V1 pill lost its shadow owner"
rg -Fq 'implicitWidth: visible ? actionRow.implicitWidth : 0' "$bar_widget" \
  || fail "OneDrive bar width still reserves standalone pill padding"

if rg -qi 'onedrive|omaonedrive' \
    "$repo_root/shinigami.quick-access/BarWidget.qml" \
    "$repo_root/shinigami.quick-access/Service.qml"; then
  fail "Quick Access still owns OneDrive presentation or IPC"
fi

printf 'onedrive plugin regression passed\n'
