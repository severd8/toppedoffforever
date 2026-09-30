-- ToppedOff Forever: options window
-- Left side: display settings. Right side: every check for your class, with on/off,
-- minimum counts, preferred spells, weapon items and your own items.

local ADDON, ns = ...
local TO = ns.TO

local refreshers = {}
local function AddRefresher(fn) table.insert(refreshers, fn) end
local function RunRefreshers() for _, fn in ipairs(refreshers) do fn() end end

---------------------------------------------------------------------------
-- Widget helpers
---------------------------------------------------------------------------
local function Label(parent, text, x, y, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

-- Section heading in the logo's gold
local function Heading(parent, text, x, y)
    local fs = Label(parent, text, x, y, "GameFontNormal")
    fs:SetTextColor(unpack(TO.COLORS.gold))
    return fs
end

local function CheckBox(parent, text, x, y, getter, setter, tip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(text)
    cb.label = fs
    cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    if tip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(text)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    cb:SetChecked(getter())
    return cb
end

-- A checkbox bound to an account-wide display setting
local function SettingCheck(parent, text, x, y, key, tip)
    local cb = CheckBox(parent, text, x, y, function() return TO.db[key] end, function(v)
        if key == "locked" then
            TO:SetLocked(v)
        else
            TO.db[key] = v
            TO:ApplySettings()
        end
    end, tip)
    AddRefresher(function() cb:SetChecked(TO.db[key] and true or false) end)
    return cb
end

local function Slider(parent, text, x, y, key, min, max, suffix)
    suffix = suffix or ""
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", x, y)

    local s = CreateFrame("Slider", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(180, 17)
    s:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    s:SetHitRectInsets(0, 0, -8, -8)
    if s.SetBackdrop and BACKDROP_SLIDER_8_8 then
        s:SetBackdrop(BACKDROP_SLIDER_8_8)
    else
        local track = s:CreateTexture(nil, "BACKGROUND")
        local n = TO.COLORS.navy
        track:SetColorTexture(n[1], n[2], n[3], 1)
        track:SetHeight(6)
        track:SetPoint("LEFT")
        track:SetPoint("RIGHT")
    end
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(min, max)
    s:SetValueStep(1)
    if s.SetObeyStepsOnDrag then s:SetObeyStepsOnDrag(true) end   -- missing on Forever

    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        title:SetText(text .. ": |cff" .. TO.GOLD_HEX .. v .. suffix .. "|r")
        if TO.db[key] ~= v then
            TO.db[key] = v
            TO:ApplySettings()
        end
    end)
    AddRefresher(function()
        s:SetValue(TO.db[key])
        title:SetText(text .. ": |cff" .. TO.GOLD_HEX .. TO.db[key] .. suffix .. "|r")
    end)
    return s
end

local function EditBox(parent, width, x, y, text, numeric, onCommit)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width, 20)
    e:SetPoint("TOPLEFT", x, y)
    e:SetAutoFocus(false)
    if numeric then e:SetNumeric(true) e:SetMaxLetters(4) end
    e:SetText(text or "")
    local function commit(self)
        if onCommit then onCommit(self:GetText()) end
        self:ClearFocus()
    end
    e:SetScript("OnEnterPressed", commit)
    e:SetScript("OnEditFocusLost", function(self) if onCommit then onCommit(self:GetText()) end end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

local function PanelButton(parent, text, width, x, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- Button that cycles through a list of spell names
local function SpellCycle(parent, x, y, options, getter, setter)
    local b = PanelButton(parent, "", 170, x, y)
    local function refresh() b:SetText(getter() or "") end
    b:SetScript("OnClick", function()
        local cur, nextIdx = getter(), 1
        for i, v in ipairs(options) do
            if v == cur then nextIdx = (i % #options) + 1 break end
        end
        setter(options[nextIdx])
        refresh()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Click to choose which spell to cast")
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    refresh()
    return b
end

---------------------------------------------------------------------------
-- Checks list (rebuilt every time the window opens, since it depends on
-- your class, spells and added items)
---------------------------------------------------------------------------
local ROW = 26

function TO:BuildChecksList()
    local frame = self.config
    if frame.checks then frame.checks:Hide() end
    local c = CreateFrame("Frame", nil, frame.scrollChild)
    c:SetPoint("TOPLEFT")
    c:SetSize(330, 10)
    frame.checks = c
    local y = 0

    local function header(text)
        y = y - 6
        Heading(c, text, 0, y)
        y = y - 20
    end
    local function note(text)
        Label(c, text, 28, y - 4, "GameFontDisableSmall")
        y = y - 18
    end
    local function toggle(id, label, default)
        local cb = CheckBox(c, label, 0, y, function() return TO:IsEnabled(id, default) end,
            function(v) TO:SetEnabled(id, v) end)
        return cb
    end

    local class = self:PlayerClass()

    -- Buffs
    local buffs = self.CLASS_BUFFS[class] or {}
    if #buffs > 0 then
        header("Buffs")
        for _, buff in ipairs(buffs) do
            local known = self:KnownOptions(buff.cast)
            local cb = toggle("buff:" .. buff.id, buff.label, not buff.off)
            if #known == 0 then
                cb.label:SetText(buff.label .. " |cff808080(not learned)|r")
            elseif #known > 1 then
                SpellCycle(c, 160, y, known, function() return TO:BuffPreference(buff) end,
                    function(v) TO.char.prefs[buff.id] = v TO:RequestUpdate() end)
            end
            y = y - ROW
        end
    end

    -- Well Fed (stat food buff)
    header("Stat food buff")
    toggle("wellfed", "Well Fed", true)
    y = y - ROW
    CheckBox(c, "Only in dungeons and raids", 24, y, function() return TO.char.wellFedInstanceOnly end,
        function(v) TO.char.wellFedInstanceOnly = v TO:RequestUpdate() end)
    y = y - ROW
    note("Click the icon to eat your stat food (see Your own items).")

    -- Weapons
    header("Weapon enhancement")
    local w = self:WeaponConfig()
    if w.kind == "spell" then
        local known = self:KnownOptions(w.cast)
        local cb = toggle("weapon:mh", "Weapon buff", true)
        if #known == 0 then
            cb.label:SetText("Weapon buff |cff808080(not learned)|r")
        elseif #known > 1 then
            SpellCycle(c, 160, y, known, function() return TO:WeaponConfig().spell end,
                function(v) TO.char.weapon.spell = v TO:RequestUpdate() end)
        end
        y = y - ROW
    else
        for _, key in ipairs({ "mh", "oh" }) do
            toggle("weapon:" .. key, key == "mh" and "Main hand" or "Off hand", true)
            EditBox(c, 150, 170, y - 2, w[key], false, function(text)
                TO.char.weapon[key] = strtrim and strtrim(text) or text
                TO:RequestUpdate()
            end)
            y = y - ROW
        end
        note("Item to use, like Wizard Oil. Blank = off.")
    end

    -- Reagents
    local reagents = self.CLASS_REAGENTS[class] or {}
    local showAmmo = self.AMMO_CLASSES[class] or class == "WARRIOR" or class == "ROGUE"
    header("Reagents and ammo")
    local function minBox(id, default)
        EditBox(c, 40, 288, y - 2, tostring(TO:ReagentMin(id, default)), true, function(text)
            local n = tonumber(text)
            if n and n >= 0 then TO.char.mins[id] = math.floor(n) TO:RequestUpdate() end
        end)
    end
    for _, rg in ipairs(reagents) do
        local id = "reagent:" .. rg.id
        local cb = toggle(id, rg.label, true)
        if not self:FirstKnown(rg.requires) then
            cb.label:SetText(rg.label .. " |cff808080(not learned)|r")
        end
        minBox(id, rg.min)
        y = y - ROW
    end
    if showAmmo then
        toggle("ammo", "Ammo", self.AMMO_CLASSES[class] == true)
        minBox("ammo", self.AMMO_DEFAULT_MIN)
        y = y - ROW
    end
    if #reagents > 0 or showAmmo then note("Number on the right = remind me below this many.") end

    -- Durability
    header("Gear")
    toggle("durability", "Low durability (set % on the left)", true)
    y = y - ROW

    -- Your own items
    header("Your own items")
    local function subheading(text)
        Label(c, text, 4, y - 2, "GameFontNormalSmall")
        y = y - 18
    end

    -- Auto-tracked: the best of each kind in your bags
    subheading("Auto-tracked (best in your bags)")
    self:UpdateAutoItems()
    local hasMana = self.MANA_CLASSES[class]
    local autoLabels = {}
    local function slotText(slot)
        local a = self.char.auto[slot.key]
        return slot.label .. ": " .. (a and a.name or "|cff808080none in your bags yet|r")
    end
    for _, slot in ipairs(self.AUTO_SLOTS) do
        if not slot.mana or hasMana then
            local a = self.char.auto[slot.key]
            local cb = toggle("auto:" .. slot.key, slotText(slot), true)
            autoLabels[slot.key] = { cb = cb, slot = slot }
            cb.label:SetWidth(196)
            cb.label:SetWordWrap(false)
            cb.label:SetJustifyH("LEFT")
            if a then
                EditBox(c, 40, 230, y - 2, tostring(a.min or slot.min), true, function(t)
                    local n = tonumber(t)
                    if n and n >= 1 then a.min = math.floor(n) TO:RequestUpdate() end
                end)
            end
            y = y - ROW
        end
    end
    -- Which stats the stat food should give
    Label(c, "Stat food for", 28, y - 4, "GameFontHighlightSmall")
    local focusKeys = { false }
    for _, k in ipairs(self.STAT_KEYS) do focusKeys[#focusKeys + 1] = k end
    local function focusLabel(k)
        if not k then
            local base = (self.CLASS_STATS[class] or { "sta" })[1]
            return "Class default (" .. self.STAT_LABELS[base] .. ")"
        end
        return self.STAT_LABELS[k]
    end
    local focusBtn = PanelButton(c, focusLabel(self.char.statFocus), 190, 110, y)
    focusBtn:SetScript("OnClick", function(b)
        local cur, nextIdx = self.char.statFocus or false, 1
        for i, k in ipairs(focusKeys) do
            if k == cur then nextIdx = (i % #focusKeys) + 1 break end
        end
        TO:SetStatFocus(focusKeys[nextIdx] or nil)
        TO:UpdateAutoItems()
        b:SetText(focusLabel(TO.char.statFocus))
        local row = autoLabels.statfood
        if row then row.cb.label:SetText(slotText(row.slot)) end
    end)
    y = y - ROW
    note("Better items replace these automatically. Uncheck one to stop tracking it.")

    subheading("Added by you")
    for _, item in ipairs(self.char.custom) do
        local name = item.name
        toggle("custom:" .. name:lower(), name, true)
        EditBox(c, 40, 230, y - 2, tostring(item.min), true, function(text)
            local n = tonumber(text)
            if n and n >= 1 then item.min = math.floor(n) TO:RequestUpdate() end
        end)
        PanelButton(c, "Remove", 60, 275, y, function()
            TO:RemoveCustom(name)
            TO:BuildChecksList()
        end)
        y = y - ROW
    end
    Label(c, "Item", 4, y - 4, "GameFontHighlightSmall")
    local nameBox = EditBox(c, 160, 36, y, "", false)
    Label(c, "Min", 206, y - 4, "GameFontHighlightSmall")
    local minEdit = EditBox(c, 40, 232, y, "20", true)
    PanelButton(c, "Add", 50, 280, y + 1, function()
        if TO:AddCustom(nameBox:GetText(), minEdit:GetText()) then
            TO:BuildChecksList()
        else
            TO.Print("type an item name and a number first.")
        end
    end)
    y = y - ROW
    note("Food, water, potions, anything. Exact item name.")
    CheckBox(c, "Always show these, with counts", 0, y, function() return TO.char.customAlways end,
        function(v) TO.char.customAlways = v TO:RequestUpdate() end,
        "Show your own items even when you have enough. Click an icon to use the item.")
    y = y - ROW

    c:SetHeight(-y + 10)
    frame.scrollChild:SetHeight(-y + 10)
end

function TO:RefreshConfig()
    if self.config and self.config:IsShown() then
        RunRefreshers()
        self:BuildChecksList()
    end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
function TO:BuildConfig()
    local f = CreateFrame("Frame", "ToppedOffForeverOptions", UIParent)
    f:SetSize(620, 508)
    TO:SkinFrame(f, TO.COLORS.purple, TO.COLORS.goldDark, 0.96, 2)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()
    table.insert(UISpecialFrames, "ToppedOffForeverOptions")   -- Escape closes it

    -- Crimson title banner with gold edges, like the logo's ribbon
    local banner = CreateFrame("Frame", nil, f)
    banner:SetPoint("TOPLEFT", 2, -2)
    banner:SetPoint("TOPRIGHT", -2, -2)
    banner:SetHeight(28)
    TO:SkinFrame(banner, TO.COLORS.crimson, TO.COLORS.goldDark, 1, 1)
    local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER")
    title:SetText("ToppedOff Forever")
    title:SetTextColor(unpack(TO.COLORS.gold))
    f.banner = banner

    local close = CreateFrame("Button", nil, banner, "UIPanelCloseButton")
    close:SetPoint("RIGHT", 2, 0)
    close:SetScript("OnClick", function() f:Hide() end)
    self.config = f

    -- Logo in the top-left corner
    -- Its own frame, drawn above the title banner so the banner doesn't cover it
    local logoFrame = CreateFrame("Frame", nil, f)
    logoFrame:SetAllPoints(f)
    logoFrame:SetFrameLevel(banner:GetFrameLevel() + 5)
    local logo = logoFrame:CreateTexture(nil, "OVERLAY")
    logo:SetSize(60, 60)
    logo:SetPoint("TOPLEFT", -18, 18)
    logo:SetTexture(TO.ICONS.addon)
    f.logo = logo

    -- Left column: display
    local x, y = 16, -46
    Heading(f, "Display", x + 30, y)
    y = y - 22
    SettingCheck(f, "Show reminders", x, y, "shown")
    y = y - 24
    SettingCheck(f, "Lock position", x, y, "locked", "Unlock to drag the reminders by the ToppedOff header above them.")
    y = y - 24
    SettingCheck(f, "Hide in combat", x, y, "hideInCombat",
        "Reminders can only change out of combat, so hiding them in combat keeps things tidy.")
    y = y - 24
    SettingCheck(f, "Only in dungeons and raids", x, y, "onlyInInstance")
    y = y - 24
    SettingCheck(f, "Show header and frame", x, y, "showHeader",
        "The ToppedOff frame around the icons. It always shows while unlocked, so you can drag it by the header.")
    y = y - 24
    SettingCheck(f, "Minimap button", x, y, "minimap")
    y = y - 34
    Slider(f, "Icon size", x + 4, y, "iconSize", 20, 64)
    y = y - 46
    Slider(f, "Warn before buffs run out", x + 4, y, "warnMinutes", 1, 10, " min")
    y = y - 46
    Slider(f, "Durability warning below", x + 4, y, "durabilityPct", 5, 75, "%")
    y = y - 44
    Heading(f, "Chat reminders", x, y)
    y = y - 22
    SettingCheck(f, "On ready check", x, y, "readyCheck", "Lists anything missing in chat when a ready check starts.")
    y = y - 24
    SettingCheck(f, "On entering a dungeon or raid", x, y, "instanceReminder")
    y = y - 24
    SettingCheck(f, "Play a sound with chat reminders", x, y, "sound")
    y = y - 32
    PanelButton(f, "Reset position", 120, x, y, function()
        SlashCmdList.TOPPEDOFFFOREVER("reset")
    end)
    PanelButton(f, "Check spells", 110, x + 126, y, function() TO:Check() end)

    -- Right column: checks
    Heading(f, "What to check (this character)", 262, -46)
    -- Navy panel behind the checks list
    local panel = CreateFrame("Frame", nil, f)
    panel:SetPoint("TOPLEFT", 252, -66)
    panel:SetPoint("BOTTOMRIGHT", -8, 8)
    TO:SkinFrame(panel, TO.COLORS.navy, TO.COLORS.goldDark, 0.9, 1)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 258, -72)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(330, 10)
    scroll:SetScrollChild(child)
    f.scroll = scroll
    f.scrollChild = child

    f:SetScript("OnShow", function()
        RunRefreshers()
        TO:BuildChecksList()
    end)
end

function TO:OpenConfig()
    if not self.config then self:BuildConfig() end
    if self.config:IsShown() then
        self.config:Hide()
    else
        self.config:Show()
    end
end

function TO:ToggleConfig() self:OpenConfig() end
