# Shinigami plugin catalog

Status: reference

The experimental Shinigami suite contains 27 independently registered Omarchy plugins. The
default suite profile installs all of them as one verified transaction.

The authoritative inventory is
[`../../contracts/plugin-suite-v1.json`](../../contracts/plugin-suite-v1.json).
Each plugin's `manifest.json` defines its Omarchy kinds and entry points.

## Core plugins

| Plugin | Role |
| --- | --- |
| `shinigami.bar` | Selectable full-bar host |
| `shinigami.state` | Validated persistent Shinigami configuration |
| `shinigami.control-center` | G1 Control Center and bar wordmark |
| `shinigami.reactor` | Cross-feature event choreography |
| `shinigami.telemetry` | Shared process-wide telemetry |
| `shinigami.power-state` | Shared battery and power-profile state |

## Feature plugins

| Plugin | Role | Primary surface |
| --- | --- | --- |
| `shinigami.workspaces` | G2 | Workspace widget and service |
| `shinigami.update-center` | Update owner | Arch and Git-theme update state |
| `shinigami.status` | G3 | Tray and notification presentation |
| `shinigami.memory` | G4 | Memory widget and panel |
| `shinigami.cpu` | G5 | CPU widget, panel, and GPU telemetry adapter |
| `shinigami.audio` | G6 | Audio widget and panel |
| `shinigami.ai` | G7 | AI usage widget and panel |
| `shinigami.center` | G8 | Clock, weather, calendar, and update presentation |
| `shinigami.indicators` | Standalone | System status and quick controls |
| `shinigami.media` | G9 | Media controls and visualization |
| `shinigami.quick-access` | G10 | Themes and screenshot/video pickers |
| `shinigami.wallpaper-manager` | Standalone | Folder-backed per-display wallpapers, shuffle and scaling |
| `shinigami.onedrive` | Standalone | Sync status, accounts, and notification routing |
| `shinigami.network` | G11 | Network widget and panel |
| `shinigami.battery` | G12 | Battery widget and panel |
| `shinigami.display-manager` | G13 | Display configuration, scaling, text size, and brightness |
| `shinigami.power-profile` | G14 | Power-profile widget and panel |
| `shinigami.bluetooth` | G15 | Bluetooth widget, service, and panel |
| `shinigami.temperature` | G16 | Selectable temperature source |
| `shinigami.gpu` | G17 | GPU widget and panel |
| `shinigami.storage` | G18 | Storage widget, service, and panel |

AI usage, power profile, and Bluetooth are disabled by default in the V1
configuration. Hardware-dependent widgets may remain hidden when their
required device or service is unavailable.

## Host service reuse

Shinigami uses native Quattro owners where they provide sufficient state and
actions, including media, notifications, tray, background, monitor, weather,
idle, and system-update services. Shinigami owns native Audio and Network state.
Its Bluetooth adapter keeps BlueZ QObjects private and publishes detached
identity-bound records. Device actions retain one `omarchy-bluetooth-device`
helper path with exact device-identity checks. Global radio power instead uses
one explicit `omarchy-bluetooth-power on|off` request for all Bluetooth radios;
it follows the host's rfkill persistence policy and cannot clear a hardware
block. BlueZ remains authoritative for the displayed radio state. Bar, panel,
and IPC share the same adapter-bound pending target and ignore repeat clicks.

The Bluetooth adapter owns five bounded lifecycle timers. Its separate
one-shot 20-second power-state deadline clears pending state; it neither stops
the detached helper nor prevents later effects. The service facade retains
one discovery-reconciliation timer and the bounded native-adapter discovery
teardown guard. See the [architecture contract](../../ARCHITECTURE.md).

Shinigami owns its presentation and adds a narrow adapter only where the host
contract cannot produce the approved behavior. It must not create a duplicate
platform owner.

## Installation model

Quattro's repository installer expects one root manifest. Shinigami instead has
27 top-level plugin roots and uses `scripts/shinigami-suite` to install, update,
verify, roll back, and remove them together.

Individual plugin directories are not advertised as unsupported ad hoc
installs. Use the suite adapter so dependencies, ownership markers, config
continuity, and runtime verification remain intact.

Shinigami deliberately does not ship an application launcher menu. Omarchy's
native menu remains the sole owner. Read [plugin compatibility](../plugin-compatibility.md)
before using visible Shinigami widgets with another bar host.
