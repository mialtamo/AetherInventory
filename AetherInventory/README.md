# Aether Inventory 0.5.11 (WoW Forever)

An experimental character and inventory addon in the ornate purple, lavender, and antique-gold style of Aether Encounter.

## Features

- One character, equipment, and bags window with live item and character data.
- Character panel tabs for Gear, Stats, Reputation, Skills, Currency, Titles, Pet, and Settings. Long pages scroll.
- Pet page shows active-pet health, movement speed, armor, damage range, attack power, critical strike, six resistances, happiness, loyalty, diet, and compatible food when the client exposes those values. For feeding, activate the in-game Feed Pet (Yum) ability and then left-click compatible food in Aether Inventory, as with Blizzard's bags.
- Settings lets you choose RGB colors and background opacity for the window art, bag panels, bag headers, and item slots; choices are saved and can be reset to the original purple palette.
- Separate sections for the Backpack, each equipped bag, and the reagent bag when present. Bag sections use the client's bag names when available.
- Right-click ordinary items to use them through secure actions; right-click items while a merchant is open to sell them. Locked items are protected from either action.
- In **All** view, bag slots stay in their physical positions. Category and search filters compact matching items into rows within their original bag sections and hide sections with no matches. Each displayed button stays linked to its real physical bag slot. Recent tracks newly acquired items or stack increases for 90 seconds.
- A compact footer separates general and specialty free slots and displays carried gold, silver, and copper.
- Each specialty bag header names its supported item families.
- Skills and professions show progress bars as well as rank values.
- Drag items between bag slots, onto equipment slots, and back from equipment into bags. These use Blizzard's secure drag handlers and remain subject to the client's item and combat rules.
- Click the small padlock on a bag slot to protect an item from right-click vendor sales and item-targeting actions such as salvage. The lock follows that item across moves and auto-sort when an item GUID is available; the safe fallback locks every copy of the same item link/ID.
- Left-click an item after activating an item-targeting spell such as Feed Pet; right-click items to use/equip them. Right-click while a merchant is open to sell the selected item.
- Upgrade candidates receive an `UP` badge and green outline; their suggested equipment slot receives a matching highlight.
- Damaged gear shows a red `BROKEN` label or amber `LOW` label at 20% durability or less, with a count on the Gear page and details in the tooltip.
- Upgrade suggestions compare only against equipped gear. Generic one-handed weapons only compare with the main hand, and Skinning Knives / Mining Picks are excluded as profession tools.
- Clean Up calls WoW Forever's native bag sort. Auto-sort can be toggled from the window and sorts after bag changes, out of combat and after the cursor is clear.
- **Bind B** and **Bind C** assign a direct click binding that toggles the inventory and reapply it after reload. Unbinding restores the saved prior action; when older saved settings have no prior action, B returns to the backpack and C to the character panel.
- The secure X/B/C controls can open or close the window during combat. Bag layout refreshes pause during combat and catch up when combat ends.
- When a merchant opens, Aether Inventory closes the Blizzard bags synchronously after WoW Forever's open call, so they should not flash onscreen.
- The Stats page reads armor from WoW Forever's `UnitArmor` API and uses the legacy armor function only as a fallback.
- Character model, equipment tooltips, item tooltips, free-slot counts, item quality borders, search, and category filters.
- The existing `/ai`, `/ai scale 0.85`, and `/ai reset` commands remain available.

## Install

1. Close WoW Forever.
2. Unzip `AetherInventory-0.5.7.zip` into `World of Warcraft\\_forever_\\Interface\\AddOns\\`.
3. Confirm `AddOns\\AetherInventory\\AetherInventory.toc` exists.
4. Enable **Aether Inventory** at character select, then log in and type `/ai`.

## Notes

- Drag-and-drop, vendor sale, bag sorting, and item-target selection call WoW Forever client APIs and remain subject to its secure-action and combat restrictions. While the client reports an item-target spell is active, bag slots temporarily expose a secure left-click item action to select the food. The synchronous merchant bag close hook still needs in-game validation for flicker and item-action behavior.
- Recent acquisition detection compares bag contents after updates. Items acquired before login are treated as the starting inventory rather than marked new.
- B/C bindings use WoW Forever's click-binding API. Changing a binding is blocked during combat and is saved to the active keybinding set.
- Upgrade scores are advisory and can miss equip requirements, weapon-speed preferences, set effects, enchants, and hidden effects. Empty equipment slots are intentionally not counted as upgrade opportunities. Compare the item tooltip before equipping.
- WoW Forever's merchant frame opens its native bags automatically. Aether Inventory lets that open call finish and closes the Blizzard bags immediately in a post-hook, while its own secure bag buttons remain responsible for item actions.
- `PREVIEW.png` remains a schematic illustration rather than an in-game screenshot.

