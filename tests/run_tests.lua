-- Test scenarios for ToppedOff Forever. Run via tests/run.lua (see DEVNOTES.md).
-- Any Lua error aborts with a traceback.
local ADDON = "ToppedOffForever"
local ns = {}
local function load_file(path)
    local f = assert(io.open(path)) local src = f:read("*a") f:close()
    local chunk = assert(loadstring(src, "@" .. path))
    chunk(ADDON, ns)
end
load_file(ADDON_DIR .. "/Core.lua")
load_file(ADDON_DIR .. "/Options.lua")
local TO = ns.TO

local function fire(event, ...)
    for _, f in ipairs(ALL_FRAMES) do
        if f.__events and f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
    end
end
local function tick() for _, fn in ipairs(TICKERS) do fn() end end
local function step(name) print("STEP " .. name) end
local function assertEq(a, b, msg) if a ~= b then error(("ASSERT %s: got %s expected %s"):format(msg, tostring(a), tostring(b)), 2) end end
local function ids()
    local t = {}
    for _, r in ipairs(TO.reminders) do t[r.id] = r end
    return t
end
local function refresh() TO:RequestUpdate() tick() end
local function lastLog(pattern)
    for i = #LOG, 1, -1 do if LOG[i]:find(pattern) then return LOG[i] end end
end

---------------------------------------------------------------------------
step("load + login (mage)")
LEARN("Arcane Intellect", "Frost Armor", "Ice Armor", "Teleport: Stormwind", "Slow Fall")
FUTURE = { "Mage Armor", "Arcane Brilliance" }     -- visible in the spellbook but not learned
fire("ADDON_LOADED", ADDON)
fire("PLAYER_LOGIN")
assert(TO.built, "frames not built")
assert(lastLog("ToppedOff Forever|r loaded"), "login message")
fire("PLAYER_ENTERING_WORLD")
tick()

step("missing buffs")
local r = ids()
assert(r["buff:intellect"], "Arcane Intellect missing")
assert(r["buff:armor"], "armor missing")
assertEq(r["buff:armor"].action.spell, "Ice Armor", "prefers Ice Armor over Frost Armor")
assertEq(TO:Knows("Mage Armor"), false, "future spells don't count as learned")
local b1 = TO.buttons[1]
assertEq(b1.__shown, true, "first icon shown")
assertEq(b1.__attrs.type, "spell", "icon casts a spell")
assertEq(b1.__attrs.unit, "player", "cast on yourself")
assertEq(TO.bar.__shown, true, "bar shown with reminders")

step("reagents")
assert(r["reagent:teleport"], "teleport runes low")
assertEq(r["reagent:teleport"].text, "0/2", "rune count text")
assert(r["reagent:feather"], "light feathers (Slow Fall known)")
assertEq(r["reagent:portal"], nil, "no portal check without Portal spells")
assertEq(r["reagent:powder"], nil, "no powder check: Arcane Brilliance not learned")
assertEq(r["buff:intellect"].action.spell, "Arcane Intellect", "intellect spell")
assertEq(b1.__attrs.macrotext, nil, "spell icon has no macro")

step("buffs present, reagents stocked")
STATE.buffs = { ["Arcane Brilliance"] = 1800, ["Ice Armor"] = 0 }   -- raid version counts
STATE.bags = { { id = 1, name = "Rune of Teleportation", count = 5 }, { id = 2, name = "Light Feather", count = 3 },
    { id = 3, name = "Light Feather", count = 4 } }
