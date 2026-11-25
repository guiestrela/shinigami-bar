# Shinigami bar port

> **Document status: working design for the isolated `shinigami-bar` copy.**
> This directory is an experimental derivative of `exemplo 1` (Shibumi Shell).
> It is not the production repository and is not an installed Omarchy plugin
> until a separate, explicitly approved packaging/lifecycle change is made.

## Goal

The experimental port keeps the original bar host and layout engine from
`exemplo 1`. The four Rise widgets from `exemplo 2` each have their own
bar entry in V1 and V2.

| Plugin | Behavior | Service owner |
| --- | --- | --- |
| `shinigami.display-manager` | Opens monitor, scaling, text size, and brightness controls | `shinigami.display-manager` |
| `shinigami.wallpaper-manager` | Opens the wallpaper picker or cycles wallpapers with middle-click | `shinigami.quick-access` |
| `shinigami.indicators` | Shows recording, Do Not Disturb, Stay Awake, and Voxtype status next to the clock | `shinigami.status` |
| `shinigami.onedrive` | Shows sync status and opens the account panel | `shinigami.onedrive` |

The Icons page maps the Rise catalog aliases G20 to `shinigami.wallpaper-manager`,
G22 to `shinigami.onedrive`, and G23 to `shinigami.indicators`. These aliases are
appearance-only; they are not native bar groups and do not change plugin
activation.

Quick Access exposes themes, idle inhibition, and the screenshots and videos
pickers. Center owns the clock, calendar, weather, and update presentation.
The suite profile declares 27 plugin roots.

The calendar follows Rise's Monday-first 42-cell month grid, selection
semantics, and four-row agenda cap. Google setup/pull/push and event
create/delete controls are not ported, so `DEL` stays unmapped until a deletion
owner exists. Credential-backed calendar sync is outside the parity claim.

The OneDrive notification target `io.github.salemsayed.omaonedrive` belongs to
the process-wide OneDrive service. Notification clicks route to the widget on
the target output. Display and wallpaper actions use the existing Omarchy
monitor and picker paths.

## Plugin identity

Plugin IDs use `shinigami.<plugin>`. The suite and ownership markers use
`hancore.shibumi`. The installer can read the previous settings keys and
write them using the new names. Published upstream identities retain their
original names and digests.

## Presentation rules

- V1 keeps the pill/slot treatment from Shinigami and the Rise V1 glyphs.
- V2 keeps the flat Shinigami slot treatment and the Rise V2 glyphs.
- Rise `TooltipMixin` behavior is translated to `bar.showTooltip` /
  `bar.hideTooltip`, preserving output-local tooltip ownership. The wallpaper
  manager tooltip includes the right-click settings hint, and right-click
  summons the installed wallpaper manager settings provider.
- Popouts and panels continue to use Shinigami's one routed owner per output.
- Rise-specific state that has no Shinigami owner (for example passwordless sudo
  and remote-session indicators) is not invented; the indicator model exposes
  only capabilities backed by an existing Shinigami service.

## Power-profile compatibility

The bar remains compatible with Omarchy's
`omarchy-power-profiles-daemon` build. The package contract, AUR `depends`, and
install documentation require that package rather than the stock
`power-profiles-daemon` name. The shared `shinigami.power-state` owner
reads the active profile through the `net.hadess.PowerProfiles` D-Bus alias
exported by Omarchy's shell and daemon. It lists profiles with
`omarchy-powerprofiles-list`, applies them with
`omarchy-powerprofiles-set autodetect <profile>` so the AC/battery preference
and shell IPC stay authoritative, and reads battery state from UPower through
one process-wide service. No ported widget creates a second profile daemon,
poller, or IPC owner.

## Validation status

The source trees can be checked with the suite contract and shared runtime
regressions. Physical monitor behavior, live OneDrive credentials, and
installed shell acceptance require separate runtime evidence.
