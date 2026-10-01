-- Lays out ToppedOff Forever's frames outside the game and writes them to JSON,
-- so tests/render.py can draw them as images for a visual check.
-- From the repo root:  lua5.1 tests/render.lua && python3 tests/render.py
-- Not shipped (the tests folder is left out of the download).

ADDON_DIR = "."
dofile("tests/wowstub.lua")
local M = STUB_METHODS

---------------------------------------------------------------------------
-- Track layout on the fake frames
---------------------------------------------------------------------------
local baseSetPoint, baseSetSize = M.SetPoint, M.SetSize
function M:SetPoint(p, rel, rp, x, y)
    baseSetPoint(self, p, rel, rp, x, y)
    local a
    if type(rel) == "table" then
        a = { p = p, rel = rel, rp = rp or p, x = x or 0, y = y or 0 }
    elseif type(rel) == "string" then
        a = { p = p, rp = rel, x = rp or 0, y = x or 0 }
    else
        a = { p = p, rp = p, x = rel or 0, y = rp or 0 }
    end
    self.__pts = self.__pts or {}
    for i, old in ipairs(self.__pts) do
        if old.p == p then table.remove(self.__pts, i) break end
    end
    table.insert(self.__pts, a)
end
function M:ClearAllPoints() self.__pts = {} end
function M:SetAllPoints(rel)
    rel = type(rel) == "table" and rel or nil
    self.__pts = { { p = "TOPLEFT", rel = rel, rp = "TOPLEFT", x = 0, y = 0 },
        { p = "BOTTOMRIGHT", rel = rel, rp = "BOTTOMRIGHT", x = 0, y = 0 } }
end
function M:SetSize(w, h) baseSetSize(self, w, h) self.__w, self.__h = w, h end
function M:SetWidth(w) self.__w = w end
function M:SetHeight(h) self.__h = h end
function M:SetColorTexture(r, g, b, a) self.__color = { r, g, b, a or 1 } end
function M:SetTextColor(r, g, b) self.__tcolor = { r, g, b } end
function M:SetJustifyH(j) self.__justify = j end
function M:SetFont(_, size) self.__fsize = size end
function M:SetFontObject(f) self.__font = f and f.__name end
function M:SetScrollChild(ch)
    ch.__pts = { { p = "TOPLEFT", rel = self, rp = "TOPLEFT", x = 0, y = 0 } }
    ch.__scrollOf = self
end
function M:SetWordWrap(v) self.__wrap = v end
function M:CreateFontString(_, _, template)
    local f = newObj("FontString", nil, self)
    f.__text = ""
    f.__font = template
    return f
end
function M:SetFontString(fs) self.__fontString = fs end
function M:CreateTexture(_, layer)
    local t = newObj("Texture", nil, self)
    t.__layer = layer
    return t
end
function M:GetFrameLevel() return self.__frameLevel or 1 end

local FONT_SIZES = { GameFontNormal = 12, GameFontHighlight = 12, GameFontNormalSmall = 10,
    GameFontHighlightSmall = 10, GameFontDisableSmall = 10, GameFontNormalLarge = 16, NumberFontNormal = 12 }
local function FontSize(o) return o.__fsize or FONT_SIZES[o.__font or ""] or 12 end
local function Plain(t)
    t = tostring(t or "")
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "  ")
    return t
end
local function TextWidth(o) return #Plain(o.__text) * FontSize(o) * 0.56 end
function M:GetStringHeight()
    local size = FontSize(self)
    local w = self.__w
    if not w or w <= 0 then return size end
    local lines = math.max(1, math.ceil(TextWidth(self) / w))
    return lines * (size + 2)
end

---------------------------------------------------------------------------
-- Load the addon and log in
---------------------------------------------------------------------------
local ADDON = "ToppedOffForever"
local ns = {}
local function load_file(path)
    local f = assert(io.open(path)) local src = f:read("*a") f:close()
    assert(loadstring(src, "@" .. path))(ADDON, ns)
