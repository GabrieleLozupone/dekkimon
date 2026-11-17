# Contributing to Dekkimon

Thanks for helping. Dekkimon is a Steam Deck–only PlayStation Remote Play client based on
chiaki-ng.

- **Bugs and ideas:** open an issue. For bugs, the template asks for your Dekkimon version,
  SteamOS version and a log.
- **Code:** read [docs/building.md](docs/building.md) to build in the SteamOS container and run
  the tests, and [docs/upstream.md](docs/upstream.md) for how Dekkimon stays mergeable with
  chiaki-ng.
- **UI changes:** include before/after pictures from the GPU preview
  (`test/gui/portal_preview.py`). The GUI smoke tests must pass.
- **Protocol fixes** in `lib/` usually help chiaki-ng too. Consider sending them there as well.

By contributing, you agree that your contribution is licensed under the
[AGPL-3.0](COPYING), like the rest of the project.
