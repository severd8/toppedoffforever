# ToppedOff Forever — developer notes

A reminder addon for **World of Warcraft: Forever** (interface 16001, client 1.60.x). Shows an icon when one of your own buffs, weapon enhancements, reagents, ammo or durability needs topping off. Clicking a buff or weapon icon casts or uses the fix.

- Author: Tyler (GitHub `severd8`). New to GitHub — explain Git steps plainly when he needs to do anything himself.
- Commits authored as `severd8 <44451903+severd8@users.noreply.github.com>`. No AI co-author or session lines in commit messages.
- CurseForge project ID: **1718878** (in the `.toc` as `X-Curse-Project-ID`).
- License: MIT. Sister addon: TauntMaster Forever (`severd8/tauntmasterforever`), which this project's setup mirrors.
- Name note: an unrelated Classic addon called "Topped Off" (by Cupz, auto-buys reagents) exists on CurseForge. Tyler chose to keep this name.

## Files

- `ToppedOffForever.toc` — `## Version: @project-version@` is filled in by the packager from the git tag. Don't hard-code a version. `ToppedOffForeverDB` (account: display settings) and `ToppedOffForeverCharDB` (per character: what to check).
- `Core.lua` — check data tables (`CLASS_BUFFS`, `WEAPON_DEFAULTS`, `CLASS_REAGENTS`), game scanning (spellbook, buffs, bags, weapon enchants, durability), building the reminder list, the secure reminder icons, minimap button, chat reminders, slash commands, events.
- `Options.lua` — options window: display settings on the left, a per-class checks list (rebuilt each time the window opens) on the right.
- `Media/Icon.tga` — the logo mark (64×64, 32-bit TGA with alpha): TOC icon, minimap button, options window corner, mover, and inline in chat/tooltips via `TO.LOGO_TEXT`. WoW needs TGA or BLP, not PNG.
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
- Weapon items match any bag item whose name *contains* the text; the highest item ID wins (usually the best rank).
- Reagent checks only run once a spell in `requires` is learned.

## WoW Forever rules the code must follow

Forever runs the modern (Midnight 12.x-style) addon API, not the Classic one.

- **Lua 5.1.** No `goto`, `//`, bitwise operators or `_ENV`.
- **Secret values.** Some API results are hidden from addons (party names, class, health, threat, your own current mana; aura data may be secret in combat). Comparing, doing math on, concatenating or truth-testing a secret throws an error.
  - Always check `IsSecret(v)` (or use the `Num()` / `Str()` helpers) **before** any comparison, `and`/`or` test, arithmetic or concatenation on an API result.
  - Secrets can go straight into widgets (`SetText`, `SetValue`, `SetAlpha`), inside `pcall`.
  - Scanning is skipped in combat, which avoids most secrets. Chat reminders in combat use the last out-of-combat result.
- **Combat lockdown.** The reminder icons are `SecureActionButtonTemplate` buttons inside secure frames (`TO.main`, `TO.bar`). Never move, resize, show/hide or change their attributes in combat. Use `TO:RunOutOfCombat(fn)`; `TO:Layout()` bails out in combat. Combat visibility is handled by a state driver (`[combat] hide; show`).
- **No automation.** Every cast or item use comes from the player's click or keypress. Never auto-buy, auto-cast or auto-use.
- **Missing APIs seen on Forever:** `Slider:SetObeyStepsOnDrag` doesn't exist (guarded). Guard any newer API the same way.

## Testing

Run from the repo root before every commit:

    lua5.1 tests/run.lua

It loads the addon against the fake WoW API and covers every class's checks, buffs missing/expiring, group buffs, preferred spells, reagents, custom items, weapon items and spells, shields skipped, ammo, durability, combat lockdown (fails if a protected frame is touched in combat), visibility, instance-only mode, chat reminders, secret-value mode, slash commands, the options window, minimap button and tooltips. Add a scenario to `tests/run_tests.lua` for any new feature. The stub can't detect truth-tests on secret values, so review those by hand.

Only testable in game: Forever's exact spell and item names, real clicking of the secure icons, the weapon-enhancement replace prompt, and Forever's exact secret-value rules.

## Releasing

1. Make the change, run the tests, and add a new section at the top of `CHANGELOG.md` (e.g. `## 1.0.1`).
2. Commit and push to `main`. The **Tests** workflow must be green.
3. Tyler creates the tag himself in GitHub Desktop (History tab → right-click the commit → Create Tag → e.g. `v1.0.1` → Push origin). Tell him exactly which commit and version. Tags containing `beta` or `alpha` upload as Beta/Alpha files.
4. The **Package and release** workflow runs the tests again, then uploads to CurseForge. Tyler checks the Actions tab for a green check and the CurseForge Files page (new files go through CurseForge review).

Before the first release: add `CF_API_KEY` to this repo's secrets.
