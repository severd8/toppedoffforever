-- ToppedOff Forever: other game languages. Spell and item names in Core.lua are
-- English. On a client in another language, each is replaced at login by the game's
-- own name for its ID, so the checks find your spells, buffs and reagents. English
-- clients are left alone. IDs are WoW Classic's; DEVNOTES.md says how to check one.

local _, ns = ...
local TO = ns.TO

TO.SPELL_IDS = {
    -- Mage
    ["Arcane Intellect"] = 1459, ["Arcane Brilliance"] = 23028,
    ["Frost Armor"] = 168, ["Ice Armor"] = 7302, ["Mage Armor"] = 6117,
    ["Teleport: Stormwind"] = 3561, ["Teleport: Ironforge"] = 3562, ["Teleport: Undercity"] = 3563,
    ["Teleport: Darnassus"] = 3565, ["Teleport: Thunder Bluff"] = 3566, ["Teleport: Orgrimmar"] = 3567,
    ["Portal: Stormwind"] = 10059, ["Portal: Ironforge"] = 11416, ["Portal: Orgrimmar"] = 11417,
    ["Portal: Undercity"] = 11418, ["Portal: Darnassus"] = 11419, ["Portal: Thunder Bluff"] = 11420,
    ["Slow Fall"] = 130, ["Conjure Water"] = 5504, ["Conjure Food"] = 587,
    ["Conjure Mana Agate"] = 759, ["Conjure Mana Jade"] = 3552, ["Conjure Mana Citrine"] = 10053,
    ["Conjure Mana Ruby"] = 10054,
    -- Priest
    ["Power Word: Fortitude"] = 1243, ["Prayer of Fortitude"] = 21562, ["Inner Fire"] = 588,
    ["Divine Spirit"] = 14752, ["Prayer of Spirit"] = 27681, ["Shadow Protection"] = 976,
    ["Prayer of Shadow Protection"] = 27683, ["Shadowguard"] = 18137, ["Touch of Weakness"] = 2652,
    ["Fear Ward"] = 6346, ["Levitate"] = 1706,
    -- Druid
    ["Mark of the Wild"] = 1126, ["Gift of the Wild"] = 21849, ["Thorns"] = 467, ["Omen of Clarity"] = 16864,
    ["Rebirth"] = 20484,
    -- Warlock
    ["Demon Skin"] = 687, ["Demon Armor"] = 706, ["Drain Soul"] = 1120,
    ["Summon Imp"] = 688, ["Summon Voidwalker"] = 697, ["Summon Succubus"] = 712, ["Summon Felhunter"] = 691,
    ["Create Soulstone (Minor)"] = 693, ["Create Soulstone (Lesser)"] = 20752, ["Create Soulstone"] = 20755,
    ["Create Soulstone (Greater)"] = 20756, ["Create Soulstone (Major)"] = 20757,
    ["Create Healthstone (Minor)"] = 6201, ["Create Healthstone (Lesser)"] = 6202, ["Create Healthstone"] = 5699,
    ["Create Healthstone (Greater)"] = 11729, ["Create Healthstone (Major)"] = 11730,
    ["Soulstone Resurrection"] = 20707,
    -- Paladin
    ["Blessing of Might"] = 19740, ["Blessing of Wisdom"] = 19742, ["Blessing of Kings"] = 20217,
    ["Blessing of Salvation"] = 1038, ["Blessing of Light"] = 19977, ["Blessing of Sanctuary"] = 20911,
    ["Greater Blessing of Might"] = 25782, ["Greater Blessing of Wisdom"] = 25894,
    ["Greater Blessing of Kings"] = 25898, ["Greater Blessing of Salvation"] = 25895,
    ["Greater Blessing of Light"] = 25890, ["Greater Blessing of Sanctuary"] = 25899,
    ["Devotion Aura"] = 465, ["Retribution Aura"] = 7294, ["Concentration Aura"] = 19746,
    ["Sanctity Aura"] = 20218, ["Shadow Resistance Aura"] = 19876, ["Frost Resistance Aura"] = 19888,
    ["Fire Resistance Aura"] = 19891, ["Righteous Fury"] = 25780, ["Divine Intervention"] = 19752,
    -- Hunter
    ["Aspect of the Hawk"] = 13165, ["Aspect of the Monkey"] = 13163, ["Aspect of the Cheetah"] = 5118,
    ["Aspect of the Pack"] = 13159, ["Aspect of the Wild"] = 20043, ["Aspect of the Beast"] = 13161,
    ["Trueshot Aura"] = 19506, ["Call Pet"] = 883, ["Revive Pet"] = 982, ["Feed Pet"] = 6991,
    -- Warrior
    ["Battle Shout"] = 6673,
    -- Shaman
    ["Lightning Shield"] = 324, ["Windfury Weapon"] = 8232, ["Flametongue Weapon"] = 8024,
    ["Frostbrand Weapon"] = 8033, ["Rockbiter Weapon"] = 8017, ["Reincarnation"] = 20608,
    ["Stoneskin Totem"] = 8071, ["Earthbind Totem"] = 2484, ["Strength of Earth Totem"] = 8075,
    ["Searing Totem"] = 3599, ["Fire Nova Totem"] = 1535, ["Magma Totem"] = 8190,
    ["Healing Stream Totem"] = 5394, ["Mana Spring Totem"] = 5675, ["Poison Cleansing Totem"] = 8166,
    ["Grace of Air Totem"] = 8835, ["Windfury Totem"] = 8512, ["Grounding Totem"] = 8177,
    -- Rogue
    ["Vanish"] = 1856, ["Blind"] = 2094,
}

