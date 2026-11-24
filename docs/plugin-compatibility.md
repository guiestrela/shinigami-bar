# Use Shinigami plugins with other bars

Status: user reference

Shinigami can keep another Omarchy bar active while the complete Shinigami suite
provides its widgets, panels, and internal services. Shinigami must remain
suite-installed; individual plugin-root installations are not supported.

## Compatibility by plugin type

| Plugin type | Stock Omarchy bar | Standard Quattro-compatible bar | Shinigami bar |
| --- | --- | --- | --- |
| Shinigami bar widgets and panels | Supported | Supported when the host implements the standard Quattro widget contract | Supported |
| Shinigami service-only plugins | Managed suite dependencies | Managed suite dependencies | Managed suite dependencies |
| Shinigami full-bar plugin | Installed but inactive | Installed but inactive | Active host |

Shinigami's compatibility adapter supplies missing visual tokens from the active
host's foreground, background, accent, font, and bar size. Tooltip, popout,
screen ownership, and click routing still come from the active bar's standard
Quattro widget interface.

When the Shinigami V2 bar hosts a non-Shinigami widget, one generic hosted-panel
adapter discovers the standard Omarchy `KeyboardPanel`/card contract, including
bar-widget entry points that load their standard panel owner through nested
`Loader` objects. It applies the active Shinigami panel color, border, radius,
tooltip behavior, bar cutout, and native connected panel tip. The path is
provider-neutral: Quattro built-ins and third-party plugins use the same
adapter, so adding another compatible plugin does not require a panel-specific
geometry patch.

Inline widget-state writes that keep the same unique layout entry in place are
also applied to the running widget without rebuilding it. A third-party panel
therefore remains open when its provider persists state such as a high score or
selection. Structural layout changes and ambiguous repeated entries still use
the normal rebuild path.

A plugin with fully custom panel objects that do not expose the standard
contract cannot be adapted safely by guessing its visual tree. Such a plugin
needs the explicit host-wrapper contract tracked in
[issue #1](https://github.com/HANCORE-linux/Shibumi-Shell/issues/1).

Advanced Shinigami-only shell surfaces, split editing, and layout mutation require
the complete [Shinigami host facade V1](host-facade-v1.md). The Control Center
hides unsupported layout controls while a standard external host is active.

## Install without replacing the current bar

Install all 27 managed plugin roots while preserving the current bar and its
widget layout:

```bash
./scripts/shinigami-suite install --no-activate --keep-layout --yes
```

Shinigami enables only the required suite services. Add or arrange Shinigami
widgets through Omarchy Settings or the active bar's supported widget manager.
Updates and repairs preserve the external bar and its layout.

## Switch an existing installation

Switch from the Shinigami bar to the stock Omarchy bar without removing the
current Shinigami widgets:

```bash
./scripts/shinigami-suite deactivate --keep-layout
```

Return to the Shinigami bar and its managed profile:

```bash
./scripts/shinigami-suite activate
```

The Control Center's **Bars** page maintains separate Shinigami and Omarchy
layout profiles. Widgets added to the Omarchy profile stay there when switching
away and back.

## Suite ownership

Do not disable, remove, install, or update individual Shinigami roots through the
generic plugin menu. Service-only roots are implementation dependencies, not
standalone products. Use the [suite lifecycle](install.md) so updates, repair,
payload verification, and uninstall remain transactional.

The application launcher remains owned by Omarchy. Shinigami neither registers
a `menu` entry point nor enables an application-menu service.

## Third-party bar acceptance

A third-party bar must implement Omarchy Quattro's standard bar-widget
properties and panel-routing methods. Passing the
[host-facade acceptance gates](host-facade-v1.md#acceptance) additionally
enables Shinigami-only layout and shell-surface features.

Validate a new host on the validation system with the
[additional bar validation](multi-bar-extension-plan.md#required-gates-for-every-bar)
before calling it release-supported.
