-- ToppedOff Forever
-- Reminds you when a buff, weapon enhancement, reagent, ammo or durability runs low
-- in World of Warcraft: Forever (interface 16001). Each reminder is an icon; clicking a
-- buff or weapon icon casts or uses the fix. Nothing ever happens without your click.

local ADDON, ns = ...
local TO = {}
ns.TO = TO
_G.ToppedOffForever = TO

-- Colors from the logo: gold ring, deep navy, dark purple, crimson banner, cyan drop
TO.COLORS = {
    gold      = { 1.00, 0.85, 0.40 },   -- #ffd966 text
    goldDark  = { 0.85, 0.65, 0.19 },   -- #d9a531 borders
    navy      = { 0.06, 0.14, 0.23 },   -- #10243a panels
    purple    = { 0.07, 0.05, 0.11 },   -- #120d1c window background
    crimson   = { 0.55, 0.12, 0.12 },   -- #8b1e1e title banner
    cyan      = { 0.16, 0.71, 0.91 },   -- #28b6e8 highlights
    expiring  = { 1.00, 0.55, 0.00 },   -- #ff8c00 buff running out
    urgent    = { 1.00, 0.13, 0.13 },   -- #ff2121 buff almost gone
}
TO.GOLD_HEX, TO.CYAN_HEX = "ffd966", "28b6e8"
local PREFIX = "|cffffd966ToppedOff|r: "
local function Print(msg) print((TO.LOGO_TEXT or "") .. " " .. PREFIX .. msg) end
TO.Print = Print

-- Forever hands some values to addons as "secret". Comparing, doing math on or
-- truth-testing them errors, so every API result is checked before use.
local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end
TO.IsSecret = IsSecret

-- A plain number, or nil if the value is missing, secret or not a number.
local function Num(v)
    if IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

-- A plain string, or nil if the value is missing, secret or not a string.
local function Str(v)
    if IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

---------------------------------------------------------------------------
-- What gets checked
---------------------------------------------------------------------------
-- Buffs you can put on yourself. `cast` is in order of preference (the first one you
-- know is cast, unless you pick another in the options). Any aura in `auras` counts
-- as having the buff, so a raid version or another player's buff is fine too.
-- `off = true` means the check starts turned off.
-- Spell names are Classic-era; verify in-game with /topoff check.
TO.CLASS_BUFFS = {
    MAGE = {
        { id = "intellect", label = "Arcane Intellect", cast = { "Arcane Intellect" },
          auras = { "Arcane Intellect", "Arcane Brilliance" }, party = true, skip = { WARRIOR = true, ROGUE = true } },
        { id = "armor", label = "Armor", cast = { "Ice Armor", "Frost Armor", "Mage Armor" } },
    },
    PRIEST = {
        { id = "fortitude", label = "Power Word: Fortitude", cast = { "Power Word: Fortitude" },
          auras = { "Power Word: Fortitude", "Prayer of Fortitude" }, party = true },
        { id = "innerfire", label = "Inner Fire", cast = { "Inner Fire" } },
        { id = "spirit", label = "Divine Spirit", cast = { "Divine Spirit" },
          auras = { "Divine Spirit", "Prayer of Spirit" }, party = true, skip = { WARRIOR = true, ROGUE = true } },
        { id = "shadowprot", label = "Shadow Protection", cast = { "Shadow Protection" },
          auras = { "Shadow Protection", "Prayer of Shadow Protection" }, off = true, party = true },
        -- Racial Priest buffs: only listed for Priests who have them
        { id = "shadowguard", label = "Shadowguard", cast = { "Shadowguard" }, racial = true },
        { id = "touchweak", label = "Touch of Weakness", cast = { "Touch of Weakness" }, racial = true },
        { id = "fearward", label = "Fear Ward", cast = { "Fear Ward" }, racial = true, off = true },
    },
    DRUID = {
        { id = "motw", label = "Mark of the Wild", cast = { "Mark of the Wild" },
          auras = { "Mark of the Wild", "Gift of the Wild" }, party = true },
        { id = "thorns", label = "Thorns", cast = { "Thorns" } },
        { id = "omen", label = "Omen of Clarity", cast = { "Omen of Clarity" } },
    },
    WARLOCK = {
        { id = "armor", label = "Demon Armor", cast = { "Demon Armor", "Demon Skin" } },
    },
    PALADIN = {
        { id = "blessing", label = "Blessing", cast = { "Blessing of Might", "Blessing of Wisdom",
          "Blessing of Kings", "Blessing of Sanctuary", "Blessing of Light", "Blessing of Salvation" },
          auras = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Sanctuary",
          "Blessing of Light", "Blessing of Salvation", "Greater Blessing of Might", "Greater Blessing of Wisdom",
          "Greater Blessing of Kings", "Greater Blessing of Sanctuary", "Greater Blessing of Light",
          "Greater Blessing of Salvation" } },
        { id = "aura", label = "Aura", cast = { "Devotion Aura", "Retribution Aura", "Concentration Aura",
          "Sanctity Aura", "Shadow Resistance Aura", "Frost Resistance Aura", "Fire Resistance Aura" } },
        { id = "rfury", label = "Righteous Fury", cast = { "Righteous Fury" }, off = true },
    },
    HUNTER = {
        { id = "aspect", label = "Aspect", cast = { "Aspect of the Hawk", "Aspect of the Monkey",
          "Aspect of the Cheetah", "Aspect of the Pack", "Aspect of the Wild", "Aspect of the Beast" } },
        { id = "trueshot", label = "Trueshot Aura", cast = { "Trueshot Aura" } },
    },
    WARRIOR = {
        { id = "shout", label = "Battle Shout", cast = { "Battle Shout" }, off = true },
    },
    SHAMAN = {
        { id = "shield", label = "Lightning Shield", cast = { "Lightning Shield" } },
    },
    ROGUE = {},
}

-- Weapon enhancements. "spell" = cast a weapon buff (Shaman); "item" = use an item from
-- your bags on the weapon (poisons, oils, sharpening stones). An item name matches any
-- bag item containing it, so "Instant Poison" finds "Instant Poison IV".
TO.WEAPON_DEFAULTS = {
    SHAMAN = { kind = "spell", cast = { "Windfury Weapon", "Flametongue Weapon", "Frostbrand Weapon", "Rockbiter Weapon" } },
    ROGUE = { kind = "item", mh = "Instant Poison", oh = "Instant Poison" },
}

-- Reagents and class items. Checked only if you know one of the `requires` spells.
-- Any item in `items` counts toward the total (e.g. both candle ranks).
TO.CLASS_REAGENTS = {
    WARLOCK = {
        { id = "shard", label = "Soul Shard", items = { "Soul Shard" }, min = 5, requires = { "Drain Soul" } },
    },
    MAGE = {
        { id = "teleport", label = "Rune of Teleportation", items = { "Rune of Teleportation" }, min = 2,
          requires = { "Teleport: Stormwind", "Teleport: Ironforge", "Teleport: Darnassus",
          "Teleport: Orgrimmar", "Teleport: Undercity", "Teleport: Thunder Bluff" } },
        { id = "portal", label = "Rune of Portals", items = { "Rune of Portals" }, min = 2,
          requires = { "Portal: Stormwind", "Portal: Ironforge", "Portal: Darnassus",
          "Portal: Orgrimmar", "Portal: Undercity", "Portal: Thunder Bluff" } },
        { id = "powder", label = "Arcane Powder", items = { "Arcane Powder" }, min = 10, requires = { "Arcane Brilliance" } },
        { id = "feather", label = "Light Feather", items = { "Light Feather" }, min = 5, requires = { "Slow Fall" } },
    },
    PRIEST = {
        { id = "candle", label = "Candles", items = { "Sacred Candle", "Holy Candle" }, min = 10,
          buy = { { "Holy Candle", 48 }, { "Sacred Candle", 60 } },
          requires = { "Prayer of Fortitude", "Prayer of Spirit", "Prayer of Shadow Protection" } },
        { id = "feather", label = "Light Feather", items = { "Light Feather" }, min = 5, requires = { "Levitate" } },
    },
    DRUID = {
        { id = "gotw", label = "Gift of the Wild herbs", items = { "Wild Thornroot", "Wild Berries" }, min = 10,
          buy = { { "Wild Berries", 50 }, { "Wild Thornroot", 60 } },
          requires = { "Gift of the Wild" } },
        { id = "seed", label = "Rebirth seed", items = { "Ironwood Seed", "Hornbeam Seed", "Ashwood Seed",
          "Stranglethorn Seed", "Maple Seed" }, min = 2, requires = { "Rebirth" },
          buy = { { "Maple Seed", 20 }, { "Stranglethorn Seed", 30 }, { "Ashwood Seed", 40 },
          { "Hornbeam Seed", 50 }, { "Ironwood Seed", 60 } } },
    },
    PALADIN = {
        { id = "kings", label = "Symbol of Kings", items = { "Symbol of Kings" }, min = 20,
          requires = { "Greater Blessing of Might", "Greater Blessing of Wisdom", "Greater Blessing of Kings",
          "Greater Blessing of Sanctuary", "Greater Blessing of Light", "Greater Blessing of Salvation" } },
        { id = "divinity", label = "Symbol of Divinity", items = { "Symbol of Divinity" }, min = 1,
          requires = { "Divine Intervention" } },
    },
    SHAMAN = {
        { id = "ankh", label = "Ankh", items = { "Ankh" }, min = 1, requires = { "Reincarnation" } },
        { id = "earth", label = "Earth Totem", items = { "Earth Totem" }, min = 1,
          requires = { "Stoneskin Totem", "Earthbind Totem", "Strength of Earth Totem" } },
        { id = "fire", label = "Fire Totem", items = { "Fire Totem" }, min = 1,
          requires = { "Searing Totem", "Fire Nova Totem", "Magma Totem" } },
        { id = "water", label = "Water Totem", items = { "Water Totem" }, min = 1,
          requires = { "Healing Stream Totem", "Mana Spring Totem", "Poison Cleansing Totem" } },
        { id = "air", label = "Air Totem", items = { "Air Totem" }, min = 1,
          requires = { "Grace of Air Totem", "Windfury Totem", "Grounding Totem" } },
    },
    ROGUE = {
        { id = "flash", label = "Flash Powder", items = { "Flash Powder" }, min = 5, requires = { "Vanish" } },
        { id = "blinding", label = "Blinding Powder", items = { "Blinding Powder" }, min = 5, requires = { "Blind" } },
    },
}

-- Ammo is checked for these classes by default (only when ammo is equipped).
TO.AMMO_CLASSES = { HUNTER = true }
TO.AMMO_DEFAULT_MIN = 200

TO.ICONS = {
    durability = "Interface\\Icons\\Trade_BlackSmithing",
    ammo = "Interface\\Icons\\INV_Ammo_Arrow_02",
    unknown = "Interface\\Icons\\INV_Misc_QuestionMark",
    wellFed = "Interface\\Icons\\Spell_Misc_Food",
    bags = "Interface\\Icons\\INV_Misc_Bag_08",
    pet = "Interface\\Icons\\Ability_Hunter_BeastCall",
    happy = "Interface\\Icons\\Ability_Hunter_BeastTraining",
    soulstone = "Interface\\Icons\\Spell_Shadow_SoulGem",
    addon = "Interface\\AddOns\\ToppedOffForever\\Media\\Icon",   -- the ToppedOff logo
}
-- Logo as inline chat/tooltip text
TO.LOGO_TEXT = "|T" .. TO.ICONS.addon .. ":0|t"

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
local DEFAULTS = {            -- account-wide: display
    shown = true,
    locked = false,
    iconSize = 40,
    showHeader = true,
    hideInCombat = true,
    onlyInInstance = false,
    warnMinutes = 3,
    durabilityPct = 25,
    iconsPerRow = 8,
    readyCheck = true,
    instanceReminder = true,
    sound = false,
    minimap = true,
    minimapAngle = 200,
    point = { "CENTER", "CENTER", 0, -150 },
}

