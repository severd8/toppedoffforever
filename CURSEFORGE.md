# ToppedOff Forever

**Never pull with a missing buff, empty reagents or a bare weapon again.**

ToppedOff Forever is a reminder addon for **World of Warcraft: Forever**. It watches your own character and shows a small icon only when something needs topping off: a buff that's missing or about to run out, a weapon without its poison or oil, low reagents, low ammo, or worn-out gear. Click the icon and it's fixed.

Icons sit in two groups: **buffs** on top (your buffs, party buffs, weapon enhancements, Well Fed, Well-Rested, elixirs, pet, Soulstone), and **things to top off** below a gold divider (reagents, ammo, food, water, bandages, potions, your own items, conjures, Healthstone, bag space, repairs). Long rows wrap after 8 icons (change it with "Icons per row").

---

## Features

- **Shows what's wrong, plus a quick-use bar.** Buffs, reagents and gear only show when something needs fixing. Your food, water, bandages and potions stay on screen as a dimmed bar you can click, and turn bright with a red count when they run low.
- **Class buffs for every class** (Rogues get poisons instead). The icon gets an **orange border** when a buff is about to run out and turns **red** near the end. **Click to cast it on yourself.** Group versions and buffs from other players count, and you pick which Blessing, Aura, Aspect, Armor or weapon buff is cast. Paladins get the aura for their role until they pick one.
- **Party buffs and blessings.** See how many party members are missing your buff, or have it running out, and **click to buff the next one in range**. When 3 or more in your party need it and you carry the reagent, the click casts the group version (Prayer of Fortitude, Arcane Brilliance, Gift of the Wild). Paladins choose a blessing for each class. The whole raid can be included.
- **Weapon enhancements.** Shaman weapon buffs, Rogue poisons, and any oil or sharpening stone you choose. **Click to apply it**; your best rank is used, and low poison charges are flagged.
- **Food, water, bandages and potions, picked for you.** Each row follows your bags: it's the best of its kind you're carrying, plus the right **stat food for your class or role**. Swap one food for another, or run out of your best potion, and the row changes with it. A **Well Fed** reminder (in dungeons and raids by default) eats your stat food with a click.
- **Combat bar.** In combat, your healing and mana potions, mana gem, Healthstone and bandage stay clickable, with counts and the potion cooldown. Add any of your own items to it.
- **Reagents, ammo and class items.** Soul Shards, runes, powders, candles, Ankhs, totems and more, checked once you've learned a spell that needs them, and ammo for Hunters. Set your own minimums.
- **Well-Rested**, if you carry a Cozy Sleeping Bag: an icon when the experience bonus is missing, below 3 stacks (it reads 1/3 or 2/3) or running out. Click it to unfurl the bag.
- **Class extras.** Hunter and Warlock pets (missing, dead or unhappy, with one-click feeding), Soulstones, Healthstones, Mage conjures, and the elixirs and flasks you choose.
- **Gear and bags.** Low durability and low bag space warnings.
- **Vendors.** One click restocks everything you're short on that the vendor sells, with the cost shown first, and a **Repair all** button. For food, water, bandages and potions it buys the best the vendor has that you can use. Nothing is bought until you click.
- **Bank.** Beside the bank window, a list of what you're short on that's in your bank. One click moves it to your bags.
- **Your own items.** Add anything with a minimum count, and **click the icon to use it**.
- **Profiles and reminders.** A lighter set of checks outside dungeons, copy a character's setup to an alt, chat reminders on ready checks and when you enter a dungeon, and keybindings for the first three reminders.

## Installation

Install it with the CurseForge app, or download the file and unzip it into your WoW: Forever `Interface\AddOns` folder. Then restart the game or type `/reload`.

Your class's checks are set up automatically. Type `/topoff check` to see them.

## Using it

- **Move the icons.** They start unlocked, inside a frame with a "ToppedOff" header. Drag the header to move them, then lock it in the options or with `/topoff lock`. Clicking the icons works whether they're locked or not.
- **Fix a reminder.** Hover over an icon to see what's wrong, then click it. Your buffs are cast on you, and party buffs and blessings on the party member shown. Poisons, oils and stones are used on your weapon. Your own items are used (bandages on you). **Shift + right-click** an icon to hide it for 10 minutes; `/topoff unhide` brings it back.
- **Open the options.** Type `/topoff`, left-click the minimap button, or right-click the "ToppedOff" header and choose **Settings**. The header menu also has **Lock**.
- **Show or hide.** Right-click the minimap button, or type `/topoff toggle`.