TO.ITEM_IDS = {
    ["Soul Shard"] = 6265, ["Rune of Teleportation"] = 17031, ["Rune of Portals"] = 17032,
    ["Arcane Powder"] = 17020, ["Light Feather"] = 17056, ["Holy Candle"] = 17028, ["Sacred Candle"] = 17029,
    ["Wild Berries"] = 17021, ["Wild Thornroot"] = 17026, ["Maple Seed"] = 17034, ["Stranglethorn Seed"] = 17035,
    ["Ashwood Seed"] = 17036, ["Hornbeam Seed"] = 17037, ["Ironwood Seed"] = 17038, ["Symbol of Kings"] = 21177,
    ["Symbol of Divinity"] = 17033, ["Ankh"] = 17030, ["Earth Totem"] = 5175, ["Fire Totem"] = 5176,
    ["Water Totem"] = 5177, ["Air Totem"] = 5178, ["Flash Powder"] = 5140, ["Blinding Powder"] = 5530,
    ["Mana Agate"] = 5514, ["Mana Jade"] = 5513, ["Mana Citrine"] = 8007, ["Mana Ruby"] = 8008,
}

-- Every place in the data that holds a spell or item name: { table, key, English name }
function TO:NameRefs()
    local spells, items = {}, {}
    local function list(t, out)
        for i, n in ipairs(t or {}) do out[#out + 1] = { t, i, n } end
    end
    local function map(t, out)
        for k, n in pairs(t or {}) do out[#out + 1] = { t, k, n } end
    end
    for _, buffs in pairs(self.CLASS_BUFFS) do
        for _, b in ipairs(buffs) do
            list(b.cast, spells)
            if b.auras ~= b.cast then list(b.auras, spells) end
            map(b.byRole, spells)
            if b.group then
                spells[#spells + 1] = { b.group, "spell", b.group.spell }
                list(b.group.items, items)
            end
        end
    end
    for _, w in pairs(self.WEAPON_DEFAULTS) do list(w.cast, spells) end
    for _, rgs in pairs(self.CLASS_REAGENTS) do
        for _, rg in ipairs(rgs) do
            list(rg.requires, spells)
            list(rg.items, items)
            for _, b in ipairs(rg.buy or {}) do items[#items + 1] = { b, 1, b[1] } end
        end
    end
    list(self.WARLOCK_PETS, spells)
    list(self.SOULSTONE_SPELLS, spells)
    list(self.HEALTHSTONE_SPELLS, spells)
    map(self.PET_SPELLS, spells)
    map(self.AURAS, spells)
    map(self.BLESSING_SPELLS, spells)
    map(self.GREATER_BLESSINGS, spells)
    for _, c in ipairs(self.CONJURES) do spells[#spells + 1] = { c, "spell", c.spell } end
    for _, g in ipairs(self.MANA_GEMS) do
        spells[#spells + 1] = { g, "spell", g.spell }
        items[#items + 1] = { g, "item", g.item }
    end
    return spells, items
end

local function English()
    local loc = GetLocale and GetLocale()
    return loc == nil or loc == "enUS" or loc == "enGB"
end

-- Puts the game's names in. Item names the game hasn't loaded yet are asked for, and
-- filled in by LocalizeItems when they arrive (GET_ITEM_INFO_RECEIVED).
function TO:Localize()
    if English() then return end
    if not self.nameRefs then
        local spells, items = self:NameRefs()
        self.nameRefs = { spells = spells, items = items }
    end
    for _, ref in ipairs(self.nameRefs.spells) do
        local id = self.SPELL_IDS[ref[3]]
        local name = id and C_Spell and C_Spell.GetSpellName and self.Str(C_Spell.GetSpellName(id))
        ref[1][ref[2]] = name or ref[3]
    end
    self:LocalizeItems()
end

-- True while some item names are still to come
function TO:LocalizeItems()
    if not self.nameRefs then return false end
    local waiting = false
    for _, ref in ipairs(self.nameRefs.items) do
        local id = self.ITEM_IDS[ref[3]]
        local name = id and self.Str(C_Item.GetItemNameByID(id))
        if name then
            ref[1][ref[2]] = name
        elseif id then
            waiting = true
            self.pendingItems[id] = true
            if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        end
    end
    self.itemsLocalizing = waiting
    return waiting
end