end
load_file("Core.lua")
load_file("Options.lua")
load_file("Vendor.lua")
local TO = ns.TO
local function fire(event, ...)
    for _, f in ipairs(ALL_FRAMES) do
        if f.__events and f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
    end
end
local function tick() for _, fn in ipairs(TICKERS) do fn() end end

---------------------------------------------------------------------------
-- Resolve rectangles (WoW coordinates: y grows upward) and dump them
---------------------------------------------------------------------------
local SW, SH = 1280, 900
local function Resolve(o, cache)
    if o == UIParent or o == nil then return { l = 0, r = SW, t = SH, b = 0 } end
    if cache[o] then return cache[o] end
    cache[o] = { l = 0, r = 0, t = 0, b = 0 }
    local l, r, t, b, cx, cy
    for _, a in ipairs(o.__pts or {}) do
        local rr = Resolve(a.rel or o.__parent, cache)
        local px = a.rp:find("LEFT") and rr.l or a.rp:find("RIGHT") and rr.r or (rr.l + rr.r) / 2
        local py = a.rp:find("TOP") and rr.t or a.rp:find("BOTTOM") and rr.b or (rr.t + rr.b) / 2
        px, py = px + a.x, py + a.y
        if a.p:find("LEFT") then l = px elseif a.p:find("RIGHT") then r = px else cx = px end
        if a.p:find("TOP") then t = py elseif a.p:find("BOTTOM") then b = py else cy = py end
    end
    local w, h = o.__w, o.__h
    if o.__kind == "FontString" then
        w = w or TextWidth(o)
        h = h or o:GetStringHeight()
    end
    w, h = w or 0, h or 0
    if l and r then w = r - l elseif l then r = l + w elseif r then l = r - w elseif cx then l, r = cx - w / 2, cx + w / 2 else l, r = 0, w end
    if t and b then h = t - b elseif t then b = t - h elseif b then t = b + h elseif cy then t, b = cy + h / 2, cy - h / 2 else t, b = h, 0 end
    local rect = { l = l, r = r, t = t, b = b, anchored = o.__pts and #o.__pts > 0 }
    cache[o] = rect
    return rect
end

local function Visible(o, root)
    local f = o
    while f do
        if f.__shown == false then return false end
        if f == root then return true end
        f = f.__parent
    end
    return false
end

local function ScrollClip(o)
    local f = o.__parent
    while f do
        if f.__scrollOf then return f.__scrollOf end
        f = f.__parent
    end
end

local function Esc(s)
    return (tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"))
end
local function Num(n) return string.format("%.1f", n) end

-- Frame level: set explicitly, or one above the parent frame. Textures and text
-- draw at their frame's level.
function FrameLevel(o)
    if o.__kind == "Texture" or o.__kind == "FontString" then return FrameLevel(o.__parent) end
    if not o or o == UIParent then return 0 end
    if o.__frameLevel then return o.__frameLevel end
    return (o.__parent and FrameLevel(o.__parent) or 0) + 1
end

local out = {}
local function Dump(name, root, unclip)
    local cache = {}
    local items = {}
    for i, o in ipairs(ALL_FRAMES) do
        if o ~= root and Visible(o, root) and o.__pts and #o.__pts > 0 then
            local rc = Resolve(o, cache)
            local fields = {
                '"i":' .. i, '"kind":"' .. o.__kind .. '"',
                '"l":' .. Num(rc.l), '"r":' .. Num(rc.r), '"t":' .. Num(SH - rc.t), '"b":' .. Num(SH - rc.b),
            }
            if o.__template then fields[#fields + 1] = '"tmpl":"' .. o.__template .. '"' end
            if o.__layer then fields[#fields + 1] = '"layer":"' .. o.__layer .. '"' end
            if o.__w and o.__kind == "FontString" then fields[#fields + 1] = '"fixedw":true' end
            fields[#fields + 1] = '"fl":' .. FrameLevel(o)
            for pi, po in ipairs(ALL_FRAMES) do
                if po == o.__parent then fields[#fields + 1] = '"p":' .. pi break end
            end
            if o.__color then fields[#fields + 1] = '"color":[' .. table.concat(o.__color, ",") .. "]" end
            if o.__tcolor then fields[#fields + 1] = '"tcolor":[' .. table.concat(o.__tcolor, ",") .. "]" end
            if o.__text and o.__text ~= "" then fields[#fields + 1] = '"text":"' .. Esc(Plain(o.__text)) .. '"' end
            if o.__font then fields[#fields + 1] = '"font":"' .. o.__font .. '"' end
            fields[#fields + 1] = '"size":' .. FontSize(o)
            if o.__justify then fields[#fields + 1] = '"justify":"' .. o.__justify .. '"' end
            if o.__checked then fields[#fields + 1] = '"checked":true' end
            if o.__texture then fields[#fields + 1] = '"texture":"' .. Esc(o.__texture) .. '"' end
            if o.__desat then fields[#fields + 1] = '"desat":true' end
            if o.__alpha then fields[#fields + 1] = '"alpha":' .. tostring(o.__alpha) end
            local clip = not unclip and ScrollClip(o)
            if clip then
                local cr = Resolve(clip, cache)
                fields[#fields + 1] = '"clip":[' .. Num(cr.l) .. "," .. Num(SH - cr.t) .. "," .. Num(cr.r) .. "," .. Num(SH - cr.b) .. "]"
            end
            items[#items + 1] = "{" .. table.concat(fields, ",") .. "}"
        end
    end
    local rc = Resolve(root, cache)
    out[#out + 1] = '{"name":"' .. name .. '","frame":[' .. Num(rc.l) .. "," .. Num(SH - rc.t) .. ","
        .. Num(rc.r) .. "," .. Num(SH - rc.b) .. '],"items":[' .. table.concat(items, ",") .. "]}"
end

---------------------------------------------------------------------------
-- Scenarios
---------------------------------------------------------------------------
fire("ADDON_LOADED", ADDON)
STATE.class = "DRUID"
LEARN("Mark of the Wild", "Thorns", "Omen of Clarity", "Gift of the Wild", "Rebirth")
fire("PLAYER_LOGIN")
tick()
TO.main.__left, TO.main.__top = 400, 600
TO:RestorePosition()

local EAT = " Must remain seated while eating."
STATE.level = 40
STATE.instance = true
STATE.party = { "party1", "party2" }
STATE.partyBuffs = { party1 = { ["Mark of the Wild"] = 900 }, party2 = {} }
STATE.buffs = { ["Thorns"] = 40 }
STATE.freeSlots = 2
STATE.bags = {
    { id = 102, name = "Mutton Chop", count = 6, tip = "Requires Level 25\nUse: Restores 552 health over 21 sec." .. EAT },
    { id = 104, name = "Spiced Wolf Meat", count = 3, tip = "Requires Level 5\nUse: Restores 61 health over 15 sec." .. EAT
        .. " If you spend at least 10 seconds eating you will become well fed and gain 2 Stamina and Spirit for 15 min." },
    { id = 106, name = "Melon Juice", count = 19, tip = "Requires Level 15\nUse: Restores 835 mana over 27 sec. Must remain seated while drinking." },
    { id = 107, name = "Heavy Linen Bandage", count = 12, tip = "Use: Heals 114 damage over 6 sec." },
    { id = 110, name = "Healing Potion", count = 2, tip = "Requires Level 12\nUse: Restores 280 to 360 health." },
    { id = 111, name = "Mana Potion", count = 3, tip = "Requires Level 14\nUse: Restores 280 to 360 mana." },
    { id = 301, name = "Elixir of the Mongoose", count = 3, spell = "Elixir of the Mongoose" },
    { id = 302, name = "Flask of Distilled Wisdom", count = 1, spell = "Distilled Wisdom" },
    { id = 303, name = "Wild Berries", count = 4 },
}
TO:AddCustom("Swiftness Potion", 5)
TO:TrackElixir("Elixir of the Mongoose", true)
TO.db.locked = false
TO:RequestUpdate()
tick()
Dump("reminders", TO.main)
-- The combat bar, as it shows in combat (locked, header on)
TO.db.locked = true
TO:RequestUpdate()
tick()
TO.combat:Show()
Dump("combat-bar", TO.combat)
TO.combat:Hide()
TO.db.locked = false
TO:RequestUpdate()
tick()

TO:OpenConfig()
for _, t in ipairs(TO.OPTION_TABS) do
    TO:ShowOptionsTab(t.key)
    Dump("options-druid-" .. t.key, TO.config)
    Dump("tab-druid-" .. t.key, TO.config.scrollChild, true)
end

local function Class(cls, spells, tabs)
    STATE.class = cls
    SPELLBOOK, FUTURE = {}, {}
    LEARN(unpack(spells))
    fire("SPELLS_CHANGED")
    for _, key in ipairs(tabs) do
        TO:ShowOptionsTab(key)
        Dump("tab-" .. cls:lower() .. "-" .. key, TO.config.scrollChild, true)
    end
end
Class("HUNTER", { "Call Pet", "Revive Pet", "Feed Pet", "Aspect of the Hawk", "Aspect of the Monkey", "Trueshot Aura" }, { "buffs", "more" })
Class("WARLOCK", { "Summon Imp", "Summon Voidwalker", "Demon Skin", "Demon Armor", "Drain Soul", "Create Soulstone (Lesser)" }, { "buffs", "more" })
Class("ROGUE", { "Vanish", "Blind" }, { "buffs", "supplies" })
Class("PRIEST", { "Power Word: Fortitude", "Inner Fire", "Divine Spirit", "Prayer of Fortitude", "Levitate" }, { "buffs" })
Class("PALADIN", { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Devotion Aura", "Retribution Aura",
    "Righteous Fury" }, { "buffs" })

Class("MAGE", { "Arcane Intellect", "Ice Armor", "Conjure Water", "Conjure Food", "Conjure Mana Jade",
    "Teleport: Stormwind", "Slow Fall" }, { "supplies" })
Class("WARLOCK", { "Demon Skin", "Create Healthstone (Lesser)", "Drain Soul", "Summon Imp" }, { "supplies" })

-- Profiles tab with another character, and the "Editing" choice on a check tab
TO.db.chars["Aeri - Forever"] = { class = "PRIEST", settings = {} }
TO.db.chars["Grunt - Forever"] = { class = "WARRIOR", settings = {} }
STATE.class = "DRUID"
SPELLBOOK, FUTURE = {}, {}
LEARN("Mark of the Wild", "Thorns", "Omen of Clarity")
fire("SPELLS_CHANGED")
TO:ShowOptionsTab("profiles")
Dump("options-druid-profiles", TO.config)
TO.char.splitProfiles = true
TO:ShowOptionsTab("buffs")
Dump("tab-druid-buffs-split", TO.config.scrollChild, true)
TO.char.splitProfiles = false

-- Vendor panel
STATE.class = "PRIEST"
SPELLBOOK, FUTURE = {}, {}
LEARN("Prayer of Fortitude", "Levitate")
fire("SPELLS_CHANGED")
STATE.bags = { { id = 801, name = "Sacred Candle", count = 4 } }
STATE.merchant = { { name = "Sacred Candle", price = 500 }, { name = "Light Feather", price = 10 },
    { name = "Morning Glory Dew", price = 400, stack = 5 } }
TO:AddCustom("Morning Glory Dew", 20)
STATE.repairCost = 12345
fire("MERCHANT_SHOW")
Dump("vendor", TO.vendor)

local f = assert(io.open(arg and arg[1] or "tests/render-out.json", "w"))
f:write("[" .. table.concat(out, ",\n") .. "]")
f:close()
io.write("wrote " .. #out .. " views\n")
