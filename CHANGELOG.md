# Changelog

## [0.0.1] - Unreleased

### Changed

- Quick Access keeps its theme, screenshot, and video pickers and no longer exposes an Idle Inhibitor toggle. Stay Awake remains available through Indicators.
- Indicators reuses the former Quick Access idle glyph in place of the three-dot marker when no indicator is active, in both V1 and V2.

### Fixed

- Launcher: render the transparent Shinigami mark with the size, alignment, and foreground color used by the other launcher icons. Keep the original artwork in the Plugins summary.
- Wallpapers: use the standard V1 capsule, and show **Shinigami Wallpapers** with an image icon in the plugin catalog.
- OneDrive: show a cloud icon in the plugin catalog without changing icons for similarly named third-party plugins.
- Lifecycle: preserve healthy managed widget order during repair and recognize verified source predecessors by their exact revision and payload digests.
- Packaging: keep the release tests and AUR checker aligned with the lifecycle predecessor contract.
