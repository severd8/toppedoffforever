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
    SetHeight = true, SetAttribute = true, Show = true, Hide = true, SetShown = true, SetScale = true }

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

function newObj(kind, name, parent, template)
    local o = setmetatable({ __kind = kind, __name = name, __parent = parent, __template = template,
        __scripts = {}, __shown = true, __attrs = {}, __children = {} }, ObjMT)
    if template and (template:find("Secure") or template:find("SecureUnitButton")) then o.__protected = true end
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
function Methods:GetCenter() return 0, 0 end
function Methods:GetEffectiveScale() return 1 end
function Methods:GetName() return self.__name end
function Methods:GetFrameLevel() return 1 end
function Methods:SetFrameLevel(l) self.__frameLevel = l end
function Methods:SetSize(w, h) protectedCheck(self, "SetSize") self.__size = { w, h } end
function Methods:SetValue(v) self.__value = v if self.__scripts.OnValueChanged then self.__scripts.OnValueChanged(self, issecretvalue(v) and 0 or v) end end
function Methods:SetMinMaxValues(a, b) end
function Methods:RegisterEvent(e) self.__events = self.__events or {} self.__events[e] = true end
function Methods:RegisterUnitEvent(e) self.__events = self.__events or {} self.__events[e] = true end
function Methods:SetAlpha(a) self.__alpha = a end
function Methods:GetFontString() return nil end
function Methods:SetEnabled(v) self.__enabled = v end
function Methods:SetDesaturated(v) self.__desat = v end
function Methods:SetTexture(t) self.__texture = t end
function Methods:StartMoving() end

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
function UnitIsConnected(u) return true end
function UnitIsDeadOrGhost(u) return u == "player" and STATE.playerDead or false end
function UnitIsDead(u) if u == "pet" then return STATE.pet == "dead" end return false end
function UnitIsVisible(u) return true end
function UnitInRange(u) return not STATE.outOfRange[u], true end
function UnitGroupRolesAssigned(u) return STATE.roles[u] or "NONE" end
function IsMounted() return STATE.mounted or false end
function UnitOnTaxi() return false end
function IsResting() return STATE.resting or false end
function GetPetHappiness() return STATE.happiness end
-- Talents (Classic style): STATE.talents = { { "Discipline", 5 }, { "Holy", 0 }, { "Shadow", 31 } }
function GetNumTalentTabs() return STATE.talents and #STATE.talents or 0 end
function GetTalentTabInfo(i) local t = STATE.talents[i] return t[1], "icon", t[2], "bg" end
-- Tooltips: a bag entry's `tip` field is its tooltip text (lines split on "\n")
C_TooltipInfo = { GetItemByID = function(id)
    for _, e in ipairs(STATE.bags) do
        if e.id == id then
            local lines = { { leftText = e.name } }
            for l in (e.tip or ""):gmatch("[^\n]+") do lines[#lines + 1] = { leftText = l } end
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
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, FutureSpell = 2 } }

-- Spells: name -> { id, icon }. SPELLBOOK lists what's learned; FUTURE lists unlearned spells
-- the modern spellbook still shows.
SPELLS = {}
local nextSpell = 1000
local function spell(name) if not SPELLS[name] then nextSpell = nextSpell + 1 SPELLS[name] = { id = nextSpell, icon = "icon:" .. name } end return SPELLS[name] end
SPELLBOOK, FUTURE = {}, {}
function LEARN(...) for _, n in ipairs({ ... }) do spell(n) table.insert(SPELLBOOK, n) end end
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function(i) return { itemIndexOffset = 0, numSpellBookItems = #SPELLBOOK + #FUTURE } end,
    GetSpellBookItemInfo = function(j)
        if j <= #SPELLBOOK then return { name = maybeSecret(SPELLBOOK[j]), itemType = 1 } end
        return { name = FUTURE[j - #SPELLBOOK], itemType = 2 }
    end,
}
C_Spell = {
    GetSpellInfo = function(n)
        local s = SPELLS[n]
        if not s then return nil end
        return { name = n, spellID = s.id, iconID = s.icon }
    end,
}
function IsPlayerSpell(id) for _, n in ipairs(SPELLBOOK) do if SPELLS[n].id == id then return true end end return false end

-- Buffs on you: STATE.buffs[name] = seconds left (0 = permanent)
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, i, filter)
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
        return { name = maybeSecret(e[1]), expirationTime = maybeSecret(exp) }
    end,
}

-- Bags: STATE.bags = { { id = 1, name = "Soul Shard", count = 3 }, ... } (one stack per slot)
C_Container = {
    GetContainerNumSlots = function(bag) if bag == 0 then return 16 end return 0 end,
    GetContainerNumFreeSlots = function(bag)
        if bag ~= 0 then return 0, 0 end
        if STATE.freeSlots then return STATE.freeSlots, 0 end
        return 16 - #STATE.bags, 0
    end,
    GetContainerItemInfo = function(bag, slot)
        local e = STATE.bags[slot]
        if bag ~= 0 or not e then return nil end
        return { itemID = e.id, stackCount = e.count, iconFileID = "item:" .. e.name }
    end,
}
local function itemById(id) for _, e in ipairs(STATE.bags) do if e.id == id then return e end end end
C_Item = {
    GetItemNameByID = function(id) local e = itemById(id) return e and e.name end,
    GetItemIconByID = function(id) return "item:" .. tostring(id) end,
    GetItemSpell = function(id) local e = itemById(id) return e and e.spell, e and 1 end,
    GetItemInfoInstant = function(id)
        if id == 900 then return id, "Weapon", "Dagger", "INVTYPE_WEAPON" end
        return id, "Armor", "Shield", "INVTYPE_SHIELD"
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
function GetMerchantItemInfo(i)
    local m = STATE.merchant[i]
    return m.name, m.icon or "icon", m.price, m.stack or 1, -1, true, true, m.extended or false
end
function GetMerchantItemMaxStack(i) return 20 end
function BuyMerchantItem(i, q) BOUGHT[#BOUGHT + 1] = STATE.merchant[i].name .. ":" .. tostring(q) end
function GetMoney() return STATE.money end
function CanMerchantRepair() return STATE.repairCost > 0 end
function GetRepairAllCost() return STATE.repairCost, STATE.repairCost > 0 end
function RepairAllItems() REPAIRED = true end

StaticPopupDialogs = {}
UISpecialFrames = UISpecialFrames or {}
SlashCmdList = SlashCmdList or {}