local CHAR_DEFAULTS = {       -- per character: what to check
    checks = {},              -- check id -> true/false (missing = class default)
    prefs = {},               -- buff id -> preferred spell name
    mins = {},                -- reagent/ammo id -> minimum count
    weapon = {},              -- mh / oh -> item name, spell -> preferred weapon spell
    custom = {},              -- { name = "Conjured Crystal Water", min = 20 }
    customAlways = true,      -- show food, water and your items even when stocked (a quick-use bar)
    autoMins = {},            -- auto slot -> your Min (kept when the tracked item changes)
    auto = {},                -- auto-tracked best items: slot -> { name, id, score, min }
    statFocus = nil,          -- stat food override ("str", "agi", ...); nil = class default
    wellFedInstanceOnly = true, -- Well Fed reminder only in dungeons and raids
    elixirs = {},             -- tracked elixirs/flasks: { name = , auras = { ... } }
    elixirInstanceOnly = true,
    soulstoneInstanceOnly = true,
    petFood = "",             -- Hunter pet food item name ("" = not set)
    blessings = {},           -- Paladin: class -> "Kings" / "Might" / "Wisdom" / ... / "none"
    splitProfiles = false,    -- separate on/off checks outside dungeons and raids
    checksOutside = {},       -- check id -> on/off outside instances (missing = same as inside)
    wholeRaid = false,        -- party buffs, blessings and Soulstone look at the whole raid
    restockAtVendor = true,   -- restock list at vendors
    repairAtVendor = true,    -- repair button at vendors
}

local function FillDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = {}
                FillDefaults(dst[k], v)
            else
                dst[k] = v
            end
        end
    end
end
TO.DEFAULTS = DEFAULTS

function TO:PlayerClass()
    local _, class = UnitClass("player")
    return Str(class) or "UNKNOWN"
end

-- Checks are on/off per character. With "separate checks outside dungeons" on,
-- a second set applies outside instances; anything not set there follows the
-- dungeon set. `outside` = true/false picks a set; nil = the one in use right now.
function TO:UsingOutsideChecks()
    return self.char.splitProfiles and not self:InInstance()
end

function TO:IsEnabled(id, default, outside)
    if outside == nil then outside = self:UsingOutsideChecks() end
    local v
    if outside then v = self.char.checksOutside[id] end
    if v == nil then v = self.char.checks[id] end
    if v == nil then return default ~= false end
    return v
end

function TO:SetEnabled(id, on, outside)
    local t = outside and self.char.checksOutside or self.char.checks
    t[id] = on and true or false
    self:RequestUpdate()
end

---------------------------------------------------------------------------
-- Combat-safe queue: secure buttons can't be changed in combat
---------------------------------------------------------------------------
function TO:RunOutOfCombat(fn)
    if InCombatLockdown() then
        self.pending = self.pending or {}
        table.insert(self.pending, fn)
        return false
    end
    fn()
    return true
end

function TO:FlushPending()
    if not self.pending then return end
    local list = self.pending
    self.pending = nil
    for _, fn in ipairs(list) do fn() end
end

---------------------------------------------------------------------------
-- Reading the game
---------------------------------------------------------------------------
-- Names of every spell you've learned (lowercase). Ranks share a name, so this
-- works no matter which rank you have.
function TO:ScanSpellbook()
    local known = {}
    local sb = C_SpellBook
    if sb and sb.GetNumSpellBookSkillLines and sb.GetSpellBookSkillLineInfo and sb.GetSpellBookItemInfo then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        local future = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
        local lines = Num(sb.GetNumSpellBookSkillLines()) or 0
        for i = 1, lines do
            local line = sb.GetSpellBookSkillLineInfo(i)
            if type(line) == "table" then
                local offset = Num(line.itemIndexOffset) or 0
                local count = Num(line.numSpellBookItems) or 0
                for j = offset + 1, offset + count do
                    local info = sb.GetSpellBookItemInfo(j, bank)
                    if type(info) == "table" then
                        local name = Str(info.name)
                        local isFuture = future ~= nil and info.itemType == future
                        if name and not isFuture then known[name:lower()] = true end
                    end
                end
            end
        end
    end
    self.known = known
end

function TO:Knows(name)
    if not name or name == "" then return false end
    if self.known and self.known[name:lower()] then return true end
    -- Fallback for spells the spellbook scan missed
    if C_Spell and C_Spell.GetSpellInfo and IsPlayerSpell then
        local info = C_Spell.GetSpellInfo(name)
        local id = type(info) == "table" and Num(info.spellID)
        if id then
            local ok = IsPlayerSpell(id)
            if not IsSecret(ok) and ok then return true end
        end
    end
    return false
end

function TO:FirstKnown(list)
    for _, name in ipairs(list or {}) do
        if self:Knows(name) then return name end
    end
    return nil
end

