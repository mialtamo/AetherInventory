# Aether Inventory

This repository contains the Aether Inventory WoW addon and a small Windows updater.

## Install or update with the updater

1. Download `tools/AetherInventoryUpdater.cmd` and `tools/AetherInventoryUpdater.ps1` from this repository into the same folder.
2. Double-click `AetherInventoryUpdater.cmd`.
3. Select the correct WoW `Interface\AddOns` folder. The updater remembers this location.
4. Click **Install latest update**. When it finishes, return to WoW and type `/reload`.

The updater runs outside the game, like the CurseForge app. The WoW addon itself cannot download or write addon files. WoW can remain open during installation; `/reload` loads the files afterward.

The updater also includes an optional **Donate via Venmo** button that opens [@Mike-A-34](https://venmo.com/Mike-A-34) in your browser.

The updater replaces only the `AetherInventory` addon folder. It keeps the old folder temporarily while installing and restores it if the replacement fails. Character settings are stored separately by WoW.

## Manual install

Download [`dist/latest.zip`](https://github.com/mialtamo/AetherInventory/raw/refs/heads/main/dist/latest.zip), extract it, then copy its `AetherInventory` folder into the WoW client's `Interface\AddOns` folder. The installed folder must directly contain `AetherInventory.toc`.

## Development files

- `AetherInventory/` — readable Lua/XML source and documentation
- `dist/latest.zip` — complete install package, including the game texture media
- `tools/` — Windows updater

