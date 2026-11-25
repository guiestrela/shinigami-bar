#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/tests/lib/baselines.sh"
shinigami_load_omarchy_baseline
omarchy_path=$OMARCHY_PATH
quickshell_bin=${QUICKSHELL_BIN:-/usr/bin/quickshell}
tmpdir=$(mktemp -d /tmp/shinigami-brightness.XXXXXX)
trap 'rm -rf -- "$tmpdir"' EXIT

fail() {
  printf 'brightness plugin regression failed: %s\n' "$*" >&2
  exit 1
}

[[ -d $omarchy_path/shell ]] || fail "Omarchy shell not found: $omarchy_path/shell"
[[ -x $quickshell_bin ]] || fail "Quickshell not found: $quickshell_bin"

mkdir -p "$tmpdir/runtime" "$tmpdir/fixtures"
chmod 700 "$tmpdir/runtime"
shinigami_stage_suite_runtime "$repo_root" "$tmpdir"
cp -a -- "$repo_root/shinigami.display-manager" "$tmpdir/brightness"
cp -a -- "$omarchy_path/shell/Commons" "$tmpdir/Commons"
cp -a -- "$omarchy_path/shell/Ui" "$tmpdir/Ui"
install -m 0644 "$repo_root/tests/brightness-plugin-smoke.qml" "$tmpdir/shell.qml"
install -m 0644 "$repo_root/tests/fixtures/MonitorTestView.qml" \
  "$tmpdir/MonitorTestView.qml"
install -m 0755 "$repo_root/tests/fixtures/display-manager-helper.py" \
  "$tmpdir/fixtures/display-manager-helper.py"
fixture_helper="$tmpdir/fixtures/display-manager-helper.py"
fixture_state="$tmpdir/display-manager-state.json"

set +e
output=$(timeout 12 env \
  QT_QPA_PLATFORM=offscreen \
  WAYLAND_DISPLAY= \
  XDG_RUNTIME_DIR="$tmpdir/runtime" \
  SHINIGAMI_DISPLAY_MANAGER_APPLY="$fixture_helper" \
  SHINIGAMI_DISPLAY_MANAGER_GUARD="$fixture_helper" \
  SHINIGAMI_DISPLAY_STATE_CACHE="$tmpdir/display-state-cache.json" \
  SHINIGAMI_DISPLAY_FIXTURE_STATE="$fixture_state" \
  QML_IMPORT_PATH="$omarchy_path/shell${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" \
  QML2_IMPORT_PATH="$omarchy_path/shell${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}" \
  "$quickshell_bin" -p "$tmpdir" 2>&1)
rc=$?
set -e

printf '%s\n' "$output"
[[ $rc -eq 0 ]] || fail "component smoke exited $rc"
grep -F 'brightness plugin smoke passed' <<<"$output" >/dev/null \
  || fail "success marker missing"
if grep -Eq 'TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign|Internal error' \
    <<<"$output"; then
  fail "component smoke emitted a QML runtime error"
fi

plugin="$repo_root/shinigami.display-manager"
widget="$plugin/BarWidget.qml"
service="$plugin/Service.qml"
panel="$plugin/BrightnessPanel.qml"
content="$plugin/DisplayManagerPanelContent.qml"
controller="$plugin/DisplayManagerController.qml"
panel_shell="$plugin/ShinigamiPanel.qml"

[[ ! -e $plugin/MonitorPanelBridge.qml ]] \
  || fail "removed monitor bridge reappeared in the payload"
[[ ! -e $plugin/HostWidgetEmbed.qml ]] \
  || fail "removed host embed reappeared in the display payload"
if rg -q 'MonitorPanelBridge|HostWidgetEmbed|bar\.monitorService|embed\.resolveComponent' \
    "$plugin"; then
  fail "display plugin still depends on a hidden official backend or bridge"
fi

rg -Fq 'serviceFor("shinigami.display-manager")' "$widget" \
  || fail "brightness widget does not resolve the shared service"
rg -Fq 'property var bar: Qt.isQtObject(shell) && "bar" in shell ? shell.bar : null' "$service" \
  || fail "monitor service does not guard the versioned active bar facade"
[[ $(rg -c '^  DisplayManagerController \{' "$service" || true) -eq 1 ]] \
  || fail "display service must own exactly one Rise-backed controller"
rg -Fq 'readonly property var controllerApi: controller' "$service" \
  || fail "service does not expose the controller facade to passive panels"
[[ $(rg -c '^  Commons\.ShellIpc \{' "$service" || true) -eq 1 ]] \
  || fail "display service must own exactly one legacy IPC handler"
rg -Fq 'target: "omarchy.monitor"' "$service" \
  || fail "display owner lost the documented legacy monitor IPC identity"
rg -Fq 'function acquireVisualBar(holder, candidate)' "$service" \
  || fail "shared owner cannot acquire the active visual bar facade"
