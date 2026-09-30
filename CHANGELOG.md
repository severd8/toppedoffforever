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
