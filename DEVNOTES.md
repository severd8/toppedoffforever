# ToppedOff Forever — developer notes

A reminder addon for **World of Warcraft: Forever** (interface 16001, client 1.60.x). Shows an icon when one of your own buffs, weapon enhancements, reagents, ammo or durability needs topping off. Clicking a buff or weapon icon casts or uses the fix.

- Author: `severd8`.
- CurseForge project ID: **1718878** (in the `.toc` as `X-Curse-Project-ID`).
- License: MIT. Sister addon: TauntMaster Forever (`severd8/tauntmasterforever`), which this project's setup mirrors.
- Name note: an unrelated Classic addon called "Topped Off" (by Cupz, auto-buys reagents) exists on CurseForge. This name was kept on purpose.

## Files

- `ToppedOffForever.toc` — `## Version: @project-version@` is filled in by the packager from the git tag. Don't hard-code a version. `ToppedOffForeverDB` (account: display settings) and `ToppedOffForeverCharDB` (per character: what to check).
- `Core.lua` — check data tables (`CLASS_BUFFS`, `WEAPON_DEFAULTS`, `CLASS_REAGENTS`), game scanning (spellbook, buffs, bags, weapon enchants, durability), building the reminder list, the secure reminder icons, minimap button, chat reminders, slash commands, events.
- `Theme.lua` — **the shared look, and the same file in TauntMaster Forever, ToppedOff Forever and Outfitter Forever.** Change it in one repo, then copy it to the other two (it finds its own addon's name and logo from the folder name, in `BRANDS`). It has the colours (`C`), `Fill`, `Border`, `Text`, `FlatButton`, `SwitchWidget`, `Tooltip`, `Panel` (an on-screen panel), `HeaderStrip` (the red bar with the logo and name above an on-screen frame), the settings widgets (`Card`, `Note`, `RowLabel`, `LabeledSwitch`, `Dropdown`, `Slider`, `EditBox`, `ScrollArea`), `Window` (the settings window: header with logo, name and version, tabs down the left, pages, footer), and `CHAT_PREFIX` (logo and name for chat lines). Loaded first. Don't use Blizzard templates (UIPanelButtonTemplate etc.) in a window with this look.
- `Options.lua` — the options window, built with `Theme.Window`: tabs down the left. Buffs, Supplies, Pet & gear and Profiles are this character's checks; each is a scrolling list of cards that is drawn again every time it's shown (`TO:BuildChecksList`), since it depends on your class, spells and bags. The third tab is "Pet & gear" for Hunters and Warlocks and "Gear & bags" for everyone else (`TO:NameMoreTab`, set each time a list is drawn). Display and General are the settings every character shares, built once. The game never frees a frame, so the lists reuse their widgets: each list frame has a `pool`, and the helpers (`Label`, `Toggle`, `EditBox`, `Button`, `Dropdown`, the cards) take a widget from it before making one (`Acquire`). A reused widget is put back to how a new one starts (`ResetText`, `ResetHover`, and every helper sets its size, text and scripts each time). If a helper starts changing something else on a widget, reset that too; the "options lists reuse their rows" test compares reused rows with new ones.
- `Vendor.lua` — restock and repair panel beside the vendor window (MERCHANT_SHOW). The buy logic is in `Core.lua` (`RestockNeeds`, `MerchantItems`, `RestockPlan`, `BuyRestock`). Items sold in stacks are bought one stack per `BuyMerchantItem(index)` call; single items with a quantity.
- Combat bar (`Core.lua`: `BuildCombatBar`, `LayoutCombatBar`, `UpdateCombatCounts`) — a second secure frame pinned to the reminder frame's top-left, visibility driver `[combat] show; hide`. Its buttons and attributes are set only out of combat (at the end of `Layout`); in combat only counts, desaturation and cooldowns change (allowed on protected frames).
- `Media/Icon.tga` — the logo mark (64×64, 32-bit TGA with alpha): TOC icon, minimap button, options window corner, the header above the icons, and inline in chat/tooltips via `TO.LOGO_TEXT`. WoW needs TGA or BLP, not PNG.
- `art/` — logo sources (not shipped): `logo.svg` (full logo with banner), `logo.png` (1024×1024, for CurseForge and the README), `icon.svg` (the medallion used in game). Re-export `Media/Icon.tga` from `icon.svg` if the logo changes.
- `Bindings.xml` — keybindings (loaded automatically, not listed in the `.toc`). `CLICK ToppedOffForeverButton1-3:LeftButton` press the first three icons; `TOPPEDOFFFOREVER_OPTIONS` opens the options. Names are set in `Core.lua`.
- `tests/` — offline test suite (not shipped). `wowstub.lua` fakes the WoW API; `run_tests.lua` holds the scenarios; `run.lua` runs them.
- `CHANGELOG.md` — release notes shown on CurseForge. Newest version at the top.
- `.pkgmeta` — packager config (folder name, changelog, files left out of the download).
- `.github/workflows/test.yml` — runs the tests on every push. `release.yml` — on a `v*` tag, runs the tests, then packages and uploads to CurseForge as `toppedoff-{project-version}{classic}{nolib}`. Needs the `CF_API_KEY` repository secret.

## How it works

- `TO:Update()` runs out of combat only: scans buffs (`C_UnitAuras.GetAuraDataByIndex`), bags (`C_Container`), weapon enchants (`GetWeaponEnchantInfo`), ammo and durability, builds a list of reminders and lays out the icons.
- Events only mark the list dirty (`TO:RequestUpdate()`); a 1-second ticker refreshes when dirty, and every 5 seconds anyway for countdowns.
- Spells are matched by **name** from a spellbook scan (ranks share a name). Unlearned spells the modern spellbook shows (`Enum.SpellBookItemType.FutureSpell`) are skipped.
- **Passive spells** (`isPassive` in the spellbook; Omen of Clarity on Forever) can't be cast, so `TO:KnownOptions` leaves them out: no buff reminder, and no row in the options (`TO:AllPassive`). `TO:Knows` still counts them, because a passive can need a reagent (Reincarnation and Ankhs).
- Weapon items match any bag item whose name *contains* the text; the highest item ID wins (usually the best rank).
- Reagent checks only run once a spell in `requires` is learned.
- Food, water, bandages and potions are picked by reading each bag item's tooltip (`TO:ItemKind`). Right after login a tooltip can be incomplete: the item is loaded but its "Use:" line (which comes from a spell) isn't yet. So `ItemKind` waits while the item's spell text is loading (`UseTextLoaded`), and an item whose tooltip shows nothing to track is read again every couple of seconds for two minutes (`unsure`) before that's final.
- Each auto-tracked slot remembers one item (`char.auto[key]`, the one a vendor restocks). When you have none of it, the reminder and the combat bar use the next best of that kind in your bags instead (`TO:AutoItemInBags`).
- Group members' buffs are read once per round of checks (`TO:UnitBuffs`, cached in `self.unitBuffs` for the length of `BuildReminders`), however many party checks ask. Until your own buffs have been readable once, `BuildReminders` changes nothing.
- Saved settings are checked at load: a value of the wrong type goes back to its default (`FillDefaults`), and list entries that can't be used are dropped (`KeepValid`).
- Only the modern API is used (`C_Container`, `C_Item`, `C_Spell`, `C_SpellBook`, `C_UnitAuras`, `C_MerchantFrame.GetItemInfo`). All of it is documented on this client, so there are no fallbacks to the old global functions.

## WoW Forever rules the code must follow

Forever runs the modern (Midnight 12.x-style) addon API, not the Classic one.

- **Lua 5.1.** No `goto`, `//`, bitwise operators or `_ENV`.
- **Secret values.** Some API results are hidden from addons (party names, class, health, threat, your own current mana; aura data may be secret in combat). Comparing, doing math on, concatenating or truth-testing a secret throws an error.
  - Always check `IsSecret(v)` (or use the `Num()` / `Str()` helpers) **before** any comparison, `and`/`or` test, arithmetic or concatenation on an API result.
  - Secrets can go straight into widgets (`SetText`, `SetValue`, `SetAlpha`), inside `pcall`.
  - Scanning is skipped in combat, which avoids most secrets. Chat reminders in combat use the last out-of-combat result.
- **Combat lockdown.** The reminder icons are `SecureActionButtonTemplate` buttons inside secure frames (`TO.main`, `TO.bar`). Never move, resize, show/hide or change their attributes in combat. Use `TO:RunOutOfCombat(key, fn)`: in combat the work waits until the fight ends, and a later request under the same key replaces the earlier one, so each kind of work (`"build"`, `"visibility"`, `"update"`, `"position"`, `"drop"`) runs once, in the order first asked. `TO:Layout()` bails out in combat. Combat visibility is handled by a state driver (`[combat] hide; show`).
- **No automation.** Every cast or item use comes from the player's click or keypress. Never auto-buy, auto-cast or auto-use.
- **Secure action buttons** must be registered for `"AnyUp", "AnyDown"`. The template acts on only one phase, picked by the `ActionButtonUseKeyDown` setting (and the `useOnKeyDown` attribute); with only `AnyUp`, clicks do nothing when that setting is on.
- **Missing APIs seen on Forever:** `Slider:SetObeyStepsOnDrag` doesn't exist (guarded). Guard any newer API the same way.

## Testing

Run from the repo root before every commit:

    lua5.1 tests/run.lua

It loads the addon against the fake WoW API and covers every class's checks, buffs missing/expiring, group buffs, preferred spells, reagents, custom items, weapon items and spells, shields skipped, ammo, durability, combat lockdown (fails if a protected frame is touched in combat), visibility, instance-only mode, chat reminders, secret-value mode, slash commands, the options window, minimap button and tooltips. Add a scenario to `tests/run_tests.lua` for any new feature. The stub can't detect truth-tests on secret values, so review those by hand.

Visual check of the layout: `lua5.1 tests/render.lua out.json && python3 tests/render.py out.json outdir` draws the reminder frame and every options tab (for several classes) as PNG images. It's an approximation of the game's look (plain colors instead of icons) for catching overlaps, alignment and text running past the edge. Needs Python with Pillow.

Only testable in game: Forever's exact spell and item names, real clicking of the secure icons, the weapon-enhancement replace prompt, and Forever's exact secret-value rules.

## Releasing

1. Make the change, run the tests, and add a new section at the top of `CHANGELOG.md` (e.g. `## 1.0.1`).
2. Commit and push to `main`. The **Tests** workflow must be green.
3. Create the tag in GitHub Desktop (History tab → right-click the commit → Create Tag → e.g. `v1.0.1` → Push origin). Tags containing `beta` or `alpha` upload as Beta/Alpha files.
4. The **Package and release** workflow runs the tests again, then uploads to CurseForge. Check the Actions tab for a green check and the CurseForge Files page (new files go through CurseForge review).

