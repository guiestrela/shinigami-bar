# Install, update, and remove

Status: user reference

Shinigami installs 27 independent plugin roots into Omarchy's normal plugin
directory. The repository root is a suite source, not a single installable
Omarchy plugin.

Use a clean Shinigami Git checkout for source lifecycle commands. See the
[current release notes](../.github/release-notes/v0.0.1.md) for the version reset.

## Requirements

- Omarchy Quattro with an active, unlocked desktop session.
- A clean Shinigami Git checkout with a committed revision. The source
  installer checks this even for a dry run.
- The runtime dependencies in the Pacman command below, including
  `omarchy-power-profiles-daemon` and the fonts used by the widgets.

The exact accepted Omarchy and Quickshell packages are recorded in the
[Shinigami host compatibility record](architecture/quattro-compatibility.md).

Notification history follows the host's on-disk layout. On Omarchy 4.0.6 the Recent list
keeps per-row removal and "Clear all". On Omarchy 4.5.0, Clear all hides every row of
the host's history locally; ✕ hides one row; the host's history.json is not modified.
Live rows remain unavailable through the host proxy on both.

## Package status

Shinigami is not yet published in Omarchy's package repository. The
`packaging/` directory contains a local package scaffold and validation tools,
but `omarchy pkg add shinigami-shell` is not a current installation command.
Use [Install from source](#install-from-source) for the supported installation
route.

## Install from source

1. In an unlocked Omarchy desktop session, open a terminal at the checkout
   root and install the dependencies.

   ```bash
   sudo pacman -S --needed git quickshell python python-dbus iputils glib2 systemd jq curl networkmanager omarchy-power-profiles-daemon upower xdg-utils libnotify wl-clipboard ttf-material-symbols-variable ttf-jetbrains-mono-nerd-basic noto-fonts-cjk adwaita-fonts
   ```

2. Preview the targets and check that the command succeeds.

   ```bash
   ./scripts/shinigami-suite install --dry-run
   ```

3. Install as your desktop user and confirm the prompt. The installer switches
   from the current bar to Shinigami and restarts the Omarchy shell automatically.

   ```bash
   ./scripts/shinigami-suite install
   ```

The dry run validates the suite and prints its targets. If the Omarchy shell
is stopped, start it with `omarchy restart shell` before running the installer
so it can check the session lock state. The installation then performs these
steps.

1. validates all plugin manifests with Omarchy;
2. rejects unsafe or foreign replacement targets;
3. stages and hashes the complete payload;
4. snapshots the affected plugins and `shell.json`;
5. verifies that the session is unlocked;
6. for managed activation, drains the production shell before publishing any
   plugin root, writes the new config, and performs one full restart;
7. for external-layout installation, publishes the roots and uses a live
   registry rescan and config reload without changing the active bar owner;
8. confirms the running payload and, for managed activation, checks that
   Shinigami is the only active bar. If verification fails, the transaction
   restores the previous state.

Shinigami's lifecycle does not edit files below `~/.config/hypr/` and does not
change Hyprland window borders, inner gaps, or outer gaps. Such changes are not
an expected effect of installing, updating, activating, deactivating, or
uninstalling Shinigami. Keep a separately run `omarchy update` distinct when
diagnosing an installation: Omarchy owns its own Hyprland defaults and config
migrations, while Shinigami only owns its plugin payload, `shell.json`, menu
routing, and Shinigami state.

Pass `--yes` only when you intentionally want to skip the confirmation prompt.
Do not run `omarchy plugin add` against the repository root. Quattro installs
one root manifest at a time, while Shinigami is a managed suite.

### Keep the current bar

Install the complete suite without replacing the active bar or its widget
layout:

```bash
./scripts/shinigami-suite install --no-activate --keep-layout --yes
```

The two flags form one safety policy and must be used together. The adapter
stages all 27 roots, enables required Shinigami services, records external layout
ownership, and verifies the running payload through the bar-independent state
service. It does not install individual plugin roots.

Add Shinigami widgets with Omarchy Settings or the active bar's supported widget
manager. See [cross-bar plugin compatibility](plugin-compatibility.md).

## Migrate a managed QS Rise installation

Use migration only when the predecessor was installed by its suite adapter:

```bash
./scripts/shinigami-suite migrate --dry-run
./scripts/shinigami-suite migrate
```

Migration preserves unrelated `shell.json` data, bar position, layout order,
widget options, and Shinigami-compatible settings. It refuses unmanaged legacy
directories, invalid state, and unfinished predecessor transactions.

## Update

Run lifecycle commands from a terminal inside the Hyprland session. Plain SSH
cannot reach the compositor for the shell restart; it can hang and leave an
interrupted transaction, recovered by the next run from a session terminal.

From the accepted Shinigami checkout:

```bash
./scripts/shinigami-suite update --dry-run
./scripts/shinigami-suite update --yes
./scripts/shinigami-suite status
```

The `shinigami-shell` equivalents apply only to a locally built, installed
package. No update is available through `omarchy pkg` while the package remains
unpublished.

An update requires a suite-managed Shinigami installation. It stages all 27
current plugin roots as one transaction and verifies that the shell executes
the accepted payload rather than a stale QML cache. For the managed Shinigami
bar, the updater drains the shell before publishing live plugin roots, then
starts it once; this prevents a plugin hot reload from overlapping IPC teardown.
Hidden staging directories
do not trigger Quattro's live plugin watcher. Immediately before replacing the
live roots, the updater requires an authoritative lock status with `locked`,
`requested`, `pending`, `sessionLocked`, and `secure` all explicitly false. An
active, incomplete, malformed, or unavailable lock status aborts the update,
discards staging, and leaves the live plugins unchanged; unlock the active
session and retry. For an external-bar installation, update preserves the
active bar and layout.

The lifecycle inventories every existing journal before recovery and admits only
exact revision, plugin-digest, payload-digest, activation, marker, and journal
identities declared by the lifecycle predecessor contract. A shared version
string is not sufficient. Step-6 Power registration or journal metadata, mixed
live markers, multiple public journals, and unknown states fail closed before
recovery or mutation. One fully admitted interrupted journal may be recovered
before the lifecycle checks live payload identity again.

Exact supported identities are declared in
[`lifecycle-predecessors-v1.json`](../contracts/lifecycle-predecessors-v1.json);
a version range or arbitrary development checkout is not an admission rule.
Tag `v0.1.1-beta.14` was never published and is not a supported predecessor.
For a source checkout outside the admitted identities, follow
[supervised recovery](#supervised-recovery). Do not bypass admission by manually
deleting lifecycle state, journals, markers, or plugin directories.

### Move from a checkout to a local package

This route applies only after building and installing the package locally.
Install it without uninstalling the existing suite, then run:

```bash
shinigami-shell update --dry-run
shinigami-shell update --yes
shinigami-shell status
```

The transaction adopts the package payload, preserves the active profile,
layout, settings, and unrelated Omarchy data, and records `package` as the new
authoritative origin. The old checkout is not deleted or modified.

### Roll back a package version

> [!WARNING]
> **Downgrade warning (also applies to 0.2.0).**
> Beta.15.4 and older cannot read V1 layouts containing
> `order.parked`. They reset V1 order, roles, and splits to defaults; other
> settings and V2 remain. `uninstall --keep-settings` does not prevent this.
> Back up the complete settings before attempting a downgrade, including a
> source-checkout downgrade. See [backup before downgrade](#backup-before-downgrade).

Roll back only to an accepted package that explicitly uses the same canonical
State service-entry storage contract. Beta.12 is the first package with that
contract, so it has no older eligible package target. Do not install Beta.11 or
an earlier package after Beta.12. Pacman replaces the lifecycle code before the
user-level update runs, and the older code cannot enforce Beta.12's one-way
storage guard or export canonical settings back to legacy storage.

For a future eligible release, install its package from Pacman's cache, then
authorize staging its older payload:

```bash
sudo pacman -U /var/cache/pacman/pkg/shinigami-shell-compatible-older.pkg.tar.zst
shinigami-shell update --allow-downgrade --dry-run
shinigami-shell update --allow-downgrade --yes
```

Without `--allow-downgrade`, compatible update and repair paths refuse to replace
a newer staged suite with an older payload. The authorized rollback still uses
the target release's normal transaction, runtime verification, and automatic
failure recovery, but only between identities that release explicitly admits.
It is not a Step-6 rollback mechanism.

### Backup before downgrade

Save a complete, consistent copy outside the live configuration directories,
with no settings or lifecycle transaction being written. Include:

- `${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json` in full, not only the
  State entry: it contains `plugins[]`, the State `.shinigami` settings, bar
  layouts, and retained host-layout data;
- `${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/extensions/omarchy-menu.jsonc`,
  if present, for suite-managed menu routing;
- `${XDG_STATE_HOME:-$HOME/.local/state}/shinigami/` in full, including
  `install.json`, `backups/`, and any `transactions/`, as lifecycle recovery
  evidence. Resolve an unfinished transaction before attempting a downgrade.

Use the actual configured paths if lifecycle overrides are in use. Keep the
backup with the installed source revision or package identity and retain access
to that exact code. A backup does not make an old reader understand new layout
fields. For an old target, retain a pre-upgrade settings backup compatible with
that reader. Restore the settings with a matching payload. Do not
copy an old `install.json`, edit `order.parked`, or delete journals to force
admission. `--keep-settings` preserves data, not schema compatibility.

## Status

```bash
shinigami-shell status
```

Use `./scripts/shinigami-suite status` for a source installation.

Status reports the source and installed revision, managed plugin count,
modified or missing payloads, active bar, and configuration drift. A nonzero
exit indicates a state that needs attention.

## Repair a partial suite

Omarchy's generic plugin manager sees the 27 Shinigami roots as individual
third-party plugins. Do not remove or disable Shinigami internals individually.
If one was removed, disabled, or modified, restore the complete payload and
managed profile with:

```bash
./scripts/shinigami-suite repair --dry-run
./scripts/shinigami-suite repair
./scripts/shinigami-suite status
```

Repair validates and stages all current plugin roots, verifies the running
payload, and rolls back to the exact pre-repair state if a gate fails. Repair
alone tolerates a missing owned plugin root or changed payload bytes only while
the supported install state and every remaining ownership marker stay exact.
For a managed installation, a healthy current widget layout, entry options, and
Shinigami settings are preserved by default; a fresh installation uses the
profile's canonical default order. External-bar repairs continue to preserve the
external bar and layout.

If managed widget membership is malformed, duplicated, or incomplete, ordinary
repair refuses before publishing changes. Use the explicit recovery option to
rebuild the canonical managed membership:

```bash
./scripts/shinigami-suite repair --restore-layout
```

This keeps the installation managed and restores the profile's canonical widget
order. Valid external widgets already present in the layout are retained when
possible; invalid, duplicate, unsupported, or unavailable entries are not
preserved. Repair refuses unsafe markers or paths and never overwrites a foreign
directory.

## Switch bar hosts

Keep Shinigami installed but return to the stock Omarchy bar:

```bash
./scripts/shinigami-suite deactivate --dry-run
./scripts/shinigami-suite deactivate
```

Switching between the Shinigami and Omarchy bar owners performs Quattro's full
shell handoff: the previous instance stops before the new bar configuration is
published, then a fresh instance starts and is verified. V1/V2 presentation
changes within the Shinigami bar remain live.

Keep the current Shinigami widgets in the stock bar instead:

```bash
./scripts/shinigami-suite deactivate --keep-layout
```

Restore the Shinigami bar and managed layout:

```bash
./scripts/shinigami-suite activate --dry-run
./scripts/shinigami-suite activate
```

The Control Center **Bars** page performs the same supported host switch and
keeps both return paths visible.

`omarchy bar reset` selects the stock bar while preserving the current layout.
`omarchy bar defaults` replaces the complete `bar` object and its layout.
Canonical settings in the State `plugins[]` service entry survive; activation
restores the managed layout.

## Uninstall

Run these commands from a terminal inside the Hyprland session, not plain SSH.

For a source installation, preview and remove all managed Shinigami plugins:

```bash
./scripts/shinigami-suite uninstall --dry-run
./scripts/shinigami-suite uninstall --yes
```

For a locally built package installation, remove the user-scoped suite with
`shinigami-shell uninstall` before removing the system package. Pacman removal
by itself intentionally does not mutate user configuration. Uninstall uses
Quattro's supported full shell restart before removing the complete provider
tree. Install, activate, deactivate, and migration use the same boundary; this
avoids racing Qt's live QML loaders during a wholesale bar-owner transition.

Do not run `omarchy pkg drop shinigami-shell` for a source installation.
The source workflow did not install a package with that name, and that package
is not yet available from the Omarchy repository.
Its Pacman-managed runtime dependencies remain installed because they may be
shared with Omarchy or other software.

The default uninstall restores the stock bar and removes Shinigami's managed
configuration. Shinigami records the bar that was active before installation so
its widgets and options can be restored as a complete layout. Install states
created before this record existed fall back to Quattro's current stock-bar
definition instead of leaving an empty bar. Preserve the complete canonical
State service entry, including unknown fields and deep settings, with:

```bash
./scripts/shinigami-suite uninstall --keep-settings
```

With `--keep-settings`, the retained State entry is dormant while its payload is
absent and is reused on reinstall. Native per-plugin disable/removal is destructive
and is not equivalent to this option.

The adapter removes only suite-owned plugin directories. It refuses foreign or
ambiguous targets.

## State and recovery

The suite stores installation metadata under:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/shinigami/
```

Interrupted transactions are recovered before the next mutating suite command.
After a reboot, recovery accepts a changed device number only for the same config-directory inode and a journal from an earlier boot (older journals use their modification time); inode changes still refuse recovery.
Do not edit `install.json`, transaction snapshots, ownership markers, or plugin
hashes by hand.

If an operation fails:

1. keep the checkout and error output unchanged;
2. run `./scripts/shinigami-suite status`;
3. rerun the same suite command so automatic recovery can complete;
4. use [troubleshooting](development/troubleshooting.md) before removing files
   manually.

### Supervised recovery

#### Installed from `main` before a tagged release

With maintainer guidance, identify the exact `sourceRevision` in `install.json`
and use a clean checkout of that commit to uninstall with settings retained,
then install the published tag. For example, only if the recorded revision is
`e92d8ee1ce9821d0b203a9d4d5dd9932d2e460fb` (Beta.10, August 21):

```bash
git checkout e92d8ee1ce9821d0b203a9d4d5dd9932d2e460fb
./scripts/shinigami-suite uninstall --keep-settings --yes
./scripts/shinigami-suite install --yes
```

The stock Omarchy bar appears between uninstall and install. Do not substitute
a different old revision or delete `install.json` to bypass admission.

#### Plugin root without `.shinigami-managed.json`

Only after the maintainer confirms an admitted `install.json`, a normal
non-symlink plugin root whose marker alone is missing, and no pending recovery,
move that root aside to a new, unused path outside the plugin directory (for
example, `mv -T -- ~/.config/omarchy/plugins/shinigami.ai ~/shinigami-quarantine-ai`),
then run `./scripts/shinigami-suite repair --dry-run` followed by
`./scripts/shinigami-suite repair --yes` if the preview is correct.
Keep the quarantined root even if repair fails; do not delete state, manufacture
a marker, or use this procedure for unknown identities or invalid existing markers.

## Security boundary

Omarchy plugins execute unsandboxed inside the desktop shell. Install Shinigami
and third-party catalog plugins only from sources you trust.

The suite adapter rejects symlinked payloads, special files, unsafe manifest
entry points, foreign ownership markers, and unknown replacement directories.
It hashes the staged payload and verifies the running revision before
committing a transaction.

Shinigami does not fetch its own source updates. For a source installation,
update only from a trusted checkout. Package update checks are read-only and package
installation remains owned by Omarchy/Pacman.
