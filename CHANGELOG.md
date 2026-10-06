## 1.8.0

- **Food, water, bandage and potion rows follow your bags.** Each row is now "the best of its kind you're carrying" and says so: **Best food in your bags: Wild Hog Shank**. Sell your old food and buy another and the row changes with it, where before it kept the old item's name unless the new one restored more. With none left it reads **No food in your bags (last: Wild Hog Shank)**. Your Min stays with the row.
- **Items that are just as good count together.** Foods of one tier restore the same under different names. If you carry 10 Wild Hog Shank and 6 of another food that restores as much, the row counts 16, and it stays on the one it was on.
- **Restock buys the best a vendor sells.** For those rows, the Restock button now picks the best food, water, bandage or potion the vendor has that you can use (it reads the item's required level), as long as it's at least as good as what you carry. If the vendor has yours, yours is bought. If it only has one just as good under another name, that one makes up what you're short. A better one is bought up to your Min. The cost is still shown first, and nothing is bought until you click.
- Fixed: items that restore 1,000 or more weren't recognised, because the game writes the number with a comma. Sweet Nectar wasn't seen as water, for one.
- The Supplies tab redraws when your bags change while it's open.

## 1.7.0

- **Well-Rested**, the experience bonus from the Cozy Sleeping Bag, is tracked. If the bag is in your bags, an icon shows when the buff is missing, below 3 stacks (the icon reads 1/3 or 2/3) or running out. Click it to unfurl the bag. Nothing shows without the bag or at the level cap. Turn it off with **Well-Rested** on the Buffs tab (the switch is only there while you carry the bag).

## 1.6.2

- **Tidier logo**: the arrow in the drop is bolder and centred. It's the same everywhere the logo shows: the header above the icons, the settings window, chat lines, the minimap button and the AddOns list.
- The logo file was saved upside down, so in game the drop could show pointing down. It's the right way up now.

## 1.6.1

- The options tab called "Pet & gear" is now "Gear & bags" on classes that have no pet checks (everyone but Hunters and Warlocks).

## 1.6.0

A new look, shared with TauntMaster Forever and Outfitter Forever.

- **New options window**, laid out like TauntMaster Forever's: tabs down the left, settings in cards. Buffs, Supplies, Pet & gear and Profiles are this character's checks; Display and General are shared by all your characters. Every setting is still there.
- Tick boxes are now on/off switches, and a choice of spells opens a list instead of stepping to the next one.
- The header above the icons, the frame around them and the vendor restock panel use the same dark and red colours. The header keeps the logo and name.
- Chat lines start with the logo and "ToppedOff Forever".
- A list you've scrolled down stays where it is when you add or remove an item.

## 1.5.14

Under the hood: a code review, with fixes and lighter work in groups. Nothing changes in how the addon looks or is used.

- Fixed: every time the options window was opened or a tab was clicked, a whole new set of checkboxes and buttons was made and the old set was kept, hidden, until the next `/reload`. The list now reuses them.
- Fixed: changing settings during a fight queued every change, and all of them were re-applied one after another when the fight ended. Each kind of change is now applied once.
- Fixed: the chat reminder on a ready check or on entering a dungeon could fail with an error when the game refused to show your buffs at that moment. It now uses the last check, like the icons do.
- Fixed: if the game hid your buffs from the first moment after logging in or a `/reload`, an error was reported. ToppedOff now waits until it can read them.
- Fixed: with two buffs that count for the same elixir or Well Fed check, one that never expires could be shown as "running out", depending on which the game listed first.
- `/topoff reset` in combat now says the position will reset when combat ends, instead of saying it already has.
- A damaged settings file (a setting of the wrong kind, or a broken entry in your own items or elixirs) no longer causes errors; the damaged part goes back to its default or is dropped.
- Lighter in groups: each member's buffs are read once per check instead of once for every party buff.

## 1.5.13

- Passive spells are no longer checked. On WoW: Forever, Omen of Clarity is passive (always on, nothing to cast), so the reminder to cast it is gone, and so is its row in the options. This applies to any class buff the game marks as passive.

## 1.5.12

- Fixed: right after logging in, food, water, bandages and potions could all show "none in bags yet" until a `/reload`. The game hadn't finished filling in what those items do, and ToppedOff took that as final. It now looks again until the game has caught up (within a few seconds).
- New: when you run out of your best food, water, bandage or potion, the next best one in your bags takes its place, in the reminders and on the combat bar, so there's always something to click. The better one is still what a vendor restocks, and it takes over again when you have some.

## 1.5.11

- Fixed: dragging the ToppedOff window in combat printed "WoW blocked ToppedOffForeverFrame:StopMovingOrSizing()" messages in chat. WoW doesn't allow the window to be moved in combat, so a drag in combat now does nothing and says so in chat. A drag that's still going when combat starts drops the window where it is and saves that spot.

## 1.5.10

- Fixed: gear with a "drinking" or "eating" effect on use (like Skum's Bucket) could be picked as your best water, food or potion, and then asked you to carry 20 of it. Anything you can equip is never tracked now, and gear that was already tracked is dropped. Your Min is kept.

## 1.5.9

- New: **combat bar**. While the reminders are hidden in combat, your healing potion, mana potion, Healthstone and bandage stay on screen in one row, in the same spot. Click to use them. Counts and the potion cooldown update during combat, and an item you run out of turns grey. On by default; turn it off with "Keep potions in combat" under "Hide in combat".

## 1.5.8

- Fixed: food, stat food, water, bandages and potions that the game hadn't finished loading (common right after logging in) were misread and never tracked, so Automatic stat food could show "none in bags" while you had some. ToppedOff now waits for the item to load and checks again.

## 1.5.7

- Fixed: a "GetAuraDataByIndex(): Auras cannot be accessed when secret" error. When the game hides buffs (for example in some instances), ToppedOff now keeps the last buffs it could read instead of erroring, and party buff checks wait until buffs are readable.
- If the game refuses some other read, the error is reported once instead of every few seconds.
- New: **Thorns** is now a party buff for Druids. See who's missing it and click to cast it on them.

## 1.5.6

- Fixed: "ToppedOffForever has been blocked from an action only available to the Blizzard UI" when opening the Game Menu (Escape). The options code re-assigned one of Blizzard's own tables, which made WoW distrust Blizzard's menu code.
- The bag space icon no longer opens your bags when clicked. Opening them from an addon could cause the same kind of blocked-action message later.
- If WoW ever blocks an action and blames ToppedOff, it now says which one in chat, to make reports easy.

## 1.5.5

- Fixed: picking a stat under "Stat food for" still tracked food with a different stat when you had none with your stat. Now only food with the stat you picked is tracked. Automatic still falls back to any stat food.

## 1.5.4

- Fixed: recipes (like "Recipe: Minor Discolored Healing Potion") could be picked as your best food, water or potion, because their tooltip shows the item they make. Recipes are never tracked now, and one that was already tracked is dropped. Your Min is kept.

## 1.5.3

- New: **Priest racial buffs**. Shadowguard (Troll) and Touch of Weakness (Undead) are tracked like your other buffs, and Fear Ward (Dwarf) is available but off by default. They only appear for Priests who have learned them.

## 1.5.2

- The divider between buffs and things to top off is bolder: a thicker gold line with dark edges that runs the full width of the frame, with a bit more space around it.
- Right-clicking the "ToppedOff" header now opens a menu with **Lock** and **Settings**, like TauntMaster Forever.

## 1.5.1

- Food, water, bandages, potions and your own items now show as a **quick-use bar** by default: dimmed when you're stocked, bright with a red count when you're low. Click one to use it. Turn it off with "Always show these, as a quick-use bar" on the Supplies tab. Existing characters keep their current setting.

## 1.5.0

- New: **one-click restock at vendors**. A list beside the vendor window shows everything you're short on (reagents, food, water, potions, your own items, ammo, pet food) that the vendor sells, with the cost. Untick anything you don't want, then click Restock. Multi-rank reagents buy the rank for your level (Holy or Sacred Candles, Wild Berries or Thornroot, Rebirth seeds). Nothing is bought until you click.
- New: **Repair all** button with the cost, at vendors who repair.
- New: **Mage conjures**. Conjured water and food below your Min, and a missing mana gem. Click to conjure your best rank. Conjured items and mana gems are no longer picked as your "best" food, water or mana potion.
- New: **Healthstones**. Warlocks are reminded to make one; everyone else is reminded in dungeons when a Warlock is in the group.
- New: **In raids, check the whole raid** for party buffs, blessings and Soulstone (off by default).
- New: **Profiles** tab. Turn on separate checks outside dungeons and raids for a lighter set while questing, and copy another character's settings.
- Arcane Intellect and Divine Spirit party checks skip Warriors and Rogues.
- Your stat food Min is kept when the stat food changes.

## 1.4.1

- New: **party blessings** for Paladins. Shows how many party members are missing their blessing, and a click blesses the next one in range. Choose the blessing for each class on the Buffs tab (Might for Warriors and Rogues, Wisdom for everyone else by default, or Kings, or none). A Greater Blessing or the same blessing from another Paladin counts.
- Stat food now recognizes **spell power** and **healing** foods, in case Forever adds them. Both are also in the "Stat food for" choices.
- Stat food now follows **your role**, not just your class. Priests, Shamans, Druids and Paladins get food for what they do, read from the talent tree with the most points (or your group role): healers get healing then mana regen, casters (Shadow, Elemental, Balance) get spell power then Intellect, Enhancement and Retribution get Strength, and tanks get Stamina. Mages and Warlocks get spell power then Intellect. The "Stat food for" button shows what was picked, like "Caster: Spell power".
- "Stat food for" is now a dropdown list: keep **Automatic**, or pick any stat yourself (for example Strength for a Protection Paladin). Your pick is saved per character.

## 1.4.0

- New: **party buffs**. See how many party members are missing your Fortitude, Arcane Intellect, Mark of the Wild or Divine Spirit, and click to buff the next one in range.
- New: **elixirs and flasks**. Tick the ones in your bags to be reminded when the buff is missing or running out. Click to drink. Dungeons and raids only by default.
- New: **pet reminders**. Hunters and Warlocks see when their pet isn't out or is dead (click to call, revive or summon; pick your demon). Hunters also see when their pet isn't happy: set a pet food and one click feeds it, with a reminder when the food runs low. Not shown while mounted or resting in town.
- New: **Soulstone** (Warlocks). Reminds you when nobody in the group has one. Click to put yours on the healer, or make one. Dungeons and raids only by default.
- New: **bag space**. Warns when you have fewer than 3 free bag slots. Click to open your bags.
- New: **poison charges** (Rogues). Warns when a poison drops below 10 charges.
- New: **Icons per row** setting (default 8). Long rows wrap instead of stretching the frame.
- The options window is reorganized into three tabs: **Buffs**, **Supplies**, and **Pet & gear**, with aligned Min columns and small X buttons to remove your own items.

## 1.3.0

- New: **Well Fed reminder**. Shows when your stat food buff is missing or running out (orange, then red, like other buffs). Click it to eat your stat food. Not shown while you're eating. On by default in dungeons and raids only; change it under "Stat food buff" in the options.
- New layout: **buffs on the top row** (class buffs, weapon enhancements, Well Fed) and **things to top off on the second row** (reagents, ammo, food, water, bandages, potions, repairs), with a gold divider between them. This replaces the side-by-side separator.

## 1.2.0

- New: **auto-tracked items**. ToppedOff picks the best food, water, bandage, healing potion and mana potion in your bags, plus the best stat food for your class, and reminds you when you're low (Min 20 for food, water and bandages, 10 for stat food, 5 for potions). Better items take over automatically as you level, and your Min is kept. An item stays tracked when you run out, so you know to restock.
- Stat food follows your class: Strength (Warrior), Agility (Rogue, Hunter), Intellect (Mage, Warlock), mana regen (Priest, Shaman), Stamina (Druid, Paladin). Change it with "Stat food for" in the options.
- Water and mana potions are only tracked for classes that use mana.
- Uncheck an auto-tracked item to stop tracking it. Items you've added yourself aren't shown twice.
- New: buffs and weapon enhancements that are running out get an orange border at your warning time, and a red border in the last 20% of it.

## 1.1.1

- The frame now stays pinned by its top-left corner. When a reminder goes away, the icons to its right slide left and the header stays where it is, instead of the whole frame shifting.
- Your own items (food, water, potions, bandages) now sit on the right, with a thin gold separator between them and your buffs and other reminders on the left.

## 1.1.0

- New: click one of your own items' icons to use it: food, drink, potions, and bandages (on yourself).
- New option: "Always show these, with counts" under Your own items. Your items stay on screen even when you have enough; the count is red when you're low and white when you're topped off. Topped-off items aren't listed as missing in chat reminders.

## 1.0.3

- New: the icons sit in a tidy frame with a "ToppedOff" header, in the logo's colors. It's always at least two icons wide and grows as more reminders show up. Drag the header to move it while unlocked; right-click it for options. Turn it off with "Show header and frame".

## 1.0.2

- Fixed: clicking a reminder icon (or pressing its keybinding) did nothing when "Cast action keybinds on key down" was turned on.
- Fixed: clicking a reminder icon did nothing while the reminders were unlocked. The drag box covered the icons.
- New: a "ToppedOff" header bar above the icons, in the logo's colors. Drag it to move the icons while unlocked; right-click it for options.
- Icons are a bit bigger by default (40 instead of 36), and their counts and timers are centered so they fit.
- Options window: the logo is no longer hidden behind the title bar, and crowded rows are tidied up.
- Author name is now severd8.

## 1.0.0 — Initial release

First public release of ToppedOff Forever for WoW: Forever.

- Reminder icons appear only when something needs topping off, and disappear when it's fixed
- Class buffs for every class: missing or about to run out. Click the icon to cast it on yourself
- Raid versions and other players' buffs count (e.g. Arcane Brilliance covers Arcane Intellect)
- Pick which spell to cast for Blessings, Auras, Aspects, Armors and Shaman weapon buffs
- Weapon enhancements: Shaman weapon buffs, Rogue poisons, and any oil or sharpening stone you choose. Click to apply
- Reagents and class items: Soul Shards, teleport runes, candles, symbols, Ankhs, totems, powders and more, with your own minimum counts
- Ammo count for Hunters
- Low durability warning
- Add any item of your own, like food, water or potions, with a minimum count
- Chat reminder on ready checks and when entering a dungeon or raid
- Keybindings to fix the first three reminders
- Options window, minimap button and /topoff commands
