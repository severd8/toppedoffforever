-- Test scenarios for ToppedOff Forever. Run via tests/run.lua (see DEVNOTES.md).
-- Any Lua error aborts with a traceback.
local ADDON = "ToppedOffForever"
local ns = {}
local function load_file(path)
    local f = assert(io.open(path)) local src = f:read("*a") f:close()
    local chunk = assert(loadstring(src, "@" .. path))
    chunk(ADDON, ns)
end
-- Blizzard's global tables: the addon may add to them but must never assign the
-- global itself (even to the same table: that taints it, and WoW then blocks
-- Blizzard UI actions like the Escape menu and blames the addon). While the addon
-- loads, they're served through a guard that fails on any assignment.
local BLIZZARD_GLOBALS = { "StaticPopupDialogs", "UISpecialFrames", "SlashCmdList", "RAID_CLASS_COLORS", "SOUNDKIT" }
local guarded = {}
for _, n in ipairs(BLIZZARD_GLOBALS) do guarded[n] = rawget(_G, n); rawset(_G, n, nil) end
setmetatable(_G, {
    __index = function(_, k) return guarded[k] end,
    __newindex = function(t, k, v)
        if guarded[k] ~= nil then error("assigned Blizzard global " .. k .. " (taints the Blizzard UI)", 2) end
        rawset(t, k, v)
    end,
})
load_file(ADDON_DIR .. "/Theme.lua")
load_file(ADDON_DIR .. "/Core.lua")
load_file(ADDON_DIR .. "/Options.lua")
load_file(ADDON_DIR .. "/Vendor.lua")
setmetatable(_G, nil)
for n, v in pairs(guarded) do rawset(_G, n, v) end
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
ToppedOffForeverDB = { iconSize = 36 }   -- settings from 1.0.0
LEARN("Arcane Intellect", "Frost Armor", "Ice Armor", "Teleport: Stormwind", "Slow Fall")
FUTURE = { "Mage Armor", "Arcane Brilliance" }     -- visible in the spellbook but not learned
fire("ADDON_LOADED", ADDON)
fire("PLAYER_LOGIN")
assert(TO.built, "frames not built")
assertEq(TO.char.customAlways, true, "quick-use bar on by default")
TO.char.customAlways = false   -- most scenarios below test the "only when low" behavior
assertEq(TO.db.iconSize, 40, "old default icon size upgraded")
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
-- Always show, even when stocked; click uses the item
TO.char.customAlways = true; refresh()
local w = ids()["custom:conjured water"]
assertEq(w and w.text, "5/3", "stocked item shown with count")
assertEq(w.stocked, true, "marked as topped off")
for _, b in ipairs(TO.buttons) do
    if b.reminder == w then assertEq(b.icon.__alpha, TO.STOCKED_ALPHA, "stocked item dimmed") end
end
local wb
for _, b in ipairs(TO.buttons) do if b.reminder == w then wb = b end end
assertEq(wb.__attrs.type, "item", "click uses the item")
assertEq(wb.__attrs.item, "item:4", "uses it by item ID")
assertEq(wb.__attrs.unit, "player", "on yourself (bandages)")
-- Buffs on the top row, things to top off on the second row, divider between
do
    local lastTop, firstBottom
    for i, b in ipairs(TO.buttons) do
        if b.__shown ~= false and b.reminder then
            if TO:IsBuffReminder(b.reminder) then lastTop = i else firstBottom = firstBottom or i end
        end
    end
    assert(lastTop, "scenario has a buff reminder too")
    assert(firstBottom and firstBottom > lastTop, "top-off items come after buffs")
    assertEq(TO.divider.__shown, true, "divider shown between rows")
end
local mark = #LOG; TO:Remind("Ready check")
for i = mark + 1, #LOG do assert(not LOG[i]:find("Conjured Water"), "topped-off items aren't reported as missing") end
TO.char.customAlways = false; refresh()
assertEq(ids()["custom:conjured water"], nil, "hidden again when stocked")
SlashCmdList.TOPPEDOFFFOREVER("add 20 Conjured Water"); refresh()
local lb
for _, b in ipairs(TO.buttons) do if b.reminder and b.reminder.id == "custom:conjured water" then lb = b end end
assertEq(lb.__attrs.item, "item:4", "low item is clickable too")
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
-- Poison charges
STATE.charges = { mh = 6, oh = 30 }
refresh()
r = ids()
assertEq(r["weapon:mh"] and r["weapon:mh"].text, "6c", "low poison charges")
assertEq(r["weapon:mh"].urgentNow, true, "low charges get the red border")
TO.char.mins.charges = 5; refresh()
assertEq(ids()["weapon:mh"], nil, "above your charge minimum")
TO.char.mins.charges = nil; STATE.charges = nil
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
-- A tab asked for before the options window has ever been opened is the one it opens on
assertEq(TO.config, nil, "(the window isn't built until it's first opened)")
TO:ShowOptionsTab("supplies")
SlashCmdList.TOPPEDOFFFOREVER("")
assertEq(TO.optionsTab, "supplies", "the window opens on the tab that was asked for")
assertEq(TO.config.pages.supplies:IsVisible(), true, "(and shows it)")
SlashCmdList.TOPPEDOFFFOREVER("")
assertEq(TO.config:IsShown(), false, "/topoff again closes it")
for _, cmd in ipairs({ "", "", "lock", "unlock", "check", "toggle", "toggle", "help", "reset" }) do
    SlashCmdList.TOPPEDOFFFOREVER(cmd)
end
assertEq(TO.db.locked, false, "unlocked")
assertEq(TO.box.__shown, true, "frame shown when unlocked")
assertEq(TO.header.__point, "TOPRIGHT", "header runs along the top of the frame")
assertEq(TO.box.__frameLevel, 1, "frame sits behind the icons")
SlashCmdList.TOPPEDOFFFOREVER("lock")
TO.shownCount = 0 TO:UpdateHeader()
assertEq(TO.box.__shown, false, "frame hidden when locked with no reminders")
TO.shownCount = 2 TO:UpdateHeader()
assertEq(TO.box.__shown, true, "frame shown with reminders")
TO.db.showHeader = false TO:UpdateHeader()
assertEq(TO.box.__shown, false, "frame can be turned off")
TO.db.showHeader = true

step("options window")
TO:OpenConfig()
assert(TO.config.__shown, "options open")
for _, class in ipairs({ "MAGE", "PRIEST", "DRUID", "WARLOCK", "PALADIN", "HUNTER", "WARRIOR", "SHAMAN", "ROGUE" }) do
    STATE.class = class
    TO:AddCustom("Healing Potion", 3)
    for _, t in ipairs(TO.OPTION_TABS) do TO:ShowOptionsTab(t.key) end
    -- The third tab is "Pet & gear" only for the classes with pet checks
    local pets = class == "HUNTER" or class == "WARLOCK"
    local name = pets and "Pet & gear" or "Gear & bags"
    assertEq(TO.config.tabButtons.more:GetText(), name, class .. ": the third tab's name")
    assertEq(TO.config.pages.more.title:GetText(), name, class .. ": and its page's title")
    assertEq(TO.config.tabButtons.more.icon.__texture,
        "Interface\\Icons\\" .. (pets and "Ability_Hunter_BeastCall" or "Trade_BlackSmithing"), class .. ": and its icon")
    local petCard, note = false, nil
    for _, f in ipairs(ALL_FRAMES) do
        if f.__kind == "FontString" and f:IsVisible() then
            local text = f:GetText() or ""
            if text:find("^Turn this on to have a lighter set of checks") then note = text end
        end
    end
    assert(note and note:find("Supplies and " .. name .. " tabs", 1, true), class .. ": the Profiles note names the tab the same way")
    TO:ShowOptionsTab("more")
    for _, f in ipairs(ALL_FRAMES) do
        if f.__kind == "FontString" and f:IsVisible() and f:GetText() == "PET" then petCard = true end
    end
    assertEq(petCard, pets, class .. ": a Pet card only when there are pet checks")
    TO:ShowOptionsTab("profiles")
