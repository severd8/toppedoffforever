-- ToppedOff Forever: options window
-- Left side: display settings (account-wide). Right side: what to check for this
-- character, in three tabs: Buffs, Supplies, and Pet & gear.

local _, ns = ...
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
-- Checks (right side), split into three tabs. Rebuilt every time the window
-- opens or the tab changes, since it depends on your class, spells and bags.
---------------------------------------------------------------------------
local ROW = 26
local RIGHT = 320     -- right edge of every row
local MIN_X = 236     -- "Min" boxes line up in one column
local MIN_W = 40
local X_X = 298       -- remove buttons line up at the far right
local CYCLE_X = 150   -- spell choice buttons
local CYCLE_W = RIGHT - CYCLE_X
local LABEL_W = MIN_X - 34   -- a checkbox label that stops before the Min column

TO.OPTION_TABS = {
    { key = "buffs",    label = "Buffs" },
    { key = "supplies", label = "Supplies" },
    { key = "more",     label = "Pet & gear" },
    { key = "profiles", label = "Profiles" },
}

-- Which set of on/off checks the options are editing (see the Profiles tab)
function TO:EditingOutside()
    return (self.char.splitProfiles and self.editOutside) and true or false
end

-- Row helpers shared by the tabs. `ctx` holds the frame being filled and the y cursor.
local function Builder(c)
    local ctx = { c = c, y = 0 }

    function ctx.header(text, minLabel)
        ctx.y = ctx.y - (ctx.y == 0 and 2 or 12)
        local h = Heading(c, text, 0, ctx.y)
        local line = c:CreateTexture(nil, "ARTWORK")
        local g = TO.COLORS.goldDark
        line:SetColorTexture(g[1], g[2], g[3], 0.5)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", 0, ctx.y - 17)
        line:SetPoint("TOPRIGHT", c, "TOPLEFT", RIGHT, ctx.y - 17)
        if minLabel then
            local m = Label(c, minLabel, MIN_X, ctx.y - 3, "GameFontDisableSmall")
            m:SetWidth(MIN_W)
            m:SetJustifyH("CENTER")
        end
        ctx.y = ctx.y - 24
        return h
    end

    function ctx.note(text)
        local n = Label(c, text, 26, ctx.y - 2, "GameFontDisableSmall")
        n:SetWidth(RIGHT - 26)
        n:SetJustifyH("LEFT")
        n:SetWordWrap(true)
        ctx.y = ctx.y - math.max(16, math.ceil((n:GetStringHeight() or 12)) + 4)
        return n
    end

    -- Checkbox bound to a check id (on/off per character, in the set being edited)
    c.toggles = {}
    function ctx.toggle(id, label, default, x)
        local function get() return TO:IsEnabled(id, default, TO:EditingOutside()) end
        local cb = CheckBox(c, label, x or 0, ctx.y, get, function(v) TO:SetEnabled(id, v, TO:EditingOutside()) end)
        cb.refresh = function() cb:SetChecked(get()) end
        c.toggles[#c.toggles + 1] = cb
        return cb
    end

    -- Checkbox bound to a per-character setting
    function ctx.charCheck(label, key, x, tip)
        return CheckBox(c, label, x or 0, ctx.y, function() return TO.char[key] and true or false end,
            function(v) TO.char[key] = v TO:RequestUpdate() end, tip)
    end

    -- Keep a label clear of the Min column
    function ctx.fit(cb)
        cb.label:SetWidth(LABEL_W)
        cb.label:SetWordWrap(false)
        cb.label:SetJustifyH("LEFT")
    end

    -- Min box in the Min column; onCommit gets the new number
    function ctx.minBox(value, onCommit, allowZero)
        return EditBox(c, MIN_W, MIN_X, ctx.y - 2, tostring(value), true, function(text)
            local n = tonumber(text)
            if n and (n >= 1 or (allowZero and n >= 0)) then onCommit(math.floor(n)) TO:RequestUpdate() end
        end)
    end
    function ctx.reagentMin(id, default)
        return ctx.minBox(TO:ReagentMin(id, default), function(n) TO.char.mins[id] = n end, true)
    end

    function ctx.row() ctx.y = ctx.y - ROW end
    return ctx
end

local function NotLearned(cb, text)
    cb.label:SetText(text .. " |cff808080(not learned)|r")
end

-- A button that opens a list to pick from (steps through the choices if menus
-- aren't available). choices = { { value = , text = }, ... }
local function Dropdown(parent, x, y, width, choices, getter, setter, tip)
    local b = PanelButton(parent, "", width, x, y)
    local function label()
        local cur = getter()
        for _, ch in ipairs(choices) do if ch.value == cur then return ch.text end end
        return choices[1] and choices[1].text or ""
    end
    b:SetText(label())
    b:SetScript("OnClick", function(self)
        local function pick(v) setter(v) self:SetText(label()) end
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(_, root)
                for _, ch in ipairs(choices) do
                    root:CreateRadio(ch.text, function() return getter() == ch.value end, function() pick(ch.value) end)
                end
            end)
        else
            local cur, nextIdx = getter(), 1
            for i, ch in ipairs(choices) do
                if ch.value == cur then nextIdx = (i % #choices) + 1 break end
            end
            pick(choices[nextIdx].value)
        end
    end)
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
end

-- Small red X that removes a row
local function RemoveButton(parent, x, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    b:SetSize(22, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Remove")
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

---------------------------------------------------------------------------
-- Buffs tab: your buffs, party buffs, weapon, Well Fed, elixirs and flasks
---------------------------------------------------------------------------
local function BuildBuffsTab(self, ctx, class)
    local c = ctx.c
    local buffs = self.CLASS_BUFFS[class] or {}
    if #buffs > 0 then
        ctx.header("Your buffs")
        for _, buff in ipairs(buffs) do
            local known = self:KnownOptions(buff.cast)
            if not (buff.racial and #known == 0) then   -- racial buffs only for races that have them
                local cb = ctx.toggle("buff:" .. buff.id, buff.label, not buff.off)
                if #known == 0 then
                    NotLearned(cb, buff.label)
                elseif #known > 1 then
                    cb.label:SetWidth(CYCLE_X - 30)
                    cb.label:SetWordWrap(false)
                    cb.label:SetJustifyH("LEFT")
                    SpellCycle(c, CYCLE_X, ctx.y, known, function() return TO:BuffPreference(buff) end,
                        function(v) TO.char.prefs[buff.id] = v TO:RequestUpdate() end)
                end
                ctx.row()
            end
        end

        local partyBuffs = {}
        for _, buff in ipairs(buffs) do if buff.party then partyBuffs[#partyBuffs + 1] = buff end end
        if #partyBuffs > 0 then
            ctx.header("Party buffs")
            for _, buff in ipairs(partyBuffs) do
                local cb = ctx.toggle("party:" .. buff.id, buff.label .. " on your party", not buff.off)
                if #self:KnownOptions(buff.cast) == 0 then NotLearned(cb, buff.label .. " on your party") end
                ctx.row()
            end
            ctx.charCheck("In raids, check the whole raid", "wholeRaid", 24)
            ctx.row()
            ctx.note("Shows how many party members are missing it. Click to buff the next one in range.")
        end
    end

    -- Paladin: which blessing each class in your party gets
    if class == "PALADIN" then
        ctx.header("Party blessings")
        ctx.toggle("party:blessing", "Bless your party", true)
        ctx.row()
        local choices = {}
        for _, b in ipairs(self.BLESSING_NAMES) do
            if self:Knows("Blessing of " .. b) then choices[#choices + 1] = { value = b, text = "Blessing of " .. b } end
        end
        choices[#choices + 1] = { value = "none", text = "None" }
        for _, cls in ipairs(self.BLESSING_CLASSES) do
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
            local name = Label(c, self.CLASS_PLURALS[cls], 26, ctx.y - 5, "GameFontHighlight")
            if color then name:SetTextColor(color.r, color.g, color.b) end
            Dropdown(c, CYCLE_X, ctx.y, CYCLE_W, choices,
                function()
                    local spell = TO:BlessingFor(cls)
                    return spell and spell:gsub("^Blessing of ", "") or "none"
                end,
                function(v) TO.char.blessings[cls] = v TO:RequestUpdate() end,
                "Blessing to give " .. self.CLASS_PLURALS[cls] .. " in your party")
            ctx.row()
        end
        ctx.charCheck("In raids, check the whole raid", "wholeRaid", 24)
        ctx.row()
        ctx.note("Shows how many party members are missing their blessing. Click to bless the next one in range. "
            .. "A Greater Blessing, or the same blessing from another Paladin, counts.")
    end

    -- Weapon enhancement
    ctx.header("Weapon enhancement", class == "ROGUE" and "Min" or nil)
    local w = self:WeaponConfig()
    if w.kind == "spell" then
        local known = self:KnownOptions(w.cast)
        local cb = ctx.toggle("weapon:mh", "Weapon buff", true)
        if #known == 0 then
            NotLearned(cb, "Weapon buff")
        elseif #known > 1 then
            SpellCycle(c, CYCLE_X, ctx.y, known, function() return TO:WeaponConfig().spell end,
                function(v) TO.char.weapon.spell = v TO:RequestUpdate() end)
        end
        ctx.row()
    else
        for _, key in ipairs({ "mh", "oh" }) do
            ctx.toggle("weapon:" .. key, key == "mh" and "Main hand" or "Off hand", true)
            EditBox(c, CYCLE_W - 6, CYCLE_X + 6, ctx.y - 2, w[key], false, function(text)
                TO.char.weapon[key] = strtrim and strtrim(text) or text
                TO:RequestUpdate()
            end)
            ctx.row()
        end
        if class == "ROGUE" then
            local cb = ctx.toggle("charges", "Warn when poison charges run low", true)
            ctx.fit(cb)
            ctx.reagentMin("charges", self.CHARGES_DEFAULT_MIN)
            ctx.row()
        end
        ctx.note("Item to use on each weapon, like Instant Poison or Wizard Oil. Blank = off. "
            .. "Your best rank in your bags is used.")
    end

    -- Well Fed
    ctx.header("Food buff")
    ctx.toggle("wellfed", "Well Fed", true)
    ctx.row()
    ctx.charCheck("Only in dungeons and raids", "wellFedInstanceOnly", 24)
    ctx.row()
    ctx.note("Click the icon to eat your stat food (set on the Supplies tab).")

    -- Elixirs and flasks
    ctx.header("Elixirs and flasks")
    local shown = {}
    for _, el in ipairs(self.char.elixirs) do
        shown[el.name:lower()] = true
        local cb = CheckBox(c, el.name, 0, ctx.y, function() return true end,
            function(v) TO:TrackElixir(el.name, v) end)
        ctx.fit(cb)
        ctx.row()
    end
    for _, e in ipairs(self:BagElixirs()) do
        if not shown[e.name:lower()] then
            local cb = CheckBox(c, e.name, 0, ctx.y, function() return false end,
                function(v) TO:TrackElixir(e.name, v) end)
            ctx.fit(cb)
            ctx.row()
        end
    end
    if #self.char.elixirs == 0 and #self:BagElixirs() == 0 then
        Label(c, "|cff808080No elixirs or flasks in your bags.|r", 26, ctx.y - 4, "GameFontHighlightSmall")
        ctx.row()
    end
    ctx.y = ctx.y - 4
    ctx.charCheck("Only in dungeons and raids", "elixirInstanceOnly", 24)
    ctx.row()
    ctx.note("Elixirs and flasks in your bags are listed here. Tick one to be reminded when its buff is "
        .. "missing or running out. Click the icon to drink it.")
end

---------------------------------------------------------------------------
-- Supplies tab: auto-tracked food, water, potions; your own items; reagents
---------------------------------------------------------------------------
local function BuildSuppliesTab(self, ctx, class)
    local c = ctx.c

    ctx.header("Food, water and potions", "Min")
    self:UpdateAutoItems()
    local hasMana = self.MANA_CLASSES[class]
    local autoRows = {}
    local function slotText(slot)
        local a = self.char.auto[slot.key]
        return slot.label .. ": " .. (a and a.name or "|cff808080none in bags yet|r")
    end
    for _, slot in ipairs(self.AUTO_SLOTS) do
        if not slot.mana or hasMana then
            local a = self.char.auto[slot.key]
            local cb = ctx.toggle("auto:" .. slot.key, slotText(slot), true)
            ctx.fit(cb)
            autoRows[slot.key] = { cb = cb, slot = slot }
            if a then ctx.minBox(a.min or slot.min, function(n) a.min = n TO.char.autoMins[slot.key] = n end) end
            ctx.row()
        end
    end
    -- Healthstone
    if class == "WARLOCK" then
        if self:FirstKnown(self.HEALTHSTONE_SPELLS) then
            ctx.fit(ctx.toggle("healthstone", "Healthstone (click to make one)", true))
            ctx.row()
        end
    else
        ctx.fit(ctx.toggle("healthstone", "Healthstone, if a Warlock is along", true))
        ctx.row()
    end
    Label(c, "Stat food for", 26, ctx.y - 5, "GameFontHighlightSmall")
    local focusKeys = { false }
    for _, k in ipairs(self.STAT_KEYS) do focusKeys[#focusKeys + 1] = k end
    local function focusLabel(k)
        if not k then
            local prio, role = TO:AutoStatPriority()
            local who = role and TO.ROLE_LABELS[role] or "Auto"
            return who .. ": " .. TO.STAT_LABELS[prio[1]]
        end
        return TO.STAT_LABELS[k] .. " (your pick)"
    end
    local focusBtn = PanelButton(c, focusLabel(self.char.statFocus), CYCLE_W, CYCLE_X, ctx.y)
    local function choose(k)
        TO:SetStatFocus(k or nil)
        TO:UpdateAutoItems()
        focusBtn:SetText(focusLabel(TO.char.statFocus))
        local row = autoRows.statfood
        if row then row.cb.label:SetText(slotText(row.slot)) end
    end
    -- A list to pick from (or step through the choices if menus aren't available)
    focusBtn:SetScript("OnClick", function(b)
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(b, function(_, root)
                root:CreateTitle("Stat food")
                for _, k in ipairs(focusKeys) do
                    local text = k and TO.STAT_LABELS[k] or ("Automatic (" .. focusLabel(nil) .. ")")
                    root:CreateRadio(text, function() return (TO.char.statFocus or false) == k end,
                        function() choose(k) end)
                end
            end)
        else
            local cur, nextIdx = TO.char.statFocus or false, 1
            for i, k in ipairs(focusKeys) do
                if k == cur then nextIdx = (i % #focusKeys) + 1 break end
            end
            choose(focusKeys[nextIdx])
        end
    end)
    focusBtn:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Stat food")
        GameTooltip:AddLine("Automatic picks food for your role, and falls back to any stat food. "
            .. "Pick a stat yourself (like Strength for a Protection Paladin) to track only food with that stat.",
            1, 1, 1, true)
        GameTooltip:Show()
    end)
    focusBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ctx.row()
    ctx.note("The best of each in your bags is picked for you, and better ones take over as you level. "
        .. "Stat food follows your talents (or group role). Untick one to stop tracking it.")

    -- Mage conjures
    if class == "MAGE" then
        ctx.header("Conjured food and water", "Min")
        for _, cj in ipairs(self.CONJURES) do
            local id = "conjure:" .. cj.key
            local cb = ctx.toggle(id, cj.label, true)
            ctx.fit(cb)
            if not self:Knows(cj.spell) then NotLearned(cb, cj.label) end
            ctx.reagentMin(id, cj.min)
            ctx.row()
        end
        local gem
        for _, g in ipairs(self.MANA_GEMS) do if self:Knows(g.spell) then gem = g break end end
        local cb = ctx.toggle("conjure:gem", gem and ("Mana gem: " .. gem.item) or "Mana gem", true)
        ctx.fit(cb)
        if not gem then NotLearned(cb, "Mana gem") end
        ctx.row()
        ctx.note("Click to conjure your best rank.")
    end

    ctx.header("Your own items", "Min")
    for _, item in ipairs(self.char.custom) do
        local name = item.name
        local cb = ctx.toggle("custom:" .. name:lower(), name, true)
        ctx.fit(cb)
        ctx.minBox(item.min, function(n) item.min = n end)
        RemoveButton(c, X_X, ctx.y, function()
            TO:RemoveCustom(name)
            TO:ShowOptionsTab("supplies")
        end)
        ctx.row()
    end
    Label(c, "Item", 4, ctx.y - 5, "GameFontHighlightSmall")
    local nameBox = EditBox(c, MIN_X - 44, 38, ctx.y - 2, "", false)
    local minEdit = EditBox(c, MIN_W, MIN_X, ctx.y - 2, "20", true)
    PanelButton(c, "Add", RIGHT - (MIN_X + MIN_W + 6), MIN_X + MIN_W + 6, ctx.y - 1, function()
        if TO:AddCustom(nameBox:GetText(), minEdit:GetText()) then
            TO:ShowOptionsTab("supplies")
        else
            TO.Print("type an item name and a number first.")
        end
    end)
    ctx.row()
    ctx.charCheck("Always show these, as a quick-use bar", "customAlways", 0,
        "Show your food, water, potions and items even when you have enough, dimmed, so you can click to use them. "
        .. "Low ones are bright with a red count.")
    ctx.row()
    ctx.note("Anything else you want to keep stocked. Exact item name.")

    local reagents = self.CLASS_REAGENTS[class] or {}
    local showAmmo = self.AMMO_CLASSES[class] or class == "WARRIOR" or class == "ROGUE"
    local function vendorSection()
        ctx.header("At vendors")
        ctx.charCheck("Show a restock list", "restockAtVendor")
        ctx.row()
        ctx.charCheck("Show a Repair all button", "repairAtVendor")
        ctx.row()
        ctx.note("Beside the vendor window: everything above that's below its Min and this vendor sells. "
            .. "Nothing is bought until you click Restock.")
    end
    if #reagents > 0 or showAmmo then
        ctx.header("Reagents and ammo", "Min")
        for _, rg in ipairs(reagents) do
            local id = "reagent:" .. rg.id
            local cb = ctx.toggle(id, rg.label, true)
            ctx.fit(cb)
            if not self:FirstKnown(rg.requires) then NotLearned(cb, rg.label) end
            ctx.reagentMin(id, rg.min)
            ctx.row()
        end
        if showAmmo then
            ctx.fit(ctx.toggle("ammo", "Ammo", self.AMMO_CLASSES[class] == true))
            ctx.reagentMin("ammo", self.AMMO_DEFAULT_MIN)
            ctx.row()
        end
    end
    vendorSection()
end

---------------------------------------------------------------------------
-- Pet & gear tab: pet, Soulstone, durability, bag space
---------------------------------------------------------------------------
local function BuildMoreTab(self, ctx, class)
    local c = ctx.c
    if self.PET_CLASSES[class] then
        ctx.header("Pet", class == "HUNTER" and "Min" or nil)
        if class == "HUNTER" then
            local cb = ctx.toggle("pet:summon", "Pet is out and alive", true)
            if not self:Knows("Call Pet") then NotLearned(cb, "Pet is out and alive") end
            ctx.row()
            ctx.toggle("pet:happy", "Pet is happy", true)
            ctx.row()
            local fcb = ctx.toggle("pet:food", "Pet food", true)
            fcb.label:SetWidth(70)
            EditBox(c, MIN_X - 110, 102, ctx.y - 2, self.char.petFood or "", false, function(text)
                TO.char.petFood = strtrim and strtrim(text) or text
                TO:RequestUpdate()
            end)
            ctx.reagentMin("pet:food", self.PET_FOOD_DEFAULT_MIN)
            ctx.row()
            ctx.note("Type your pet's food, like Roasted Quail. Then one click feeds your pet, "
                .. "and you're reminded when you're low.")
        else
            local known = self:KnownOptions(self.WARLOCK_PETS)
            local cb = ctx.toggle("pet:summon", "Demon is out", true)
            if #known == 0 then
                NotLearned(cb, "Demon is out")
            elseif #known > 1 then
                SpellCycle(c, CYCLE_X, ctx.y, known, function() return TO:PetSummonSpell() end,
                    function(v) TO.char.prefs.pet = v TO:RequestUpdate() end)
            end
            ctx.row()
        end
        ctx.note("Not shown while mounted or resting in a town or inn.")
    end

    if class == "WARLOCK" then
        ctx.header("Soulstone")
        local cb = ctx.toggle("soulstone", "Someone in the group has one", true)
        if not self:FirstKnown(self.SOULSTONE_SPELLS) then NotLearned(cb, "Someone in the group has one") end
        ctx.row()
        ctx.charCheck("Only in dungeons and raids", "soulstoneInstanceOnly", 24)
        ctx.row()
        ctx.charCheck("In raids, check the whole raid", "wholeRaid", 24)
        ctx.row()
        ctx.note("Click to put your Soulstone on the healer (or your friendly target), or to make one.")
    end

    ctx.header("Gear and bags", "Min")
    ctx.fit(ctx.toggle("durability", "Low durability", true))
    Label(c, "|cff808080set % on the left|r", MIN_X - 20, ctx.y - 5, "GameFontHighlightSmall")
    ctx.row()
    ctx.fit(ctx.toggle("bags", "Free bag slots", true))
    ctx.reagentMin("bags", self.BAGS_DEFAULT_MIN)
    ctx.row()
end

---------------------------------------------------------------------------
-- Profiles tab: separate checks outside dungeons; copy another character
---------------------------------------------------------------------------
StaticPopupDialogs["TOPPEDOFFFOREVER_COPY"] = {
    text = "Copy ToppedOff settings from %s?\nThis replaces this character's checks, Min counts and choices.",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, key)
        if TO:CopySettingsFrom(key) then
            TO.Print("copied settings from " .. key .. ".")
            TO:ShowOptionsTab("profiles")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function BuildProfilesTab(self, ctx)
    local c = ctx.c
    ctx.header("Dungeons and the open world")
    CheckBox(c, "Separate checks outside dungeons and raids", 0, ctx.y,
        function() return TO.char.splitProfiles and true or false end,
        function(v)
            TO.char.splitProfiles = v
            TO.editOutside = false
            TO:RequestUpdate()
        end)
    ctx.row()
    ctx.note("Turn this on to have a lighter set of checks while questing. Each tab then has an "
        .. "\"Editing\" choice at the top: tick and untick checks for dungeons and raids, or for everywhere else. "
        .. "Anything you don't change outside follows the dungeon setting.")

    ctx.header("Copy another character")
    local others = self:OtherCharacters()
    if #others == 0 then
        Label(c, "|cff808080No other characters yet. Log in with them once.|r", 26, ctx.y - 4, "GameFontHighlightSmall")
        ctx.row()
    else
        local choices = {}
        for _, o in ipairs(others) do
            local cls = o.class and o.class:sub(1, 1) .. o.class:sub(2):lower() or "?"
            choices[#choices + 1] = { value = o.key, text = o.key .. " (" .. cls .. ")" }
        end
        self.copySource = self.copySource or others[1].key
        local ok = false
        for _, o in ipairs(others) do if o.key == self.copySource then ok = true end end
        if not ok then self.copySource = others[1].key end
        Dropdown(c, 0, ctx.y, RIGHT - 76, choices, function() return TO.copySource end,
            function(v) TO.copySource = v end)
        PanelButton(c, "Copy", 70, RIGHT - 70, ctx.y, function()
            local key = TO.copySource
            if not key then return end
            if StaticPopup_Show then
                local dialog = StaticPopup_Show("TOPPEDOFFFOREVER_COPY", key)
                if dialog then dialog.data = key end
            elseif TO:CopySettingsFrom(key) then
                TO:ShowOptionsTab("profiles")
            end
        end)
        ctx.row()
    end
    ctx.note("Copies checks, Min counts, your own items, blessing and stat food choices. "
        .. "Display settings on the left are already shared by all your characters.")
end

local TAB_BUILDERS = { buffs = BuildBuffsTab, supplies = BuildSuppliesTab, more = BuildMoreTab,
    profiles = BuildProfilesTab }

function TO:BuildChecksList()
    local frame = self.config
    if frame.checks then frame.checks:Hide() end
    local c = CreateFrame("Frame", nil, frame.scrollChild)
    c:SetPoint("TOPLEFT")
    c:SetSize(RIGHT + 4, 10)
    frame.checks = c
    local ctx = Builder(c)
    local tab = self.optionsTab or "buffs"
    if self.char.splitProfiles and tab ~= "profiles" then
        Label(c, "Editing checks for", 0, -6, "GameFontNormal")
        Dropdown(c, CYCLE_X, -2, CYCLE_W, {
            { value = false, text = "Dungeons and raids" },
            { value = true, text = "Everywhere else" },
        }, function() return TO.editOutside and true or false end,
        function(v)
            TO.editOutside = v
            for _, cb in ipairs(c.toggles) do cb.refresh() end
        end)
        ctx.y = -30
    end
    TAB_BUILDERS[tab](self, ctx, self:PlayerClass())
    local h = -ctx.y + 10
    c:SetHeight(h)
    frame.scrollChild:SetHeight(h)
    if frame.scroll.SetVerticalScroll then frame.scroll:SetVerticalScroll(0) end
end

function TO:ShowOptionsTab(key)
    self.optionsTab = key
    local frame = self.config
    if not frame then return end
    for k, b in pairs(frame.tabs) do b:SetSelected(k == key) end
    self:BuildChecksList()
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
    f:SetSize(620, 580)
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
    SettingCheck(f, "Keep potions in combat", x + 20, y, "combatBar",
        "While the reminders are hidden in combat, your healing and mana potions, Healthstone and bandage stay on screen in one row, with live counts and cooldowns.")
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
    Slider(f, "Icons per row", x + 4, y, "iconsPerRow", 4, 16)
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
    PanelButton(f, "Reset position", 112, x, y, function()
        SlashCmdList.TOPPEDOFFFOREVER("reset")
    end)
    PanelButton(f, "Check spells", 104, x + 118, y, function() TO:Check() end)

    -- Right column: checks, in tabs
    Heading(f, "What to check (this character)", 262, -46)
    -- Navy panel behind the checks list
    local panel = CreateFrame("Frame", nil, f)
    panel:SetPoint("TOPLEFT", 252, -94)
    panel:SetPoint("BOTTOMRIGHT", -8, 8)
    TO:SkinFrame(panel, TO.COLORS.navy, TO.COLORS.goldDark, 0.9, 1)

    -- Tab buttons sitting on top of the panel
    f.tabs = {}
    local tabW, tabX = 86, 252
    for _, t in ipairs(TO.OPTION_TABS) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(tabW, 24)
        b:SetPoint("TOPLEFT", tabX, -71)
        TO:SkinFrame(b, TO.COLORS.navy, TO.COLORS.goldDark, 0.9, 1)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.text:SetPoint("CENTER", 0, 0)
        b.text:SetText(t.label)
        function b:SetSelected(on)
            local bg = on and TO.COLORS.crimson or TO.COLORS.navy
            self.skinBg:SetColorTexture(bg[1], bg[2], bg[3], on and 1 or 0.6)
            if on then self.text:SetTextColor(unpack(TO.COLORS.gold)) else self.text:SetTextColor(0.7, 0.7, 0.7) end
        end
        b:SetScript("OnClick", function() TO:ShowOptionsTab(t.key) end)
        f.tabs[t.key] = b
        tabX = tabX + tabW + 4
    end

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 260, -102)
    scroll:SetPoint("BOTTOMRIGHT", -30, 14)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(330, 10)
    scroll:SetScrollChild(child)
    f.scroll = scroll
    f.scrollChild = child

    f:SetScript("OnShow", function()
        RunRefreshers()
        TO:ShowOptionsTab(TO.optionsTab or "buffs")
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