rg -Fq 'VisualBarLease {}' "$service" \
  || fail "visual bar registration is not holder-parented"
rg -Fq 'function summonVisiblePanel()' "$service" \
  || fail "display owner lost its visible panel summon path"
rg -Fq 'function closeVisiblePanels()' "$service" \
  || fail "display owner lost its visible panel close path"
rg -Fq 'Quickshell.execDetached(["omarchy-shell", "osd", "show", payload])' "$service" \
  || fail "display owner lost the host OSD fallback"
rg -Fq 'state.setWidgetSetting("G13", "shinigami.display-manager",' "$service" \
  || fail "display owner bypasses the authoritative widget state service"

rg -Fq 'function localScriptPath(url)' "$controller" \
  || fail "controller lost its plugin-local helper resolution"
rg -Fq 'scripts/shinigami-display-manager-apply' "$controller" \
  || fail "controller does not use the Shinigami apply helper"
rg -Fq 'scripts/shinigami-display-manager-guard' "$controller" \
  || fail "controller does not use the Shinigami rollback guard"
rg -Fq 'SHINIGAMI_DISPLAY_STATE_CACHE' "$controller" \
  || fail "controller lost the isolated display state cache seam"
rg -Fq 'function previewMonitor(name)' "$controller" \
  || fail "controller does not expose passive preview state"
rg -Fq 'function stageMonitor(name, patch)' "$controller" \
  || fail "controller does not stage display drafts"
rg -Fq 'function applyDrafts()' "$controller" \
  || fail "controller does not apply guarded display drafts"
rg -Fq 'function toggleMirror(' "$controller" \
  || fail "controller lost the Rise mirror action"
rg -Fq 'function saveLayout()' "$controller" \
  || fail "controller lost the Rise layout save action"
for helper in shinigami-display-manager-apply shinigami-display-manager-guard; do
  [[ -x $plugin/scripts/$helper ]] || fail "display helper is not executable: $helper"
done
rg -Fq 'LEGACY_BEGIN = "-- BEGIN RISE DISPLAY MANAGER (AUTO-GENERATED)"' \
  "$plugin/scripts/shinigami-display-manager-apply" \
  || fail "apply helper lost legacy Rise managed-block compatibility"
rg -Fq 'BEGIN = "-- BEGIN SHINIGAMI DISPLAY MANAGER (AUTO-GENERATED)"' \
  "$plugin/scripts/shinigami-display-manager-apply" \
  || fail "apply helper no longer writes the Shinigami managed block"

[[ $(rg -c '^PanelWindow \{' "$panel_shell" || true) -eq 1 ]] \
  || fail "the plugin must own exactly one panel window implementation"
[[ $(rg -c '^ShinigamiPanel \{' "$panel" || true) -eq 1 ]] \
  || fail "the visible display panel must own exactly one Shinigami surface"
if rg -q 'PanelWindow|PopupWindow' "$widget" "$service" "$panel" "$content" "$controller"; then
  fail "display backend or content opened a second visible surface"
fi
rg -Fq 'Loader { id: popupLoader }' "$widget" \
  || fail "display panel is not lazily loaded"
rg -Fq 'popupLoader.setSource(popupSource, {' "$widget" \
  || fail "display panel loader does not receive output-local ownership"
rg -Fq 'function childPanelWidget(pluginId)' "$widget" \
  || fail "display widget lost its one-panel ownership guard"
rg -Fq 'function ownsPanelWidget(owner) { return owner === root }' "$widget" \
  || fail "display widget no longer owns its visible panel"
rg -Fq 'Commons.Util.wheelSteps(wheelAccumulator' "$widget" \
  || fail "brightness wheel does not accumulate high-resolution deltas"
rg -Fq 'if (!brightnessAvailable) return false' "$widget" \
  || fail "unavailable brightness still accumulates wheel deltas"
rg -Fq 'monitorService.showBrightnessOsd(monitorService.brightnessPercent)' "$widget" \
  || fail "effective brightness wheel changes do not forward host OSD"
rg -Fq 'const leases = _visualBarLeases.slice()' "$service" \
  || fail "monitor service teardown does not retire external visual leases"

if rg -q 'Process \{|Quickshell\.Io|FileView|UPower' \
    "$widget" "$panel" "$content"; then
  fail "screen-local brightness presentation owns hardware work"
fi
rg -q '^  function refreshDisplayState\(\)' "$panel" \
  || fail "display panel does not expose its explicit refresh action"
rg -q 'onClicked: panel\.refreshDisplayState\(\)' "$panel" \
  || fail "display refresh button bypasses the tested action path"
rg -Fq 'contentWidth: fittedContentWidth(Commons.Style.space(380))' "$panel" \
  || fail "display panel drifted from the documented 380 px width"
rg -Fq 'displayContent && displayContent.expandedSelectCount > 0' "$panel" \
  || fail "display panel does not grow for an expanded Rise select"
