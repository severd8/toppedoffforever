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
          auras = { "Arcane Intellect", "Arcane Brilliance" } },
        { id = "armor", label = "Armor", cast = { "Ice Armor", "Frost Armor", "Mage Armor" } },
    },
    PRIEST = {
        { id = "fortitude", label = "Power Word: Fortitude", cast = { "Power Word: Fortitude" },
          auras = { "Power Word: Fortitude", "Prayer of Fortitude" } },
        { id = "innerfire", label = "Inner Fire", cast = { "Inner Fire" } },
        { id = "spirit", label = "Divine Spirit", cast = { "Divine Spirit" },
          auras = { "Divine Spirit", "Prayer of Spirit" } },
        { id = "shadowprot", label = "Shadow Protection", cast = { "Shadow Protection" },
          auras = { "Shadow Protection", "Prayer of Shadow Protection" }, off = true },
    },
    DRUID = {
        { id = "motw", label = "Mark of the Wild", cast = { "Mark of the Wild" },
          auras = { "Mark of the Wild", "Gift of the Wild" } },
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
          requires = { "Prayer of Fortitude", "Prayer of Spirit", "Prayer of Shadow Protection" } },
        { id = "feather", label = "Light Feather", items = { "Light Feather" }, min = 5, requires = { "Levitate" } },
    },
    DRUID = {
        { id = "gotw", label = "Gift of the Wild herbs", items = { "Wild Thornroot", "Wild Berries" }, min = 10,
          requires = { "Gift of the Wild" } },
        { id = "seed", label = "Rebirth seed", items = { "Ironwood Seed", "Hornbeam Seed", "Ashwood Seed",
          "Stranglethorn Seed", "Maple Seed" }, min = 2, requires = { "Rebirth" } },
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
    customAlways = false,     -- show your own items even when you have enough
    auto = {},                -- auto-tracked best items: slot -> { name, id, score, min }
    statFocus = nil,          -- stat food override ("str", "agi", ...); nil = class default
    wellFedInstanceOnly = true, -- Well Fed reminder only in dungeons and raids
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

function TO:IsEnabled(id, default)
    local v = self.char.checks[id]
    if v == nil then return default ~= false end
    return v
end

function TO:SetEnabled(id, on)
    self.char.checks[id] = on and true or false
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
    local hasMH, mhExp, _, _, hasOH, ohExp = GetWeaponEnchantInfo()
    local warn = self.db.warnMinutes * 60
    local hands = {
        { key = "mh", slot = 16, label = "Main hand", has = hasMH, exp = mhExp },
        { key = "oh", slot = 17, label = "Off hand", has = hasOH, exp = ohExp },
    }
    for _, h in ipairs(hands) do
        local id = "weapon:" .. h.key
        if self:IsEnabled(id, true) and HasWeapon(h.slot) and not IsSecret(h.has) then
            local left = h.has and (Num(h.exp) or 0) / 1000 or nil
            local needs = (not h.has) or (left and left > 0 and left < warn)
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
                    if h.has then
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
TO.STAT_KEYS = { "str", "agi", "sta", "int", "spi", "mp5" }
TO.STAT_LABELS = { str = "Strength", agi = "Agility", sta = "Stamina", int = "Intellect",
    spi = "Spirit", mp5 = "Mana regen" }
TO.CLASS_STATS = {
    WARRIOR = { "str", "sta", "agi" },
    ROGUE   = { "agi", "str", "sta" },
    HUNTER  = { "agi", "int", "mp5", "sta" },
    MAGE    = { "int", "mp5", "spi", "sta" },
    WARLOCK = { "int", "sta", "spi", "mp5" },
    PRIEST  = { "mp5", "int", "spi", "sta" },
    SHAMAN  = { "mp5", "int", "sta", "str" },
    PALADIN = { "sta", "str", "mp5", "int" },
    DRUID   = { "sta", "agi", "str", "int" },
}
local STAT_WORDS = { strength = "str", agility = "agi", stamina = "sta", intellect = "int", spirit = "spi" }

function TO:StatPriority()
    local base = self.CLASS_STATS[self:PlayerClass()] or { "sta", "spi" }
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
function TO:ItemKind(id)
    if itemKinds[id] then return itemKinds[id] end
    local text = TooltipText(id)
    if not text then return nil end   -- not loaded yet; try again next scan
    local k = { level = tonumber(text:match("requires level (%d+)")) or 0 }
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
    local hasMana = self.MANA_CLASSES[self:PlayerClass()]
    for _, slot in ipairs(self.AUTO_SLOTS) do
        if not slot.mana or hasMana then
            local best, bestScore
            for _, e in pairs(self.bag or {}) do
                local k = self:ItemKind(e.id)
                if k and k.level <= level then
                    local score = self:AutoScore(slot.key, k)
                    if score and (not bestScore or score > bestScore
                        or (score == bestScore and e.id > best.id)) then
                        best, bestScore = e, score
                    end
                end
            end
            local cur = self.char.auto[slot.key]
            if best and (not cur or cur.id ~= best.id) and (not cur or bestScore > (cur.score or 0)
                or not self:StillGood(cur, level)) then
                self.char.auto[slot.key] = { name = best.name, id = best.id, score = bestScore,
                    min = cur and cur.min or slot.min }
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
function TO:SetStatFocus(focus)
    self.char.statFocus = focus
    self.char.auto.statfood = nil
    self:RequestUpdate()
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
    self:CheckBuffs(list)
    self:CheckWeapons(list)
    self:UpdateAutoItems()
    self:CheckWellFed(list)
    self:CheckReagents(list)
    self:CheckAutoItems(list)
    self:CheckAmmo(list)
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
    if r.action and r.action.spell then
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
    b:Hide()
    self.buttons[i] = b
    return b
end

-- Secure attributes for a reminder. Casts on yourself, or uses the item on the weapon.
function TO:ActionAttributes(r)
    local a = r.action
    if a and a.spell then
        return { type = "spell", spell = a.spell, unit = "player" }
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
    if r.expires and r.expires > 0 then
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
    -- Your own items: red count when you're low, white when topped off
    if r.low then b.text:SetTextColor(1, 0.35, 0.3) else b.text:SetTextColor(1, 1, 1) end
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
    local twoRows = #top > 0 and #bottom > 0
    local rowStep = size + self.DIVIDER_SPACE

    if not self.divider then
        self.divider = self.bar:CreateTexture(nil, "ARTWORK")
        local g = self.COLORS.gold
        self.divider:SetColorTexture(g[1], g[2], g[3], 0.8)
        self.divider:SetHeight(2)
    end
    for i, r in ipairs(shownList) do
        local b = self.buttons[i] or self:CreateButton(i)
        self:ApplyButton(b, r)
        b:SetSize(size, size)
        b:ClearAllPoints()
        local col, rowY = i - 1, 0
        if twoRows and i > #top then col, rowY = i - #top - 1, -rowStep end
        b:SetPoint("TOPLEFT", self.bar, "TOPLEFT", col * (size + gap), rowY)
        b:Show()
    end
    local cols = twoRows and math.max(#top, #bottom) or #shownList
    local slots = math.max(cols, self.MIN_SLOTS)
    local width = math.max(slots * (size + gap) - gap, self.HEADER_MIN_WIDTH)
    self.divider:ClearAllPoints()
    if twoRows then
        local y = -(size + math.floor(self.DIVIDER_SPACE / 2) - 1)
        self.divider:SetPoint("TOPLEFT", self.bar, "TOPLEFT", 0, y)
        self.divider:SetPoint("TOPRIGHT", self.bar, "TOPRIGHT", 0, y)
        self.divider:Show()
    else
        self.divider:Hide()
    end
    for i = #shownList + 1, #self.buttons do
        local b = self.buttons[i]
        b.reminder = nil
        b:SetAttribute("type", nil)
        b:Hide()
    end
    -- Always room for at least two icons, so the frame keeps one tidy size and only
    -- grows once a third reminder shows up. A second row makes it taller.
    self.main:SetSize(width, twoRows and (size + rowStep) or size)
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
TO.DIVIDER_SPACE = 10      -- room between the buff row and the top-off row

-- Buffs (row 1) vs things to top off (row 2)
function TO:IsBuffReminder(r)
    local id = r.id or ""
    return id:find("^buff:") ~= nil or id:find("^weapon:") ~= nil or id == "wellfed"
end
TO.URGENT_SHARE = 0.2      -- red border in the last 20% of the warning time

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
    header:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then TO:OpenConfig() end
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
