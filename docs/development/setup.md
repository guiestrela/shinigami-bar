# Development setup

Status: maintainer reference

Work from a clean Shinigami checkout on the development machine:

```bash
cd /path/to/shinigami
git status --short
rg --files
```

Shinigami source inspection and automated tests run locally. Live release
acceptance is repeated by maintainers on an isolated Omarchy Quattro system;
external contributors do not need access to it. Avoid deploying development
payloads into a primary desktop's Omarchy plugin directory.

## Repository shape

- `shinigami.*/` contains the 27 plugin roots and the canonical bar-host
  and feature-owner sources. The only cross-plugin QML imports are the exact,
  declared State runtime and passive presentation modules.
- `shinigami.state/lib/presentation/` contains the passive shared visual
  components; its declared consumers depend directly on State.
- `shared/presentation/` contains canonical panel and widget components.
  `scripts/sync-shared.sh` verifies their vendored copies.
- `contracts/` contains executable product and evidence contracts.
- `scripts/shinigami_suite/` implements the transactional lifecycle adapter.
- `tests/` contains source, component, runtime, and lifecycle regressions.
- `docs/` contains user references, contracts, evidence, and historical notes.

## Maintainer runtime acceptance

Maintainers synchronize only the intended source changes into the isolated
validation checkout and run the relevant test there. Its Omarchy runtime stays
at `/usr/share/omarchy` unless the compatibility target changes deliberately.

Do not start a second long-lived Quickshell process. Component smokes use
isolated temporary runtimes and must clean them up on exit.

See [testing](testing.md) for the required command order and
[troubleshooting](troubleshooting.md) for Wayland session details.