function TO:KnownOptions(list)
    local out = {}
    for _, name in ipairs(list or {}) do
        if self:Knows(name) then out[#out + 1] = name end
    end
    return out
end

-- Your buffs, keyed by lowercase name -> seconds left (0 = doesn't expire)
-- Buff names on any unit (lowercase -> seconds left). nil if the game hides them.
function TO:UnitBuffs(unit)
    local buffs = {}
    local now = GetTime()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
    for i = 1, 40 do
        local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if a == nil then break end
        if IsSecret(a) or type(a) ~= "table" then return nil end
        local name = a.name
        if IsSecret(name) then return nil end
        name = Str(name)
        if name then
            local left, exp = 0, Num(a.expirationTime)
            if exp and exp > 0 then left = math.max(0, exp - now) end
            buffs[name:lower()] = left
        end
    end
    return buffs
end

function TO:ScanBuffs()
    local buffs = {}
    local now = GetTime()
    local function add(name, expires)
        name = Str(name)
        if not name then return end
        local left = 0
        expires = Num(expires)
        if expires and expires > 0 then left = math.max(0, expires - now) end
        buffs[name:lower()] = left
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if a == nil or IsSecret(a) or type(a) ~= "table" then break end
            add(a.name, a.expirationTime)
        end
    elseif UnitBuff then
        for i = 1, 40 do
            local name, _, _, _, _, expires = UnitBuff("player", i)
            if name == nil or IsSecret(name) then break end
            add(name, expires)
        end
    end
    self.buffs = buffs
end

local function ContainerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return Num(C_Container.GetContainerNumSlots(bag)) or 0 end
    if GetContainerNumSlots then return Num(GetContainerNumSlots(bag)) or 0 end
    return 0
end

local function ContainerItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if type(info) == "table" then return Num(info.itemID), Num(info.stackCount) or 1, info.iconFileID end
        return nil
    end
    if GetContainerItemInfo and GetContainerItemID then
        local _, count = GetContainerItemInfo(bag, slot)
        return Num(GetContainerItemID(bag, slot)), Num(count) or 1
    end
    return nil
end

local function ItemName(id)
    if C_Item and C_Item.GetItemNameByID then
        local n = Str(C_Item.GetItemNameByID(id))
        if n then return n end
    end
    if GetItemInfo then return Str((GetItemInfo(id))) end
    return nil
end

-- Mage- and Warlock-made items (can't be bought): conjured food and water,
-- mana gems and Healthstones. They have their own checks.
local MADE_ITEMS = { ["mana agate"] = true, ["mana jade"] = true, ["mana citrine"] = true, ["mana ruby"] = true }
local function IsConjured(name)
    local n = name:lower()
    return n:find("^conjured ") ~= nil or MADE_ITEMS[n] == true or n:find("healthstone", 1, true) ~= nil
end
TO.IsConjured = IsConjured

local function ItemIcon(id)
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
    if GetItemIcon then return GetItemIcon(id) end
    return nil
end

-- Everything in your bags: bag[lowercase name] = { name, id, count, icon }
function TO:ScanBags()
    local bag = {}
    local last = NUM_BAG_SLOTS or 4
    for b = 0, last do
        for s = 1, ContainerSlots(b) do
            local id, count, icon = ContainerItem(b, s)
            if id then
                local name = ItemName(id)
                if name then
                    local key = name:lower()
                    local e = bag[key]
                    if not e then
                        e = { name = name, id = id, count = 0, icon = icon or ItemIcon(id) }
                        bag[key] = e
                    end
                    e.count = e.count + count
                end
            end
        end
    end
    self.bag = bag
end

function TO:BagCount(names)
    local total, icon = 0, nil
    for _, n in ipairs(names) do
        local e = self.bag[n:lower()]
        if e then
            total = total + e.count
            icon = icon or e.icon
        end
    end
    return total, icon
end

-- The bag item whose name contains `text`. Higher item IDs are usually higher ranks,
-- so "Instant Poison" picks your best Instant Poison.
function TO:FindBagItem(text)
    if not text or text == "" then return nil end
    local needle = text:lower()
    local best
    for key, e in pairs(self.bag) do
        if key:find(needle, 1, true) and (not best or e.id > best.id) then best = e end
    end
    return best
end

local function SpellIcon(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        if type(info) == "table" and info.iconID then return info.iconID end
    end
    return TO.ICONS.unknown
end
TO.SpellIcon = SpellIcon

local WEAPON_LOCS = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true }

local function HasWeapon(slot)
    local id = Num(GetInventoryItemID("player", slot))
    if not id then return false end
    if slot == 16 then return true end
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, equipLoc = C_Item.GetItemInfoInstant(id)
        return Str(equipLoc) ~= nil and WEAPON_LOCS[equipLoc] == true
    end
    return false
end

local function FormatTime(sec)
    if sec >= 60 then return math.ceil(sec / 60) .. "m" end
    return math.floor(sec) .. "s"
end
TO.FormatTime = FormatTime
TO.Num = Num
TO.IsSecretValue = IsSecret

---------------------------------------------------------------------------
-- Building the list of reminders
---------------------------------------------------------------------------
-- Each reminder: { id, label, icon, text, detail, action = { spell = } or { item = , slot = }, noItem }

function TO:BuffPreference(buff)
    local known = self:KnownOptions(buff.cast)
    local pref = self.char.prefs[buff.id]
    for _, n in ipairs(known) do
        if n == pref then return n end
    end
    return known[1]
end

function TO:WeaponConfig()
    local class = self:PlayerClass()
    local def = self.WEAPON_DEFAULTS[class] or { kind = "item", mh = "", oh = "" }
    local w = self.char.weapon
    if def.kind == "spell" then
        local known = self:KnownOptions(def.cast)
        local spell = known[1]
        for _, n in ipairs(known) do if n == w.spell then spell = n end end
        return { kind = "spell", cast = def.cast, spell = spell }
    end
    return { kind = "item", mh = w.mh or def.mh or "", oh = w.oh or def.oh or "" }
end

function TO:CheckBuffs(list)
    local warn = self.db.warnMinutes * 60
    for _, buff in ipairs(self.CLASS_BUFFS[self:PlayerClass()] or {}) do
        local id = "buff:" .. buff.id
        local spell = self:BuffPreference(buff)
        if spell and self:IsEnabled(id, not buff.off) then
            local left
            for _, aura in ipairs(buff.auras or buff.cast) do
                local l = self.buffs[aura:lower()]
                if l and (not left or l == 0 or l > left) then left = l end
                if left == 0 then break end
            end
            if not left then
                list[#list + 1] = { id = id, label = buff.label, icon = SpellIcon(spell),
                    detail = "Missing", action = { spell = spell } }
            elseif left > 0 and left < warn then
                list[#list + 1] = { id = id, label = buff.label, icon = SpellIcon(spell), text = FormatTime(left),
                    detail = "Runs out in " .. FormatTime(left), action = { spell = spell }, expires = left }
            end
        end
    end
end

function TO:CheckWeapons(list)
    local cfg = self:WeaponConfig()
    local hasMH, mhExp, mhCharges, _, hasOH, ohExp, ohCharges = GetWeaponEnchantInfo()
    local minCharges = self:ReagentMin("charges", self.CHARGES_DEFAULT_MIN)
    local warn = self.db.warnMinutes * 60
    local hands = {
        { key = "mh", slot = 16, label = "Main hand", has = hasMH, exp = mhExp, charges = Num(mhCharges) },
        { key = "oh", slot = 17, label = "Off hand", has = hasOH, exp = ohExp, charges = Num(ohCharges) },
    }
    for _, h in ipairs(hands) do
        local id = "weapon:" .. h.key
        if self:IsEnabled(id, true) and HasWeapon(h.slot) and not IsSecret(h.has) then
            local left = h.has and (Num(h.exp) or 0) / 1000 or nil
            -- Poisons also run out of charges
            local lowCharges = h.has and cfg.kind == "item" and h.charges and h.charges > 0
                and h.charges < minCharges and self:IsEnabled("charges", true)
            local needs = (not h.has) or (left and left > 0 and left < warn) or lowCharges
            if needs then
                local r = { id = id, slot = h.slot }
                if cfg.kind == "spell" then
                    -- Shaman weapon buffs only go on the main hand
                    if h.key == "mh" and cfg.spell then
                        r.label = h.label .. ": " .. cfg.spell
                        r.icon = SpellIcon(cfg.spell)
                        r.action = { spell = cfg.spell }
                    end
                else
                    local want = cfg[h.key]
                    if want ~= "" then
                        local item = self:FindBagItem(want)
                        r.label = h.label .. ": " .. (item and item.name or want)
                        if item then
                            r.icon = item.icon
                            r.action = { item = item.name, slot = h.slot }
                        else
                            r.icon = self.ICONS.unknown
                            r.noItem = want
                        end
                    end
                end
                if r.label then
                    if lowCharges then
                        r.text = h.charges .. "c"
                        r.detail = h.charges .. " charges left (want " .. minCharges .. ")"
                        r.urgentNow = true
                    elseif h.has then
                        r.text = FormatTime(left)
                        r.detail = "Runs out in " .. FormatTime(left)
                        r.expires = left
                    else
                        r.detail = "No weapon enhancement"
                    end
                    if r.noItem then r.detail = r.detail .. "\nNo " .. r.noItem .. " in your bags" end
                    list[#list + 1] = r
                end
            end
        end
    end
end

function TO:ReagentMin(id, default)
    return Num(self.char.mins[id]) or default
end

function TO:CheckReagents(list)
    for _, rg in ipairs(self.CLASS_REAGENTS[self:PlayerClass()] or {}) do
        local id = "reagent:" .. rg.id
        if self:IsEnabled(id, true) and self:FirstKnown(rg.requires) then
            local min = self:ReagentMin(id, rg.min)
            local have, icon = self:BagCount(rg.items)
            if have < min then
                list[#list + 1] = { id = id, label = rg.label, icon = icon or self:ItemIconByName(rg.items[1]),
                    text = have .. "/" .. min, detail = ("%d in your bags (want %d)"):format(have, min) }
            end
        end
    end
    for _, c in ipairs(self.char.custom) do
        local id = "custom:" .. c.name:lower()
        if self:IsEnabled(id, true) then
            local have, icon = self:BagCount({ c.name })
            local low = have < c.min
            if low or self.char.customAlways then
                local r = { id = id, label = c.name, icon = icon or self:ItemIconByName(c.name),
                    text = have .. "/" .. c.min, low = low, stocked = not low, ownItem = true,
                    detail = low and ("%d in your bags (want %d)"):format(have, c.min)
                        or ("%d in your bags. Topped off."):format(have) }
                -- Click to use it (food, drink, potions, bandages on yourself)
                local e = self.bag[c.name:lower()]
                if e then r.action = { use = "item:" .. e.id, useName = e.name } end
                list[#list + 1] = r
            end
        end
    end
end

---------------------------------------------------------------------------
-- Auto-tracked items: the best food, water, stat food, bandage, healing potion
-- and mana potion in your bags. Items are recognized from their tooltip text
-- ("Restores 294 health over 21 sec... while eating"), and the biggest one you're
-- high enough level for wins. Once picked, an item stays tracked even when you
-- run out (that's when you need the reminder), until something better shows up.
---------------------------------------------------------------------------
TO.AUTO_SLOTS = {
    { key = "food",     label = "Food",           min = 20 },
    { key = "water",    label = "Water",          min = 20, mana = true },
    { key = "statfood", label = "Stat food",      min = 10 },
    { key = "bandage",  label = "Bandage",        min = 20 },
    { key = "healing",  label = "Healing potion", min = 5 },
    { key = "mana",     label = "Mana potion",    min = 5, mana = true },
}
TO.MANA_CLASSES = { DRUID = true, HUNTER = true, MAGE = true, PALADIN = true, PRIEST = true,
    SHAMAN = true, WARLOCK = true }

-- Stat food: which Well Fed stats matter, best first
TO.STAT_KEYS = { "str", "agi", "sta", "int", "spi", "mp5", "sp", "heal" }
TO.STAT_LABELS = { str = "Strength", agi = "Agility", sta = "Stamina", int = "Intellect",
    spi = "Spirit", mp5 = "Mana regen", sp = "Spell power", heal = "Healing" }
TO.CLASS_STATS = {
    WARRIOR = { "str", "sta", "agi" },
    ROGUE   = { "agi", "str", "sta" },
    HUNTER  = { "agi", "int", "mp5", "sta" },
    MAGE    = { "sp", "int", "mp5", "spi", "sta" },
    WARLOCK = { "sp", "int", "sta", "spi", "mp5" },
    PRIEST  = { "heal", "mp5", "int", "spi", "sp", "sta" },
    SHAMAN  = { "heal", "mp5", "int", "sta", "str" },
    PALADIN = { "sta", "str", "heal", "mp5", "int" },
    DRUID   = { "sta", "agi", "str", "heal", "int" },
}
local STAT_WORDS = { strength = "str", agility = "agi", stamina = "sta", intellect = "int", spirit = "spi" }

-- Hybrid classes: stat food by what you do. Talent tree or spec name -> role.
TO.SPEC_ROLES = {
    shadow = "caster", discipline = "healer", holy = "healer",
    elemental = "caster", enhancement = "melee", restoration = "healer",
    balance = "caster", feral = "tank", ["feral combat"] = "tank", guardian = "tank",
    protection = "tank", retribution = "melee",
}
TO.ROLE_STATS = {
    PRIEST  = { healer = { "heal", "mp5", "int", "spi", "sta" }, caster = { "sp", "int", "sta", "spi", "mp5" } },
    SHAMAN  = { healer = { "heal", "mp5", "int", "sta" }, caster = { "sp", "int", "mp5", "sta" },
                melee = { "str", "agi", "sta", "int" } },
    DRUID   = { healer = { "heal", "mp5", "int", "spi" }, caster = { "sp", "int", "mp5", "sta" },
                tank = { "sta", "agi", "str" }, melee = { "agi", "str", "sta" } },
    PALADIN = { healer = { "heal", "mp5", "int", "sta" }, tank = { "sta", "str", "agi" },
                melee = { "str", "sta", "agi" } },
}
TO.ROLE_LABELS = { healer = "Healer", caster = "Caster", tank = "Tank", melee = "Melee" }

-- Your role, from (1) your specialization, (2) the talent tree with the most points,
-- or (3) the role you picked for the group. Returns role, and the spec/tree name.
function TO:PlayerSpecRole()
    local class = self:PlayerClass()
    local function fromName(name)
        name = Str(name)
        return name and self.SPEC_ROLES[name:lower()], name
    end
    if GetSpecialization and GetSpecializationInfo then
        local ok, spec = pcall(GetSpecialization)
        spec = ok and Num(spec)
        if spec and spec > 0 then
            local _, _, name, _, _, specRole = pcall(GetSpecializationInfo, spec)
            local role, n = fromName(name)
            if role then return role, n end
            specRole = Str(specRole)
            if specRole == "HEALER" then return "healer", n end
            if specRole == "TANK" then return "tank", n end
        end
    end
    if GetNumTalentTabs and GetTalentTabInfo then
        local best, bestPts
        for i = 1, (Num(GetNumTalentTabs()) or 0) do
            local r = { pcall(GetTalentTabInfo, i) }
            if r[1] then
                -- Classic: name, icon, points. Later clients: id, name, description, icon, points.
                local name, pts
                if type(r[2]) == "number" then name, pts = r[3], r[6] else name, pts = r[2], r[4] end
                name, pts = Str(name), Num(pts)
                if name and pts and pts > 0 and (not bestPts or pts > bestPts) then best, bestPts = name, pts end
            end
        end
        local role, n = fromName(best)
        if role then return role, n end
    end
    local groupRole = Str(UnitGroupRolesAssigned and UnitGroupRolesAssigned("player"))
    if groupRole == "HEALER" then return "healer" end
    if groupRole == "TANK" then return "tank" end
    if groupRole == "DAMAGER" then return class == "PALADIN" and "melee" or "caster" end
    return nil
end

-- Stat priority without your override: by role for hybrids, else by class
function TO:AutoStatPriority()
    local class = self:PlayerClass()
    local roles = self.ROLE_STATS[class]
    if roles then
        local role, name = self:PlayerSpecRole()
        if role and roles[role] then return roles[role], role, name end
    end
    return self.CLASS_STATS[class] or { "sta", "spi" }
end

function TO:StatPriority()
    local base = self:AutoStatPriority()
    local focus = self.char.statFocus
    if not focus then return base end
    local list = { focus }
    for _, k in ipairs(base) do if k ~= focus then list[#list + 1] = k end end
    return list
end

-- The whole tooltip of an item as lowercase text (nil if the game hasn't loaded it yet)
local scanTip
local function TooltipText(id)
    local lines = {}
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            for _, l in ipairs(data.lines) do
                local t = Str(l.leftText)
                if t then lines[#lines + 1] = t end
            end
        end
    end
    if #lines == 0 and CreateFrame and GameTooltip then
        scanTip = scanTip or CreateFrame("GameTooltip", "ToppedOffForeverScanTip", nil, "GameTooltipTemplate")
        pcall(function()
            scanTip:SetOwner(UIParent, "ANCHOR_NONE")
            scanTip:ClearLines()
            scanTip:SetHyperlink("item:" .. id)
            for i = 1, (Num(scanTip:NumLines()) or 0) do
                local fs = _G["ToppedOffForeverScanTipTextLeft" .. i]
                local t = fs and Str(fs:GetText())
                if t then lines[#lines + 1] = t end
            end
        end)
    end
    if #lines == 0 then return nil end
    return table.concat(lines, "\n"):lower()
end

-- What an item is good for: { food = amount, water = ..., bandage = ..., healing = ...,
-- mana = ..., stats = { sta = 6, spi = 6 } (stat food), level = required level }
local itemKinds = {}
-- Recipes, patterns and the like show the tooltip of what they make, so they'd
-- look like food or potions. They're never tracked.
local RECIPE_PREFIXES = { "recipe:", "pattern:", "plans:", "schematic:", "formula:", "manual:", "design:" }
local function IsRecipeName(name)
    name = (name or ""):lower()
    for _, p in ipairs(RECIPE_PREFIXES) do
        if name:sub(1, #p) == p then return true end
    end
    return false
end

local function IsRecipe(id, text)
    if IsRecipeName(ItemName(id)) then return true end
    if C_Item and C_Item.GetItemInfoInstant then
        local classID = Num(select(6, C_Item.GetItemInfoInstant(id)))
        if classID == 9 then return true end   -- Recipe item class
    end
    return text:find("teaches you", 1, true) ~= nil
end
TO.IsRecipe = IsRecipe

function TO:ItemKind(id)
    if itemKinds[id] then return itemKinds[id] end
    local text = TooltipText(id)
    if not text then return nil end   -- not loaded yet; try again next scan
    local k = { level = tonumber(text:match("requires level (%d+)")) or 0 }
    if IsRecipe(id, text) then
        itemKinds[id] = k   -- nothing it's good for
        return k
    end
    local wellFed = text:match("well fed(.*)")
    if wellFed then
        local stats, any = {}, false
        for n, a, b in wellFed:gmatch("(%d+) (%a+) and (%a+)") do
            if STAT_WORDS[a] and STAT_WORDS[b] then
                stats[STAT_WORDS[a]], stats[STAT_WORDS[b]] = tonumber(n), tonumber(n); any = true
            end
        end
        for n, w in wellFed:gmatch("(%d+) (%a+)") do
            if STAT_WORDS[w] and not stats[STAT_WORDS[w]] then stats[STAT_WORDS[w]] = tonumber(n); any = true end
        end
        local mp5 = wellFed:match("(%d+) mana every 5") or wellFed:match("(%d+) mana per 5")
        if mp5 then stats.mp5 = tonumber(mp5); any = true end
        -- Spell power and healing foods (Burning Crusade style wording)
        local sp = wellFed:match("(%d+) spell damage") or wellFed:match("(%d+) spell power")
            or wellFed:match("spell damage[^%d]*(%d+)") or wellFed:match("spell power[^%d]*(%d+)")
        if sp then stats.sp = tonumber(sp); any = true end
        local heal = wellFed:match("(%d+) bonus healing") or wellFed:match("(%d+) healing")
            or wellFed:match("healing done[^%d]*(%d+)")
        if heal then stats.heal = tonumber(heal); any = true end
        if any then k.stats = stats end
    end
    local hp = text:match("restores (%d+) health over")
    local mp = text:match("restores (%d+) mana over")
    if hp and text:find("eating", 1, true) and not k.stats then k.food = tonumber(hp) end
    if mp and text:find("drinking", 1, true) then k.water = tonumber(mp) end
    local bandage = text:match("heals (%d+) damage over")
    if bandage then k.bandage = tonumber(bandage) end
    -- Potions: "Restores 140 to 180 health." Rejuvenation-style potions (both) are skipped.
    local hLo, hHi = text:match("restores (%d+) to (%d+) health")
    local mLo, mHi = text:match("restores (%d+) to (%d+) mana")
    if hLo and not mLo then k.healing = (tonumber(hLo) + tonumber(hHi)) / 2 end
    if mLo and not hLo then k.mana = (tonumber(mLo) + tonumber(mHi)) / 2 end
    itemKinds[id] = k
    return k
end

-- How good an item is for a slot (nil = not that kind of item)
function TO:AutoScore(slot, k)
    if slot == "statfood" then
        if not k.stats then return nil end
        local prio = self:StatPriority()
        for i, stat in ipairs(prio) do
            if k.stats[stat] then return (#prio - i + 1) * 1000 + k.stats[stat] end
        end
        return 0
    end
    return k[slot]
end

-- Picks the best item in your bags for each slot; better items replace worse ones
function TO:UpdateAutoItems()
    local level = Num(UnitLevel("player")) or 60
    -- Spec or stat choice changed: pick the stat food again
    -- (the tracked stat food is re-scored below, so a better match takes over)
    local basis = table.concat(self:StatPriority(), ",")
    local rescore = self.char.statBasis ~= basis
    self.char.statBasis = basis
    local hasMana = self.MANA_CLASSES[self:PlayerClass()]
    for _, slot in ipairs(self.AUTO_SLOTS) do
        if not slot.mana or hasMana then
            local best, bestScore
            for _, e in pairs(self.bag or {}) do
                -- Conjured items can't be bought, so they're not tracked here (Mages: see conjures)
                local k = not IsConjured(e.name) and self:ItemKind(e.id)
                if k and k.level <= level then
                    local score = self:AutoScore(slot.key, k)
                    if score and (not bestScore or score > bestScore
                        or (score == bestScore and e.id > best.id)) then
                        best, bestScore = e, score
                    end
                end
            end
            local cur = self.char.auto[slot.key]
            -- A tracked item that doesn't qualify any more (like a recipe picked by an
            -- older version) is dropped; your Min is kept for the next pick
            local curKind = cur and itemKinds[cur.id]
            if cur and (IsRecipeName(cur.name) or (curKind and self:AutoScore(slot.key, curKind) == nil)) then
                if cur.min then self.char.autoMins[slot.key] = cur.min end
                self.char.auto[slot.key] = nil
                cur = nil
            end
            if cur and rescore and slot.key == "statfood" then
                local k = itemKinds[cur.id]
                cur.score = k and self:AutoScore("statfood", k) or 0
            end
            if best and (not cur or cur.id ~= best.id) and (not cur or bestScore > (cur.score or 0)
                or not self:StillGood(cur, level)) then
                self.char.auto[slot.key] = { name = best.name, id = best.id, score = bestScore,
                    min = cur and cur.min or self.char.autoMins[slot.key] or slot.min }
            elseif cur and best and cur.id == best.id then
                cur.score = bestScore
            end
        end
    end
end

-- A tracked item you've outgrown (or can no longer use) gives way to anything in your bags
function TO:StillGood(cur, level)
    local k = itemKinds[cur.id]
    return not k or k.level <= level
end

-- Stat focus changed: pick the stat food again
-- You picked a stat: choose the stat food again (your Min is kept)
function TO:SetStatFocus(focus)
    self.char.statFocus = focus
    local old = self.char.auto.statfood
    if old and old.min then self.char.autoMins.statfood = old.min end
    self.char.auto.statfood = nil
    self:RequestUpdate()
end

---------------------------------------------------------------------------
-- Group, pet, elixir, soulstone and bag checks
---------------------------------------------------------------------------
TO.CHARGES_DEFAULT_MIN = 10   -- poison charges
TO.BAGS_DEFAULT_MIN = 3       -- free bag slots
TO.PET_FOOD_DEFAULT_MIN = 20
TO.PET_CLASSES = { HUNTER = true, WARLOCK = true }
TO.WARLOCK_PETS = { "Summon Imp", "Summon Voidwalker", "Summon Succubus", "Summon Felhunter" }
TO.HAPPINESS = { "unhappy", "content", "happy" }
TO.SOULSTONE_SPELLS = { "Create Soulstone (Major)", "Create Soulstone (Greater)", "Create Soulstone",
    "Create Soulstone (Lesser)", "Create Soulstone (Minor)" }

-- A value the game let us read, or nil when it's hidden (secret)
local function Plain(v)
    if IsSecret(v) then return nil end
    return v
end

-- Your party (your own subgroup in a raid): party1 to party4
local function PartyUnits()
    local out = {}
    if not IsInGroup() then return out end
    for i = 1, 4 do
        local u = "party" .. i
        if Plain(UnitExists(u)) then out[#out + 1] = u end
    end
    return out
end

-- Party, or the whole raid (minus you) when "Check the whole raid" is on
function TO:GroupUnits()
    if IsInRaid and IsInRaid() and self.char.wholeRaid then
        local out = {}
        for i = 1, (Num(GetNumGroupMembers()) or 0) do
            local u = "raid" .. i
            local me = UnitIsUnit(u, "player")
            if Plain(UnitExists(u)) and not (not IsSecret(me) and me) then out[#out + 1] = u end
        end
        return out, true
    end
    return PartyUnits(), false
end

local function HasAnyAura(buffs, names)
    for _, n in ipairs(names) do
        if buffs[n:lower()] then return true end
    end
    return false
end

-- Party members missing one of your group buffs. Click buffs the next one in range.
function TO:CheckPartyBuffs(list)
    local units, raid = self:GroupUnits()
    if #units == 0 then return end
    for _, buff in ipairs(self.CLASS_BUFFS[self:PlayerClass()] or {}) do
        local id = "party:" .. buff.id
        local spell = buff.party and self:BuffPreference(buff)
        if spell and self:IsEnabled(id, not buff.off) then
            local names, target = {}, nil
            for _, u in ipairs(units) do
                local usable = Plain(UnitIsConnected(u)) ~= false and Plain(UnitIsDeadOrGhost(u)) ~= true
                    and Plain(UnitIsVisible(u)) ~= false
                if usable and buff.skip then
                    local _, cls = UnitClass(u)
                    cls = Str(cls)
                    if cls and buff.skip[cls] then usable = false end   -- no use to them
                end
                local b = usable and self:UnitBuffs(u)
                if b and not HasAnyAura(b, buff.auras or buff.cast) then
                    names[#names + 1] = Str(UnitName(u)) or u
                    if not target and Plain(UnitInRange(u)) ~= false then target = u end
                end
            end
            if #names > 0 then
                local r = { id = id, label = buff.label .. (raid and " (raid)" or " (party)"), icon = SpellIcon(spell),
                    text = tostring(#names), detail = "Missing on: " .. table.concat(names, ", ") }
                if target then
                    r.action = { spell = spell, unit = target }
                    r.clickText = "Click to cast " .. spell .. " on " .. (Str(UnitName(target)) or "them")
                else
                    r.detail = r.detail .. "\nNobody missing it is in range"
                end
                list[#list + 1] = r
            end
        end
    end
end

-- Paladin: the blessing each class in your party should have
TO.BLESSING_CLASSES = { "WARRIOR", "ROGUE", "HUNTER", "DRUID", "SHAMAN", "PALADIN", "PRIEST", "MAGE", "WARLOCK" }
TO.CLASS_PLURALS = { WARRIOR = "Warriors", ROGUE = "Rogues", HUNTER = "Hunters", DRUID = "Druids",
    SHAMAN = "Shamans", PALADIN = "Paladins", PRIEST = "Priests", MAGE = "Mages", WARLOCK = "Warlocks" }
TO.BLESSING_NAMES = { "Kings", "Might", "Wisdom", "Salvation", "Light", "Sanctuary" }
-- Might for melee, Wisdom for mana users (Might doesn't help a Hunter's ranged attacks)
TO.BLESSING_DEFAULTS = { WARRIOR = "Might", ROGUE = "Might" }

-- The blessing spell for a class, or nil for none. Falls back if yours isn't learned.
function TO:BlessingFor(class)
    local pick = self.char.blessings[class]
    if pick == "none" then return nil end
    local want = pick or self.BLESSING_DEFAULTS[class] or "Wisdom"
    for _, b in ipairs({ want, self.BLESSING_DEFAULTS[class] or "Wisdom", "Might", "Wisdom" }) do
        if self:Knows("Blessing of " .. b) then return "Blessing of " .. b end
    end
    return nil
end

function TO:CheckPartyBlessings(list)
    if self:PlayerClass() ~= "PALADIN" or not self:IsEnabled("party:blessing", true) then return end
    local units, raid = self:GroupUnits()
    if #units == 0 then return end
    local names, target, targetSpell, anySpell = {}, nil, nil, nil
    for _, u in ipairs(units) do
        local usable = Plain(UnitIsConnected(u)) ~= false and Plain(UnitIsDeadOrGhost(u)) ~= true
            and Plain(UnitIsVisible(u)) ~= false
        local _, cls = UnitClass(u)
        cls = usable and Str(cls)   -- hidden class: can't tell which blessing, skip
        local spell = cls and self:BlessingFor(cls)
        local b = spell and self:UnitBuffs(u)
        if b and not (b[spell:lower()] or b[("Greater " .. spell):lower()]) then
            anySpell = anySpell or spell
            names[#names + 1] = (Str(UnitName(u)) or u) .. " (" .. spell:gsub("^Blessing of ", "") .. ")"
            if not target and Plain(UnitInRange(u)) ~= false then target, targetSpell = u, spell end
        end
    end
    if #names == 0 then return end
    local r = { id = "party:blessing", label = raid and "Blessings (raid)" or "Blessings (party)",
        icon = SpellIcon(targetSpell or anySpell),
        text = tostring(#names), detail = "Missing: " .. table.concat(names, ", ") }
    if target then
        r.action = { spell = targetSpell, unit = target }
        r.clickText = "Click to cast " .. targetSpell .. " on " .. (Str(UnitName(target)) or "them")
    else
        r.detail = r.detail .. "\nNobody missing one is in range"
    end
    list[#list + 1] = r
end

-- Elixirs and flasks: the ones you picked in the options, tracked like buffs
function TO:BagElixirs()
    local out = {}
    for _, e in pairs(self.bag or {}) do
        local n = e.name:lower()
        if n:find("elixir", 1, true) or n:find("flask", 1, true) then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Buff names an elixir can give: its own name, its spell's name, and "Flask of X" -> "X"
function TO:ElixirAuras(name, id)
    local auras = { name }
    if id and C_Item and C_Item.GetItemSpell then
        local spell = Str((C_Item.GetItemSpell(id)))
        if spell and spell:lower() ~= name:lower() then auras[#auras + 1] = spell end
    end
    local short = name:match("^Flask of (.+)$") or name:match("^Elixir of (.+)$")
    if short then auras[#auras + 1] = short end
    return auras
end

function TO:IsElixirTracked(name)
    for i, el in ipairs(self.char.elixirs) do
        if el.name:lower() == name:lower() then return true, i end
    end
    return false
end

function TO:TrackElixir(name, on)
    local tracked, i = self:IsElixirTracked(name)
    if on and not tracked then
        local e = self.bag and self.bag[name:lower()]
        table.insert(self.char.elixirs, { name = name, id = e and e.id, auras = self:ElixirAuras(name, e and e.id) })
    elseif not on and tracked then
        table.remove(self.char.elixirs, i)
    end
    self:RequestUpdate()
end

function TO:CheckElixirs(list)
    if #self.char.elixirs == 0 then return end
    if self.char.elixirInstanceOnly and not self:InInstance() then return end
    local warn = self.db.warnMinutes * 60
    for _, el in ipairs(self.char.elixirs) do
        local left
        for _, aura in ipairs(el.auras or { el.name }) do
            local l = self.buffs[aura:lower()]
            if l and (not left or l == 0 or l > left) then left = l end
        end
        if not left or (left > 0 and left < warn) then
            local r = { id = "elixir:" .. el.name:lower(), label = el.name,
                detail = left and ("Runs out in " .. FormatTime(left)) or "Missing" }
            if left then r.text, r.expires = FormatTime(left), left end
            local e = self.bag and self.bag[el.name:lower()]
            if e then
                r.icon = e.icon or ItemIcon(e.id)
                r.action = { use = "item:" .. e.id, useName = e.name }
                r.detail = r.detail .. "\n" .. e.count .. " in your bags"
            else
                r.icon = (el.id and ItemIcon(el.id)) or self.ICONS.unknown
                r.noItem = el.name
                r.detail = r.detail .. "\nNo " .. el.name .. " in your bags"
            end
            list[#list + 1] = r
        end
    end
end

-- Pets: Hunter and Warlock pet out (and alive); Hunter pet happiness and food
function TO:PetSummonSpell()
    if self:PlayerClass() == "HUNTER" then return self:Knows("Call Pet") and "Call Pet" or nil end
    local known = self:KnownOptions(self.WARLOCK_PETS)
    for _, n in ipairs(known) do
        if n == self.char.prefs.pet then return n end
    end
    return known[1]
end

function TO:CheckPet(list)
    local class = self:PlayerClass()
    if not self.PET_CLASSES[class] then return end
    if (IsMounted and Plain(IsMounted())) or (UnitOnTaxi and Plain(UnitOnTaxi("player")))
        or Plain(UnitIsDeadOrGhost("player")) then return end
    local exists = Plain(UnitExists("pet")) and true or false
    local dead = exists and Plain(UnitIsDead("pet")) and true or false

    local resting = IsResting and Plain(IsResting())
    if (not exists or dead) and not resting and self:IsEnabled("pet:summon", true) then
        local spell = self:PetSummonSpell()
        if spell then
            local r = { id = "pet:summon", label = dead and "Pet is dead" or "No pet", detail = "Missing" }
            if class == "HUNTER" then
                r.icon = SpellIcon(dead and "Revive Pet" or "Call Pet")
                r.action = { macro = "/cast [@pet,dead] Revive Pet; [nopet] Call Pet" }
                r.clickText = dead and "Click to cast Revive Pet" or "Click to cast Call Pet"
                r.detail = dead and "Your pet is dead" or "Your pet isn't out"
            else
                r.label = dead and "Demon is dead" or "No demon"
                r.icon = SpellIcon(spell)
                r.action = { spell = spell }
                r.detail = "Your demon isn't out"
            end
            list[#list + 1] = r
        end
    end

    if class ~= "HUNTER" then return end
    local foodName = self.char.petFood or ""
    local food = foodName ~= "" and self:FindBagItem(foodName) or nil
    if exists and not dead and GetPetHappiness and self:IsEnabled("pet:happy", true) then
        local h = Num(GetPetHappiness())
        if h and h < 3 then
            local r = { id = "pet:happy", label = "Pet is " .. (self.HAPPINESS[h] or "hungry"), icon = self.ICONS.happy,
                text = h == 1 and "!" or nil, urgentNow = h == 1,
                detail = "Feed your pet to make it happy again" }
            if food then
                r.icon = food.icon or r.icon
                r.action = { macro = "/cast Feed Pet\n/use " .. food.name }
                r.clickText = "Click to feed it " .. food.name
            else
                r.action = { macro = "/cast Feed Pet" }
                r.clickText = "Click to cast Feed Pet, then click the food. Set a pet food in the options to feed in one click."
            end
            list[#list + 1] = r
        end
    end
    if foodName ~= "" and self:IsEnabled("pet:food", true) then
        local have = food and food.count or 0
        local min = self:ReagentMin("pet:food", self.PET_FOOD_DEFAULT_MIN)
        if have < min then
            list[#list + 1] = { id = "pet:food", label = "Pet food: " .. (food and food.name or foodName),
                icon = food and food.icon or self:ItemIconByName(foodName), text = have .. "/" .. min, low = true,
                detail = ("%d in your bags (want %d)"):format(have, min) }
        end
    end
end

-- Warlock: nobody in the group has a Soulstone
function TO:CheckSoulstone(list)
    if self:PlayerClass() ~= "WARLOCK" or not IsInGroup() then return end
    if not self:IsEnabled("soulstone", true) then return end
    if self.char.soulstoneInstanceOnly and not self:InInstance() then return end
    local create = self:FirstKnown(self.SOULSTONE_SPELLS)
    if not create then return end
    if (self.buffs or {})["soulstone resurrection"] then return end
    local healer
    for _, u in ipairs((self:GroupUnits())) do
        local b = self:UnitBuffs(u)
        if not b then return end   -- hidden: can't tell, so don't nag
        if b["soulstone resurrection"] then return end
        if not healer and Plain(UnitGroupRolesAssigned and UnitGroupRolesAssigned(u)) == "HEALER" then healer = u end
    end
    local r = { id = "soulstone", label = "Soulstone", icon = self.ICONS.soulstone,
        detail = "Nobody in your group has a Soulstone" }
    local stone = self:FindBagItem("Soulstone")
    if stone then
        local who = healer or "target"
        r.icon = stone.icon or r.icon
        r.action = { macro = "/use [@" .. who .. ",help,nodead] " .. stone.name }
        r.clickText = healer and ("Click to put " .. stone.name .. " on " .. (Str(UnitName(healer)) or "your healer"))
            or ("Click to use " .. stone.name .. " on your friendly target")
    else
        r.action = { spell = create }
        r.clickText = "Click to cast " .. create
        r.detail = r.detail .. "\nNo Soulstone in your bags"
    end
    list[#list + 1] = r
end

-- Free bag slots (ordinary bags only, not quivers or soul bags)
function TO:FreeBagSlots()
    local free = 0
    for b = 0, NUM_BAG_SLOTS or 4 do
        local n, family
        if C_Container and C_Container.GetContainerNumFreeSlots then
            n, family = C_Container.GetContainerNumFreeSlots(b)
        elseif GetContainerNumFreeSlots then
            n, family = GetContainerNumFreeSlots(b)
        end
        n, family = Num(n), Num(family)
        if n and (not family or family == 0) then free = free + n end
    end
    return free
end

function TO:CheckBags(list)
    if not self:IsEnabled("bags", true) then return end
    local free = self:FreeBagSlots()
    local min = self:ReagentMin("bags", self.BAGS_DEFAULT_MIN)
    if free < min then
        list[#list + 1] = { id = "bags", label = "Bag space", icon = self.ICONS.bags, text = tostring(free),
            detail = ("%d free bag slots (want %d)"):format(free, min), openBags = true,
            clickText = "Click to open your bags", urgentNow = free == 0, low = true }
    end
end

-- Mage: conjured water, food and mana gem. Click to conjure.
TO.CONJURES = {
    { key = "water", label = "Conjured water", spell = "Conjure Water", min = 20 },
    { key = "food",  label = "Conjured food",  spell = "Conjure Food",  min = 20 },
}
TO.MANA_GEMS = {   -- best first
    { spell = "Conjure Mana Ruby", item = "Mana Ruby" },
    { spell = "Conjure Mana Citrine", item = "Mana Citrine" },
    { spell = "Conjure Mana Jade", item = "Mana Jade" },
    { spell = "Conjure Mana Agate", item = "Mana Agate" },
}

-- How many conjured water (or food) you have, and one of them for the icon
function TO:ConjuredCount(key)
    local total, icon = 0, nil
    for key2, e in pairs(self.bag or {}) do
        if IsConjured(key2) then
            local water = key2:find("water", 1, true) ~= nil
            local gem = key2:find("mana ", 1, true) ~= nil
            if (key == "water" and water) or (key == "food" and not water and not gem) then
                total = total + e.count
                icon = icon or e.icon
            end
        end
    end
    return total, icon
end

function TO:CheckConjures(list)
    if self:PlayerClass() ~= "MAGE" then return end
    for _, cj in ipairs(self.CONJURES) do
        local id = "conjure:" .. cj.key
        if self:Knows(cj.spell) and self:IsEnabled(id, true) then
            local have, icon = self:ConjuredCount(cj.key)
            local min = self:ReagentMin(id, cj.min)
            if have < min then
                list[#list + 1] = { id = id, label = cj.label, icon = icon or SpellIcon(cj.spell),
                    text = have .. "/" .. min, low = true, action = { spell = cj.spell },
                    detail = ("%d in your bags (want %d)"):format(have, min) }
            end
        end
    end
    if self:IsEnabled("conjure:gem", true) then
        for _, g in ipairs(self.MANA_GEMS) do
            if self:Knows(g.spell) then
                if not (self.bag and self.bag[g.item:lower()]) then
                    list[#list + 1] = { id = "conjure:gem", label = g.item, icon = SpellIcon(g.spell),
                        action = { spell = g.spell }, detail = "No " .. g.item .. " in your bags" }
                end
                break
            end
        end
    end
end

-- Healthstones: Warlocks make their own; everyone else is reminded in dungeons
-- when a Warlock is in the group
TO.HEALTHSTONE_SPELLS = { "Create Healthstone (Major)", "Create Healthstone (Greater)", "Create Healthstone",
    "Create Healthstone (Lesser)", "Create Healthstone (Minor)" }
TO.ICONS.healthstone = "Interface\\Icons\\INV_Stone_04"

function TO:CheckHealthstone(list)
    if self:FindBagItem("Healthstone") then return end
    if self:PlayerClass() == "WARLOCK" then
        local create = self:FirstKnown(self.HEALTHSTONE_SPELLS)
        if create and self:IsEnabled("healthstone", true) then
            list[#list + 1] = { id = "healthstone", label = "Healthstone", icon = SpellIcon(create),
                action = { spell = create }, detail = "No Healthstone in your bags" }
        end
        return
    end
    if not self:IsEnabled("healthstone", true) or not self:InInstance() then return end
    for _, u in ipairs((self:GroupUnits())) do
        local _, cls = UnitClass(u)
        if Str(cls) == "WARLOCK" then
            list[#list + 1] = { id = "healthstone", label = "Healthstone", icon = self.ICONS.healthstone,
                detail = "No Healthstone in your bags. Ask " .. (Str(UnitName(u)) or "your Warlock") .. " for one." }
            return
        end
    end
end

-- Well Fed: the stat buff from food. Click the icon to eat your stat food.
TO.WELL_FED_AURAS = { "well fed", "increased agility", "increased intellect", "increased stamina",
    "increased strength", "increased spirit", "mana regeneration" }
TO.EATING_AURAS = { "food", "food & drink", "refreshment" }

function TO:CheckWellFed(list)
    local id = "wellfed"
    if not self:IsEnabled(id, true) then return end
    if self.char.wellFedInstanceOnly and not self:InInstance() then return end
    local buffs = self.buffs or {}
    for _, a in ipairs(self.EATING_AURAS) do
        if buffs[a] then return end   -- eating right now
    end
    local left
    for _, a in ipairs(self.WELL_FED_AURAS) do
        local l = buffs[a]
        if l and (not left or l == 0 or l > left) then left = l end
    end
    local warn = self.db.warnMinutes * 60
    if left and (left == 0 or left >= warn) then return end

    local food = self.char.auto.statfood
    local r = { id = id, label = "Well Fed", icon = self.ICONS.wellFed }
    if left then
        r.text = FormatTime(left)
        r.detail = "Runs out in " .. FormatTime(left)
        r.expires = left
    else
        r.detail = "Missing"
    end
    local e = food and self.bag and self.bag[food.name:lower()]
    if e then
        r.icon = e.icon or ItemIcon(e.id) or r.icon
        r.action = { use = "item:" .. e.id, useName = e.name }
        r.detail = r.detail .. "\nEat " .. e.name .. " (" .. e.count .. " in your bags)"
    else
        r.noItem = food and food.name or "stat food"
        if food then r.icon = ItemIcon(food.id) or r.icon end
        r.detail = r.detail .. "\nNo " .. r.noItem .. " in your bags"
    end
    list[#list + 1] = r
end

function TO:CheckAutoItems(list)
    local hasMana = self.MANA_CLASSES[self:PlayerClass()]
    local own = {}
    for _, c in ipairs(self.char.custom) do own[c.name:lower()] = true end
    for _, slot in ipairs(self.AUTO_SLOTS) do
        local a = self.char.auto[slot.key]
        local id = "auto:" .. slot.key
        -- Skip items you've also added yourself, so they don't show twice
        if a and (not slot.mana or hasMana) and self:IsEnabled(id, true) and not own[a.name:lower()] then
            local have, icon = self:BagCount({ a.name })
            local min = a.min or slot.min
            local low = have < min
            if low or self.char.customAlways then
                local r = { id = id, label = a.name, icon = icon or ItemIcon(a.id) or self:ItemIconByName(a.name),
                    text = have .. "/" .. min, low = low, stocked = not low, ownItem = true,
                    detail = (low and ("%d in your bags (want %d)"):format(have, min)
                        or ("%d in your bags. Topped off."):format(have)) .. "\nAuto-tracked: best " .. slot.label:lower() }
                local e = self.bag[a.name:lower()]
                if e then r.action = { use = "item:" .. e.id, useName = e.name } end
                list[#list + 1] = r
            end
        end
    end
end

---------------------------------------------------------------------------
-- Your characters: each one's settings are kept in the account-wide save too,
-- so another character can copy them.
---------------------------------------------------------------------------
TO.COPY_FIELDS = { "checks", "checksOutside", "splitProfiles", "prefs", "mins", "weapon", "custom",
    "customAlways", "statFocus", "wellFedInstanceOnly", "elixirs", "elixirInstanceOnly",
    "soulstoneInstanceOnly", "petFood", "blessings", "wholeRaid", "restockAtVendor", "repairAtVendor" }

local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = DeepCopy(x) end
    return t
end

function TO:CharacterKey()
    local name = Str(UnitName("player")) or "?"
    local realm = GetRealmName and Str(GetRealmName()) or nil
    return realm and (name .. " - " .. realm) or name
end

function TO:RegisterCharacter()
    self.db.chars = self.db.chars or {}
    -- The same table as this character's own save, so it's always current
    self.db.chars[self:CharacterKey()] = { class = self:PlayerClass(), settings = self.char }
end

-- Other characters you've logged in with, sorted by name
function TO:OtherCharacters()
    local out, me = {}, self:CharacterKey()
    for key, info in pairs(self.db.chars or {}) do
        if key ~= me and type(info) == "table" and type(info.settings) == "table" then
            out[#out + 1] = { key = key, class = info.class }
        end
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end

function TO:CopySettingsFrom(key)
    local info = self.db.chars and self.db.chars[key]
    if not info or type(info.settings) ~= "table" or key == self:CharacterKey() then return false end
    for _, field in ipairs(self.COPY_FIELDS) do
        local v = info.settings[field]
        if v ~= nil then self.char[field] = DeepCopy(v) end
    end
    self.char.statFocus = DeepCopy(info.settings.statFocus)   -- Automatic (nil) copies too
    -- Their Min counts for food, water and potions; the items are re-picked from your bags
    local mins = DeepCopy(info.settings.autoMins) or {}
    for slot, a in pairs(info.settings.auto or {}) do
        if type(a) == "table" and a.min and mins[slot] == nil then mins[slot] = a.min end
    end
    self.char.autoMins = mins
    self.char.auto, self.char.statBasis = {}, nil
    self:RequestUpdate()
    return true
end

---------------------------------------------------------------------------
-- Restocking at vendors: what you're short on, matched against what the vendor sells
---------------------------------------------------------------------------
-- { names = { ... }, need = n, label = } for every enabled item below its Min
function TO:RestockNeeds()
    local out = {}
    local function add(names, have, min, label, partial)
        if min and have < min then out[#out + 1] = { names = names, need = min - have, label = label, partial = partial } end
    end
    -- Restocking is getting ready for dungeons, so the dungeon set of checks is used
    local function on(id, default) return self:IsEnabled(id, default, false) end
    local class = self:PlayerClass()
    local level = Num(UnitLevel("player")) or 60
    for _, rg in ipairs(self.CLASS_REAGENTS[class] or {}) do
        local id = "reagent:" .. rg.id
        if on(id, true) and self:FirstKnown(rg.requires) then
            -- Multi-rank reagents: buy the one your level needs
            local names = rg.items
            if rg.buy then
                local pick
                for _, b in ipairs(rg.buy) do if level >= b[2] then pick = b[1] end end
                names = { pick or rg.buy[1][1] }
            end
            add(names, (self:BagCount(rg.items)), self:ReagentMin(id, rg.min), rg.label)
        end
    end
    local own = {}
    for _, c in ipairs(self.char.custom) do own[c.name:lower()] = true end
    local hasMana = self.MANA_CLASSES[class]
    for _, slot in ipairs(self.AUTO_SLOTS) do
        local a = self.char.auto[slot.key]
        if a and (not slot.mana or hasMana) and on("auto:" .. slot.key, true) and not IsConjured(a.name)
            and not own[a.name:lower()] then
            add({ a.name }, (self:BagCount({ a.name })), a.min or slot.min, a.name)
        end
    end
    for _, c in ipairs(self.char.custom) do
        if on("custom:" .. c.name:lower(), true) then
            add({ c.name }, (self:BagCount({ c.name })), c.min, c.name)
        end
    end
    local ammo = Num(GetInventoryItemID("player", 0))
    if ammo and on("ammo", self.AMMO_CLASSES[class] == true) then
        local name = ItemName(ammo)
        if name then
            add({ name }, Num(GetInventoryItemCount("player", 0)) or 0, self:ReagentMin("ammo", self.AMMO_DEFAULT_MIN), name)
        end
    end
    local food = self.char.petFood or ""
    if class == "HUNTER" and food ~= "" and on("pet:food", true) then
        local e = self:FindBagItem(food)
        add({ e and e.name or food }, e and e.count or 0, self:ReagentMin("pet:food", self.PET_FOOD_DEFAULT_MIN),
            e and e.name or food, not e)
    end
    return out
end

-- What this vendor sells: list of { index, name, price, stack, available, icon }
function TO:MerchantItems()
    local items = {}
    local n = Num(GetMerchantNumItems and GetMerchantNumItems()) or 0
    for i = 1, n do
        local name, icon, price, stack, avail, purchasable, extended
        if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
            local info = C_MerchantFrame.GetItemInfo(i)
            if type(info) == "table" then
                name, icon, price, stack, avail, purchasable, extended = info.name, info.texture, info.price,
                    info.stackCount, info.numAvailable, info.isPurchasable, info.hasExtendedCost
            end
        elseif GetMerchantItemInfo then
            local _
            name, icon, price, stack, avail, purchasable, _, extended = GetMerchantItemInfo(i)
        end
        name, price = Str(name), Num(price)
        if name and price and not Plain(extended) and Plain(purchasable) ~= false then
            items[#items + 1] = { index = i, name = name, price = price, stack = math.max(1, Num(stack) or 1),
                available = Num(avail) or -1, icon = icon }
        end
    end
    return items
end

-- Rows to buy: { index, name, lots, count, cost, stack, icon }
function TO:RestockPlan()
    local merchant = self:MerchantItems()
    local byName = {}
    for _, m in ipairs(merchant) do byName[m.name:lower()] = byName[m.name:lower()] or m end
    local plan, used = {}, {}
    for _, need in ipairs(self:RestockNeeds()) do
        local m
        for _, n in ipairs(need.names) do
            m = byName[n:lower()]
            if m then break end
        end
        if not m and need.partial then   -- pet food typed as part of a name
            local text = need.names[1]:lower()
            for _, x in ipairs(merchant) do
                if x.name:lower():find(text, 1, true) then m = x break end
            end
        end
        if m and not used[m.index] then
            used[m.index] = true
            local lots = math.ceil(need.need / m.stack)
            if m.available >= 0 then lots = math.min(lots, m.available) end
            if lots > 0 then
                plan[#plan + 1] = { index = m.index, name = m.name, lots = lots, count = lots * m.stack,
                    cost = lots * m.price, stack = m.stack, icon = m.icon }
            end
        end
    end
    return plan
end

-- Buys the rows (a click on the Restock button). Stacked goods (like arrows sold
-- 200 at a time) are bought one stack per call; single items in batches.
function TO:BuyRestock(plan)
    local money = Num(GetMoney and GetMoney()) or 0
    local bought, skipped = {}, {}
    for _, row in ipairs(plan) do
        if row.skip then   -- luacheck: ignore 542 (unticked: nothing to buy)
        elseif row.cost > money then
            skipped[#skipped + 1] = row.name
        else
            if row.stack == 1 then
                local left = row.lots
                local max = Num(GetMerchantItemMaxStack and GetMerchantItemMaxStack(row.index)) or 20
                max = math.max(1, max)
                while left > 0 do
                    local q = math.min(left, max)
                    BuyMerchantItem(row.index, q)
                    left = left - q
                end
            else
                for _ = 1, row.lots do BuyMerchantItem(row.index) end
            end
            money = money - row.cost
            bought[#bought + 1] = row.count .. " " .. row.name
        end
    end
    if #bought > 0 then Print("bought " .. table.concat(bought, ", ") .. ".") end
    if #skipped > 0 then Print("not enough money for " .. table.concat(skipped, ", ") .. ".") end
    return bought, skipped
end

function TO:ItemIconByName(name)
    if C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(name)
        if icon and not IsSecret(icon) then return icon end
    end
    return self.ICONS.unknown
end

function TO:CheckAmmo(list)
    local id = "ammo"
    if not self:IsEnabled(id, self.AMMO_CLASSES[self:PlayerClass()] == true) then return end
    local ammo = Num(GetInventoryItemID("player", 0))
    if not ammo then return end
    local have = Num(GetInventoryItemCount("player", 0)) or 0
    local min = self:ReagentMin(id, self.AMMO_DEFAULT_MIN)
    if have < min then
        list[#list + 1] = { id = id, label = "Ammo", icon = ItemIcon(ammo) or self.ICONS.ammo,
            text = tostring(have), detail = ("%d left (want %d)"):format(have, min) }
    end
end

function TO:LowestDurability()
    local lowest
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        cur, max = Num(cur), Num(max)
        if cur and max and max > 0 then
            local pct = cur / max * 100
            if not lowest or pct < lowest then lowest = pct end
        end
    end
    return lowest
end

function TO:CheckDurability(list)
    if not self:IsEnabled("durability", true) then return end
    local pct = self:LowestDurability()
    if pct and pct < self.db.durabilityPct then
        list[#list + 1] = { id = "durability", label = "Repair", icon = self.ICONS.durability,
            text = math.floor(pct) .. "%", detail = ("Your most worn item is at %d%%"):format(math.floor(pct)) }
    end
end

-- Reads the game and returns every reminder. Only called out of combat, when your
-- own buffs and bags are readable.
function TO:BuildReminders()
    self:ScanBuffs()
    self:ScanBags()
    local list = {}
    self:UpdateAutoItems()
    -- Row 1: buffs
    self:CheckBuffs(list)
    self:CheckPartyBuffs(list)
    self:CheckPartyBlessings(list)
    self:CheckWeapons(list)
    self:CheckWellFed(list)
    self:CheckElixirs(list)
    self:CheckPet(list)
    self:CheckSoulstone(list)
    -- Row 2: things to top off
    self:CheckReagents(list)
    self:CheckConjures(list)
    self:CheckHealthstone(list)
    self:CheckAutoItems(list)
    self:CheckAmmo(list)
    self:CheckBags(list)
    self:CheckDurability(list)
    return list
end

---------------------------------------------------------------------------
-- Skin helpers (plain textures, so they work without Backdrop templates)
---------------------------------------------------------------------------
function TO:AddBorder(f, color, size)
    size = size or 1
    local edges = {
        { "TOPLEFT", "TOPRIGHT", nil, size },
        { "BOTTOMLEFT", "BOTTOMRIGHT", nil, size },
        { "TOPLEFT", "BOTTOMLEFT", size, nil },
        { "TOPRIGHT", "BOTTOMRIGHT", size, nil },
    }
    f.borders = {}
    for _, e in ipairs(edges) do
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(color[1], color[2], color[3], 1)
        t:SetPoint(e[1])
        t:SetPoint(e[2])
        if e[3] then t:SetWidth(e[3]) else t:SetHeight(e[4]) end
        table.insert(f.borders, t)
    end
end

-- Fills a frame with a color and gives it a border
function TO:SkinFrame(f, bg, border, alpha, size)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(bg[1], bg[2], bg[3], alpha or 0.95)
    f.skinBg = t
    self:AddBorder(f, border or self.COLORS.goldDark, size or 2)
end

---------------------------------------------------------------------------
-- Reminder icons
---------------------------------------------------------------------------
local function Button_OnEnter(self)
    local r = self.reminder
    if not r then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(r.label, unpack(TO.COLORS.gold))
    if r.detail then GameTooltip:AddLine(r.detail, 1, 1, 1, true) end
    if r.clickText then
        GameTooltip:AddLine(r.clickText, 0.4, 1, 0.4)
    elseif r.action and r.action.spell then
        GameTooltip:AddLine("Click to cast " .. r.action.spell, 0.4, 1, 0.4)
    elseif r.action and r.action.use then
        GameTooltip:AddLine("Click to use " .. r.action.useName, 0.4, 1, 0.4)
    elseif r.action and r.action.item then
        GameTooltip:AddLine("Click to use " .. r.action.item .. " on your " ..
            (r.action.slot == 17 and "off hand" or "main hand"), 0.4, 1, 0.4)
    end
    GameTooltip:Show()
end

function TO:CreateButton(i)
    local b = CreateFrame("Button", "ToppedOffForeverButton" .. i, self.bar, "SecureActionButtonTemplate")
    -- Register for both up and down: the secure template acts on only one of them,
    -- chosen by the "Cast action keybinds on key down" setting. With only "AnyUp",
    -- nothing happens when that setting is on.
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetPoint("TOPLEFT", -1, 1)
    b.border:SetPoint("BOTTOMRIGHT", 1, -1)
    local gd = self.COLORS.goldDark
    b.border:SetColorTexture(gd[1], gd[2], gd[3], 1)
    b.text = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.text:SetPoint("BOTTOMLEFT", 1, 2)
    b.text:SetPoint("BOTTOMRIGHT", -1, 2)
    b.text:SetJustifyH("CENTER")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnEnter", Button_OnEnter)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Not a spell or item: the bag space icon opens your bags (once per click)
    b:HookScript("PostClick", function(self, _, down)
        if down then return end
        local r = self.reminder
        if r and r.openBags then
            if ToggleAllBags then ToggleAllBags() elseif OpenAllBags then OpenAllBags() end
        end
    end)
    b:Hide()
    self.buttons[i] = b
    return b
end

-- Secure attributes for a reminder. Casts on yourself, or uses the item on the weapon.
function TO:ActionAttributes(r)
    local a = r.action
    if a and a.macro then
        return { type = "macro", macrotext = a.macro }
    elseif a and a.spell then
        return { type = "spell", spell = a.spell, unit = a.unit or "player" }
    elseif a and a.item then
        return { type = "macro", macrotext = "/use " .. a.item .. "\n/use " .. a.slot }
    elseif a and a.use then
        return { type = "item", item = a.use, unit = "player" }
    end
    return { type = nil }
end

function TO:ApplyButton(b, r)
    b.reminder = r
    local attrs = self:ActionAttributes(r)
    b:SetAttribute("type", attrs.type)
    b:SetAttribute("spell", attrs.spell)
    b:SetAttribute("unit", attrs.unit)
    b:SetAttribute("macrotext", attrs.macrotext)
    b:SetAttribute("item", attrs.item)
    b.icon:SetTexture(r.icon or self.ICONS.unknown)
    if b.icon.SetDesaturated then b.icon:SetDesaturated(r.noItem ~= nil) end
    b.text:SetText(r.text or "")
    -- Running out: orange border at the warning time, red in its last 20%
    local warn = self.db.warnMinutes * 60
    local color, thick = self.COLORS.goldDark, 1
    if r.urgentNow then
        color, thick = self.COLORS.urgent, 3
    elseif r.expires and r.expires > 0 then
        if r.expires <= warn * self.URGENT_SHARE then
            color, thick = self.COLORS.urgent, 3
        else
            color, thick = self.COLORS.expiring, 3
        end
    end
    b.border:SetColorTexture(color[1], color[2], color[3], 1)
    b.border:ClearAllPoints()
    b.border:SetPoint("TOPLEFT", -thick, thick)
    b.border:SetPoint("BOTTOMRIGHT", thick, -thick)
    b.urgency = (color == self.COLORS.urgent and "urgent") or (color == self.COLORS.expiring and "expiring") or nil
    -- Your own items: red count when you're low; dimmed with a white count when
    -- they're only shown for quick use (topped off)
    if r.low then b.text:SetTextColor(1, 0.35, 0.3) else b.text:SetTextColor(1, 1, 1) end
    b.icon:SetAlpha(r.stocked and self.STOCKED_ALPHA or 1)
end

-- Places the icons in a row. Must run out of combat (the icons are secure buttons).
function TO:Layout(list)
    if InCombatLockdown() then self.dirty = true return end
    local size, gap = self.db.iconSize, 4
    local shownList = list
    if self.db.onlyInInstance and not self:InInstance() then shownList = {} end

    -- Row 1: buffs (class buffs, weapon enhancements, Well Fed).
    -- Row 2: things to top off (reagents, ammo, food, water, potions, repair).
    -- A thin gold divider sits between the rows when both have icons.
    local top, bottom = {}, {}
    for _, r in ipairs(shownList) do
        if self:IsBuffReminder(r) then top[#top + 1] = r else bottom[#bottom + 1] = r end
    end
    shownList = {}
    for _, r in ipairs(top) do shownList[#shownList + 1] = r end
    for _, r in ipairs(bottom) do shownList[#shownList + 1] = r end
    -- Each group wraps after "Icons per row"
    local perRow = math.max(1, self.db.iconsPerRow or 8)
    local lines = {}
    local function addGroup(group)
        for i = 1, #group, perRow do
            local line = {}
            for j = i, math.min(i + perRow - 1, #group) do line[#line + 1] = group[j] end
            lines[#lines + 1] = line
        end
    end
    addGroup(top)
    local split = (#top > 0 and #bottom > 0) and #lines or nil   -- divider after this line
    addGroup(bottom)

    -- The divider: a bold gold bar with a dark edge above and below, running
    -- the full width of the frame like the header's bottom line
    if not self.divider then
        local d = self.bar:CreateTexture(nil, "ARTWORK")
        local g = self.COLORS.goldDark
        d:SetColorTexture(g[1], g[2], g[3], 1)
        d:SetHeight(self.DIVIDER_THICKNESS)
        d.edges = {}
        for i = 1, 2 do
            local e = self.bar:CreateTexture(nil, "BORDER")
            e:SetColorTexture(0, 0, 0, 0.8)
            e:SetHeight(1)
            d.edges[i] = e
        end
        self.divider = d
    end
    local idx, y, cols = 0, 0, 0
    for n, line in ipairs(lines) do
        for col, r in ipairs(line) do
            idx = idx + 1
            local b = self.buttons[idx] or self:CreateButton(idx)
            self:ApplyButton(b, r)
            b:SetSize(size, size)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.bar, "TOPLEFT", (col - 1) * (size + gap), y)
            b:Show()
        end
        cols = math.max(cols, #line)
        if n < #lines then
            if n == split then
                self.divider.y = y - size - math.floor((self.DIVIDER_SPACE - self.DIVIDER_THICKNESS) / 2)
                y = y - size - self.DIVIDER_SPACE
            else
                y = y - size - gap
            end
        end
    end
    local height = #lines > 0 and (-y + size) or size
    local slots = math.max(cols, self.MIN_SLOTS)
    local width = math.max(slots * (size + gap) - gap, self.HEADER_MIN_WIDTH)
    local d = self.divider
    d:ClearAllPoints()
    for _, e in ipairs(d.edges) do e:ClearAllPoints() end
    if split then
        local inset = self.FRAME_PAD - 1   -- reach the frame's border on both sides
        d:SetPoint("TOPLEFT", self.bar, "TOPLEFT", -inset, d.y)
        d:SetPoint("TOPRIGHT", self.bar, "TOPRIGHT", inset, d.y)
        d.edges[1]:SetPoint("BOTTOMLEFT", d, "TOPLEFT")
        d.edges[1]:SetPoint("BOTTOMRIGHT", d, "TOPRIGHT")
        d.edges[2]:SetPoint("TOPLEFT", d, "BOTTOMLEFT")
        d.edges[2]:SetPoint("TOPRIGHT", d, "BOTTOMRIGHT")
        d:Show()
        for _, e in ipairs(d.edges) do e:Show() end
    else
        d:Hide()
        for _, e in ipairs(d.edges) do e:Hide() end
    end
    for i = #shownList + 1, #self.buttons do
        local b = self.buttons[i]
        b.reminder = nil
        b:SetAttribute("type", nil)
        b:Hide()
    end
    -- Always room for at least two icons, so the frame keeps one tidy size and only
    -- grows once a third reminder shows up. A second row makes it taller.
    self.main:SetSize(width, height)
    self.bar:SetAllPoints(self.main)
    self.bar:SetShown(#shownList > 0)
    self.shownCount = #shownList
    self:UpdateHeader()
    -- In case the position couldn't be read at login yet
    if self.db.point[1] ~= "TOPLEFT" then self:PinTopLeft() end
end

function TO:InInstance()
    local inside = IsInInstance()
    if IsSecret(inside) then return false end
    return inside and true or false
end

function TO:Update()
    if not self.built then return end
    if InCombatLockdown() then self.dirty = true return end
    self.dirty = false
    self.lastUpdate = GetTime()
    self.reminders = self:BuildReminders()
    self:Layout(self.reminders)
    if self.merchantOpen and self.UpdateVendorPanel then self:UpdateVendorPanel() end
end

function TO:RequestUpdate()
    self.dirty = true
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
-- The frame is pinned by its top-left corner, so when icons come and go the
-- header stays put and the frame grows or shrinks to the right.
function TO:PinTopLeft()
    local left, top = Num(self.main:GetLeft()), Num(self.main:GetTop())
    if not left or not top then return false end
    self.main:ClearAllPoints()
    self.main:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    self.db.point = { "TOPLEFT", "BOTTOMLEFT", left, top }
    return true
end

-- Right-click menu on the "ToppedOff" header (same as TauntMaster Forever's)
function TO:ShowHeaderMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        self:OpenConfig()
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("ToppedOff Forever")
        root:CreateCheckbox("Lock",
            function() return TO.db.locked end,
            function() TO:SetLocked(not TO.db.locked) end)
        root:CreateButton("Settings", function()
            if not (TO.config and TO.config:IsShown()) then TO:OpenConfig() end
        end)
    end)
end

function TO:SavePosition()
    if self:PinTopLeft() then return end
    local p, _, rp, x, y = self.main:GetPoint()
    self.db.point = { p, rp, x, y }
end

function TO:RestorePosition()
    local pt = self.db.point
    self.main:ClearAllPoints()
    self.main:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
    -- Older saves (and the default) use the center: switch to the top-left corner
    if pt[1] ~= "TOPLEFT" then self:PinTopLeft() end
end

function TO:ApplyVisibility()
    local driver
    if not self.db.shown then
        driver = "hide"
    elseif self.db.hideInCombat then
        driver = "[combat] hide; show"
    else
        driver = "show"
    end
    self:RunOutOfCombat(function()
        UnregisterStateDriver(self.main, "visibility")
        RegisterStateDriver(self.main, "visibility", driver)
    end)
    self.driver = driver
end

TO.HEADER_HEIGHT = 22      -- header strip at the top of the frame
TO.HEADER_MIN_WIDTH = 84   -- room for the logo and "ToppedOff"
TO.FRAME_PAD = 4           -- space between the frame's edge and the icons
TO.MIN_SLOTS = 2           -- the frame is always at least two icons wide
TO.DIVIDER_SPACE = 14      -- room between the buff row and the top-off row
TO.DIVIDER_THICKNESS = 4   -- the gold divider line

-- Buffs (row 1) vs things to top off (row 2)
local BUFF_ROW = { "^buff:", "^party:", "^weapon:", "^elixir:", "^wellfed$", "^pet:summon$", "^pet:happy$",
    "^soulstone$" }
function TO:IsBuffReminder(r)
    local id = r.id or ""
    for _, pat in ipairs(BUFF_ROW) do
        if id:find(pat) then return true end
    end
    return false
end
TO.URGENT_SHARE = 0.2      -- red border in the last 20% of the warning time
TO.STOCKED_ALPHA = 0.6     -- topped-off items shown for quick use are dimmed

-- The frame (header + box around the icons) shows while unlocked, so it can be
-- dragged, or whenever there are reminders if "Show header and frame" is on.
function TO:UpdateHeader()
    if not self.box then return end
    local unlocked = not self.db.locked
    self.box:SetShown(unlocked or (self.db.showHeader and (self.shownCount or 0) > 0))
end

function TO:SetLocked(locked)
    self.db.locked = locked
    self:UpdateHeader()
end

function TO:ApplySettings()
    if not self.built then return end
    self:ApplyVisibility()
    self:SetLocked(self.db.locked)
    self:UpdateMinimapButton()
    self:RequestUpdate()
    self:RunOutOfCombat(function() self:Update() end)
end

function TO:BuildFrames()
    local main = CreateFrame("Frame", "ToppedOffForeverFrame", UIParent, "SecureHandlerStateTemplate")
    main:SetSize(self.db.iconSize, self.db.iconSize)
    main:SetMovable(true)
    main:SetClampedToScreen(true)
    self.main = main
    self:RestorePosition()

    local bar = CreateFrame("Frame", "ToppedOffForeverBar", main, "SecureFrameTemplate")
    bar:SetAllPoints(main)
    self.bar = bar
    self.buttons = {}
    -- The first three exist from the start so their keybindings always work
    for i = 1, 3 do self:CreateButton(i) end

    -- One uniform frame around the header and the icons, in the logo's colors.
    -- It sits behind the icons and ignores the mouse, so it never blocks clicks;
    -- only the header strip at the top takes the mouse (drag to move, right-click
    -- for options).
    local pad, headerH = self.FRAME_PAD, self.HEADER_HEIGHT
    local box = CreateFrame("Frame", nil, main)
    box:SetPoint("TOPLEFT", main, "TOPLEFT", -pad, pad + headerH)
    box:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", pad, -pad)
    box:SetFrameLevel(main:GetFrameLevel())   -- behind the icons
    box:EnableMouse(false)
    self:SkinFrame(box, self.COLORS.navy, self.COLORS.goldDark, 0.85, 1)
    self.box = box
    if main.SetClampRectInsets then main:SetClampRectInsets(-pad, pad, pad + headerH, -pad) end

    local header = CreateFrame("Frame", nil, box)
    header:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", box, "TOPRIGHT", -1, -1)
    header:SetHeight(headerH - 2)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    local cr = self.COLORS.crimson
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetColorTexture(cr[1], cr[2], cr[3], 0.95)
    local gd = self.COLORS.goldDark
    header.line = header:CreateTexture(nil, "BORDER")
    header.line:SetPoint("BOTTOMLEFT")
    header.line:SetPoint("BOTTOMRIGHT")
    header.line:SetHeight(1)
    header.line:SetColorTexture(gd[1], gd[2], gd[3], 1)
    header.logo = header:CreateTexture(nil, "OVERLAY")
    header.logo:SetSize(16, 16)
    header.logo:SetPoint("LEFT", 3, 0)
    header.logo:SetTexture(self.ICONS.addon)
    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.text:SetPoint("LEFT", header.logo, "RIGHT", 4, 0)
    header.text:SetText("ToppedOff")
    header.text:SetTextColor(unpack(self.COLORS.gold))
    header:SetScript("OnDragStart", function()
        if TO.db.locked or InCombatLockdown() then return end
        main:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        main:StopMovingOrSizing()
        TO:SavePosition()
    end)
    header:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then TO:ShowHeaderMenu(self) end
    end)
    header:SetScript("OnEnter", function(f)
        GameTooltip:SetOwner(f, "ANCHOR_TOP")
        GameTooltip:AddLine(TO.LOGO_TEXT .. " ToppedOff Forever", unpack(TO.COLORS.gold))
        if not TO.db.locked then
            GameTooltip:AddLine("Drag to move", 1, 1, 1)
            GameTooltip:AddLine("Lock it in the options or with /topoff lock", 1, 1, 1)
        end
        GameTooltip:AddLine("Right-click for options", 1, 1, 1)
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.header = header

    self:BuildMinimapButton()
    self.built = true
    self:ApplySettings()

    C_Timer.NewTicker(1, function() TO:OnTick() end)
end

-- Every second: refresh if something changed, and every 5 seconds anyway so
-- countdowns and "runs out soon" warnings stay current.
function TO:OnTick()
    if InCombatLockdown() then return end
    if self.dirty or not self.lastUpdate or GetTime() - self.lastUpdate >= 5 then
        self:Update()
    end
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
function TO:PositionMinimapButton()
    local angle = math.rad(self.db.minimapAngle or 200)
    local radius = (Minimap:GetWidth() / 2) + 10
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function TO:BuildMinimapButton()
    local b = CreateFrame("Button", "ToppedOffForeverMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(22, 22)
    icon:SetTexture(self.ICONS.addon)
    icon:SetPoint("TOPLEFT", 5, -4)

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then TO:Toggle() else TO:OpenConfig() end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            TO.db.minimapAngle = math.deg(math.atan2(py - my, px - mx))
            TO:PositionMinimapButton()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(TO.LOGO_TEXT .. " ToppedOff Forever")
        GameTooltip:AddLine("Left-click: options", 1, 1, 1)
        GameTooltip:AddLine("Right-click: show/hide reminders", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.minimapButton = b
    self:PositionMinimapButton()
end

function TO:UpdateMinimapButton()
    if self.minimapButton then self.minimapButton:SetShown(self.db.minimap) end
end

---------------------------------------------------------------------------
-- Chat reminders (ready checks, entering a dungeon)
---------------------------------------------------------------------------
function TO:ReminderSummary(list)
    local parts = {}
    for _, r in ipairs(list) do
        local s = r.label
        if r.text then s = s .. " (" .. r.text .. ")" end
        parts[#parts + 1] = s
    end
    return table.concat(parts, ", ")
end

function TO:Remind(reason)
    -- In combat your buffs may be hidden from addons, so use the last check
    local list = self.reminders or {}
    if not InCombatLockdown() then list = self:BuildReminders() end
    -- Items shown only because "always show" is on aren't missing
    local missing = {}
    for _, r in ipairs(list) do if not r.stocked then missing[#missing + 1] = r end end
    list = missing
    if #list == 0 then return end
    Print((reason and (reason .. " — ") or "") .. "missing: " .. self:ReminderSummary(list))
    if self.db.sound and PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.RAID_WARNING) end
end

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------
function TO:SetShown(show)
    self.db.shown = show
    self:ApplyVisibility()
    if InCombatLockdown() then
        Print("Will " .. (show and "show" or "hide") .. " when you leave combat.")
    else
        Print(show and "reminders shown." or "reminders hidden.")
    end
end

function TO:Toggle() self:SetShown(not self.db.shown) end

function TO:AddCustom(name, min)
    name = name and name:match("^%s*(.-)%s*$") or ""
    min = tonumber(min)
    if name == "" or not min or min < 1 then return false end
    min = math.floor(min)
    for _, c in ipairs(self.char.custom) do
        if c.name:lower() == name:lower() then c.min = min self:RequestUpdate() return true end
    end
    table.insert(self.char.custom, { name = name, min = min })
    self:RequestUpdate()
    return true
end

function TO:RemoveCustom(name)
    name = (name or ""):lower():match("^%s*(.-)%s*$")
    for i, c in ipairs(self.char.custom) do
        if c.name:lower() == name then
            table.remove(self.char.custom, i)
            self.char.checks["custom:" .. name] = nil
            self.char.checksOutside["custom:" .. name] = nil
            self:RequestUpdate()
            return true
        end
    end
    return false
end

local function Colored(ok, text)
    return (ok and "|cff40ff40" or "|cffffcc00") .. text .. "|r"
end

-- Lists every check for your class and whether its spell/item was found.
function TO:Check()
    self:ScanSpellbook()
    self:ScanBags()
    local class = self:PlayerClass()
    Print("checks for " .. (Str((UnitClass("player"))) or class) .. ":")
    for _, buff in ipairs(self.CLASS_BUFFS[class] or {}) do
        local spell = self:BuffPreference(buff)
        local on = self:IsEnabled("buff:" .. buff.id, not buff.off)
        if spell then
            print("  " .. Colored(true, buff.label .. ": " .. spell) .. (on and "" or " (off)"))
        else
            print("  " .. Colored(false, buff.label .. ": not learned yet (" .. table.concat(buff.cast, ", ") .. ")"))
        end
    end
    local w = self:WeaponConfig()
    if w.kind == "spell" then
        print("  " .. Colored(w.spell ~= nil, "Weapon buff: " .. (w.spell or "not learned yet")))
    else
        for _, key in ipairs({ "mh", "oh" }) do
            local label = key == "mh" and "Main hand" or "Off hand"
            if w[key] == "" then
                print("  " .. label .. ": not set (optional, set it in /topoff)")
            else
                local item = self:FindBagItem(w[key])
                print("  " .. Colored(item ~= nil, label .. ": " .. w[key] ..
                    (item and (" — found " .. item.name) or " — none in your bags")))
            end
        end
    end
    for _, rg in ipairs(self.CLASS_REAGENTS[class] or {}) do
        if self:FirstKnown(rg.requires) then
            local have = self:BagCount(rg.items)
            local min = self:ReagentMin("reagent:" .. rg.id, rg.min)
            print("  " .. Colored(have >= min, ("%s: %d/%d"):format(rg.label, have, min)))
        end
    end
    for _, c in ipairs(self.char.custom) do
        local have = self:BagCount({ c.name })
        print("  " .. Colored(have >= c.min, ("%s: %d/%d"):format(c.name, have, c.min)))
    end
    local pct = self:LowestDurability()
    if pct then print("  " .. Colored(pct >= self.db.durabilityPct, ("Durability: %d%%"):format(math.floor(pct)))) end
end

local function Help()
    Print("commands:")
    print("  /topoff — open options")
    print("  /topoff show | hide | toggle — show or hide the reminders")
    print("  /topoff lock | unlock — lock or unlock the reminders' position")
    print("  /topoff check — list what's checked for your class")
    print("  /topoff add <count> <item> — remind you when you have fewer than <count> of an item")
    print("  /topoff remove <item> — stop checking an item you added")
    print("  /topoff reset — move the reminders back to the default position")
end

SLASH_TOPPEDOFFFOREVER1 = "/topoff"
SLASH_TOPPEDOFFFOREVER2 = "/toppedoff"
SlashCmdList.TOPPEDOFFFOREVER = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if not TO.built then Print("not ready yet.") return end
    if cmd == "" or cmd == "config" or cmd == "options" then
        TO:OpenConfig()
    elseif cmd == "show" then
        TO:SetShown(true)
    elseif cmd == "hide" then
        TO:SetShown(false)
    elseif cmd == "toggle" then
        TO:Toggle()
    elseif cmd == "lock" or cmd == "unlock" then
        TO:SetLocked(cmd == "lock")
        Print(cmd == "lock" and "locked." or "unlocked — drag the ToppedOff header to move.")
    elseif cmd == "check" then
        TO:Check()
    elseif cmd == "add" then
        local count, name = rest:match("^(%d+)%s+(.+)$")
        if TO:AddCustom(name, count) then
            Print(("will remind you below %d %s."):format(tonumber(count), name))
            if TO.RefreshConfig then TO:RefreshConfig() end
        else
            Print("usage: /topoff add 20 Conjured Crystal Water")
        end
    elseif cmd == "remove" then
        if TO:RemoveCustom(rest) then
            Print("stopped checking " .. rest .. ".")
            if TO.RefreshConfig then TO:RefreshConfig() end
        else
            Print("no added item called \"" .. rest .. "\".")
        end
    elseif cmd == "reset" then
        TO.db.point = { unpack(DEFAULTS.point) }
        TO:RunOutOfCombat(function() TO:RestorePosition() end)
        Print("position reset.")
    else
        Help()
    end
end

-- Keybinding names (Options > Keybindings > ToppedOff Forever)
BINDING_NAME_TOPPEDOFFFOREVER_OPTIONS = "Open options"
for i = 1, 3 do
    _G["BINDING_NAME_CLICK ToppedOffForeverButton" .. i .. ":LeftButton"] = "Fix reminder " .. i
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
events:RegisterEvent("READY_CHECK")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
-- Pet events; guarded in case this client doesn't have them
pcall(events.RegisterUnitEvent, events, "UNIT_PET", "player")
pcall(events.RegisterUnitEvent, events, "UNIT_HAPPINESS", "pet")
-- Talent / spec changes (stat food follows your role)
for _, e in ipairs({ "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        ToppedOffForeverDB = ToppedOffForeverDB or {}
        FillDefaults(ToppedOffForeverDB, DEFAULTS)
        TO.db = ToppedOffForeverDB
        if (TO.db.schema or 0) < 2 then
            if TO.db.iconSize == 36 then TO.db.iconSize = 40 end   -- old default: use the new, larger one
            TO.db.schema = 2
        end
        ToppedOffForeverCharDB = ToppedOffForeverCharDB or {}
        FillDefaults(ToppedOffForeverCharDB, CHAR_DEFAULTS)
        TO.char = ToppedOffForeverCharDB
    elseif event == "PLAYER_LOGIN" then
        TO:RegisterCharacter()
        TO:ScanSpellbook()
        TO:RunOutOfCombat(function() TO:BuildFrames() end)
        print(TO.LOGO_TEXT .. " |cffffd966ToppedOff Forever|r loaded. Type /topoff for options.")
    elseif event == "PLAYER_REGEN_ENABLED" then
        TO:FlushPending()
        TO:RequestUpdate()
    elseif not TO.built then
        return
    elseif event == "SPELLS_CHANGED" then
        TO:ScanSpellbook()
        TO:RequestUpdate()
    elseif event == "READY_CHECK" then
        if TO.db.readyCheck then TO:Remind("Ready check") end
    elseif event == "PLAYER_ENTERING_WORLD" then
        TO:RequestUpdate()
        local inside = TO:InInstance()
        if inside and not TO.wasInInstance and TO.db.instanceReminder then
            C_Timer.After(3, function() TO:Remind("Entering instance") end)
        end
        TO.wasInInstance = inside
    else
        TO:RequestUpdate()
    end
end)