rg -Fq 'function ensureControlVisible(control)' "$panel" \
  || fail "display panel cannot scroll an expanded Rise select into view"
rg -Fq 'onExpandedChanged: {' "$content" \
  || fail "Rise select expansion is not reported to the panel"
rg -Fq 'objectName: panel.shellStyle === "shinigami"' "$panel" \
  || fail "display panel header no longer distinguishes V1 and V2"
rg -Fq 'glyph: "\uE5D5"' "$panel" \
  || fail "display refresh action lost the Rise Material glyph"
rg -Fq 'glyph: "✕"' "$panel" \
  || fail "display close action lost the Rise X glyph"

rg -Fq 'DisplayManagerPanelContent {' "$panel" \
  || fail "visible panel does not host the full Rise display content"
rg -Fq 'required property var panel' "$content" \
  || fail "Rise content lost its Shinigami panel facade"
rg -Fq 'required property var service' "$content" \
  || fail "Rise content lost the single-owner service facade"
rg -Fq 'readonly property var controller: service.controllerApi' "$content" \
  || fail "Rise content bypasses the controller facade"
rg -Fq 'controller.stageBrightness(controller.selectedMonitor, value)' "$content" \
  || fail "Rise brightness control bypasses the shared owner"
rg -Fq 'controller.setTextSize(index)' "$content" \
  || fail "Rise Text Size control bypasses the shared owner"
rg -Fq 'controller.saveLayout()' "$content" \
  || fail "Rise layout save bypasses the shared owner"
rg -Fq 'controller.confirmChanges()' "$content" \
  || fail "Rise confirmation bypasses the guarded rollback owner"
rg -Fq 'controller.revertChanges()' "$content" \
  || fail "Rise rollback bypasses the guarded rollback owner"
[[ $(rg -c '^[[:space:]]+Ui\.PanelSlider \{' "$content" || true) -eq 1 ]] \
  || fail "Rise display content must use one unsegmented brightness slider"
for token in controlFillColor controlHoverFillColor controlActiveFillColor \
  controlBorderColor controlHoverBorderColor controlAccent controlForeground \
  renderedSurfaceColor; do
  rg -q "panel\.${token}" "$content" \
    || fail "Rise display control bypasses the shared Shinigami token: $token"
done
for object_name in display-canvas display-resolution \
  display-position-x display-position-y display-scale display-rotation \
  display-mirror display-enable display-disable \
  display-brightness display-brightness-readout display-text-size display-save \
  display-confirmation display-keep display-revert; do
  rg -Fq "\"${object_name}\"" "$content" \
    || fail "Rise display control missing: $object_name"
done
rg -Fq 'objectName: "display-monitor-" + modelData.name' "$content" \
  || fail "Rise monitor selection controls are missing"
rg -Fq 'objectName: "display-workspace-" + (index + 1)' "$content" \
  || fail "Rise workspace assignment controls are missing"
if rg -q 'width: parent\.width - x - Commons\.Style\.space\(82\)' "$content"; then
  fail "display rotation field can collapse and elide its label"
fi
rg -Fq 'width: Commons.Style.space(110)' "$content" \
  || fail "display rotation field is not sized for the compact Rise layout"
rg -Fq 'width: parent.width - brightnessReadout.width - parent.spacing * 2' "$content" \
  || fail "display brightness readout can overflow the panel edge"
rg -Fq -- '- Commons.Style.space(74) - Commons.Style.space(4)' "$content" \
  || fail "display brightness readout has no edge clearance"

rg -Fq 'RiseV1.DisplayManagerWidget' "$widget" \
  || fail "V1 does not use the Display Manager face"
rg -Fq 'RiseV2.DisplayManagerWidget' "$widget" \
  || fail "V2 does not use the Display Manager face"
rg -Fq 'readonly property string tooltipText: "Display Manager · click to configure monitors"' "$widget" \
  || fail "display widget tooltip drifted from the Rise surface name"
if rg -q 'Brightness · ' "$widget"; then
  fail "display widget tooltip must not duplicate live brightness state"
fi
v2_face="$plugin/rise/v2/DisplayManagerWidget.qml"
rise_root="$plugin/rise/RiseRoot.qml"
rg -Fq 'readonly property color contentColor: root.widgetContentColor("G13", root.widgetIconColor)' "$v2_face" \
  || fail "V2 display face does not resolve its group content color"
rg -Fq 'widgetHasFill("G13")' "$v2_face" \
  || fail "V2 display face does not use the Shinigami display group fill state"
rg -Fq 'function widgetContentColor(groupId, fallback)' "$rise_root" \
  || fail "Rise display facade does not expose widgetContentColor"
rg -Fq 'function widgetHasFill(groupId)' "$rise_root" \
  || fail "Rise display facade does not expose widgetHasFill"

printf 'brightness plugin regression passed\n'