refresh()
r = ids()
assertEq(r["buff:intellect"], nil, "Arcane Brilliance satisfies Arcane Intellect")
assertEq(r["buff:armor"], nil, "permanent armor is fine")
assertEq(r["reagent:feather"], nil, "stacks add up (7 feathers)")
assertEq(#TO.reminders, 0, "nothing to remind")
assertEq(TO.bar.__shown, false, "bar hidden with no reminders")

step("buff running out")
STATE.buffs["Arcane Brilliance"] = 90
refresh()
r = ids()
assert(r["buff:intellect"], "expiring buff warned")
assertEq(r["buff:intellect"].text, "2m", "time left shown")
STATE.buffs["Arcane Brilliance"] = 1800

step("preferred spell + disabling a check")
TO.char.prefs.armor = "Frost Armor"
STATE.buffs["Ice Armor"] = nil
refresh()
assertEq(ids()["buff:armor"].action.spell, "Frost Armor", "chosen spell used")
TO:SetEnabled("buff:armor", false)
tick()
assertEq(ids()["buff:armor"], nil, "disabled check skipped")
TO:SetEnabled("buff:armor", true)
STATE.buffs["Ice Armor"] = 0

step("combat lockdown")
STATE.buffs["Arcane Brilliance"] = nil
COMBAT = true
BLOCKED = {}
fire("UNIT_AURA", "player")
tick()
fire("BAG_UPDATE_DELAYED")
TO:ApplySettings()
SlashCmdList.TOPPEDOFFFOREVER("reset")
assertEq(#BLOCKED, 0, "protected frame touched in combat: " .. table.concat(BLOCKED, ", "))
assertEq(TO.dirty, true, "update waits for combat to end")
COMBAT = false
fire("PLAYER_REGEN_ENABLED")
tick()
assert(ids()["buff:intellect"], "updated after combat")

step("visibility driver")
assertEq(TO.main.__driver, "[combat] hide; show", "hide in combat by default")
TO.db.hideInCombat = false TO:ApplySettings()
assertEq(TO.main.__driver, "show", "always show")
SlashCmdList.TOPPEDOFFFOREVER("hide")
assertEq(TO.main.__driver, "hide", "hidden")
SlashCmdList.TOPPEDOFFFOREVER("show")
TO.db.hideInCombat = true TO:ApplySettings()

step("only in instances")
TO.db.onlyInInstance = true TO:ApplySettings()
assertEq(TO.bar.__shown, false, "hidden outside instances")
STATE.instance = true
refresh()
assertEq(TO.bar.__shown, true, "shown in instance")
TO.db.onlyInInstance = false TO:ApplySettings()

step("chat reminders")
AFTER = {}
STATE.instance = false
fire("PLAYER_ENTERING_WORLD")
STATE.instance = true
fire("PLAYER_ENTERING_WORLD")
assertEq(#AFTER, 1, "instance reminder scheduled")
AFTER[1]()
assert(lastLog("Entering instance.-Arcane Intellect"), "instance reminder lists missing buff")
fire("READY_CHECK")
assert(lastLog("Ready check.-Arcane Intellect"), "ready check reminder")
TO.db.sound = true
fire("READY_CHECK")
assert(lastLog("^SOUND"), "reminder sound")
TO.db.sound = false
STATE.instance = false

step("custom items")
SlashCmdList.TOPPEDOFFFOREVER("add 20 Conjured Water")
assertEq(#TO.char.custom, 1, "custom item added")
STATE.bags[4] = { id = 4, name = "Conjured Water", count = 5 }
refresh()
assertEq(ids()["custom:conjured water"].text, "5/20", "custom count")
SlashCmdList.TOPPEDOFFFOREVER("add 3 conjured water")
assertEq(#TO.char.custom, 1, "re-adding updates instead of duplicating")
refresh()
assertEq(ids()["custom:conjured water"], nil, "5 >= 3")
SlashCmdList.TOPPEDOFFFOREVER("remove Conjured Water")
assertEq(#TO.char.custom, 0, "custom item removed")
SlashCmdList.TOPPEDOFFFOREVER("add banana")
assert(lastLog("usage"), "bad add shows usage")

step("durability")
STATE.durability = { [1] = 80, [5] = 10 }
refresh()
assertEq(ids().durability.text, "10%", "lowest durability")
STATE.durability = { [1] = 80 }
refresh()
assertEq(ids().durability, nil, "fine durability")

step("weapon: item (rogue-style)")
STATE.class = "ROGUE"
SPELLBOOK, FUTURE = {}, {}
LEARN("Vanish")
fire("SPELLS_CHANGED")
STATE.mh, STATE.oh = 900, 900
STATE.bags = { { id = 10, name = "Instant Poison", count = 5 }, { id = 12, name = "Instant Poison III", count = 5 },
    { id = 20, name = "Flash Powder", count = 1 } }
refresh()
r = ids()
assert(r["weapon:mh"] and r["weapon:oh"], "both weapons need poison")
assertEq(r["weapon:mh"].action.item, "Instant Poison III", "best rank picked")
local wb
for _, b in ipairs(TO.buttons) do if b.reminder and b.reminder.id == "weapon:oh" then wb = b end end
assertEq(wb.__attrs.type, "macro", "weapon uses a macro")
assertEq(wb.__attrs.macrotext, "/use Instant Poison III\n/use 17", "poison on off hand")
assertEq(r["reagent:flash"].text, "1/5", "flash powder low")
STATE.enchant = { mh = 30 * 60 * 1000, oh = 60 * 1000 }
refresh()
r = ids()
assertEq(r["weapon:mh"], nil, "fresh poison fine")
assertEq(r["weapon:oh"].text, "1m", "expiring poison")
STATE.bags = {}
STATE.enchant = {}
refresh()
r = ids()
assertEq(r["weapon:mh"].noItem, "Instant Poison", "no poison in bags")
assertEq(r["weapon:mh"].action, nil, "nothing to click without the item")

step("weapon: shield in off hand is skipped")
STATE.oh = 901
refresh()
assertEq(ids()["weapon:oh"], nil, "shield skipped")

step("weapon: spell (shaman)")
STATE.class = "SHAMAN"
SPELLBOOK = {}
LEARN("Rockbiter Weapon", "Flametongue Weapon", "Lightning Shield", "Reincarnation")
fire("SPELLS_CHANGED")
refresh()
r = ids()
assertEq(r["weapon:mh"].action.spell, "Flametongue Weapon", "best weapon spell known")
assert(r["buff:shield"], "Lightning Shield")
assertEq(r["reagent:ankh"].text, "0/1", "ankh")
TO.char.weapon.spell = "Rockbiter Weapon"
refresh()
assertEq(ids()["weapon:mh"].action.spell, "Rockbiter Weapon", "chosen weapon spell")

step("warrior: no weapon item set")
STATE.class = "WARRIOR"
SPELLBOOK = {}
LEARN("Battle Shout")
fire("SPELLS_CHANGED")
STATE.oh = 900
refresh()
r = ids()
assertEq(r["weapon:mh"], nil, "no item set = no weapon reminder")
assertEq(r["buff:shout"], nil, "Battle Shout is off by default")
TO.char.weapon.mh = "Sharpening Stone"
refresh()
assert(ids()["weapon:mh"], "item set = weapon reminder")

step("ammo (hunter)")
STATE.class = "HUNTER"
SPELLBOOK = {}
LEARN("Aspect of the Hawk")
fire("SPELLS_CHANGED")
STATE.ammo, STATE.ammoCount = 700, 150
refresh()
assertEq(ids().ammo.text, "150", "low ammo")
STATE.ammoCount = 1000
refresh()
assertEq(ids().ammo, nil, "enough ammo")

step("secret values")
SECRET_MODE = true
refresh()
STATE.durability = { [1] = 10 }
refresh()
TO:Check()
fire("READY_CHECK")
SECRET_MODE = false
refresh()

step("slash commands")
for _, cmd in ipairs({ "", "", "lock", "unlock", "check", "toggle", "toggle", "help", "reset" }) do
    SlashCmdList.TOPPEDOFFFOREVER(cmd)
end
assertEq(TO.db.locked, false, "unlocked")
assertEq(TO.mover.__shown, true, "mover shown when unlocked")
SlashCmdList.TOPPEDOFFFOREVER("lock")
assertEq(TO.mover.__shown, false, "mover hidden when locked")

step("options window")
TO:OpenConfig()
assert(TO.config.__shown, "options open")
for _, class in ipairs({ "MAGE", "PRIEST", "DRUID", "WARLOCK", "PALADIN", "HUNTER", "WARRIOR", "SHAMAN", "ROGUE" }) do
    STATE.class = class
    TO:AddCustom("Healing Potion", 3)
    TO:BuildChecksList()
end
-- Click every checkbox and button in the checks list, and commit every edit box
for _, f in ipairs(ALL_FRAMES) do
    if f.__kind == "CheckButton" and f.__scripts.OnClick then
        f.__checked = not f.__checked
        f.__scripts.OnClick(f)
    elseif f.__kind == "EditBox" and f.__scripts.OnEnterPressed then
        f.__text = f.__text ~= "" and f.__text or "7"
        f.__scripts.OnEnterPressed(f)
    end
end
for _, f in ipairs(ALL_FRAMES) do
    if f.__kind == "Button" and f.__template == "UIPanelButtonTemplate" and f.__scripts.OnClick then
        f.__scripts.OnClick(f)
    end
end
tick()
TO:OpenConfig()
assertEq(TO.config.__shown, false, "options toggle closed")

step("minimap button")
local mm = TO.minimapButton
mm.__scripts.OnClick(mm, "LeftButton")
mm.__scripts.OnClick(mm, "RightButton")
mm.__scripts.OnEnter(mm)
TO.db.minimap = false TO:ApplySettings()
assertEq(mm.__shown, false, "minimap button hidden")

assert(TO.config.logo.__texture:find("Media\\Icon"), "options window shows the logo")
assert(TO.mover.logo.__texture:find("Media\\Icon"), "mover shows the logo")
assert(lastLog("Media\\Icon"), "chat lines carry the logo")

step("tooltips")
TO.db.shown = true TO:ApplySettings()
for _, b in ipairs(TO.buttons) do if b.reminder then b.__scripts.OnEnter(b) end end

print("ALL TESTS PASSED")
