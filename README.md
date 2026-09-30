<p align="center"><img src="https://raw.githubusercontent.com/severd8/toppedoffforever/main/art/logo.png" width="160" alt="ToppedOff Forever logo"></p>

# ToppedOff Forever

**Never pull with a missing buff, empty reagents or a bare weapon again.**

ToppedOff Forever is a reminder addon for **World of Warcraft: Forever**. It watches your own character and shows a small icon only when something needs topping off: a buff that's missing or about to run out, a weapon without its poison or oil, low reagents, low ammo, or worn-out gear. Click the icon and it's fixed.

---

## Features

- **Only shows what's wrong.** No icons when you're topped off. An icon appears when something runs low and disappears once it's fixed.
- **Class buffs for every class.** Arcane Intellect, Fortitude, Inner Fire, Mark of the Wild, Thorns, Demon Armor, Blessings, Auras, Aspects, Lightning Shield and more. You're warned when a buff is missing or about to run out: the icon gets an **orange border** at your warning time and turns **red** in the last 20% of it. **Click the icon to cast it on yourself.**
- **Group buffs count.** Arcane Brilliance covers Arcane Intellect, Prayer of Fortitude covers Fortitude, and a buff from another player counts too.
- **Choose your spell.** For Blessings, Auras, Aspects, Armors and Shaman weapon buffs, pick which one the icon casts.
- **Weapon enhancements.** Shaman weapon buffs, Rogue poisons, and any oil or sharpening stone you choose. **Click to apply it to your weapon.** Your best rank in your bags is used automatically.
- **Reagents and class items.** Soul Shards, teleport and portal runes, Arcane Powder, candles, Light Feathers, Symbols of Kings and Divinity, Ankhs, totems, Flash Powder and more. Checked only once you've learned a spell that needs them. Set your own minimums.
- **Ammo** for Hunters.
- **Low durability** warning before your gear breaks.
- **Food, water, bandages and potions, picked for you.** ToppedOff finds the best food, water, bandage, healing potion and mana potion in your bags, plus the right **stat food for your class** (Strength for Warriors, Agility for Rogues and Hunters, Intellect for Mages and Warlocks, mana regen for Priests and Shamans, Stamina for Druids and Paladins; change it in the options). When something better lands in your bags, it takes over. Water and mana potions are only tracked for mana users.
- **Your own items.** Add anything, like food, water, potions or bandages, with a minimum count. **Click the icon to use the item** (bandages go on you). Turn on "Always show these, with counts" to keep them on screen even when you're stocked up; the count turns red when you're low. They sit on the right of the frame, after a separator, with buffs and other reminders on the left.
- **Chat reminders.** Lists anything missing when a ready check starts or when you enter a dungeon or raid.
- **Keybindings.** Fix the first three reminders from the keyboard or a controller.

## Installation

1. Download the latest release.
2. Unzip it into your WoW: Forever `Interface\AddOns` folder so you end up with an `AddOns\ToppedOffForever\` folder.
3. Restart the game, or type `/reload` if it's already running.

Your class's checks are set up automatically. Type `/topoff check` to see them.

## Using it

- **Move the icons.** They start unlocked, inside a frame with a "ToppedOff" header. Drag the header to move them, then lock it in the options or with `/topoff lock`. Clicking the icons works whether they're locked or not.
- **Fix a reminder.** Hover over an icon to see what's wrong, then click it. Buffs are cast on you. Poisons, oils and stones are used on your weapon. Your own items are used (bandages on you).
- **Open the options.** Type `/topoff`, left-click the minimap button, or right-click the "ToppedOff" header.
- **Show or hide.** Right-click the minimap button, or type `/topoff toggle`.

### Options window

| Side | What's there |
|---|---|
| **Display** (left) | Show reminders, lock, hide in combat, only in dungeons and raids, show header, minimap button, icon size, warning time for buffs, durability warning %, chat reminders and sound |
| **What to check** (right) | Every check for your class with on/off, which spell to cast, weapon items, minimum counts, and your own items. Saved per character. |

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
| `/topoff check` | List everything checked for your class and what was found |
| `/topoff add 20 Conjured Crystal Water` | Remind you when you have fewer than 20 of an item |
| `/topoff remove Conjured Crystal Water` | Stop checking an item you added |
| `/topoff reset` | Move the reminders back to the default position |

`/toppedoff` works too.

## Good to know

WoW: Forever runs on the modern addon system, which limits what addons can do in combat. ToppedOff Forever is built around those rules:

- **It never acts on its own.** Every buff, weapon enhancement and item use is your click. It never buys, casts or uses anything by itself.
- **Reminders update out of combat.** WoW doesn't let addons change clickable icons during combat, so the icons are hidden in combat by default and refresh as soon as it ends.
- **Replacing a weapon enhancement** that hasn't run out yet makes WoW ask you to confirm. That's the game's normal prompt.
- **Spell and item names** are the Classic ones. If something isn't found in Forever, `/topoff check` shows it in yellow. Please report it.

## Troubleshooting

- **An icon doesn't appear for a buff.** Type `/topoff check`. The spell may not be learned yet, or the check may be turned off in the options.
- **A weapon icon is grey.** The item you chose isn't in your bags. Hover for details.
- **The icons disappeared.** You may have hidden them, turned on **Only in dungeons and raids**, or you may simply be topped off. Type `/topoff show`.
- **The icons are off-screen.** Type `/topoff reset`.

## Feedback and bug reports

Found a bug, or want a buff or reagent added? Please [submit it on GitHub](https://github.com/severd8/toppedoffforever/issues/new/choose). A short form asks for your class and any error message. You'll need a free GitHub account. Otherwise, feel free to leave a comment on the CurseForge page.

## Also by me

**TauntMaster Forever**: one-click taunts off your healers and DPS, for tanks. Free on CurseForge.

## License

MIT — see [LICENSE](LICENSE).
