<p align="center"><img src="https://raw.githubusercontent.com/severd8/toppedoffforever/main/art/logo.png" width="160" alt="ToppedOff Forever logo"></p>

# ToppedOff Forever

**Never pull with a missing buff, empty reagents or a bare weapon again.**

ToppedOff Forever is a reminder addon for **World of Warcraft: Forever**. It watches your own character and shows a small icon only when something needs topping off: a buff that's missing or about to run out, a weapon without its poison or oil, low reagents, low ammo, or worn-out gear. Click the icon and it's fixed.

Icons sit in two groups: **buffs** on top (your buffs, party buffs, weapon enhancements, Well Fed, elixirs, pet, Soulstone), and **things to top off** below a gold divider (reagents, ammo, food, water, bandages, potions, your own items, conjures, Healthstone, bag space, repairs). Long rows wrap after 8 icons (change it with "Icons per row").

---

## Features

- **Shows what's wrong, plus a quick-use bar.** Buffs, reagents and gear only show when something needs fixing. Your food, water, bandages and potions stay on screen as a dimmed bar you can click, and turn bright with a red count when they run low.
- **Class buffs for every class** (Rogues get poisons instead). The icon gets an **orange border** when a buff is about to run out and turns **red** near the end. **Click to cast it on yourself.** Group versions and buffs from other players count, and you pick which Blessing, Aura, Aspect, Armor or weapon buff is cast.
- **Party buffs and blessings** (off by default). See how many party members are missing your buff and **click to buff the next one in range**. Paladins choose a blessing for each class. The whole raid can be included.
- **Weapon enhancements.** Shaman weapon buffs, Rogue poisons, and any oil or sharpening stone you choose. **Click to apply it**; your best rank is used, and low poison charges are flagged.
- **Food, water, bandages and potions, picked for you.** The best of each in your bags, plus the right **stat food for your class or role**. When you run out of the best one, the next best takes its place. A **Well Fed** reminder (in dungeons and raids by default) eats your stat food with a click.
- **Combat bar.** In combat, your healing and mana potions, Healthstone and bandage stay clickable, with counts and the potion cooldown.
- **Reagents, ammo and class items.** Soul Shards, runes, powders, candles, Ankhs, totems and more, checked once you've learned a spell that needs them, and ammo for Hunters. Set your own minimums.
- **Class extras.** Hunter and Warlock pets (missing, dead or unhappy, with one-click feeding), Soulstones, Healthstones, Mage conjures, and the elixirs and flasks you choose.
- **Gear and bags.** Low durability and low bag space warnings.
- **Vendors.** One click restocks everything you're short on that the vendor sells, with the cost shown first, and a **Repair all** button. Nothing is bought until you click.
- **Your own items.** Add anything with a minimum count, and **click the icon to use it**.
- **Profiles and reminders.** A lighter set of checks outside dungeons, copy a character's setup to an alt, chat reminders on ready checks and when you enter a dungeon, and keybindings for the first three reminders.

## Installation

1. Download the latest release.
2. Unzip it into your WoW: Forever `Interface\AddOns` folder so you end up with an `AddOns\ToppedOffForever\` folder.
3. Restart the game, or type `/reload` if it's already running.

Your class's checks are set up automatically. Type `/topoff check` to see them.

## Using it

- **Move the icons.** They start unlocked, inside a frame with a "ToppedOff" header. Drag the header to move them, then lock it in the options or with `/topoff lock`. Clicking the icons works whether they're locked or not.
- **Fix a reminder.** Hover over an icon to see what's wrong, then click it. Your buffs are cast on you, and party buffs and blessings on the party member shown. Poisons, oils and stones are used on your weapon. Your own items are used (bandages on you).
- **Open the options.** Type `/topoff`, left-click the minimap button, or right-click the "ToppedOff" header and choose **Settings**. The header menu also has **Lock**.
- **Show or hide.** Right-click the minimap button, or type `/topoff toggle`.

### Options window

| Side | What's there |
|---|---|
| **Display** (left) | Show reminders, lock, hide in combat, keep potions in combat, only in dungeons and raids, show header, minimap button, icon size, icons per row, warning time for buffs, durability warning %, chat reminders and sound, Reset position and Check spells buttons |
| **Buffs** tab (right) | Your buffs and which spell to cast, party buffs, party blessings (Paladins), whole-raid option, weapon enhancements, Well Fed, elixirs and flasks |
| **Supplies** tab | Auto-tracked food, water, bandages and potions, Healthstone, stat food choice, conjured food and water (Mages), your own items, reagents and ammo, vendor restock and repair |
| **Pet & gear** tab | Pet, Soulstone (Warlocks), durability and bag space |
| **Profiles** tab | Separate checks outside dungeons, copy another character |

Everything on the right is saved per character. Display settings on the left (including **Icons per row**) are shared by all your characters.

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
| `/topoff reset` | Move the reminders back to the default position |

`/toppedoff` works too.

## Good to know

WoW: Forever limits what addons can do in combat. ToppedOff Forever is built around those rules:

- **It never acts on its own.** Every buff, weapon enhancement, purchase and item use is your click.
- **Reminders update out of combat.** They're hidden in combat by default (except the combat bar) and refresh as soon as it ends.
- **Replacing a weapon enhancement** that hasn't run out makes the game ask you to confirm.
- **Spell and item names** are the Classic ones. If something isn't found in Forever, `/topoff check` shows it in yellow. Please report it.

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

MIT — see [LICENSE](LICENSE).