### Options window

| Tab | What's there |
|---|---|
| **Buffs** | Your buffs and which spell to cast, party buffs, party blessings (Paladins), whole-raid option, weapon enhancements, Well Fed, Well-Rested (while you carry the sleeping bag), elixirs and flasks |
| **Supplies** | The best food, water, bandage and potions in your bags, Healthstone, stat food choice, conjured food and water (Mages), your own items (and which go on the combat bar), reagents and ammo, vendor restock, repair and the bank list |
| **Pet & gear** (Hunters and Warlocks), **Gear & bags** (everyone else) | Pet, Soulstone (Warlocks), durability and bag space |
| **Profiles** | Separate checks outside dungeons, copy another character |
| **Display** | Show reminders, lock, show header and frame, only in dungeons and raids, hide in combat, keep potions in combat, Reset position, icon size, icons per row, warning time for buffs, durability warning % |
| **General** | Chat reminders and sound, minimap icon, Check spells, the slash commands |

The first four tabs are saved per character. Display and General are shared by all your characters.

### Keybindings

Go to **Options → Keybindings → ToppedOff Forever**:

| Binding | Does |
|---|---|
| **Fix reminder 1–3** | Presses the first, second or third reminder icon |
| **Open options** | Opens or closes the options window |

### Slash commands

| Command | Does |
|---|---|
| `/topoff` | Open or close the options |
| `/topoff show` · `/topoff hide` · `/topoff toggle` | Show or hide the reminders |
| `/topoff lock` · `/topoff unlock` | Lock or unlock the reminders' position |
| `/topoff check` | List your class buffs, weapon, reagents, your own items and durability, and whether each was found |
| `/topoff add 20 Conjured Crystal Water` | Remind you when you have fewer than 20 of an item |
| `/topoff remove Conjured Crystal Water` | Stop checking an item you added |
| `/topoff unhide` | Bring back reminders you hid with Shift + right-click |
| `/topoff reset` | Move the reminders back to the default position |

`/toppedoff` works too.

## Good to know

WoW: Forever limits what addons can do in combat. ToppedOff Forever is built around those rules:

- **It never acts on its own.** Every buff, weapon enhancement, purchase and item use is your click.
- **Reminders update out of combat.** They're hidden in combat by default (except the combat bar) and refresh as soon as it ends.
- **Replacing a weapon enhancement** that hasn't run out makes the game ask you to confirm.
- **Spell and item names** are the Classic ones. On a game in another language, ToppedOff asks the game for its own names, but food, water and potions are still only recognised in English. If something isn't found, `/topoff check` shows it in yellow. Please report it.

## Troubleshooting

- **An icon doesn't appear for a buff.** Type `/topoff check`. The spell may not be learned yet, or the check may be turned off in the options.
- **A weapon icon is grey.** The item you chose isn't in your bags. Hover for details.
- **The icons disappeared.** You may have hidden them, turned on **Only in dungeons and raids**, or you may simply be topped off. Type `/topoff show`.
- **The icons are off-screen.** Type `/topoff reset`.
- **"WoW blocked ..." in chat.** The game stopped an action and blamed ToppedOff. Please report it with the message.

## Feedback and bug reports

Found a bug, or want a buff or reagent added? Please [submit it on GitHub](https://github.com/severd8/toppedoffforever/issues/new/choose). A short form asks for your class and any error message. You'll need a free GitHub account. Otherwise, feel free to leave a comment on the CurseForge page.

## Support the addon

ToppedOff Forever is free. If it has saved you a wipe, you can [leave a small tip on Ko-fi](https://ko-fi.com/tauntmasterforever). Thank you!

## Also by me

- **TauntMaster Forever**: one-click taunts off your healers and DPS, for tanks. Free on CurseForge.
- **Outfitter Forever**: the classic Outfitter gear manager, ported to WoW Forever. Free on CurseForge.
- **BattleText Forever**: scrolling combat text for your hits, heals and the damage you take. Free on CurseForge.

## License

MIT — see [LICENSE](https://github.com/severd8/toppedoffforever/blob/main/LICENSE).