end
assertEq(TO.optionsTab, "profiles", "last tab shown")
-- On every tab: flip every switch, pick from every choice box, press every button,
-- and commit every text box (the window's own X, Close and tab buttons aside)
for _, tab in ipairs({ "buffs", "supplies", "more", "profiles", "display", "general" }) do
    TO:ShowOptionsTab(tab)
    assertEq(TO.config.pages[tab]:IsVisible(), true, tab .. " tab shown")
    local function inWindow(f)
        while f do if f == TO.config then return true end f = f.__parent end
        return false
    end
    local visible = {}
    for _, f in ipairs(ALL_FRAMES) do
        if f:IsVisible() and inWindow(f) and f.__parent ~= TO.config.header and f.__parent ~= TO.config.footer
            and not f.selBg then
            visible[#visible + 1] = f
        end
    end
    for _, f in ipairs(visible) do
        if f.__kind == "EditBox" and f.__scripts.OnEnterPressed then
            f.__text = f.__text ~= "" and f.__text or "7"
            f.__scripts.OnEnterPressed(f)
        elseif f.__kind == "Button" and f.__scripts.OnClick and TO.config:IsVisible() then
            f.__scripts.OnClick(f)
        end
    end
    assertEq(TO.config:IsVisible(), true, "the window stays open")
end
tick()
TO:OpenConfig()
assertEq(TO.config.__shown, false, "options toggle closed")
-- The walk above flipped settings; put the defaults back for later steps
TO.char.wellFedInstanceOnly, TO.char.elixirInstanceOnly, TO.char.soulstoneInstanceOnly = true, true, true
TO.char.customAlways, TO.char.splitProfiles, TO.char.wholeRaid = false, false, false
TO.char.restockAtVendor, TO.char.repairAtVendor = true, true
TO.char.checksOutside = {}

step("minimap button")
local mm = TO.minimapButton
mm.__scripts.OnClick(mm, "LeftButton")
mm.__scripts.OnClick(mm, "RightButton")
mm.__scripts.OnEnter(mm)
TO.db.minimap = false TO:ApplySettings()
assertEq(mm.__shown, false, "minimap button hidden")

assert(TO.config.logo.__texture:find("Media\\Icon"), "options window shows the logo")
assertEq(TO.config.title:GetText(), "ToppedOff Forever", "and the addon's name")
assertEq(TO.header.text:GetText(), "ToppedOff", "the header bar shows the short name")
assert(TO.header.logo.__texture:find("Media\\Icon"), "header shows the logo")
-- The logo file itself: what the game can load (an uncompressed 32-bit TGA, 64x64), and the
-- right way up. A TGA's rows run bottom to top, so the drop's point (the top of the picture)
-- is in the last rows of the file and its round end in the first.
do
    local f = assert(io.open(ADDON_DIR .. "/Media/Icon.tga", "rb"), "the logo file")
    local data = f:read("*a") f:close()
    assertEq(data:byte(3), 2, "uncompressed true-color TGA")
    assertEq(data:byte(13) + data:byte(14) * 256, 64, "64 wide")
    assertEq(data:byte(15) + data:byte(16) * 256, 64, "64 tall")
    assertEq(data:byte(17), 32, "32-bit, with transparency")
    assertEq(math.floor(data:byte(18) / 32) % 2, 0, "rows stored bottom to top")
    local function blueInRow(row)   -- how much of a stored row is the drop's blue
        local n = 0
        for col = 0, 63 do
            local at = 18 + (row * 64 + col) * 4
            local b, _, r, a = data:byte(at + 1, at + 4)
            if a > 200 and b > 150 and r < 120 then n = n + 1 end
        end
        return n
    end
    local low, high = 0, 0
    for row = 16, 28 do low = low + blueInRow(row) end    -- lower half of the picture
    for row = 36, 48 do high = high + blueInRow(row) end  -- upper half
    assert(low > high * 1.5, "the drop is the right way up: wide below, pointed above (" .. low .. " vs " .. high .. ")")
end
SlashCmdList.TOPPEDOFFFOREVER("lock")
assertEq(LOG[#LOG], "|TInterface\\AddOns\\ToppedOffForever\\Media\\Icon:0|t |cffe8a040ToppedOff Forever|r: locked.",
    "chat lines start with the logo and the addon's name")

step("frame width")
TO.db.locked, TO.db.onlyInInstance = false, false
TO:Layout({ { id = "a", label = "A" } })
assertEq(TO.main.__size[1], 84, "one reminder: still two icons wide")
TO:Layout({ { id = "a", label = "A" }, { id = "b", label = "B" }, { id = "c", label = "C" } })
assertEq(TO.main.__size[1], 128, "three reminders: frame grows")
TO:Layout({})
assertEq(TO.main.__size[1], 84, "no reminders: two icons wide")

step("tooltips")
TO.db.shown = true TO:ApplySettings()
for _, b in ipairs(TO.buttons) do if b.reminder then b.__scripts.OnEnter(b) end end

step("frame pinned by its top-left corner")
TO.main.__left, TO.main.__top = 300, 500
TO.db.point = { "CENTER", "CENTER", 0, -150 }
TO:RestorePosition()
assertEq(TO.db.point[1], "TOPLEFT", "old center position converted")
assertEq(TO.db.point[3], 300, "left edge kept")
assertEq(TO.db.point[4], 500, "top edge kept")
assertEq(TO.main.__point, "TOPLEFT", "frame anchored top-left")
TO.main.__left = 320; TO:SavePosition()
assertEq(TO.db.point[3], 320, "drag saves the top-left corner")
step("auto-tracked best items")
STATE.class = "WARRIOR"; STATE.level = 30; STATE.buffs = {}
TO.char.custom = {}; TO.char.auto = {}; TO.char.statFocus = nil; TO.char.customAlways = false; TO.char.checks = {}
local EAT = " Must remain seated while eating."
STATE.bags = {
    { id = 101, name = "Tough Jerky", count = 4, tip = "Use: Restores 61 health over 18 sec." .. EAT },
    { id = 102, name = "Mutton Chop", count = 30, tip = "Requires Level 25\nUse: Restores 552 health over 21 sec." .. EAT },
    { id = 103, name = "Roasted Quail", count = 5, tip = "Requires Level 35\nUse: Restores 874 health over 24 sec." .. EAT },
    { id = 104, name = "Spiced Wolf Meat", count = 3, tip = "Requires Level 5\nUse: Restores 61 health over 15 sec." .. EAT
        .. " If you spend at least 10 seconds eating you will become well fed and gain 2 Stamina and Spirit for 15 min." },
    { id = 105, name = "Smoked Desert Dumplings", count = 2, tip = "Requires Level 25\nUse: Restores 1392 health over 27 sec." .. EAT
        .. " If you spend at least 10 seconds eating you will become well fed and gain 20 Strength for 15 min." },
    { id = 106, name = "Melon Juice", count = 8, tip = "Requires Level 15\nUse: Restores 835 mana over 27 sec. Must remain seated while drinking." },
    { id = 107, name = "Heavy Linen Bandage", count = 12, tip = "Requires First Aid (40)\nUse: Heals 114 damage over 6 sec." },
    { id = 108, name = "Wool Bandage", count = 2, tip = "Requires First Aid (80)\nUse: Heals 161 damage over 7 sec." },
    { id = 109, name = "Lesser Healing Potion", count = 1, tip = "Requires Level 3\nUse: Restores 140 to 180 health." },
    { id = 110, name = "Healing Potion", count = 2, tip = "Requires Level 12\nUse: Restores 280 to 360 health." },
    { id = 111, name = "Mana Potion", count = 3, tip = "Requires Level 14\nUse: Restores 280 to 360 mana." },
    { id = 112, name = "Rejuvenation Potion", count = 1, tip = "Use: Restores 70 to 90 mana and health." },
}
refresh()
local A = TO.char.auto
assertEq(A.food and A.food.name, "Mutton Chop", "best food you can eat (Quail needs 35)")
assertEq(A.statfood and A.statfood.name, "Smoked Desert Dumplings", "warrior stat food: Strength")
assertEq(A.bandage and A.bandage.name, "Wool Bandage", "best bandage")
assertEq(A.healing and A.healing.name, "Healing Potion", "best healing potion")
assertEq(A.water, nil, "warriors don't track water")
assertEq(A.mana, nil, "warriors don't track mana potions")
assertEq(A.food.min, 20, "food min 20"); assertEq(A.statfood.min, 10, "stat food min 10"); assertEq(A.healing.min, 5, "potion min 5")
local R = ids()
assertEq(R["auto:food"], nil, "30 Mutton Chop >= 20: topped off")
assertEq(R["auto:bandage"].text, "2/20", "bandage count")
assertEq(R["auto:healing"].ownItem, true, "auto items sit with your own items")
-- Stat focus override
TO:SetStatFocus("sta"); refresh()
assertEq(TO.char.auto.statfood.name, "Spiced Wolf Meat", "Stamina focus picks the Stamina food")
TO:SetStatFocus(nil); refresh()
assertEq(TO.char.auto.statfood.name, "Smoked Desert Dumplings", "back to class default")
-- Run out of the best: the next best in your bags is shown and used, and the best is still what's tracked
A = TO.char.auto
local function takeOut(id)
    for i, e in ipairs(STATE.bags) do
        if e.id == id then return table.remove(STATE.bags, i) end
    end
end
local wool = takeOut(108); refresh()
assertEq(A.bandage.name, "Wool Bandage", "still tracked when you run out (it's what a vendor restocks)")
R = ids()
assertEq(R["auto:bandage"].label, "Heavy Linen Bandage", "the next best in your bags takes its place")
assertEq(R["auto:bandage"].text, "12/20", "with its own count")
assertEq(R["auto:bandage"].action.use, "item:107", "and a click uses it")
assert(R["auto:bandage"].detail:find("Out of Wool Bandage", 1, true), "the tooltip says why")
local needs = {}
for _, n in ipairs(TO:RestockNeeds()) do needs[n.label] = n.need end
assertEq(needs["Wool Bandage"], 20, "a vendor would still restock the better one")
assertEq(needs["Heavy Linen Bandage"], nil, "not the stand-in")
local linen = takeOut(107); refresh()
assertEq(ids()["auto:bandage"].label, "Wool Bandage", "none of any kind: the tracked one")
assertEq(ids()["auto:bandage"].text, "0/20", "shows 0 so you restock")
assertEq(ids()["auto:bandage"].action, nil, "nothing to click")
table.insert(STATE.bags, linen); refresh()
assertEq(ids()["auto:bandage"].label, "Heavy Linen Bandage", "back to the next best when you pick some up")
table.insert(STATE.bags, wool); refresh()
assertEq(ids()["auto:bandage"].label, "Wool Bandage", "and to the best when you have it again")
assertEq(ids()["auto:bandage"].text, "2/20", "with its count")
takeOut(108); refresh()
-- Level up: better food takes over, custom Min kept
A.food.min = 40
STATE.level = 35; refresh()
assertEq(A.food.name, "Roasted Quail", "better food replaces the old one")
assertEq(A.food.min, 40, "your Min is kept")
-- Uncheck = stop tracking
TO:SetEnabled("auto:healing", false); refresh()
assertEq(ids()["auto:healing"], nil, "unchecked slot hidden")
TO:SetEnabled("auto:healing", true)
-- Items you added yourself aren't shown twice
TO:AddCustom("Healing Potion", 5); refresh()
local n = 0
for _, r in ipairs(TO.reminders) do if r.label == "Healing Potion" then n = n + 1 end end
assertEq(n, 1, "no duplicate icon")
TO:RemoveCustom("Healing Potion")
-- Mana users track water and mana potions
STATE.class = "PRIEST"; TO.char.auto = {}; refresh()
assertEq(TO.char.auto.water.name, "Melon Juice", "priest water")
assertEq(TO.char.auto.mana.name, "Mana Potion", "priest mana potion (rejuvenation skipped)")
assertEq(TO.char.auto.statfood.name, "Spiced Wolf Meat", "priest has no mp5/int food here: best of the rest")
table.insert(STATE.bags, { id = 120, name = "Nightfin Soup", count = 4, tip = "Requires Level 35\nUse: Restores 874 health over 27 sec."
    .. EAT .. " If you spend at least 10 seconds eating you will become well fed and restore 8 mana every 5 seconds for 10 min." })
STATE.level = 40; TO.char.auto = {}; refresh()
assertEq(TO.char.auto.statfood.name, "Nightfin Soup", "priest: mana regen food")
table.insert(STATE.bags, { id = 121, name = "Golden Fish Sticks", count = 4, tip = "Requires Level 35\nUse: Restores 1000 health over 27 sec."
    .. EAT .. " If you spend at least 10 seconds eating you will become well fed and gain up to 44 bonus healing and 20 Spirit for 30 min." })
table.insert(STATE.bags, { id = 122, name = "Blackened Basilisk", count = 4, tip = "Requires Level 35\nUse: Restores 1000 health over 27 sec."
    .. EAT .. " If you spend at least 10 seconds eating you will become well fed and gain 23 spell damage and 20 Spirit for 30 min." })
TO.char.auto = {}; refresh()
assertEq(TO.char.auto.statfood.name, "Golden Fish Sticks", "priest prefers healing food")
STATE.class = "MAGE"; TO.char.auto = {}; refresh()
assertEq(TO.char.auto.statfood.name, "Blackened Basilisk", "mage prefers spell power food")
STATE.class = "PRIEST"
TO:SetStatFocus("sp"); refresh()
assertEq(TO.char.auto.statfood.name, "Blackened Basilisk", "Spell power override")
TO:SetStatFocus(nil)
-- Hybrids follow their talents
STATE.talents = { { "Discipline", 5 }, { "Holy", 0 }, { "Shadow", 31 } }; refresh()
assertEq(TO.char.auto.statfood.name, "Blackened Basilisk", "shadow priest: spell power food")
STATE.talents = { { "Discipline", 21 }, { "Holy", 30 }, { "Shadow", 0 } }; refresh()
assertEq(TO.char.auto.statfood.name, "Golden Fish Sticks", "holy priest: healing food")
STATE.class = "SHAMAN"
STATE.talents = { { "Elemental", 0 }, { "Enhancement", 31 }, { "Restoration", 5 } }
table.insert(STATE.bags, { id = 123, name = "Smoked Desert Dumplings", count = 2, tip = "Requires Level 35\nUse: Restores 1392 health over 27 sec."
    .. EAT .. " If you spend at least 10 seconds eating you will become well fed and gain 20 Strength for 15 min." })
refresh()
assertEq(TO.char.auto.statfood.name, "Smoked Desert Dumplings", "enhancement shaman: Strength food")
STATE.talents = { { "Elemental", 31 }, { "Enhancement", 0 }, { "Restoration", 5 } }; refresh()
assertEq(TO.char.auto.statfood.name, "Blackened Basilisk", "elemental shaman: spell power food")
STATE.talents = nil; STATE.roles = { player = "HEALER" }; refresh()
assertEq(TO.char.auto.statfood.name, "Golden Fish Sticks", "no talents: group role (healer)")
STATE.roles = {}; STATE.class = "PRIEST"; refresh()
assertEq(TO.char.auto.statfood.name, "Golden Fish Sticks", "no talents or role: class default (healing)")
-- Options window lists them
TO:OpenConfig()
TO:BuildChecksList()
STATE.class = "MAGE"; TO.char.auto = {}; STATE.bags = {}; STATE.level = nil; refresh()
step("expiring buff borders")
STATE.class = "MAGE"; TO.char.checks = {}; TO.db.warnMinutes = 5
LEARN("Arcane Intellect"); fire("SPELLS_CHANGED"); TO.db.onlyInInstance = false
local function aiButton()
    for _, b in ipairs(TO.buttons) do
        if b.reminder and b.reminder.id == "buff:intellect" then return b end
    end
end
STATE.buffs = { ["Arcane Intellect"] = 200 }; refresh()      -- 3:20 left, warn at 5:00
assert(aiButton(), "expiring buff shown")
assertEq(aiButton().urgency, "expiring", "orange at the warning time")
STATE.buffs = { ["Arcane Intellect"] = 50 }; refresh()       -- under 20% of 5:00 (60 s)
assertEq(aiButton().urgency, "urgent", "red in the last 20%")
STATE.buffs = {}; refresh()
assertEq(aiButton().urgency, nil, "missing buff: normal border")
TO.db.warnMinutes = 3
step("well fed")
STATE.class = "DRUID"; TO.char.checks = {}; TO.db.onlyInInstance = false; TO.db.warnMinutes = 3
TO.char.auto = {}; TO.char.custom = {}; STATE.level = 30; TO.char.wellFedInstanceOnly = true
STATE.bags = { { id = 104, name = "Spiced Wolf Meat", count = 6, tip = "Requires Level 5\nUse: Restores 61 health over 15 sec."
    .. " Must remain seated while eating. If you spend at least 10 seconds eating you will become well fed and gain 2 Stamina and Spirit for 15 min." } }
STATE.buffs = {}
STATE.instance = false; refresh()
assertEq(ids().wellfed, nil, "only in dungeons by default")
STATE.instance = true; refresh()
local wf = ids().wellfed
assert(wf, "Well Fed missing in a dungeon")
assertEq(wf.action and wf.action.use, "item:104", "click eats the stat food")
local wfb
for _, b in ipairs(TO.buttons) do if b.reminder == wf then wfb = b end end
assertEq(wfb.__attrs.type, "item", "secure item use")
assertEq(TO:IsBuffReminder(wf), true, "Well Fed sits on the buff row")
STATE.buffs = { ["Well Fed"] = 600 }; refresh()
assertEq(ids().wellfed, nil, "fed: no reminder")
STATE.buffs = { ["Well Fed"] = 30 }; refresh()
assertEq(ids().wellfed.expires, 30, "running out")
STATE.buffs = { ["Food"] = 10 }; refresh()
assertEq(ids().wellfed, nil, "eating right now: no reminder")
STATE.buffs = {}; STATE.bags = {}; refresh()
assertEq(ids().wellfed.noItem, "Spiced Wolf Meat", "no food in bags: greyed, names the food")
TO.char.wellFedInstanceOnly = false; STATE.instance = false; refresh()
assert(ids().wellfed, "shown everywhere when turned on")
TO:SetEnabled("wellfed", false); refresh()
assertEq(ids().wellfed, nil, "turned off")
TO:SetEnabled("wellfed", true); TO.char.wellFedInstanceOnly = true
STATE.class = "MAGE"; TO.char.auto = {}; STATE.level = nil; refresh()
step("party buffs")
STATE.class = "PRIEST"; SPELLBOOK, FUTURE = {}, {}
LEARN("Power Word: Fortitude", "Inner Fire", "Divine Spirit"); fire("SPELLS_CHANGED")
TO.char.checks = {}; TO.db.onlyInInstance = false; STATE.bags = {}
STATE.buffs = { ["Power Word: Fortitude"] = 1800, ["Inner Fire"] = 600, ["Divine Spirit"] = 1800 }
STATE.party = { "party1", "party2", "party3" }
STATE.partyBuffs = { party1 = { ["Power Word: Fortitude"] = 900, ["Divine Spirit"] = 900 },
    party2 = { ["Prayer of Fortitude"] = 900 }, party3 = {} }
STATE.outOfRange = { party3 = true }
refresh()
local pf = ids()["party:fortitude"]
assertEq(pf and pf.text, "1", "one party member missing Fortitude")
assertEq(pf.action, nil, "the one missing it is out of range: no click")
STATE.outOfRange = {}; refresh()
pf = ids()["party:fortitude"]
assertEq(pf.action.unit, "party3", "click buffs the member missing it")
local pbtn
for _, b in ipairs(TO.buttons) do if b.reminder == pf then pbtn = b end end
assertEq(pbtn.__attrs.unit, "party3", "secure button targets that member")
assertEq(pbtn.__attrs.spell, "Power Word: Fortitude", "and casts the buff")
assertEq(ids()["party:spirit"].text, "2", "Divine Spirit missing on two")
assertEq(TO:IsBuffReminder(pf), true, "party buffs on the buff row")
STATE.hiddenAuras = { party3 = true }; refresh()
assertEq(ids()["party:fortitude"], nil, "hidden auras: can't tell, don't nag")
STATE.hiddenAuras = {}
TO:SetEnabled("party:fortitude", false); refresh()
assertEq(ids()["party:fortitude"], nil, "party check turned off")
TO:SetEnabled("party:fortitude", true)
STATE.party = {}; refresh()
assertEq(ids()["party:spirit"], nil, "solo: no party check")

step("elixirs and flasks")
STATE.buffs = { ["Power Word: Fortitude"] = 1800, ["Inner Fire"] = 600, ["Divine Spirit"] = 1800 }
STATE.bags = { { id = 301, name = "Elixir of the Mongoose", count = 3, spell = "Elixir of the Mongoose" },
    { id = 302, name = "Flask of Distilled Wisdom", count = 1, spell = "Distilled Wisdom" },
    { id = 303, name = "Heavy Linen Bandage", count = 10 } }
refresh()
local found = TO:BagElixirs()
assertEq(#found, 2, "elixirs and flasks in bags found")
TO.char.elixirs = {}
TO:TrackElixir("Flask of Distilled Wisdom", true)
STATE.instance = true; refresh()
local fl = ids()["elixir:flask of distilled wisdom"]
assert(fl, "tracked flask missing")
assertEq(fl.action.use, "item:302", "click drinks the flask")
STATE.buffs["Distilled Wisdom"] = 3600; refresh()
assertEq(ids()["elixir:flask of distilled wisdom"], nil, "flask buff found by its spell name")
STATE.buffs["Distilled Wisdom"] = 60; refresh()
assertEq(ids()["elixir:flask of distilled wisdom"].expires, 60, "flask running out")
STATE.instance = false; refresh()
assertEq(ids()["elixir:flask of distilled wisdom"], nil, "only in dungeons by default")
TO:TrackElixir("Flask of Distilled Wisdom", false)
assertEq(#TO.char.elixirs, 0, "untracked")

step("pets")
STATE.class = "HUNTER"; SPELLBOOK, FUTURE = {}, {}
LEARN("Call Pet", "Revive Pet", "Feed Pet"); fire("SPELLS_CHANGED")
TO.char.checks = {}; STATE.buffs = {}; STATE.bags = {}; STATE.pet = nil
refresh()
local ps = ids()["pet:summon"]
assert(ps, "no pet out")
assertEq(ps.action.macro, "/cast [@pet,dead] Revive Pet; [nopet] Call Pet", "calls or revives")
STATE.resting = true; refresh()
assertEq(ids()["pet:summon"], nil, "not in towns and inns")
STATE.resting = false; STATE.mounted = true; refresh()
assertEq(ids()["pet:summon"], nil, "not while mounted")
STATE.mounted = false; STATE.pet = "dead"; refresh()
assertEq(ids()["pet:summon"].label, "Pet is dead", "dead pet")
STATE.pet = "alive"; STATE.happiness = 3; refresh()
assertEq(ids()["pet:summon"], nil, "pet out")
assertEq(ids()["pet:happy"], nil, "happy pet")
STATE.happiness = 1; refresh()
local ph = ids()["pet:happy"]
assertEq(ph.label, "Pet is unhappy", "unhappy pet")
assertEq(ph.action.macro, "/cast Feed Pet", "no food set: just Feed Pet")
TO.char.petFood = "Roasted Quail"
STATE.bags = { { id = 401, name = "Roasted Quail", count = 4 } }
refresh()
assertEq(ids()["pet:happy"].action.macro, "/cast Feed Pet\n/use Roasted Quail", "one-click feeding")
assertEq(ids()["pet:food"].text, "4/20", "pet food count")
assertEq(TO:IsBuffReminder(ids()["pet:food"]), false, "pet food on the top-off row")
TO.char.petFood = ""; STATE.happiness = nil; STATE.pet = nil
STATE.class = "WARLOCK"; SPELLBOOK, FUTURE = {}, {}
LEARN("Summon Imp", "Summon Voidwalker", "Drain Soul", "Create Soulstone (Lesser)", "Demon Skin"); fire("SPELLS_CHANGED")
refresh()
assertEq(ids()["pet:summon"].action.spell, "Summon Imp", "warlock summons first demon")
TO.char.prefs.pet = "Summon Voidwalker"; refresh()
assertEq(ids()["pet:summon"].action.spell, "Summon Voidwalker", "preferred demon")

step("soulstone")
STATE.pet = "alive"; STATE.party = { "party1", "party2" }
STATE.partyBuffs = { party1 = {}, party2 = {} }; STATE.roles = { party2 = "HEALER" }
STATE.instance = true
STATE.bags = { { id = 501, name = "Lesser Soulstone", count = 1 } }
refresh()
local ss = ids().soulstone
assert(ss, "no soulstone in group")
assertEq(ss.action.macro, "/use [@party2,help,nodead] Lesser Soulstone", "soulstone on the healer")
STATE.partyBuffs.party2 = { ["Soulstone Resurrection"] = 1800 }; refresh()
assertEq(ids().soulstone, nil, "healer has one")
STATE.partyBuffs.party2 = {}; STATE.bags = {}; refresh()
assertEq(ids().soulstone.action.spell, "Create Soulstone (Lesser)", "none in bags: make one")
STATE.instance = false; refresh()
assertEq(ids().soulstone, nil, "only in dungeons by default")
STATE.party = {}; STATE.roles = {}; STATE.pet = nil

step("bag space")
STATE.class = "MAGE"; SPELLBOOK, FUTURE = {}, {}; fire("SPELLS_CHANGED")
STATE.freeSlots = 2; refresh()
local bs = ids().bags
assertEq(bs and bs.text, "2", "low bag space")
assertEq(TO:IsBuffReminder(bs), false, "bag space on the top-off row")
assertEq(bs.openBags, nil, "bag icon doesn't open bags (that tainted the bag windows)")
STATE.freeSlots = 10; refresh()
assertEq(ids().bags, nil, "enough space")
STATE.freeSlots = nil
step("stat food override menu")
local menu
MenuUtil = { CreateContextMenu = function(owner, fn)
    menu = { radios = {} }
    local root = { CreateTitle = function() end,
        CreateRadio = function(_, text, isSel, onSel) menu.radios[#menu.radios + 1] = { text = text, isSel = isSel, onSel = onSel } end }
    fn(owner, root)
end }
STATE.class = "PALADIN"; STATE.talents = { { "Holy", 0 }, { "Protection", 31 }, { "Retribution", 5 } }
TO.char.statFocus = nil
TO:OpenConfig(); TO:ShowOptionsTab("supplies")
local fbtn
for _, f in ipairs(ALL_FRAMES) do
    if f.__kind == "Button" and f.__shown ~= false and f:IsVisible() and type(f.__text) == "string"
        and f.__text:find("^Tank: Stamina") then fbtn = f end
end
assert(fbtn, "stat food button shows the automatic pick for a Protection Paladin")
fbtn.__scripts.OnClick(fbtn)
assert(menu and #menu.radios == #TO.STAT_KEYS + 1, "menu lists Automatic plus every stat")
assertEq(menu.radios[1].isSel(), true, "Automatic selected")
for _, r in ipairs(menu.radios) do if r.text == "Strength" then r.onSel() end end
assertEq(TO.char.statFocus, "str", "Strength picked")
assertEq(fbtn.__text, "Strength (your pick)", "button shows your pick")
assertEq(TO:StatPriority()[1], "str", "Strength food first")
fbtn.__scripts.OnClick(fbtn); menu.radios[1].onSel()
assertEq(TO.char.statFocus, nil, "back to Automatic")
TO:OpenConfig(); MenuUtil = nil; STATE.talents = nil
step("party blessings")
STATE.class = "PALADIN"; SPELLBOOK, FUTURE = {}, {}
LEARN("Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Devotion Aura"); fire("SPELLS_CHANGED")
TO.char.checks = {}; TO.char.blessings = {}; STATE.bags = {}
STATE.buffs = { ["Blessing of Kings"] = 300, ["Devotion Aura"] = 0 }
STATE.party = { "party1", "party2", "party3", "party4" }
STATE.partyClass = { party1 = "WARRIOR", party2 = "MAGE", party3 = "HUNTER", party4 = "ROGUE" }
STATE.partyBuffs = { party1 = {}, party2 = { ["Blessing of Wisdom"] = 300 }, party3 = {},
    party4 = { ["Greater Blessing of Might"] = 900 } }
refresh()
local pb = ids()["party:blessing"]
assertEq(pb and pb.text, "2", "warrior and hunter missing their blessings")
assertEq(pb.action.spell, "Blessing of Might", "warrior gets Might")
assertEq(pb.action.unit, "party1", "on the warrior")
assertEq(TO:BlessingFor("HUNTER"), "Blessing of Wisdom", "hunters default to Wisdom")
-- Per-class choice
TO.char.blessings.WARRIOR = "Kings"; refresh()
assertEq(ids()["party:blessing"].action.spell, "Blessing of Kings", "warriors set to Kings")
TO.char.blessings.WARRIOR = "none"; refresh()
assertEq(ids()["party:blessing"].action.spell, "Blessing of Wisdom", "warriors skipped: hunter next")
assertEq(ids()["party:blessing"].action.unit, "party3", "on the hunter")
TO.char.blessings.HUNTER = "Kings"; STATE.partyBuffs.party3 = { ["Blessing of Kings"] = 300 }; refresh()
assertEq(ids()["party:blessing"], nil, "everyone blessed")
-- Not learned: falls back
TO.char.blessings.MAGE = "Salvation"
assertEq(TO:BlessingFor("MAGE"), "Blessing of Wisdom", "unlearned choice falls back to Wisdom")
-- Hidden class: skipped
STATE.partyClass.party1 = "hidden"; TO.char.blessings.WARRIOR = nil; refresh()
assertEq(ids()["party:blessing"], nil, "hidden class skipped")
-- Options rows
TO:OpenConfig(); TO:ShowOptionsTab("buffs"); TO:OpenConfig()
STATE.party = {}; STATE.partyClass = {}; TO.char.blessings = {}
step("separate checks outside dungeons")
STATE.class = "MAGE"; SPELLBOOK, FUTURE = {}, {}
LEARN("Arcane Intellect", "Ice Armor"); fire("SPELLS_CHANGED")
TO.char.checks, TO.char.checksOutside = {}, {}; TO.db.onlyInInstance = false
STATE.buffs = {}; STATE.bags = {}; STATE.party = {}
TO.char.splitProfiles = true
TO:SetEnabled("buff:armor", false, true)          -- off outside only
STATE.instance = false; refresh()
assertEq(ids()["buff:armor"], nil, "armor off outside")
assert(ids()["buff:intellect"], "intellect follows the dungeon set outside")
STATE.instance = true; refresh()
assert(ids()["buff:armor"], "armor on in dungeons")
TO.char.splitProfiles = false; STATE.instance = false; refresh()
assert(ids()["buff:armor"], "one set again when turned off")
TO.char.checksOutside = {}

step("whole raid")
STATE.class = "PRIEST"; SPELLBOOK, FUTURE = {}, {}
LEARN("Power Word: Fortitude"); fire("SPELLS_CHANGED")
STATE.buffs = { ["Power Word: Fortitude"] = 1800 }
STATE.raid = { "raid1", "raid2", "raid3", "raid4", "raid5", "raid6" }; STATE.raidMe = "raid1"
STATE.party = { "party1" }
STATE.partyBuffs = { party1 = { ["Power Word: Fortitude"] = 900 }, raid2 = {}, raid3 = {},
    raid4 = { ["Prayer of Fortitude"] = 900 }, raid5 = {}, raid6 = {} }
refresh()
assertEq(ids()["party:fortitude"], nil, "raid, whole-raid off: only your group (all buffed)")
TO.char.wholeRaid = true; refresh()
local rf = ids()["party:fortitude"]
assertEq(rf and rf.text, "4", "whole raid: four missing (you're skipped)")
assertEq(rf.label, "Power Word: Fortitude (raid)", "labelled raid")
TO.char.wholeRaid = false; STATE.raid = nil; STATE.raidMe = nil; STATE.party = {}

step("mage conjures")
STATE.class = "MAGE"; SPELLBOOK, FUTURE = {}, {}
LEARN("Arcane Intellect", "Conjure Water", "Conjure Food", "Conjure Mana Jade", "Conjure Mana Agate"); fire("SPELLS_CHANGED")
TO.char.checks = {}; TO.char.auto = {}
STATE.buffs = { ["Arcane Intellect"] = 1800 }
STATE.bags = { { id = 601, name = "Conjured Sparkling Water", count = 5,
    tip = "Use: Restores 2934 mana over 27 sec. Must remain seated while drinking." },
    { id = 602, name = "Conjured Sourdough", count = 30, tip = "Use: Restores 874 health over 27 sec. Must remain seated while eating." } }
refresh()
local cw = ids()["conjure:water"]
assertEq(cw and cw.text, "5/20", "conjured water low")
assertEq(cw.action.spell, "Conjure Water", "click conjures water")
assertEq(ids()["conjure:food"], nil, "30 conjured food is enough")
assertEq(TO.char.auto.water, nil, "conjured water isn't auto-tracked (can't buy it)")
assertEq(ids()["conjure:gem"].action.spell, "Conjure Mana Jade", "best mana gem")
table.insert(STATE.bags, { id = 603, name = "Mana Jade", count = 1 }); refresh()
assertEq(ids()["conjure:gem"], nil, "have the gem")

step("healthstones")
STATE.class = "WARLOCK"; SPELLBOOK, FUTURE = {}, {}
LEARN("Demon Skin", "Create Healthstone (Lesser)", "Create Healthstone (Minor)"); fire("SPELLS_CHANGED")
STATE.bags = {}; STATE.buffs = { ["Demon Skin"] = 0 }; STATE.pet = "alive"
refresh()
assertEq(ids().healthstone.action.spell, "Create Healthstone (Lesser)", "warlock: make the best healthstone")
STATE.bags = { { id = 701, name = "Lesser Healthstone", count = 1 } }; refresh()
assertEq(ids().healthstone, nil, "has one")
STATE.class = "WARRIOR"; SPELLBOOK, FUTURE = {}, {}; fire("SPELLS_CHANGED")
STATE.bags = {}; STATE.party = { "party1" }; STATE.partyClass = { party1 = "WARLOCK" }; STATE.partyBuffs = { party1 = {} }
STATE.instance = true; refresh()
local hs = ids().healthstone
assert(hs and hs.detail:find("Ask Name_party1"), "others: ask the warlock in dungeons")
assertEq(hs.action, nil, "nothing to click")
STATE.instance = false; refresh()
assertEq(ids().healthstone, nil, "not outside dungeons")
STATE.partyClass = {}; STATE.party = {}; STATE.pet = nil

step("copy another character")
TO.db.chars["Alt - Forever"] = { class = "PRIEST", settings = { checks = { ["buff:fortitude"] = false },
    custom = { { name = "Morning Glory Dew", min = 15 } }, blessings = { WARRIOR = "Kings" }, statFocus = "spi",
    auto = { food = { name = "X", id = 1, min = 3 } } } }
local others = TO:OtherCharacters()
assertEq(#others >= 1 and others[1].key, "Alt - Forever", "other character listed")
for _, o in ipairs(others) do assert(o.key ~= TO:CharacterKey(), "you're not in the list") end
assert(TO:CopySettingsFrom("Alt - Forever"), "copied")
assertEq(TO.char.checks["buff:fortitude"], false, "checks copied")
assertEq(TO.char.custom[1].name, "Morning Glory Dew", "own items copied")
assertEq(TO.char.blessings.WARRIOR, "Kings", "blessings copied")
assertEq(TO.char.auto.food, nil, "auto picks not copied (re-picked from your bags)")
TO.char.custom[1].min = 99
assertEq(TO.db.chars["Alt - Forever"].settings.custom[1].min, 15, "a copy, not shared")
assertEq(TO:CopySettingsFrom(TO:CharacterKey()), false, "can't copy yourself")
TO.char.checks = {}; TO.char.custom = {}; TO.char.blessings = {}; TO.char.statFocus = nil
TO.db.chars["Alt - Forever"] = nil

step("vendor restock and repair")
STATE.class = "PRIEST"; SPELLBOOK, FUTURE = {}, {}
LEARN("Prayer of Fortitude", "Levitate"); fire("SPELLS_CHANGED")
TO.char.checks = {}; TO.char.auto = {}
STATE.bags = { { id = 801, name = "Sacred Candle", count = 4 },
    { id = 802, name = "Morning Glory Dew", count = 12, tip = "Requires Level 45\nUse: Restores 2934 mana over 30 sec. Must remain seated while drinking." } }
TO:AddCustom("Morning Glory Dew", 20)
STATE.merchant = {
    { name = "Sacred Candle", price = 500 },
    { name = "Light Feather", price = 10 },
    { name = "Morning Glory Dew", price = 400, stack = 5 },
    { name = "Fancy Thing", price = 1, extended = true },
}
STATE.repairCost = 12345
BOUGHT = {}; REPAIRED = false
-- What the vendor sells for gold; things you can't buy (or that cost something else) are left out
STATE.merchant[5] = { name = "Locked Thing", price = 1, purchasable = false }
local sold = {}
for _, m in ipairs(TO:MerchantItems()) do sold[#sold + 1] = m.index .. ":" .. m.name .. ":" .. m.price .. ":" .. m.stack end
assertEq(table.concat(sold, " "), "1:Sacred Candle:500:1 2:Light Feather:10:1 3:Morning Glory Dew:400:5", "vendor items read")
STATE.merchant[5] = nil
fire("MERCHANT_SHOW")
local vp = TO.vendor
assert(vp and vp.__shown, "restock panel shown")
local plan = vp.plan
local byName = {}
for _, row in ipairs(plan) do byName[row.name] = row end
assertEq(byName["Sacred Candle"].count, 6, "candles: 6 to reach 10")
assertEq(byName["Light Feather"].count, 5, "light feathers: 5")
assertEq(byName["Morning Glory Dew"].lots, 2, "dew sold in 5s: 2 stacks for 8 needed")
assertEq(byName["Morning Glory Dew"].count, 10, "dew: 10 bought")
assertEq(byName["Fancy Thing"], nil, "special-currency items skipped")
-- Untick feathers, then Restock
for _, r in ipairs(vp.rows) do
    if r.row and r.row.name == "Light Feather" then r.__scripts.OnClick(r) end
end
vp.buy.__scripts.OnClick(vp.buy)
local got = table.concat(BOUGHT, " ")
assert(got:find("Sacred Candle:6"), "candles bought in one batch: " .. got)
assert(not got:find("Light Feather"), "unticked row skipped")
assert(select(2, got:gsub("Morning Glory Dew:nil", "")) == 2, "dew bought one stack at a time: " .. got)
vp.repair.__scripts.OnClick(vp.repair)
assertEq(REPAIRED, true, "repair all")
-- Not enough money
BOUGHT = {}; STATE.money = 100
TO:BuyRestock({ { index = 1, name = "Sacred Candle", lots = 6, count = 6, cost = 3000, stack = 1 } })
assertEq(#BOUGHT, 0, "can't afford: nothing bought")
STATE.money = 100000
-- Turned off
TO.char.restockAtVendor, TO.char.repairAtVendor = false, false
TO:UpdateVendorPanel()
assertEq(vp.__shown, false, "hidden when both are off")
TO.char.restockAtVendor, TO.char.repairAtVendor = true, true
fire("MERCHANT_CLOSED")
assertEq(vp.__shown, false, "hidden when the vendor closes")
TO:RemoveCustom("Morning Glory Dew"); STATE.merchant = {}; STATE.repairCost = 0; STATE.bags = {}
step("review fixes")
-- Unticked rows stay unticked when the list refreshes
STATE.class = "PRIEST"; SPELLBOOK, FUTURE = {}, {}
LEARN("Prayer of Fortitude", "Levitate"); fire("SPELLS_CHANGED")
TO.char.checks, TO.char.checksOutside, TO.char.auto = {}, {}, {}
STATE.level = 60; STATE.bags = {}; STATE.money = 100000
STATE.merchant = { { name = "Sacred Candle", price = 500 }, { name = "Holy Candle", price = 300 },
    { name = "Light Feather", price = 10 } }
fire("MERCHANT_SHOW")
local vp = TO.vendor
for _, r in ipairs(vp.rows) do
    if r.row and r.row.name == "Light Feather" then r.__scripts.OnClick(r) end
end
fire("BAG_UPDATE_DELAYED")
local fe
for _, r in ipairs(vp.rows) do if r.row and r.row.name == "Light Feather" then fe = r end end
assertEq(fe:IsOn(), false, "switching a row off survives a refresh")
BOUGHT = {}; vp.buy.__scripts.OnClick(vp.buy)
assert(not table.concat(BOUGHT, " "):find("Light Feather"), "unticked row not bought after a refresh")
-- Reagent rank by level
local names = {}
for _, row in ipairs(vp.plan) do names[row.name] = true end
assert(names["Sacred Candle"] and not names["Holy Candle"], "level 60: Sacred Candles")
STATE.level = 50; fire("MERCHANT_SHOW")
names = {}
for _, row in ipairs(TO.vendor.plan) do names[row.name] = true end
assert(names["Holy Candle"] and not names["Sacred Candle"], "level 50: Holy Candles")
-- Restock uses the dungeon set even with separate outside checks
TO.char.splitProfiles = true; TO:SetEnabled("reagent:candle", false, true); STATE.instance = false
fire("MERCHANT_SHOW")
names = {}
for _, row in ipairs(TO.vendor.plan) do names[row.name] = true end
assert(names["Holy Candle"], "candles still restocked (dungeon set)")
TO.char.splitProfiles = false; TO.char.checksOutside = {}
-- Only shown rows are bought
STATE.merchant = {}
for i = 1, 16 do STATE.merchant[i] = { name = "Thing " .. i, price = 1 } end
for i = 1, 16 do TO:AddCustom("Thing " .. i, 1) end
fire("MERCHANT_SHOW")
assertEq(#TO.vendor.plan, 12, "plan capped to the rows shown")
for i = 1, 16 do TO:RemoveCustom("Thing " .. i) end
fire("MERCHANT_CLOSED"); STATE.merchant = {}
-- Mana gems aren't tracked as mana potions
STATE.class = "MAGE"; SPELLBOOK, FUTURE = {}, {}; LEARN("Conjure Mana Citrine"); fire("SPELLS_CHANGED")
TO.char.auto = {}; STATE.level = 60
STATE.bags = { { id = 901, name = "Mana Citrine", count = 1, tip = "Use: Restores 775 to 925 mana." },
    { id = 902, name = "Greater Mana Potion", count = 3, tip = "Requires Level 41\nUse: Restores 700 to 900 mana." } }
refresh()
assertEq(TO.char.auto.mana.name, "Greater Mana Potion", "mana gem isn't the mana potion")
-- Stat food Min survives a stat change
local EAT2 = " Must remain seated while eating."
STATE.class = "WARRIOR"; TO.char.auto = {}
STATE.bags = { { id = 911, name = "Spiced Wolf Meat", count = 3, tip = "Use: Restores 61 health over 15 sec." .. EAT2
    .. " If you spend at least 10 seconds eating you will become well fed and gain 2 Stamina and Spirit for 15 min." } }
refresh()
TO.char.auto.statfood.min = 25
TO:SetStatFocus("spi"); refresh()
assertEq(TO.char.auto.statfood.min, 25, "your stat food Min is kept")
TO:SetStatFocus(nil); TO.char.autoMins = {}
-- Arcane Intellect isn't asked for on Warriors
STATE.class = "MAGE"; SPELLBOOK, FUTURE = {}, {}; LEARN("Arcane Intellect"); fire("SPELLS_CHANGED")
STATE.buffs = { ["Arcane Intellect"] = 1800 }; STATE.bags = {}
STATE.party = { "party1", "party2" }; STATE.partyClass = { party1 = "WARRIOR", party2 = "PRIEST" }
STATE.partyBuffs = { party1 = {}, party2 = {} }
refresh()
local ai = ids()["party:intellect"]
assertEq(ai and ai.text, "1", "only the priest needs Intellect")
assertEq(ai.action.unit, "party2", "click buffs the priest")
STATE.party = {}; STATE.partyClass = {}; STATE.level = nil
step("header right-click menu")
local items = {}
MenuUtil = { CreateContextMenu = function(owner, fn)
    items = {}
    local root = { CreateTitle = function(_, t) items[#items + 1] = { kind = "title", text = t } end,
        CreateCheckbox = function(_, t, isSel, onSel) items[#items + 1] = { kind = "check", text = t, isSel = isSel, onSel = onSel } end,
        CreateButton = function(_, t, fn2) items[#items + 1] = { kind = "button", text = t, fn = fn2 } end }
    fn(owner, root)
end }
local header
for _, f in ipairs(ALL_FRAMES) do
    if f.__scripts.OnMouseUp and f.__scripts.OnDragStart and f.__parent == TO.box then header = f end
end
assert(header, "header found")
TO.db.locked = false
header.__scripts.OnMouseUp(header, "RightButton")
assertEq(items[1].text, "ToppedOff Forever", "menu title")
assertEq(items[2].text, "Lock", "lock checkbox")
assertEq(items[2].isSel(), false, "unlocked")
items[2].onSel()
assertEq(TO.db.locked, true, "locked from the menu")
assertEq(items[3].text, "Settings", "settings button")
if TO.config and TO.config:IsShown() then TO:OpenConfig() end
items[3].fn()
assertEq(TO.config.__shown, true, "settings opened")
items[3].fn()
assertEq(TO.config.__shown, true, "Settings again keeps it open")
TO:OpenConfig(); TO:SetLocked(false); MenuUtil = nil
step("priest racial buffs")
STATE.class = "PRIEST"; SPELLBOOK, FUTURE = {}, {}
LEARN("Power Word: Fortitude", "Inner Fire", "Shadowguard", "Fear Ward"); fire("SPELLS_CHANGED")
TO.char.checks = {}; STATE.party = {}; STATE.bags = {}
STATE.buffs = { ["Power Word: Fortitude"] = 1800, ["Inner Fire"] = 600 }
refresh()
assertEq(ids()["buff:shadowguard"].action.spell, "Shadowguard", "Troll priest: Shadowguard missing")
assertEq(ids()["buff:touchweak"], nil, "no Touch of Weakness if not learned")
assertEq(ids()["buff:fearward"], nil, "Fear Ward off by default")
STATE.buffs.Shadowguard = 400; refresh()
assertEq(ids()["buff:shadowguard"], nil, "Shadowguard up")
-- Options list only the racials you have
TO:OpenConfig(); TO:ShowOptionsTab("buffs")
local sawTouch, sawGuard = false, false
for _, f in ipairs(ALL_FRAMES) do
    if f.__kind == "FontString" and f:IsVisible() and f.__text then
        if f.__text:find("^Touch of Weakness") then sawTouch = true end
        if f.__text:find("^Shadowguard") then sawGuard = true end
    end
end
assert(sawGuard and not sawTouch, "only learned racial buffs listed")
TO:OpenConfig()
step("recipes aren't tracked")
STATE.class = "WARRIOR"; SPELLBOOK, FUTURE = {}, {}; fire("SPELLS_CHANGED")
TO.char.checks, TO.char.auto, TO.char.autoMins = {}, {}, {}
STATE.level = 10; STATE.buffs = {}
STATE.bags = { { id = 950, name = "Recipe: Minor Discolored Healing Potion", count = 1,
    tip = "Use: Teaches you how to make Minor Discolored Healing Potion.\nMinor Discolored Healing Potion\nUse: Restores 70 to 90 health." } }
-- An older version already picked it
TO.char.auto.healing = { name = "Recipe: Minor Discolored Healing Potion", id = 950, score = 80, min = 5 }
refresh()
assertEq(TO.char.auto.healing, nil, "recipe dropped from healing potions")
assertEq(ids()["auto:healing"], nil, "no recipe icon")
assertEq(TO.char.autoMins.healing, 5, "your Min kept")
table.insert(STATE.bags, { id = 951, name = "Minor Healing Potion", count = 3, tip = "Use: Restores 70 to 90 health." })
refresh()
assertEq(TO.char.auto.healing.name, "Minor Healing Potion", "the real potion is tracked")
-- Tracked recipe no longer in bags: dropped too
TO.char.auto.healing = { name = "Recipe: Something", id = 999, score = 80, min = 5 }
refresh()
assertEq(TO.char.auto.healing.name, "Minor Healing Potion", "recipe out of bags dropped")
STATE.bags = {}; STATE.level = nil; TO.char.auto = {}; TO.char.autoMins = {}
step("gear isn't tracked")
STATE.class = "PRIEST"; SPELLBOOK, FUTURE = {}, {}; fire("SPELLS_CHANGED")
TO.char.checks, TO.char.auto, TO.char.autoMins = {}, {}, {}
STATE.level = 30; STATE.buffs = {}
local bucketTip = "Held In Off-hand\nUse: Restores 1344 mana over 24 sec. Must remain seated while drinking."
-- In your bags: an off-hand with a drink effect, and real water that restores less
STATE.bags = {
    { id = 970, name = "Skum's Bucket", count = 1, tip = bucketTip, equipLoc = "INVTYPE_HOLDABLE" },
    { id = 971, name = "Melon Juice", count = 12, tip = "Use: Restores 835 mana over 24 sec. Must remain seated while drinking." },
}
refresh()
assertEq(TO.char.auto.water.name, "Melon Juice", "gear skipped, real water tracked")
-- Only the bucket: nothing tracked
STATE.bags = { STATE.bags[1] }; TO.char.auto = {}
refresh()
assertEq(TO.char.auto.water, nil, "gear alone isn't water")
assertEq(ids()["auto:water"], nil, "no water icon for gear")
-- An older version already picked it, and it's equipped now (not in your bags)
STATE.bags = {}; STATE.gear = { [970] = "INVTYPE_HOLDABLE" }
TO.char.auto.water = { name = "Skum's Bucket", id = 970, score = 1344, min = 20 }
refresh()
assertEq(TO.char.auto.water, nil, "equipped gear dropped from water")
assertEq(ids()["auto:water"], nil, "no icon for dropped gear")
assertEq(TO.char.autoMins.water, 20, "your Min kept")
-- Real water you ran out of stays tracked
TO.char.auto.water = { name = "Melon Juice", id = 971, score = 835, min = 20 }
refresh()
assertEq(TO.char.auto.water.name, "Melon Juice", "water you ran out of stays tracked")
STATE.bags = {}; STATE.gear = nil; STATE.level = nil; TO.char.auto = {}; TO.char.autoMins = {}
step("picked stat food is strict")
STATE.class = "DRUID"; SPELLBOOK, FUTURE = {}, {}; fire("SPELLS_CHANGED")
TO.char.checks, TO.char.auto, TO.char.autoMins = {}, {}, {}
STATE.level = 20; STATE.buffs = {}; STATE.talents = nil
STATE.bags = { { id = 960, name = "Spiced Wolf Meat", count = 8, tip = "Use: Restores 58 health over 18 sec."
    .. " Must remain seated while eating. If you spend at least 10 seconds eating you will become well fed and gain 1 Agility for 15 min." } }
TO:SetStatFocus("agi"); refresh()
assertEq(TO.char.auto.statfood.name, "Spiced Wolf Meat", "Agility picked: Agility food tracked")
TO:SetStatFocus("sta"); refresh()
assertEq(TO.char.auto.statfood, nil, "Stamina picked, only Agility food: nothing tracked")
assertEq(ids()["auto:statfood"], nil, "no stat food icon")
TO:SetStatFocus(nil); refresh()
assertEq(TO.char.auto.statfood.name, "Spiced Wolf Meat", "Automatic falls back to any stat food")
STATE.bags = {}; STATE.level = nil; TO.char.auto = {}
step("passive spells need no reminder")
-- On Forever, Omen of Clarity is a passive: it's in the spellbook, always on, and can't be cast
STATE.class = "DRUID"; SPELLBOOK, FUTURE = {}, {}
TO.char.checks = {}; STATE.buffs = {}
LEARN("Mark of the Wild", "Omen of Clarity")
fire("SPELLS_CHANGED"); refresh()
assert(ids()["buff:omen"], "castable Omen of Clarity (the classic one): reminded when it's missing")
assert(ids()["buff:mark"] or ids()["buff:motw"] or ids()["buff:wild"], "Mark of the Wild reminder")
PASSIVE["Omen of Clarity"] = true
fire("SPELLS_CHANGED"); refresh()
assertEq(ids()["buff:omen"], nil, "passive Omen of Clarity: no reminder")
assertEq(TO:Knows("Omen of Clarity"), true, "it's still a spell you have")
local markStill = false
for id in pairs(ids()) do if id:find("^buff:") then markStill = true end end
assert(markStill, "the castable buffs are still checked")
SlashCmdList.TOPPEDOFFFOREVER("check")
assert(lastLog("Omen of Clarity: passive, always on"), "/topoff check says it's passive, not \"not learned\"")
local function optionsRow(text)
    for _, f in ipairs(ALL_FRAMES) do
        if f.isSwitch and f:IsVisible() and f.label and f.label:GetText() and f.label:GetText():find(text, 1, true) then
            return f
        end
    end
end
TO:OpenConfig(); TO:ShowOptionsTab("buffs")
assert(optionsRow("Mark of the Wild"), "the options list your castable buffs")
assertEq(optionsRow("Omen of Clarity"), nil, "and leave out the passive one")
TO:OpenConfig()
-- A passive that needs a reagent still gets its reagent check (Reincarnation and Ankhs)
STATE.class = "SHAMAN"; SPELLBOOK, FUTURE = {}, {}
TO.char.checks = {}; STATE.bags = {}
LEARN("Reincarnation"); PASSIVE["Reincarnation"] = true
fire("SPELLS_CHANGED"); refresh()
assertEq(ids()["reagent:ankh"] and ids()["reagent:ankh"].text, "0/1", "passive Reincarnation still needs an Ankh")
PASSIVE = {}; SPELLBOOK, FUTURE = {}, {}; STATE.class = "DRUID"; TO.char.checks = {}
fire("SPELLS_CHANGED"); refresh()
step("moving the window and combat")
local dragHeader
for _, f in ipairs(ALL_FRAMES) do
    if f.__scripts.OnMouseUp and f.__scripts.OnDragStart and f.__parent == TO.box then dragHeader = f end
end
assert(dragHeader, "header found")
TO.db.locked = false
-- Out of combat: a drag moves the window and saves where it ends up
TO.main.__left, TO.main.__top = 300, 400
dragHeader.__scripts.OnDragStart(dragHeader)
assertEq(TO.main.__moving, true, "drag starts out of combat")
dragHeader.__scripts.OnDragStop(dragHeader)
assertEq(TO.main.__moving, false, "drag ends")
assertEq(TO.db.point[3], 300, "position saved")
-- In combat: dragging touches nothing protected, and says why
COMBAT = true; BLOCKED = {}
dragHeader.__scripts.OnDragStart(dragHeader)
assert(LOG[#LOG]:find("can't be moved in combat"), "says why it won't move")
dragHeader.__scripts.OnDragStop(dragHeader)
assertEq(#BLOCKED, 0, "dragging in combat touched protected things: " .. table.concat(BLOCKED, ", "))
assertEq(TO.main.__moving, false, "no drag in combat")
COMBAT = false; fire("PLAYER_REGEN_ENABLED"); tick()
-- Combat starts in the middle of a drag: the window is dropped and saved before lockdown
TO.main.__left, TO.main.__top = 500, 600
dragHeader.__scripts.OnDragStart(dragHeader)
fire("PLAYER_REGEN_DISABLED")
assertEq(TO.main.__moving, false, "drag ended as combat starts")
assertEq(TO.db.point[3], 500, "position saved as combat starts")
COMBAT = true; BLOCKED = {}
dragHeader.__scripts.OnDragStop(dragHeader)
assertEq(#BLOCKED, 0, "releasing the mouse in combat touched protected things: " .. table.concat(BLOCKED, ", "))
-- Locked: no drag
COMBAT = false; fire("PLAYER_REGEN_ENABLED"); tick()
TO.db.locked = true
dragHeader.__scripts.OnDragStart(dragHeader)
assertEq(TO.main.__moving, false, "locked window doesn't move")
TO.db.locked = false; TO.main.__left, TO.main.__top = nil, nil
step("blocked-action report")
local mark = #LOG
fire("ADDON_ACTION_FORBIDDEN", "ToppedOffForever", "UseContainerItem()")
assert(LOG[#LOG]:find("WoW blocked UseContainerItem"), "names the blocked function")
fire("ADDON_ACTION_FORBIDDEN", "SomeOtherAddon", "Foo()")
assert(not LOG[#LOG]:find("Foo"), "other addons ignored")
step("hidden auras don't error")
STATE.class = "DRUID"; SPELLBOOK, FUTURE = {}, {}
LEARN("Mark of the Wild", "Thorns"); fire("SPELLS_CHANGED")
TO.char.checks = {}; STATE.bags = {}; STATE.party = { "party1", "party2" }
STATE.partyClass = {}; STATE.partyBuffs = { party1 = { ["Mark of the Wild"] = 900 }, party2 = { ["Thorns"] = 500 } }
STATE.buffs = { ["Mark of the Wild"] = 1800, ["Thorns"] = 500 }
refresh()
local th = ids()["party:thorns"]
assertEq(th and th.text, "1", "Thorns on the party: one missing")
assertEq(th.action.unit, "party1", "click thorns the one missing it")
STATE.aurasLocked = true
refresh()   -- must not error
assertEq(TO.buffs["thorns"] ~= nil, true, "last readable buffs kept")
assertEq(ids()["party:thorns"], nil, "party auras hidden: no guessing")
STATE.aurasLocked = false; STATE.party = {}
step("errors reported once")
local reported = 0
geterrorhandler = function() return function() reported = reported + 1 end end
local real = TO.CheckDurability
TO.CheckDurability = function() error("boom") end
refresh(); refresh(); refresh()
assertEq(reported, 1, "same error reported once")
TO.CheckDurability = real; geterrorhandler = nil
refresh()
step("stat food: Automatic falls back to any stat food, even one that loads late")
STATE.class = "PALADIN"; STATE.level = 30; STATE.talents = nil; STATE.roles = {}; STATE.buffs = {}
TO.char.auto = {}; TO.char.statFocus = nil
STATE.uncached = { [130] = true }
STATE.bags = {
    { id = 130, name = "Spiced Wolf Meat", count = 7, tip = "Use: Restores 58 health over 18 sec. Must remain seated while eating."
        .. " If you spend at least 10 seconds eating you will become well fed and gain 1 Agility for 15 min."
        .. " Additionally, experience gained from kills is increased by 5%. (1 Sec Cooldown)" },
}
refresh()
assertEq(TO:AutoStatPriority()[1], "sta", "paladin with no role: Stamina first")
assertEq(TO.char.auto.statfood, nil, "not loaded yet: not judged")
assertEq(STATE.requested and STATE.requested[130], true, "asked the game to load it")
STATE.uncached = nil
fire("GET_ITEM_INFO_RECEIVED", 130, true)
tick()
assertEq(TO.char.auto.statfood and TO.char.auto.statfood.name, "Spiced Wolf Meat", "Agility food is the fallback for Stamina")
step("supplies are found after a fresh login, when their tooltips fill in late")
-- Right after logging in, the game has the items but not yet the text of what
-- they do ("Use: ..."). They mustn't be written off as nothing.
STATE.class = "PRIEST"; STATE.level = 20; STATE.buffs = {}; STATE.uncached = nil
TO.char.auto = {}; TO.char.custom = {}; TO.char.customAlways = true
STATE.bags = {
    { id = 150, name = "Lesser Healing Potion", count = 1, tip = "Requires Level 3\nUse: Restores 140 to 180 health." },
    { id = 151, name = "Minor Healing Potion", count = 4, tip = "Use: Restores 70 to 90 health." },
    { id = 152, name = "Lesser Mana Potion", count = 1, tip = "Requires Level 14\nUse: Restores 140 to 180 mana." },
    { id = 153, name = "Melon Juice", count = 25, tip = "Requires Level 15\nUse: Restores 835 mana over 27 sec. Must remain seated while drinking." },
    { id = 154, name = "Strange Dust", count = 3, tip = "Crafting Reagent" },
}
-- 1. The game says the use text is still loading: wait for it
STATE.spellsLoading = { [150] = true, [151] = true, [152] = true, [153] = true }
refresh()
assertEq(TO.char.auto.healing, nil, "not judged while its use text is loading")
assertEq(STATE.requestedSpells and STATE.requestedSpells[50150], true, "asked the game to load it")
STATE.spellsLoading = nil
FAKE_TIME = FAKE_TIME + 5; tick()   -- (nothing announces it; the bags are looked at every few seconds)
assertEq(TO.char.auto.healing and TO.char.auto.healing.name, "Lesser Healing Potion", "found once it has loaded")
assertEq(TO.char.auto.mana and TO.char.auto.mana.name, "Lesser Mana Potion", "mana potion too")
assertEq(TO.char.auto.water and TO.char.auto.water.name, "Melon Juice", "and water")
-- 2. The game says everything is loaded, but the tooltip is still missing that line
TO.char.auto = {}
STATE.bags[1].id, STATE.bags[2].id, STATE.bags[3].id, STATE.bags[4].id = 160, 161, 162, 163   -- (items not seen before)
STATE.thinTooltips = { [160] = true, [161] = true, [162] = true, [163] = true }
refresh()
assertEq(TO.char.auto.healing, nil, "nothing to go on yet")
STATE.thinTooltips = nil
FAKE_TIME = FAKE_TIME + 5; tick()
assertEq(TO.char.auto.healing and TO.char.auto.healing.name, "Lesser Healing Potion", "found once the tooltip is complete")
assertEq(TO.char.auto.water and TO.char.auto.water.name, "Melon Juice", "water too")
assertEq(ids()["auto:healing"].text, "1/5", "and shown")
-- An item that really is nothing to track stops being re-read after a while
for _ = 1, 30 do FAKE_TIME = FAKE_TIME + 5; tick() end
STATE.tooltipReads = 0
for _ = 1, 6 do FAKE_TIME = FAKE_TIME + 5; tick() end
assertEq(STATE.tooltipReads, 0, "settled: no tooltip is read again")

step("out of your best potion: the next best in your bags")
STATE.bags[1].count = 0
table.remove(STATE.bags, 1)   -- you drank the Lesser Healing Potion
refresh()
assertEq(TO.char.auto.healing.name, "Lesser Healing Potion", "the better potion is still the one tracked")
assertEq(ids()["auto:healing"].label, "Minor Healing Potion", "but the one you have is shown")
assertEq(ids()["auto:healing"].text, "4/5", "with its count")
assertEq(ids()["auto:healing"].action.use, "item:161", "and used when you click")
TO.db.shown = true; TO.db.hideInCombat = true; TO.db.combatBar = true; TO.db.onlyInInstance = false
TO:ApplySettings(); refresh()
assertEq(TO.combat.buttons[1]:GetAttribute("item"), "item:161", "the combat bar has it too")
-- You also track Minor Healing Potion yourself: it isn't shown a second time
TO:AddCustom("Minor Healing Potion", 5); refresh()
local shownTimes = 0
for _, r in ipairs(TO.reminders) do if r.label == "Minor Healing Potion" then shownTimes = shownTimes + 1 end end
assertEq(shownTimes, 1, "no duplicate icon")
assertEq(ids()["auto:healing"].label, "Lesser Healing Potion", "the tracked one shows as out")
TO:RemoveCustom("Minor Healing Potion")
TO.char.customAlways = false

step("combat bar: potions, Healthstone and bandage stay in combat")
STATE.class = "PRIEST"; STATE.level = 40; STATE.buffs = {}; STATE.uncached = nil
TO.db.shown = true; TO.db.hideInCombat = true; TO.db.combatBar = true; TO.db.onlyInInstance = false
TO.char.auto = {}; TO.char.custom = {}
local EAT2 = " Must remain seated while eating."
STATE.bags = {
    { id = 140, name = "Haunch of Meat", count = 12, tip = "Use: Restores 243 health over 21 sec." .. EAT2 },
    { id = 141, name = "Healing Potion", count = 3, tip = "Use: Restores 280 to 360 health." },
    { id = 142, name = "Mana Potion", count = 2, tip = "Use: Restores 280 to 360 mana." },
    { id = 143, name = "Healthstone", count = 1, tip = "Use: Instantly restores 500 health." },
    { id = 144, name = "Heavy Linen Bandage", count = 8, tip = "Use: Heals 114 damage over 6 sec." },
}
TO:ApplySettings(); refresh()
local CB = TO.combat
assertEq(CB.__driver, "[combat] show; hide", "combat bar shows only in combat")
assertEq(CB.count, 4, "healing potion, mana potion, Healthstone, bandage")
local function cbItem(i) return CB.buttons[i]:GetAttribute("item") end
assertEq(cbItem(1), "item:141", "healing potion first")
assertEq(cbItem(2), "item:142", "then mana potion")
assertEq(cbItem(3), "item:143", "then Healthstone")
assertEq(cbItem(4), "item:144", "then bandage")
assertEq(CB.buttons[1]:GetAttribute("type"), "item", "click uses the item")
assertEq(CB.buttons[1].text:GetText(), 3, "count shown")
-- In combat: counts update, nothing protected is touched
COMBAT = true; BLOCKED = {}
fire("PLAYER_REGEN_DISABLED")
STATE.bags[2].count = 2
fire("BAG_UPDATE_DELAYED")
STATE.itemCD = { [141] = 1000 }
fire("BAG_UPDATE_COOLDOWN")
tick()
assertEq(#BLOCKED, 0, "combat bar touched protected things in combat: " .. table.concat(BLOCKED, ", "))
assertEq(CB.buttons[1].text:GetText(), 2, "count updates in combat")
table.remove(STATE.bags, 3)   -- drank the last mana potion
fire("BAG_UPDATE_DELAYED")
assertEq(CB.buttons[2].text:GetText(), 0, "used up")
assertEq(CB.buttons[2].icon.__desat, true, "used up: greyed out")
COMBAT = false; fire("PLAYER_REGEN_ENABLED"); tick(); STATE.itemCD = nil
assertEq(CB.count, 3, "after combat the bar is rebuilt without the used-up potion")
-- Warriors: no mana potion; settings that turn it off
STATE.class = "WARRIOR"; TO.char.auto = {}; refresh()
for i = 1, CB.count do assert(cbItem(i) ~= "item:142", "warriors don't get mana potions") end
TO.db.combatBar = false; TO:ApplySettings(); refresh()
assertEq(CB.__driver, "hide", "combat bar off")
TO.db.combatBar = true; TO.db.hideInCombat = false; TO:ApplySettings(); refresh()
assertEq(CB.__driver, "hide", "not needed when the reminders stay in combat")
TO.db.hideInCombat = true; STATE.bags = {}; TO:ApplySettings(); refresh()
assertEq(CB.__driver, "hide", "nothing to show")
step("settings changed in combat are applied once")
STATE.class = "WARRIOR"; TO.char.auto = {}; TO.db.combatBar = true; TO.db.hideInCombat = true; refresh()
COMBAT = true; BLOCKED = {}; fire("PLAYER_REGEN_DISABLED")
local updates, realUpdate = 0, TO.Update
TO.Update = function(...) updates = updates + 1 return realUpdate(...) end
for _ = 1, 25 do TO:ApplySettings() end
SlashCmdList.TOPPEDOFFFOREVER("reset")
assert(lastLog("position will reset when combat ends"), "/topoff reset in combat says it waits")
assertEq(updates, 0, "nothing is redrawn in combat")
assertEq(#TO.pending.keys, 3, "one waiting job per kind of change, not one per change")
assertEq(#BLOCKED, 0, "no protected calls in combat: " .. table.concat(BLOCKED, ", "))
COMBAT = false; fire("PLAYER_REGEN_ENABLED")
assertEq(updates, 1, "and redrawn once when combat ends")
assertEq(TO.pending, nil, "nothing left waiting")
TO.Update = realUpdate
-- Jobs run in the order they were first asked for (the frames are built before anything is done to them)
COMBAT = true
local ran = {}
TO:RunOutOfCombat("first", function() ran[#ran + 1] = "first, as asked the first time" end)
TO:RunOutOfCombat("second", function() ran[#ran + 1] = "second" end)
TO:RunOutOfCombat("first", function() ran[#ran + 1] = "first" end)
COMBAT = false; TO:FlushPending()
assertEq(table.concat(ran, ", "), "first, second", "the latest request of each kind, in the order first asked")
SlashCmdList.TOPPEDOFFFOREVER("reset")
assert(lastLog("position reset."), "out of combat it resets right away")

step("each group member's buffs are read once per check")
STATE.class = "DRUID"; SPELLBOOK, FUTURE = {}, {}
LEARN("Mark of the Wild", "Thorns"); fire("SPELLS_CHANGED")
TO.char.checks = {}; STATE.bags = {}; STATE.party = { "party1", "party2" }
STATE.partyClass = {}; STATE.partyBuffs = { party1 = { ["Mark of the Wild"] = 900 }, party2 = { ["Thorns"] = 500 } }
STATE.buffs = { ["Mark of the Wild"] = 1800, ["Thorns"] = 500 }
local reads, realAura = {}, C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex = function(unit, i, ...)
    if i == 1 then reads[unit] = (reads[unit] or 0) + 1 end
    return realAura(unit, i, ...)
end
refresh()
assertEq(ids()["party:thorns"] and ids()["party:thorns"].text, "1", "two party buff checks ran")
assertEq(ids()["party:motw"] and ids()["party:motw"].text, "1", "(Mark of the Wild too)")
assertEq(reads.party1, 1, "party1's buffs read once for both checks")
assertEq(reads.party2, 1, "party2's buffs read once for both checks")
assertEq(TO.unitBuffs, nil, "and not kept for the next check")
STATE.partyBuffs.party2["Mark of the Wild"] = 900
refresh()
assertEq(ids()["party:motw"], nil, "the next check reads them afresh")
-- A member whose buffs the game hides is looked at once too, and not guessed at
STATE.hiddenAuras = { party1 = true }; reads = {}
refresh()
assertEq(reads.party1, 1, "hidden buffs: one look")
assertEq(ids()["party:thorns"], nil, "hidden buffs: no guessing")
STATE.hiddenAuras = {}
-- Offline, dead or out of sight: can't be buffed now, so not counted
STATE.partyBuffs = { party1 = {}, party2 = {} }
refresh()
assertEq(ids()["party:motw"].text, "2", "both in reach: both counted")
for _, why in ipairs({ "offline", "dead", "unseen" }) do
    STATE[why] = { party1 = true }
    refresh()
    assertEq(ids()["party:motw"].text, "1", why .. ": not counted")
    assertEq(ids()["party:motw"].action.unit, "party2", why .. ": the click goes to the other one")
    STATE[why] = {}
end
C_UnitAuras.GetAuraDataByIndex = realAura; STATE.party = {}; STATE.partyBuffs = {}

step("a buff that doesn't run out counts, whichever aura is found first")
STATE.class = "WARRIOR"; SPELLBOOK, FUTURE = {}, {}; fire("SPELLS_CHANGED")
TO.char.checks = {}; TO.char.wellFedInstanceOnly = false; TO.db.warnMinutes = 5
STATE.buffs = { ["Well Fed"] = 0 }
refresh()
assertEq(ids()["wellfed"], nil, "a Well Fed that never expires is not 'running out'")
STATE.buffs = { ["Well Fed"] = 60 }
refresh()
assert(ids()["wellfed"], "one minute left is")
TO.char.elixirs = { { name = "Elixir of Fortitude", auras = { "Health", "Health II" } } }; TO.char.elixirInstanceOnly = false
for _, both in ipairs({ { 0, 60 }, { 60, 0 } }) do
    STATE.buffs = { ["Health"] = both[1], ["Health II"] = both[2], ["Well Fed"] = 0 }
    refresh()
    assertEq(ids()["elixir:elixir of fortitude"], nil, "elixir aura that never expires, found " .. (both[1] == 0 and "first" or "last"))
end
STATE.buffs = {}; TO.char.wellFedInstanceOnly = true; TO.char.elixirs = {}; TO.char.elixirInstanceOnly = true

step("a refused read doesn't break the ready check reminder")
STATE.class = "PRIEST"; SPELLBOOK, FUTURE = {}, {}; LEARN("Power Word: Fortitude"); fire("SPELLS_CHANGED")
TO.char.checks = {}; STATE.buffs = {}; refresh()
assert(ids()["buff:fortitude"], "Fortitude is missing")
local realBuild = TO.BuildReminders
TO.BuildReminders = function() error("Auras cannot be accessed") end
local okRemind, errRemind = pcall(TO.Remind, TO, "Ready check")
TO.BuildReminders = realBuild
assert(okRemind, "Remind must not throw: " .. tostring(errRemind))
assert(lastLog("Ready check — missing: .*Fortitude"), "and it reports the last check instead")

step("buffs hidden from the first look: no error and no guessing")
local lastList, lastBuffs, hiddenErrors = TO.reminders, TO.buffs, 0
TO.buffs, TO.errorsSeen = nil, nil
geterrorhandler = function() return function() hiddenErrors = hiddenErrors + 1 end end
STATE.aurasLocked = true
refresh()
assertEq(hiddenErrors, 0, "no error when your buffs have never been readable")
assertEq(TO.reminders, lastList, "the reminders are left as they were")
STATE.aurasLocked = false; geterrorhandler = nil
refresh()
assert(TO.buffs and TO.reminders ~= lastList, "and checked again once the game shows them")

step("option tooltips")
STATE.class = "PALADIN"; SPELLBOOK, FUTURE = {}, {}
LEARN("Blessing of Might", "Blessing of Wisdom", "Seal of Righteousness", "Seal of the Crusader"); fire("SPELLS_CHANGED")
TO.char.checks = {}; TO.char.splitProfiles = false; MenuUtil = nil
STATE.bags = {}; TO.char.auto = {}; refresh()
TO:AddCustom("Healing Potion", 3)
if not (TO.config and TO.config:IsShown()) then TO:OpenConfig() end
-- The widgets of the list that's showing
local function listWidgets() return TO.config.lists[TO.optionsTab].child.__children end
local function kindOf(w)
    if w.isSwitch then return "switch" end
    if w.__kind == "EditBox" then return "box" end
    if w.__kind == "Button" then return rawget(w, "keys") and "choice" or "button" end
    return w.__kind
end
local function shownText(w) return w.label and w.label:GetText() or w.__text or "" end
local tipLines
rawset(GameTooltip, "AddLine", function(_, text, r, g, b, wrap)
    tipLines[#tipLines + 1] = text .. (r and (" [" .. r .. g .. b .. (wrap and " wrap" or "") .. "]") or "")
end)
local function hover(kind, text)   -- every tooltip of the visible widgets with this text, top to bottom
    local found, shown = {}, nil
    for _, w in ipairs(listWidgets()) do
        if kindOf(w) == kind and w:IsVisible() and shownText(w):find(text, 1, true) then
            tipLines = {}
            GameTooltip.__shown = false
            if w.__scripts.OnEnter then w.__scripts.OnEnter(w) end
            shown = GameTooltip.__shown
            if w.__scripts.OnLeave then w.__scripts.OnLeave(w) end
            assertEq(GameTooltip.__shown, false, text .. ": tooltip hidden when the mouse leaves")
            found[#found + 1] = { y = w.__pos[2], tip = table.concat(tipLines, " / ") }
        end
    end
    table.sort(found, function(x, y) return x.y > y.y end)
    for i, f in ipairs(found) do found[i] = f.tip end
    return table.concat(found, " || "), shown
end
TO:ShowOptionsTab("supplies")
local tipText, tipShown = hover("switch", "Always show these")
assertEq(tipText:find("Always show these, as a quick-use bar / Show your food, water, potions and items ", 1, true), 1, "switch: title, then the tip")
assert(tipText:find("%[111 wrap%]$"), "the tip is white and wraps")
assertEq(tipShown, true, "and the tooltip is shown")
assertEq(hover("switch", "Healing Potion"), "", "a switch without a tip has no tooltip")
assertEq(hover("button", "X"), "Remove", "the X says what it does")
assertEq(hover("choice", ": "):find("Stat food / Automatic picks food for your role, and falls back to any stat food. Pick a stat", 1, true), 1,
    "stat food choice: title and explanation")
assertEq(hover("button", "Add"), "", "plain buttons have none")
for _, w in ipairs(listWidgets()) do
    if kindOf(w) == "button" and w:IsVisible() then
        assertEq(table.concat(w.__size, "x"), shownText(w) == "X" and "20x20" or "90x22", shownText(w) .. " button size")
    end
end
-- Hovering a button lights it up, with or without a tooltip, and leaving puts it back
for _, name in ipairs({ "Add", "X" }) do
    for _, w in ipairs(listWidgets()) do
        if kindOf(w) == "button" and w:IsVisible() and shownText(w) == name then
            w.__scripts.OnEnter(w)
            local lit = table.concat(w.bg.__color or {}, ",")
            w.__scripts.OnLeave(w)
            assert(lit ~= table.concat(w.bg.__color or {}, ","), name .. " button lights up under the mouse")
        end
    end
end
-- Switches do what they show
local function switch(text)
    for _, f in ipairs(ALL_FRAMES) do
        if f.isSwitch and f:IsVisible() and f.label and (f.label:GetText() or ""):find(text, 1, true) then return f end
    end
end
local function click(w) w.__scripts.OnClick(w) end
local healing = switch("Healing Potion")
assertEq(healing:IsOn(), true, "a check starts on")
click(healing)
assertEq(healing:IsOn(), false, "a click turns the switch off")
assertEq(TO:IsEnabled("custom:healing potion", true), false, "and the check with it")
click(healing)
assertEq(healing:IsOn() and TO:IsEnabled("custom:healing potion", true), true, "and on again")
TO:ShowOptionsTab("general")
local minimap = switch("Show minimap icon")
TO.db.minimap = true; TO:OpenConfig(); TO:OpenConfig()
assertEq(minimap:IsOn(), true, "a display switch shows the saved setting")
click(minimap)
assertEq(TO.db.minimap, false, "and saves a click")
TO:OpenConfig(); TO.db.minimap = true; TO:OpenConfig()   -- changed while the window was closed
assertEq(minimap:IsOn(), true, "reopening the window shows the setting as it is now")
TO:ShowOptionsTab("buffs")
-- A card is as tall as its rows: title, three rows (Blessing, Aura, Righteous Fury), padding
local firstCard
for _, w in ipairs(listWidgets()) do
    if w.__kind == "Texture" and w:IsVisible() and w.__pos and w.__pos[2] == 0 and w.__width then firstCard = w end
end
assertEq(firstCard and firstCard.__height, 28 + 3 * 26 + 6, "a card wraps its rows")
assertEq(hover("choice", "Blessing of Might"):find("Click to choose which spell to cast || Blessing to give Warriors in your party [111 wrap] || Blessing to give ", 1, true), 1,
    "a spell choice, then the blessing choices, which show only their tip")
rawset(GameTooltip, "AddLine", nil)
TO:RemoveCustom("Healing Potion"); TO:OpenConfig()

step("the options lists reuse their rows")
if TO.config and TO.config:IsShown() then TO:OpenConfig() end
MenuUtil = nil
-- Everything a row shows or does, for every visible widget in the list that's showing
local function listState()
    local function text(fs)
        local width = fs.__width ~= 0 and fs.__width or nil   -- 0 = as wide as its text, like one never set
        return table.concat({ tostring(fs.__text), tostring(width), tostring(fs.__justify), tostring(fs.__wrap),
            fs.__tcolor and table.concat(fs.__tcolor, "/") or "-" }, " ")
    end
    local out = {}
    for _, w in ipairs(listWidgets()) do
        if w.label then w.label.__owner = w end
    end
    for _, w in ipairs(listWidgets()) do
        if w.__owner then   -- a switch's label is listed with its switch
            if w:IsVisible() and not w.__owner:IsVisible() then out[#out + 1] = "LABEL LEFT BEHIND " .. tostring(w.__text) end
        elseif w:IsVisible() then
            local scripts = {}
            for k, fn in pairs(w.__scripts) do scripts[#scripts + 1] = k .. ((fn == w.madeEnter or fn == w.madeLeave) and "=own" or "") end
            table.sort(scripts)
            out[#out + 1] = table.concat({ kindOf(w), tostring(w.__point),
                w.__pos and table.concat(w.__pos, ",") or "-",
                w.__size and table.concat(w.__size, "x") or (w.__kind ~= "FontString" and (tostring(w.__width) .. "x" .. tostring(w.__height)) or "-"),
                tostring(w.on), tostring(w.__numeric), tostring(rawget(w, "menuTitle")),
                w.__color and table.concat(w.__color, "/") or "-",
                w.__kind == "FontString" and text(w) or tostring(w.__text),
                w.label and (w.label:IsVisible() and text(w.label) or "LABEL HIDDEN") or "", table.concat(scripts, ",") }, " | ")
        end
    end
    table.sort(out)
    return table.concat(out, "\n")
end
local function freshList(tab)   -- a list with nothing to reuse
    TO.optionsTab = tab
    local list = TO.config.lists[tab].child
    for _, w in ipairs(list.__children) do w:Hide() end
    list.pool = {}
    TO:ShowOptionsTab(tab)
    return listState()
end
TO:OpenConfig()
TO:AddCustom("Healing Potion", 3)
local CLASSES = { "PALADIN", "HUNTER", "MAGE", "WARLOCK", "ROGUE", "DRUID" }
for i, class in ipairs(CLASSES) do
    for _, split in ipairs({ false, true }) do
        for _, t in ipairs(TO.OPTION_TABS) do
            STATE.class = class; TO.char.splitProfiles = split
            local fresh = freshList(t.key)
            -- Then a list whose rows were made for another class and the other profile setting
            STATE.class = CLASSES[i % #CLASSES + 1]; TO.char.splitProfiles = not split
            freshList(t.key)
            STATE.class = CLASSES[(i + 1) % #CLASSES + 1]
            TO:ShowOptionsTab(t.key)
            STATE.class = class; TO.char.splitProfiles = split
            TO:ShowOptionsTab(t.key)
            local reused = listState()
            if reused ~= fresh then   -- say which rows differ
                local seen, diff = {}, {}
                for line in fresh:gmatch("[^\n]+") do seen[line] = (seen[line] or 0) + 1 end
                for line in reused:gmatch("[^\n]+") do
                    if (seen[line] or 0) > 0 then seen[line] = seen[line] - 1 else diff[#diff + 1] = "reused: " .. line end
                end
                for line, n in pairs(seen) do for _ = 1, n do diff[#diff + 1] = "new:    " .. line end end
                error(class .. " " .. t.key .. (split and " (split)" or "") .. ": reused rows differ from new ones\n"
                    .. table.concat(diff, "\n"))
            end
        end
    end
end
TO.char.splitProfiles = false
-- An item added and removed: the rows that shuffled up look like new ones
STATE.class = "MAGE"
local before = freshList("supplies")
TO:AddCustom("Wild Berries", 5); TO:ShowOptionsTab("supplies")
assert(listState() ~= before, "(the added item shows)")
TO:RemoveCustom("Healing Potion"); TO:ShowOptionsTab("supplies")
TO:RemoveCustom("Wild Berries"); TO:AddCustom("Healing Potion", 3); TO:ShowOptionsTab("supplies")
assertEq(listState(), before, "after adding and removing items the list is as it was")
for _, t in ipairs(TO.OPTION_TABS) do TO:ShowOptionsTab(t.key) end
local frames = #ALL_FRAMES
for _ = 1, 3 do
    for _, t in ipairs({ "buffs", "supplies", "more", "profiles", "display", "general" }) do TO:ShowOptionsTab(t) end
    TO:OpenConfig(); TO:OpenConfig()
end
assertEq(#ALL_FRAMES, frames, "opening the window and switching tabs makes no new frames")
-- A list drawn again while you're on it stays where you'd scrolled to; reopening starts at the top
STATE.class = "PALADIN"
TO:ShowOptionsTab("buffs")
local buffsList = TO.config.lists.buffs
assert(buffsList.bar:IsShown(), "a long list gets a scroll bar")
buffsList.__scripts.OnMouseWheel(buffsList, -1); buffsList.__scripts.OnMouseWheel(buffsList, -1)
assertEq(buffsList.__scroll, 80, "the mouse wheel scrolls the list")
TO:RefreshConfig()
assertEq(buffsList.__scroll, 80, "drawn again: still where you were")
TO:ShowOptionsTab("supplies"); TO:ShowOptionsTab("buffs")
assertEq(buffsList.__scroll, 0, "another tab and back: at the top")
buffsList.__scripts.OnMouseWheel(buffsList, -1)
TO:OpenConfig(); TO:OpenConfig()
assertEq(buffsList.__scroll, 0, "closed and reopened: at the top")
for _ = 1, 40 do buffsList.__scripts.OnMouseWheel(buffsList, -1) end
local _, deepest = buffsList.bar:GetMinMaxValues()
assertEq(buffsList.__scroll, deepest, "it stops at the bottom")
TO:ShowOptionsTab("profiles")
assertEq(TO.config.lists.profiles.bar:IsShown(), false, "a short list has no scroll bar")
TO:RemoveCustom("Healing Potion"); TO:OpenConfig()

step("a damaged settings file falls back to defaults")
local savedDB, savedChar = ToppedOffForeverDB, ToppedOffForeverCharDB
ToppedOffForeverDB = "oops"
ToppedOffForeverCharDB = { checks = 7, customAlways = "yes", prefs = "x", elixirs = { 5, { name = "Elixir of the Mongoose" }, { name = false } },
    auto = { food = 3, water = { name = "Spring Water", min = 4 } },
    custom = { "junk", { name = 5, min = 2 }, { name = "Sacred Candle", min = "7" }, { name = "Rune of Portals" } } }
fire("ADDON_LOADED", ADDON)
assertEq(type(TO.db), "table", "a settings file that isn't a table is replaced")
assertEq(TO.db.iconSize, 40, "with the defaults")
assertEq(type(TO.char.checks), "table", "a wrong-typed table is replaced")
assertEq(TO.char.customAlways, true, "a wrong-typed setting gets its default")
assertEq(type(TO.char.prefs), "table", "(every one of them)")
assertEq(#TO.char.elixirs, 1, "elixirs that can't be used are dropped")
assertEq(TO.char.elixirs[1].name, "Elixir of the Mongoose", "and the good one kept")
assertEq(#TO.char.custom, 2, "list entries that can't be used are dropped")
assertEq(TO.char.custom[1].name .. " " .. TO.char.custom[1].min, "Sacred Candle 7", "a Min saved as text is read as a number")
assertEq(TO.char.custom[2].min, 20, "a missing Min gets the Add box's default")
assertEq(TO.char.auto.food, nil, "a damaged auto-tracked item is dropped")
assertEq(TO.char.auto.water.name, "Spring Water", "good ones are kept")
STATE.class = "PRIEST"; STATE.bags = {}
refresh()   -- and the checks run on what's left
assertEq(ids()["custom:sacred candle"] and ids()["custom:sacred candle"].text, "0/7", "the repaired item is checked")
ToppedOffForeverDB, ToppedOffForeverCharDB = savedDB, savedChar
fire("ADDON_LOADED", ADDON)
refresh()
print("ALL TESTS PASSED")
