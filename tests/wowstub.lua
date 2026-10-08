-- Minimal WoW API stub for exercising ToppedOff Forever outside the game.
-- Methods (CamelCase keys) default to no-ops; lowercase fields read as nil like real frames.

LOG = {}
local function log(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end LOG[#LOG + 1] = table.concat(t, " ") end
print = function(...) log(...) end

ALL_FRAMES = {}
BLOCKED = {}          -- protected actions attempted in combat
COMBAT = false
SECRET_MODE = false

-- Secret values: a marker table that errors on arithmetic, ordering, concatenation
local SecretMT = {}
local function boom() error("attempted to use a secret value", 2) end
SecretMT.__add, SecretMT.__sub, SecretMT.__mul, SecretMT.__div = boom, boom, boom, boom
SecretMT.__lt, SecretMT.__le, SecretMT.__concat, SecretMT.__unm = boom, boom, boom, boom
SecretMT.__tostring = function() return "<secret>" end
local function secret(v) return setmetatable({ v = v }, SecretMT) end
function issecretvalue(v) return type(v) == "table" and getmetatable(v) == SecretMT end
local function maybeSecret(v) if SECRET_MODE then return secret(v) end return v end

local PROTECTED_WHEN_COMBAT = { SetPoint = true, ClearAllPoints = true, SetSize = true, SetWidth = true,
    SetHeight = true, SetAttribute = true, Show = true, Hide = true, SetShown = true, SetScale = true,
    StartMoving = true, StopMovingOrSizing = true }

local ObjMT = {}
local Methods = {}
STUB_METHODS = Methods   -- tests/render.lua adds layout tracking
ObjMT.__index = function(t, k)
    if Methods[k] then return Methods[k] end
    if type(k) == "string" and k:match("^%u") then
        return function(self, ...)
            for i = 1, select("#", ...) do
                local a = select(i, ...)
                if issecretvalue(a) and not ({ SetText = 1, SetFormattedText = 1, SetValue = 1, SetMinMaxValues = 1,
                        SetAlpha = 1, SetCooldown = 1 })[k] then
                    error("secret passed to " .. k)
                end
            end
            if COMBAT and self.__protected and PROTECTED_WHEN_COMBAT[k] then
                BLOCKED[#BLOCKED + 1] = (self.__name or self.__kind) .. ":" .. k
            end
            return nil
        end
    end
    return nil
end

function TEMPLATE_HOVER() end
function newObj(kind, name, parent, template)
    local o = setmetatable({ __kind = kind, __name = name, __parent = parent, __template = template,
        __scripts = {}, __shown = true, __attrs = {}, __children = {} }, ObjMT)
    if template and (template:find("Secure") or template:find("SecureUnitButton")) then o.__protected = true end
    -- The real template shows its own tooltip on hover
    if template == "UIPanelButtonTemplate" then o.__scripts.OnEnter, o.__scripts.OnLeave = TEMPLATE_HOVER, TEMPLATE_HOVER end
    if parent and parent.__children then table.insert(parent.__children, o) end
    ALL_FRAMES[#ALL_FRAMES + 1] = o
    if name then _G[name] = o end
    return o
end

local function protectedCheck(self, what)
    if COMBAT and self.__protected then BLOCKED[#BLOCKED + 1] = (self.__name or self.__kind) .. ":" .. what end
end

function Methods:CreateTexture() return newObj("Texture", nil, self) end
function Methods:CreateFontString() local f = newObj("FontString", nil, self); f.__text = "" return f end
function Methods:CreateAnimationGroup() local g = newObj("AnimationGroup", nil, self); g.__playing = false return g end
function Methods:CreateAnimation() return newObj("Animation", nil, self) end
function Methods:Play() self.__playing = true end
function Methods:Stop() self.__playing = false end
function Methods:IsPlaying() return self.__playing end
function Methods:Show() protectedCheck(self, "Show") self.__shown = true if self.__scripts.OnShow then self.__scripts.OnShow(self) end end
function Methods:Hide() protectedCheck(self, "Hide") self.__shown = false end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:IsShown() return self.__shown end
function Methods:IsVisible()
    local f = self
    while f do if f.__shown == false then return false end f = f.__parent end
    return true
end
function Methods:SetScript(k, fn) self.__scripts[k] = fn end
function Methods:GetScript(k) return self.__scripts[k] end
function Methods:HookScript(k, fn)
    local old = self.__scripts[k]
    self.__scripts[k] = function(...) if old then old(...) end fn(...) end
end
function Methods:SetAttribute(k, v) protectedCheck(self, "SetAttribute") self.__attrs[k] = v end
function Methods:GetAttribute(k) return self.__attrs[k] end
function Methods:SetText(t)
    if issecretvalue(t) then self.__text = "<secret>" return end
    self.__text = t
end
function Methods:SetFormattedText(fmt, ...)
    for i = 1, select("#", ...) do if issecretvalue((select(i, ...))) then self.__text = "<secret fmt>" return end end
    self.__text = fmt:format(...)
end
function Methods:GetText() return self.__text end
function Methods:SetNumeric(v) self.__numeric = v end
function Methods:SetChecked(v) self.__checked = v and true or false end
function Methods:GetChecked() return self.__checked end
function Methods:GetFont() return "Fonts\\FRIZQT__.TTF", 10, "" end
function Methods:GetRegions() local r = {} for _, c in ipairs(self.__children) do if c.__kind == "Texture" or c.__kind == "FontString" then r[#r + 1] = c end end return unpack(r) end
function Methods:GetObjectType() return self.__kind end
function Methods:GetHighlightTexture() return nil end
function Methods:GetPoint() return "CENTER", UIParent, "CENTER", 12, 34 end
function Methods:GetLeft() return self.__left end
function Methods:GetTop() return self.__top end
local oldSetPoint
function Methods:SetPoint(p, rel, rp, x, y)
    if COMBAT and self.__protected then BLOCKED[#BLOCKED + 1] = (self.__name or self.__kind) .. ":SetPoint" end
    self.__point = p
    if type(rel) == "table" then self.__pos = { x or 0, y or 0 } else self.__pos = { rel or 0, rp or 0 } end
end
function Methods:GetWidth() return 140 end
-- Text layout and colour, so a test can see what a reused widget still carries
-- (nil = whatever the font gives it)
function Methods:SetWidth(w) protectedCheck(self, "SetWidth") self.__width = w if self.__size then self.__size[1] = w end end
function Methods:SetJustifyH(j) self.__justify = j end
function Methods:GetJustifyH() return self.__justify end
function Methods:SetWordWrap(v) self.__wrap = v end
function Methods:CanWordWrap() return self.__wrap end
function Methods:SetTextColor(r, g, b, a) self.__tcolor = r and { r, g, b, a } or nil end
function Methods:GetTextColor() return unpack(self.__tcolor or {}) end
function Methods:GetCenter() return 0, 0 end
function Methods:GetEffectiveScale() return 1 end
function Methods:GetName() return self.__name end
function Methods:GetFrameLevel() return 1 end
function Methods:SetFrameLevel(l) self.__frameLevel = l end
function Methods:SetSize(w, h) protectedCheck(self, "SetSize") self.__size = { w, h } end
function Methods:SetValue(v) self.__value = v if self.__scripts.OnValueChanged then self.__scripts.OnValueChanged(self, issecretvalue(v) and 0 or v) end end
function Methods:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function Methods:GetMinMaxValues() return self.__min, self.__max end
function Methods:GetValue() return self.__value end
function Methods:SetVerticalScroll(v) self.__scroll = v end
function Methods:SetColorTexture(r, g, b, a) self.__color = { r, g, b, a } end
function Methods:SetHeight(h) protectedCheck(self, "SetHeight") self.__height = h if self.__size then self.__size[2] = h end end
function Methods:GetHeight() return self.__height or (self.__size and self.__size[2]) end
function Methods:RegisterEvent(e) self.__events = self.__events or {} self.__events[e] = true end
function Methods:RegisterUnitEvent(e) self.__events = self.__events or {} self.__events[e] = true end
function Methods:SetAlpha(a) self.__alpha = a end
function Methods:GetFontString() return nil end
function Methods:SetEnabled(v) self.__enabled = v end
function Methods:SetDesaturated(v) self.__desat = v end
function Methods:SetTexture(t) self.__texture = t end
function Methods:StartMoving() protectedCheck(self, "StartMoving") self.__moving = true end
function Methods:StopMovingOrSizing() protectedCheck(self, "StopMovingOrSizing") self.__moving = false end

function CreateFrame(kind, name, parent, template) return newObj(kind, name, parent, template) end
UIParent = newObj("Frame", "UIParent")
Minimap = newObj("Frame", "Minimap")
GameTooltip = newObj("GameTooltip", "GameTooltip")
GameFontNormalSmall = newObj("Font", "GameFontNormalSmall")
GameFontNormal = newObj("Font", "GameFontNormal")
GameFontDisable = newObj("Font", "GameFontDisable")
GameFontHighlight = newObj("Font", "GameFontHighlight")
function GameTooltip_SetDefaultAnchor() end

-- World state the tests control
STATE = {
    class = "MAGE", buffs = {}, bags = {}, mh = nil, oh = nil, ammo = nil, ammoCount = 0,
    durability = {}, instance = false,
}
function UnitClass(u)
    if u ~= "player" and STATE.partyClass and STATE.partyClass[u] then
        local c = STATE.partyClass[u]
        if c == "hidden" then return secret("x"), secret("x") end
        return c, c
    end
    return "Mage", STATE.class
end
function UnitLevel(u) return STATE.level or 60 end
function GetMaxPlayerLevel() return STATE.maxLevel or 60 end
-- Group: STATE.party = { "party1", ... } present; STATE.partyBuffs[unit] = { [name] = left }
-- STATE.hiddenAuras[unit] = true makes that unit's auras secret; STATE.roles[unit] = "HEALER"
STATE.party, STATE.partyBuffs, STATE.hiddenAuras, STATE.roles, STATE.outOfRange = {}, {}, {}, {}, {}
function IsInGroup() return #STATE.party > 0 or STATE.raid ~= nil end
-- Raid: STATE.raid = { "raid1", ... } present, STATE.raidMe = the one that's you
function IsInRaid() return STATE.raid ~= nil end
function GetNumGroupMembers() return STATE.raid and #STATE.raid or (#STATE.party + 1) end
function UnitIsUnit(a, b) return a == b or (b == "player" and a == STATE.raidMe) end
function GetRealmName() return "Forever" end
local function inParty(u) for _, p in ipairs(STATE.party) do if p == u then return true end end return false end
function UnitExists(u)
    if u == "player" then return true end
    if STATE.raid then for _, r in ipairs(STATE.raid) do if r == u then return true end end end
    if u == "pet" then return STATE.pet ~= nil end
    return inParty(u)
end
function UnitName(u) if u == "player" then return "Me" end return "Name_" .. u end
-- STATE.offline[unit], STATE.dead[unit], STATE.unseen[unit]: can't be buffed right now
STATE.offline, STATE.dead, STATE.unseen = {}, {}, {}
function UnitIsConnected(u) return not STATE.offline[u] end
function UnitIsDeadOrGhost(u) return u == "player" and STATE.playerDead or STATE.dead[u] or false end
function UnitIsDead(u) if u == "pet" then return STATE.pet == "dead" end return false end
function UnitIsVisible(u) return not STATE.unseen[u] end
-- On Forever UnitInRange always returns hidden values; a spell's range can be read
function UnitInRange(u) return secret(not STATE.outOfRange[u]), secret(true) end
function UnitGroupRolesAssigned(u) return STATE.roles[u] or "NONE" end
function IsMounted() return STATE.mounted or false end
function UnitOnTaxi() return false end
function IsResting() return STATE.resting or false end
-- Forever has no GetPetHappiness, GetSpecialization or GetTalentTabInfo globals
C_PetInfo = { GetPetHappiness = function() return STATE.happiness, 0, 0 end }
-- Talents: STATE.talents = { { "Discipline", 5 }, { "Holy", 0 }, { "Shadow", 31 } }. Your
-- specialization is the tree with the most points (0 with no points spent).
C_SpecializationInfo = {
    GetSpecialization = function()
        local best, pts = 0, 0
        for i, t in ipairs(STATE.talents or {}) do if t[2] > pts then best, pts = i, t[2] end end
        return best
    end,
    GetSpecializationInfo = function(i)
        local t = STATE.talents[i]
        return 100 + i, t[1], "description", "icon", nil, 0, t[2]
    end,
}
-- Money as coin text: C_CurrencyInfo.GetCoinTextureString (the global is gone on Forever)
C_CurrencyInfo = { GetCoinTextureString = function(copper) return "coins:" .. copper end }
-- Tooltips: a bag entry's `tip` field is its tooltip text (lines split on "\n")
-- An item by ID: one in your bags, or one the vendor sells (STATE.merchant[i] = { id =, tip = })
local function stubItem(id)
    for _, e in ipairs(STATE.bags) do if e.id == id then return e end end
    for _, tab in pairs(STATE.bank or {}) do for _, e in ipairs(tab) do if e.id == id then return e end end end
    -- STATE.itemNames[id]: an item the game knows by name but you don't carry
    if STATE.itemNames and STATE.itemNames[id] then return { id = id, name = STATE.itemNames[id] } end
    for _, e in ipairs(STATE.merchant or {}) do if e.id == id then return e end end
end
C_TooltipInfo = { GetItemByID = function(id)
    for _, e in ipairs({ stubItem(id) }) do
        if e.id == id then
            local lines = { { leftText = e.name } }
            if STATE.uncached and STATE.uncached[id] then return { lines = lines } end
            STATE.tooltipReads = (STATE.tooltipReads or 0) + 1
            -- Right after login an item's "Use:" line can be missing: its spell text hasn't
            -- loaded (STATE.spellsLoading[id]), or the tooltip just isn't complete yet
            -- (STATE.thinTooltips[id]) while the game reports everything as loaded
            local thin = (STATE.spellsLoading and STATE.spellsLoading[id]) or (STATE.thinTooltips and STATE.thinTooltips[id])
            for l in (e.tip or ""):gmatch("[^\n]+") do
                if not (thin and l:find("^Use:")) then lines[#lines + 1] = { leftText = l } end
            end
            return { lines = lines }
        end
    end
    return nil
end }
function InCombatLockdown() return COMBAT end
FAKE_TIME = 1000
function GetTime() return FAKE_TIME end
function IsInInstance() return STATE.instance, STATE.instance and "party" or "none" end
function PlaySound(k) print("SOUND", k) end
SOUNDKIT = { RAID_WARNING = 8959 }
function RegisterStateDriver(f, k, v) f.__driver = v end
function UnregisterStateDriver(f, k) f.__driver = nil end
TICKERS = {}
AFTER = {}
C_Timer = {
    NewTicker = function(_, fn) TICKERS[#TICKERS + 1] = fn end,
    After = function(_, fn) AFTER[#AFTER + 1] = fn end,
}
function GetCursorPosition() return 10, 10 end
UISpecialFrames = {}
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
SlashCmdList = {}
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, FutureSpell = 2 },
    BagIndex = { Backpack = 0, CharacterBankTab_1 = 6 } }
-- Bank: STATE.bank[bag] = { { id =, name =, count = }, ... } (bag 6 is the first bank tab)
MOVED = {}
-- The game's language: STATE.locale; spell names by ID in it: STATE.spellNames[id]
function GetLocale() return STATE.locale or "enUS" end

-- Spells: name -> { id, icon }. SPELLBOOK lists what's learned; FUTURE lists unlearned spells
-- the modern spellbook still shows.
SPELLS = {}
local nextSpell = 1000
local function spell(name) if not SPELLS[name] then nextSpell = nextSpell + 1 SPELLS[name] = { id = nextSpell, icon = "icon:" .. name } end return SPELLS[name] end
SPELLBOOK, FUTURE = {}, {}
PASSIVE = {}   -- PASSIVE["Omen of Clarity"] = true: in your spellbook, but passive
function LEARN(...) for _, n in ipairs({ ... }) do spell(n) table.insert(SPELLBOOK, n) end end
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function(i) return { itemIndexOffset = 0, numSpellBookItems = #SPELLBOOK + #FUTURE } end,
    GetSpellBookItemInfo = function(j)
        if j <= #SPELLBOOK then
            return { name = maybeSecret(SPELLBOOK[j]), itemType = 1, isPassive = PASSIVE[SPELLBOOK[j]] == true }
        end
        return { name = FUTURE[j - #SPELLBOOK], itemType = 2 }
    end,
}
C_Spell = {
    -- STATE.spellsLoading[item ID] = true: that item's use spell hasn't loaded yet
    IsSpellDataCached = function(spellID) return not (STATE.spellsLoading and STATE.spellsLoading[spellID - 50000]) end,
    RequestLoadSpellData = function(spellID) STATE.requestedSpells = STATE.requestedSpells or {}; STATE.requestedSpells[spellID] = true end,
    -- STATE.outOfRange[unit]: too far for any spell
    IsSpellInRange = function(spell, unit) if not unit then return nil end return not STATE.outOfRange[unit] end,
    GetSpellName = function(id) return STATE.spellNames and STATE.spellNames[id] end,
    GetSpellInfo = function(n)
        local s = SPELLS[n]
        if not s then return nil end
        return { name = n, spellID = s.id, iconID = s.icon }
    end,
}
-- STATE.knownOnly = { name = true }: known, but missing from the spellbook scan
C_SpellBook.IsSpellKnown = function(id, bank)
    for _, n in ipairs(SPELLBOOK) do if SPELLS[n].id == id then return true end end
    for n in pairs(STATE.knownOnly or {}) do if SPELLS[n] and SPELLS[n].id == id then return true end end
    return false
end

-- Buffs on you: STATE.buffs[name] = seconds left (0 = permanent)
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, i, filter)
        -- STATE.aurasLocked: the game refuses (errors) while auras are hidden
        if STATE.aurasLocked then error("GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted") end
        -- STATE.playerAurasHidden: your own aura comes back as a hidden value
        if unit == "player" and STATE.playerAurasHidden then return secret({ name = "x" }) end
        local list = {}
        local src = STATE.buffs
        if unit ~= "player" then
            if STATE.hiddenAuras[unit] then return { name = secret("x") } end
            src = STATE.partyBuffs[unit] or {}
        end
        for n, left in pairs(src) do list[#list + 1] = { n, left } end
        table.sort(list, function(a, b) return a[1] < b[1] end)
        local e = list[i]
        if not e then return nil end
        local exp = e[2] == 0 and 0 or (FAKE_TIME + e[2])
        -- STATE.buffStacks[name]: how many times a buff of yours is stacked (0 when it doesn't stack)
        local stacks = unit == "player" and STATE.buffStacks and STATE.buffStacks[e[1]] or 0
        return { name = maybeSecret(e[1]), expirationTime = maybeSecret(exp), applications = maybeSecret(stacks) }
    end,
}

-- Bags: STATE.bags = { { id = 1, name = "Soul Shard", count = 3 }, ... } (one stack per slot)
C_Container = {
    GetItemCooldown = function(id) return (STATE.itemCD or {})[id] or 0, 0, 1 end,
    GetContainerNumSlots = function(bag)
        if bag == 0 then return 16 end
        if STATE.bank and STATE.bank[bag] then return #STATE.bank[bag] end
        return 0
    end,
    GetContainerNumFreeSlots = function(bag)
        if bag ~= 0 then return 0, 0 end
        if STATE.freeSlots then return STATE.freeSlots, 0 end
        return 16 - #STATE.bags, 0
    end,
    GetContainerItemInfo = function(bag, slot)
        local e
        if bag == 0 then e = STATE.bags[slot] elseif STATE.bank and STATE.bank[bag] then e = STATE.bank[bag][slot] end
        if not e or e.moved then return nil end
        return { itemID = e.id, stackCount = e.count, iconFileID = "item:" .. e.name }
    end,
    -- With the bank open, a bank item goes to your bags (MOVED logs it)
    UseContainerItem = function(bag, slot)
        local e = STATE.bank and STATE.bank[bag] and STATE.bank[bag][slot]
        if not e or e.moved then return end
        e.moved = true
        table.insert(STATE.bags, { id = e.id, name = e.name, count = e.count })
        MOVED[#MOVED + 1] = e.name .. ":" .. e.count
    end,
}
local function itemById(id) return stubItem(id) end
C_Item = {
    GetItemCount = function(id)
        local n = 0
        for _, e in ipairs(STATE.bags) do if e.id == id then n = n + e.count end end
        return n
    end,
    IsItemDataCachedByID = function(id) return not (STATE.uncached and STATE.uncached[id]) end,
    RequestLoadItemDataByID = function(id) STATE.requested = STATE.requested or {}; STATE.requested[id] = true end,
    GetItemNameByID = function(id) local e = itemById(id) return e and e.name end,
    GetItemIconByID = function(id) return "item:" .. tostring(id) end,
    -- An item with a "Use:" line has a spell behind it (spell ID = 50000 + item ID here)
    GetItemSpell = function(id)
        local e = itemById(id)
        if not e then return nil end
        if e.spell or (e.tip or ""):find("Use:", 1, true) then return e.spell, 50000 + id end
        return nil
    end,
    -- Bag items are consumables unless they say otherwise ({ equipLoc = "INVTYPE_HOLDABLE" });
    -- STATE.gear[id] = equipLoc marks gear that isn't in your bags (it's equipped).
    GetItemInfoInstant = function(id)
        if id == 900 then return id, "Weapon", "Dagger", "INVTYPE_WEAPON", nil, 2, 15 end
        local e = itemById(id)
        local loc = (e and e.equipLoc) or (STATE.gear and STATE.gear[id])
        if loc then return id, "Armor", "Miscellaneous", loc, nil, 4, 0 end
        if e or id ~= STATE.oh then return id, "Consumable", "Consumable", "", nil, 0, 0 end
        return id, "Armor", "Shield", "INVTYPE_SHIELD", nil, 4, 6
    end,
}
NUM_BAG_SLOTS = 4

-- Equipment: STATE.mh / STATE.oh = item ID or nil; STATE.enchant = { mh = ms left, oh = ms left }
STATE.enchant = {}
function GetInventoryItemID(unit, slot)
    if slot == 16 then return STATE.mh end
    if slot == 17 then return STATE.oh end
    if slot == 0 then return STATE.ammo end
    return nil
end
function GetInventoryItemCount(unit, slot) if slot == 0 then return STATE.ammoCount end return 0 end
function GetWeaponEnchantInfo()
    local mh, oh = STATE.enchant.mh, STATE.enchant.oh
    return mh ~= nil, mh, STATE.charges and STATE.charges.mh or 0, 1, oh ~= nil, oh,
        STATE.charges and STATE.charges.oh or 0, 2
end
function GetInventoryItemDurability(slot)
    local d = STATE.durability[slot]
    if not d then return nil end
    return maybeSecret(d), 100
end

-- Vendor: STATE.merchant = { { name, price, stack, icon }, ... }; BOUGHT logs purchases
STATE.merchant, BOUGHT = {}, {}
STATE.money, STATE.repairCost = 100000, 0
function GetMerchantNumItems() return #STATE.merchant end
-- The Mainline client's merchant API (the old GetMerchantItemInfo global is gone)
C_MerchantFrame = { GetItemInfo = function(i)
    local m = STATE.merchant[i]
    if not m then return nil end
    return { name = m.name, texture = m.icon or "icon", price = m.price, stackCount = m.stack or 1,
        numAvailable = m.available or -1, isPurchasable = m.purchasable ~= false, isUsable = true,
        hasExtendedCost = m.extended or false }
end }
function GetMerchantItemMaxStack(i) return 20 end
-- STATE.merchant[i].id: the item it sells (its tooltip comes from STATE.itemTips or the bags)
function GetMerchantItemID(i) return STATE.merchant[i] and STATE.merchant[i].id end
function GetCurrentKeyBoardFocus() return STATE.keyboardFocus end
function BuyMerchantItem(i, q) BOUGHT[#BOUGHT + 1] = STATE.merchant[i].name .. ":" .. tostring(q) end
function GetMoney() return STATE.money end
function CanMerchantRepair() return STATE.repairCost > 0 end
function GetRepairAllCost() return STATE.repairCost, STATE.repairCost > 0 end
function RepairAllItems() REPAIRED = true end

StaticPopupDialogs = {}
UISpecialFrames = UISpecialFrames or {}
SlashCmdList = SlashCmdList or {}
