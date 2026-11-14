# Aether Inventory Changelog

## 0.5.11

- Keep right-click vendor sales on the working container-item API, but route ordinary item use through SecureActionButtonTemplate to avoid the protected-action block.
- Resolve ordinary right-click use from the selected item's link; keep exact bag-slot secure actions for item-target spells such as Feed Pet.
- Disable secure use actions while a merchant is open and continue blocking locked items from sale or use.

## 0.5.10

- Route right-click use and vendor sale through `UseContainerItem`, matching Blizzard's bag-button behavior instead of the secure item-action parser.
- Route left-clicks to item-target spells through the same bag API, while preserving ordinary left-click and drag behavior.
- Keep locked items blocked from right-click actions and bag-slot dragging.

## 0.5.7

- Replace the ineffective right-click macro route with the secure item action's explicit bag/slot attributes.
- Register the bag slots for any mouse-button release so right-click use and vendor sale reach the secure action handler.
- Keep the secure item-target action on the same bag/slot attributes for Feed Pet and similar item-targeting actions.

## 0.5.6

- Fix right-click item use and vendor sale by routing both through a secure `/use bag slot` action.
- Prevent locked items from being dragged from Aether Inventory, including onto a vendor frame.
- Use the same secure container-slot action for item-targeting clicks such as Feed Pet.

## 0.5.5

- Fix the missing per-item lock controls by using the correct built-in lock texture paths and cropping their transparent button-sheet margins.
- Enlarge and brighten the lock control; unlocked items now show a visible gold lock, while protected items show a brighter green-gold locked state.

## 0.5.4

- Add a per-item padlock control to bag slots. Item GUIDs keep the lock attached as items move or auto-sort; item-link/ID fallback locks matching copies safely.
- Block vendor right-click sales and item-targeting actions such as salvage for locked items.
- Show the lock state in the slot and tooltip and persist it in SavedVariables.

## 0.5.3

- Remove the oversized footer backing and present capacity and currency as a compact outlined text row, repositioned clear of the decorative green flourish.

## 0.5.2

- Move the bag-capacity summary into a high-contrast footer plate in the left panel.
- Restore the carried gold, silver, and copper amount in a separate right-aligned field so it remains visible beside the summary.

## 0.5.1

- Rework category and search filtering into compact matching-item rows; hide empty bag sections in filtered views and show a clear no-results message.
- Preserve each filtered button's real physical bag and slot identity for drag, equip, use, and vendor actions.
- Reflow the footer into the left panel so bag capacity and currency no longer overlap the bottom controls.

## 0.5.0

- Split available capacity into general-bag and specialty-bag free slots, and label each specialty bag with the item families it accepts.
- Make category/search filters hide nonmatching items, and add a 90-second Recent filter with a NEW marker for newly acquired items or stack increases.
- Add visible progress bars to Skills and Professions rows.
- Expand the Pet tab with movement speed, armor, damage range, attack power, critical strike, and all six resistances when the client exposes those values.
- Improve auto-sort scheduling by watching bag updates, seeding the initial layout at login, and retrying safely while the cursor holds an item.

## 0.4.4

- Fix the malformed `Bindings.xml` root that caused the client to report “no element found” during addon loading.

## 0.4.3

- Close the Blizzard bags synchronously in the merchant open-bag post-hook, before a frame can be drawn, to remove the brief flash.

## 0.4.2

- Close Blizzard's native bags after WoW Forever's merchant frame opens them, leaving Aether Inventory as the visible bag window.
- Use a post-hook and close synchronously after the merchant's open-bag call completes; skip the close during combat or after the merchant window closes.

## 0.4.1

- Make Auto-sort an actual persisted Aether Inventory option: bag changes are coalesced and sorted after a short delay, out of combat and only when the cursor is clear.
- Track the sorted bag layout so the sort's own update events do not create a repeated sorting loop.
- Raise Aether Inventory over other windows when a merchant opens.

## 0.4.0

- Add red `BROKEN` and amber `LOW` durability markers to equipped gear and damaged items in the bags; low durability means 20% or less.
- Tint equipment outlines by condition, add durability details to item tooltips, and show a broken/low item count in Gear.
- Refresh durability warnings when the client reports durability changes.

## 0.3.9

- Automatically open Aether Inventory when a merchant opens, and close it afterward only if the merchant opened it.
- Keep normal vendor item-use/sell behavior by leaving Blizzard's own bag buttons and container frames untouched.

## 0.3.8

- Use the secure `item` attribute with an explicit `bag slot` item string for right-click actions, including quest-item use.
- Remove reliance on deprecated `bag` and `slot` action attributes while preserving merchant sale macros.

## 0.3.7

- Arm each bag slot's secure left-click item action only while the client reports an item-target spell is active, matching the Yum-then-food workflow.
- Keep normal left-click/drag behavior unchanged outside item targeting; preserve right-click use and merchant sale.
- Remove reliance on the previous static target-bag attributes, which did not work in the user's client.

## 0.3.6

- Match the in-game Feed Pet flow: activate the Yum ability, then left-click compatible food in an Aether Inventory slot.
- Add secure item-target bag/slot attributes to bag slots so the click can select the food for the active spell.
- Remove the extra addon Feed Pet button; keep the Pet page's food guidance and preserve right-click use/vendor selling.

## 0.3.5

- Trial right-click pet-food macro; superseded by the native Yum-then-food flow in 0.3.6.

## 0.3.4

- Use SecureActionButton's native item action for right-click use outside vendors; switch to Blizzard's container-slot macro path only while a merchant is open so gear sells instead of equipping.
- Use Forever's pet-exists conditional for Feed Pet, then the exact compatible food name; remove the incorrect `@pet` spell target.
- Combine armor, agility, stamina, and upgrade count on one stats line; move the upgrade list clear of the fixed footer.

## 0.3.3

- Replace the Feed Pet text macro with the secure spell action and an explicit target bag slot, using the client's native post-cast item-target path.
- Clear the secure spell and target attributes when no eligible food is available or feeding is unavailable.

## 0.3.2

- Restore B to the backpack and C to the character panel when unbinding has no recoverable saved action, including older addon settings that stored an empty action.

## 0.3.1

- Fix the Feed Pet action to use WoW Forever's pet-targeted spell and exact food-name macro syntax. Avoid numeric bag-slot `/use`, which can equip items instead of feeding.

## 0.3.0

- Add a Pet tab to the character panel with current pet name, family, level, health, happiness, loyalty, and diet where available.
- Add a secure Feed Pet button that selects compatible bag food through WoW Forever's pet-info API; disable it without a living pet or compatible food and while a merchant is open.
- Keep the inventory registered for Escape-to-close.

## 0.2.9

- Add the named inventory window to WoW's Escape-close list so Escape closes it like the default character and bag windows.

## 0.2.8

- Use a secure `/use bag slot` action for right-clicks so merchant-open clicks sell items just like the original bags, while preserving item use/equip behavior elsewhere.

## 0.2.7

- Make the X close control and B/C key toggles use secure click handlers so the window can open/close without blocked addon actions.
- Skip protected bag-slot layout refreshes during combat and refresh again when combat ends.

## 0.2.6

- Persist selected B/C toggle keys in addon settings and recreate the named click target on login, then reapply the keys after reload.
- Make the Bind B/C controls switch to Unbind B/C after assignment; unbinding restores the key's previous action when available.

## 0.2.5

- Add a Settings tab with WoW's RGB color picker for the window artwork tint, bag-section background, bag header, and item-slot background.
- Save color and opacity choices per character and add a one-click reset to the original purple palette.

## 0.2.4

- Remove the solid footer backing and move the bag-space text above the gold divider.

## 0.2.3

- Bind B/C through direct click bindings so the selected key toggles the window without the unsupported legacy XML binding declaration.
- Compare generic one-handed weapons only against the main hand; exclude Skinning Knives and Mining Picks from gear-upgrade scoring.
- Add a dark gold-edged backing behind the bag-space footer for readability.
- Read armor from WoW Forever's `UnitArmor` API, with legacy `GetArmor` fallbacks.

## 0.2.2

- Fixed a Lua syntax error in the Currency page that prevented the addon UI script from loading and left `/ai` unavailable.

## 0.2.1

- Added Gear, Stats, Reputation, Skills, Currency, and Titles pages to the character panel, with scrollable lists for long pages.
- Added Clean Up using WoW Forever's native bag sorting, plus a toggle for the client's backpack auto-sort setting.
- Replaced unsupported scroll arrow symbols with readable UP and DN labels.
- Corrected upgrade comparisons so empty equipment slots do not create upgrade suggestions; items are only compared against equipped gear.
- Refreshes character pages from stat, reputation, skill, currency, title, equipment, and bag update events when available.

## 0.2.0

- Added secure drag-and-drop between physical bag slots and equipment slots, including moving equipped items back into bags.
- Right-click bag items to use/equip them or sell them while a merchant is open.
- Added Use B and Use C controls that save the addon toggle in the current keybinding set.
- Added the WoW: Forever reagent bag to the inventory view.
- Display actual bag names when `C_Container.GetBagName` provides them.
- Replaced the unreadable arrow glyphs with `UP` badges and green item/equipment-slot outlines.
- Kept the original purple-and-gold visual design and bag layout.

## 0.1.0

- First experimental build, separate from Aether Encounter.
- Character model, equipped gear slots, and physical-bag grid in one window.
- Free-slot indicators, live search, category filters, and advisory gear scoring.
- Secure right-click item action, plus the native bag window as the movement fallback.

