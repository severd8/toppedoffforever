-- ToppedOff Forever: options window (/topoff), in the shared look (Theme.lua).
-- Tabs down the left: what to check for this character (Buffs, Supplies,
-- Pet & gear, Profiles), then the display settings all your characters share
-- (Display, General).

local ADDON, ns = ...
local TO = ns.TO
local T = ns.Theme
local C, Text, FlatButton, Card = T.C, T.Text, T.FlatButton, T.Card

local refreshers = {}
local function AddRefresher(fn) table.insert(refreshers, fn) end
local function RunRefreshers() for _, fn in ipairs(refreshers) do fn() end end

---------------------------------------------------------------------------
-- Widget helpers
---------------------------------------------------------------------------
-- The check lists are drawn again every time they're shown, and the game never
-- frees a frame, so their widgets are reused: a parent with a `pool` hands back
-- the widgets of the last build before making new ones. Each helper puts a
-- reused widget back to how a new one starts.
local function Acquire(parent, kind, create)
    local pool = parent.pool
    if not pool then return create(), true end
    local p = pool[kind]
    if not p then p = { used = 0 } pool[kind] = p end
    p.used = p.used + 1
    local w = p[p.used]
    if w then
        w:Show()
        if w.label then w.label:Show() end
        return w, false
    end
    w = create()
    p[p.used] = w
    return w, true
end

local function ReleasePool(parent)
    for _, p in pairs(parent.pool) do
        for i = 1, p.used do
            p[i]:Hide()
            if p[i].label then p[i].label:Hide() end
        end
        p.used = 0
    end
end

-- A text line remembers how it was made, so a reused one can go back to it:
-- no fixed width, and the justify and wrap it started with. (A colour is either
-- never set on a kind of line, or set every time: see Label.)
local function NewText(parent, template)
    local fs = Text(parent, "", template)
    fs.made = { justify = fs:GetJustifyH(), wrap = fs:CanWordWrap() }
    return fs
end

local function ResetText(fs)
    fs:SetWidth(0)
    fs:SetJustifyH(fs.made.justify)
    fs:SetWordWrap(fs.made.wrap)
end

-- Hover scripts are only set on some widgets; a reused one gets its own back
local function RememberHover(w)
    w.madeEnter, w.madeLeave = w:GetScript("OnEnter"), w:GetScript("OnLeave")
    return w
end

local function ResetHover(w)
    w:SetScript("OnEnter", w.madeEnter)
    w:SetScript("OnLeave", w.madeLeave)
end

local function Label(parent, text, x, y, template, color)
    template = template or "GameFontHighlight"
    local fs, new = Acquire(parent, template, function() return NewText(parent, template) end)
    if not new then ResetText(fs) end
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

-- On/off switch with its label. get() reads the setting, set(on) saves it. Clicking
-- the label works like the switch. A greyed-out switch (SetDisabled) ignores clicks.
local function Toggle(parent, text, x, y, get, set, tip)
    local sw, new = Acquire(parent, "switch", function()
        local sw = T.SwitchWidget(parent)
        sw.label = NewText(parent, "GameFontHighlight")
        sw.label:SetPoint("TOPLEFT", sw, "TOPRIGHT", 8, 1)
        T.Disabler(sw, { sw, sw.label })
        return RememberHover(sw)
    end)
    if not new then
        ResetText(sw.label)
        ResetHover(sw)
    end
    sw:SetDisabled(false)
    sw:SetPoint("TOPLEFT", x, y)
    sw.label:SetText(text)
    T.ClickableLabel(sw, sw.label)
    sw:SetScript("OnClick", function(self)
        if self.disabled then return end
        self:SetOn(not self:IsOn())
        set(self:IsOn())
        if parent.afterToggle then parent.afterToggle() end   -- switches that depend on this one
    end)
    if tip then T.Tooltip(sw, text, tip) end
    sw:SetOn(get())
    return sw
end

-- A switch bound to a display setting: account-wide, except the lock (per character).
-- enabledWhen(): false greys it out, for a setting that does nothing until another one is changed.
local function Setting(parent, text, x, y, key, tip, enabledWhen)
    local function store() return key == "locked" and TO.char or TO.db end
    local sw = Toggle(parent, text, x, y, function() return store()[key] end, function(v)
        if key == "locked" then
            TO:SetLocked(v)
        else
            TO.db[key] = v
            TO:ApplySettings()
        end
        RunRefreshers()
    end, tip)
    AddRefresher(function()
        sw:SetOn(store()[key])
        if enabledWhen then sw:SetDisabled(not enabledWhen()) end
    end)
    return sw
end

local function Slider(parent, text, x, y, key, min, max, suffix, tip)
    local s = T.Slider(parent, text, x, y, 244,
        function() return TO.db[key] end,
        function(v) TO.db[key] = v TO:ApplySettings() end, min, max, suffix)
    if tip then T.Tooltip(s, text, tip) end
    AddRefresher(s.Refresh)
    return s
end

-- Text box. Number boxes and text boxes are reused separately. onCommit(text, box)
-- runs on Enter or when the box loses focus; onEnter (optional) replaces it for Enter.
local function EditBox(parent, width, x, y, text, numeric, onCommit, onEnter)
    local e, new = Acquire(parent, numeric and "number" or "edit", function()
        local e = T.EditBox(parent, width)
        if numeric then
            e:SetNumeric(true)
            e:SetMaxLetters(4)
            e:SetJustifyH("CENTER")
        end
        T.Disabler(e, { e })
        local setDisabled = e.SetDisabled
        function e:SetDisabled(off)
            setDisabled(self, off)
            self:EnableMouse(not off)
            if off then self:ClearFocus() end
        end
        return RememberHover(e)
    end)
    if not new then ResetHover(e) end
    e:SetDisabled(false)
    e:SetWidth(width)
    e:SetPoint("TOPLEFT", x, y)
    e:SetText(text or "")
    local function commit(self) if onCommit and not self.disabled then onCommit(self:GetText(), self) end end
    e:SetScript("OnEnterPressed", function(self)
        if onEnter then onEnter(self) else commit(self) end
        self:ClearFocus()
    end)
    e:SetScript("OnEditFocusLost", commit)
    return e
end

local function Button(parent, text, width, x, y, onClick, height)
    local b, new = Acquire(parent, "button", function()
        local b = FlatButton(parent, text, width)
        T.Disabler(b, { b })
        return RememberHover(b)
    end)
    if not new then ResetHover(b) end
    b:SetDisabled(false)
    b:SetSize(width, height or 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", function(self) if not self.disabled then onClick(self) end end)
    return b
end

-- A box showing the current choice; click for a list of them.
-- labels: table key -> text, or a function(key) returning it.
local function Dropdown(parent, x, y, width, keys, labels, getter, setter, tip)
    local b, new = Acquire(parent, "dropdown", function()
        return RememberHover(T.Dropdown(parent, width, keys, labels, getter, setter))
    end)
    if not new then ResetHover(b) end
    b:SetDisabled(false)
    b.keys, b.labels, b.getter, b.setter = keys, labels, getter, setter
    b.menuTitle, b.menuLabels = nil, nil
    b:SetWidth(width)
    b:SetPoint("TOPLEFT", x, y)
    if tip then T.Tooltip(b, nil, tip) end
    b.Refresh()
    return b
end

---------------------------------------------------------------------------
-- Check lists (Buffs, Supplies, Pet & gear, Profiles). Each fills its own
-- scrolling page with cards, and is drawn again every time it's shown, since
-- it depends on your class, spells and bags.
---------------------------------------------------------------------------
local PAGE_W = T.WINDOW.PAGE_W
local LIST_W = PAGE_W - 16       -- cards in a list leave room for the scroll bar
local ROW = 26
local PAD = 12                   -- inside a card
local SUB = PAD + 24             -- a setting that belongs to the one above it
local X_X = LIST_W - PAD - 20    -- remove buttons line up at the far right
local MIN_W = 44
local MIN_X = X_X - 6 - MIN_W    -- "Min" boxes line up in one column
local PICK_X = 250               -- spell and blessing choices
local PICK_W = LIST_W - PAD - PICK_X
local LABEL_W = MIN_X - (PAD + 38) - 8   -- a switch label that stops before the Min column
local COMBAT_X = MIN_X - 14 - 30         -- "In combat" switches on your own items, left of Min

TO.OPTION_TABS = {
    { key = "buffs",    label = "Buffs" },
    { key = "supplies", label = "Supplies" },
    { key = "more",     label = "Pet & gear" },
    { key = "profiles", label = "Profiles" },
}

-- Only hunters and warlocks have pet checks. For everyone else the third tab is
-- just gear and bags, and says so.
local MORE_TAB = {
    pet = { "Pet & gear", "Interface\\Icons\\Ability_Hunter_BeastCall" },
    gear = { "Gear & bags", "Interface\\Icons\\Trade_BlackSmithing" },
}
local function MoreTab() return TO.PET_CLASSES[TO:PlayerClass()] and MORE_TAB.pet or MORE_TAB.gear end
function TO:NameMoreTab()
    local win = self.config
    if not (win and win.tabButtons and win.tabButtons.more) then return end
    local name, icon = MoreTab()[1], MoreTab()[2]
    win.tabButtons.more:SetText(name)
    win.tabButtons.more.icon:SetTexture(icon)
    win.pages.more.title:SetText(name)
end

-- Which set of on/off checks the options are editing (see the Profiles tab)
function TO:EditingOutside()
    return (self.char.splitProfiles and self.editOutside) and true or false
end

-- Row helpers shared by the lists. `ctx` holds the list being filled and the y cursor.
--
-- Greyed-out controls: ctx.track(widget, shared, enabledWhen) records a control that
-- is the same for both sets of checks (shared: greyed out while you edit the checks
-- for outside dungeons, which only the on/off checks have) and/or does nothing until
-- another setting is on (enabledWhen). c.applyStates() greys them; it runs after the
-- list is drawn and after every switch click.
local function Builder(c)
    local ctx = { c = c, y = 0 }
    local card
    local states = {}
    function ctx.track(w, shared, enabledWhen)
        states[#states + 1] = { w = w, shared = shared, enabledWhen = enabledWhen }
        return w
    end
    function c.applyStates()
        local outside = TO:EditingOutside()
        for _, st in ipairs(states) do
            local off = (st.shared and outside) or (st.enabledWhen and not st.enabledWhen()) or false
            st.w:SetDisabled(off)
        end
    end
    c.afterToggle = c.applyStates

    local function closeCard()
        if not card then return end
        card.edge:SetHeight(card.top - ctx.y + 6)
        ctx.y = ctx.y - 16
        card = nil
    end

    -- Starts a card: a panel with a small orange title, and "Min" over the Min column
    function ctx.card(title, minLabel)
        closeCard()
        card = Acquire(c, "card", function()
            local k = {}
            k.edge = c:CreateTexture(nil, "BACKGROUND", nil, -8)
            k.edge:SetColorTexture(unpack(C.line))
            k.fill = c:CreateTexture(nil, "BACKGROUND", nil, -7)
            k.fill:SetColorTexture(unpack(C.card))
            k.fill:SetPoint("TOPLEFT", k.edge, "TOPLEFT", 1, -1)
            k.fill:SetPoint("BOTTOMRIGHT", k.edge, "BOTTOMRIGHT", -1, 1)
            k.title = Text(c, "", "GameFontNormalSmall", C.orange)
            function k:Show() self.edge:Show() self.fill:Show() self.title:Show() end
            function k:Hide() self.edge:Hide() self.fill:Hide() self.title:Hide() end
            return k
        end)
        card.top = ctx.y
        card.edge:SetPoint("TOPLEFT", 0, ctx.y)
        card.edge:SetWidth(LIST_W)
        card.title:SetPoint("TOPLEFT", PAD, ctx.y - 10)
        card.title:SetText(title:upper())
        if minLabel then
            local m = Label(c, minLabel, MIN_X, ctx.y - 10, "GameFontDisableSmall")
            m:SetWidth(MIN_W)
            m:SetJustifyH("CENTER")
        end
        ctx.y = ctx.y - 28
    end

    -- A small grey line over settings that belong to every row above it
    function ctx.subhead(text)
        Label(c, text, PAD, ctx.y - 4, "GameFontDisableSmall")
        ctx.y = ctx.y - 20
    end

    function ctx.note(text)
        local n = Label(c, text, PAD + 38, ctx.y - 2, "GameFontDisableSmall")
        n:SetWidth(LIST_W - PAD - (PAD + 38))
        n:SetWordWrap(true)
        ctx.y = ctx.y - math.max(16, math.ceil((n:GetStringHeight() or 12)) + 6)
        return n
    end

    -- A plain line of text in a row (beside a choice box, or on its own)
    function ctx.text(text, x, color)
        return Label(c, text, x or (PAD + 38), ctx.y - 6, "GameFontHighlight", color or C.muted)
    end

    -- Switch bound to a check id (on/off per character, in the set being edited)
    function ctx.toggle(id, label, default, x, tip)
        local function get() return TO:IsEnabled(id, default, TO:EditingOutside()) end
        return Toggle(c, label, x or PAD, ctx.y - 4, get,
            function(v) TO:SetEnabled(id, v, TO:EditingOutside(), default) end, tip)
    end

    -- Switch bound to a per-character setting (the same for both sets of checks).
    -- enabledWhen(): false greys it out (it does nothing until that's on).
    function ctx.charCheck(label, key, x, tip, enabledWhen)
        return ctx.track(Toggle(c, label, x or PAD, ctx.y - 4, function() return TO.char[key] and true or false end,
            function(v) TO.char[key] = v TO:RequestUpdate() end, tip), true, enabledWhen)
    end

    -- Switch that isn't a saved check (elixirs to track)
    function ctx.switch(label, get, set, shared)
        local sw = Toggle(c, label, PAD, ctx.y - 4, get, set)
        if shared ~= false then ctx.track(sw, true) end
        return sw
    end

    -- Keep a label clear of the Min column (or of a choice box at `untilX`)
    function ctx.fit(sw, untilX)
        sw.label:SetWidth(untilX and (untilX - (PAD + 38) - 8) or LABEL_W)
        sw.label:SetWordWrap(false)
        return sw
    end

    -- Min box in the Min column. get() reads the saved number, onCommit(n) saves a new
    -- one. Anything that isn't a whole number from 0 up puts the saved one back.
    function ctx.minBox(get, onCommit, tip)
        local box = EditBox(c, MIN_W, MIN_X, ctx.y - 1, tostring(get()), true, function(text, box)
            local n = tonumber(text)
            if n and n >= 0 then
                n = math.floor(n)
                if n ~= get() then onCommit(n) TO:RequestUpdate() end
            end
            box:SetText(tostring(get()))
        end)
        T.Tooltip(box, "Min", tip or "You're reminded when you have fewer than this. 0 turns the reminder off.")
        return ctx.track(box, true)
    end
    function ctx.reagentMin(id, default, tip)
        return ctx.minBox(function() return TO:ReagentMin(id, default) end,
            function(n) TO.char.mins[id] = n end, tip)
    end

    -- A choice of spells: a list to pick from. auto (optional): label for "Automatic",
    -- the first choice, saved as no pick (getter returns false for it).
    function ctx.spellPick(known, getter, setter, auto)
        local keys = known
        if auto then
            keys = { false }
            for _, k in ipairs(known) do keys[#keys + 1] = k end
        end
        local b = Dropdown(c, PICK_X, ctx.y - 1, PICK_W, keys,
            function(k) if k then return k end return auto and auto() or "" end, getter, setter)
        if auto then
            b.menuLabels = setmetatable({}, { __index = function(_, k) return k or "Automatic (for your role)" end })
        end
        T.Tooltip(b, "Spell to cast", "Click to choose which spell the reminder casts.")
        return ctx.track(b, true)
    end

    function ctx.row() ctx.y = ctx.y - ROW end

    -- Ends the list; returns its height
    function ctx.finish()
        closeCard()
        return -ctx.y - 10
    end
    return ctx
end

local function NotLearned(sw, text)
    sw.label:SetText(text .. " |cff808080(not learned)|r")
end

---------------------------------------------------------------------------
-- Buffs tab: your buffs, party buffs, weapon, Well Fed, elixirs and flasks
---------------------------------------------------------------------------
local function BuildBuffsTab(self, ctx, class)
    local c = ctx.c
    local function on(id, default) return TO:IsEnabled(id, default, TO:EditingOutside()) end
    local buffs = self.CLASS_BUFFS[class] or {}
    if #buffs > 0 then
        ctx.card("Your buffs")
        for _, buff in ipairs(buffs) do
            local known = self:KnownOptions(buff.cast)
            -- Racial buffs only for races that have them; a passive spell needs no check at all
            if not ((buff.racial or self:AllPassive(buff.cast)) and #known == 0) then
                local sw = ctx.toggle("buff:" .. buff.id, buff.label, not buff.off)
                if #known == 0 then
                    NotLearned(sw, buff.label)
                elseif #known > 1 then
                    ctx.fit(sw, PICK_X)
                    if buff.byRole then
                        -- Automatic: the spell for your role (Paladin auras)
                        ctx.spellPick(known,
                            function()
                                local pick = TO.char.prefs[buff.id]
                                for _, n in ipairs(known) do if n == pick then return n end end
                                return false
                            end,
                            function(v) TO.char.prefs[buff.id] = v or nil TO:RequestUpdate() end,
                            function() return "Automatic: " .. (TO:BuffPreference(buff, true) or "") end)
                    else
                        ctx.spellPick(known, function() return TO:BuffPreference(buff) end,
                            function(v) TO.char.prefs[buff.id] = v TO:RequestUpdate() end)
                    end
                end
                ctx.row()
            end
        end

        local partyBuffs = {}
        for _, buff in ipairs(buffs) do if buff.party then partyBuffs[#partyBuffs + 1] = buff end end
        if #partyBuffs > 0 then
            ctx.card("Party buffs")
            local anyGroup = false
            for _, buff in ipairs(partyBuffs) do
                local sw = ctx.toggle("party:" .. buff.id, buff.label .. " on your party", not buff.off)
                if #self:KnownOptions(buff.cast) == 0 then NotLearned(sw, buff.label .. " on your party") end
                if buff.group then anyGroup = true end
                ctx.row()
            end
            local function anyOn()
                for _, buff in ipairs(partyBuffs) do
                    if on("party:" .. buff.id, not buff.off) then return true end
                end
                return false
            end
            ctx.subhead("For every party buff")
            ctx.charCheck("Also when it's running out on someone", "partyExpiring", SUB,
                "Not only when someone is missing it: also when theirs has less than your warning time left "
                .. "(Display tab).", anyOn)
            ctx.row()
            if anyGroup then
                ctx.charCheck("Cast the group version when " .. self.GROUP_MIN .. " or more in your party need it",
                    "groupBuffs", SUB, "Prayer of Fortitude, Arcane Brilliance, Gift of the Wild and the like, "
                    .. "when you've learned it and carry its reagent. You count too.", anyOn)
                ctx.row()
            end
            ctx.charCheck("In raids, check the whole raid", "wholeRaid", SUB,
                "In a raid, look at everyone, not just your own group. Also for blessings and Soulstones.", anyOn)
            ctx.row()
            ctx.note("Shows how many party members need it. Click to buff the next one in range.")
        end
    end

    -- Paladin: which blessing each class in your party gets
    if class == "PALADIN" then
        ctx.card("Party blessings")
        ctx.toggle("party:blessing", "Bless your party", true)
        ctx.row()
        local keys, labels = {}, { none = "None" }
        for _, b in ipairs(self.BLESSING_NAMES) do
            if self:Knows(self.BLESSING_SPELLS[b]) then
                keys[#keys + 1] = b
                labels[b] = self.BLESSING_SPELLS[b]
            end
        end
        keys[#keys + 1] = "none"
        local function blessingOn() return on("party:blessing", true) end
        for _, cls in ipairs(self.BLESSING_CLASSES) do
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
            ctx.text(self.CLASS_PLURALS[cls], nil, color and { color.r, color.g, color.b } or { 1, 1, 1 })
            ctx.track(Dropdown(c, PICK_X, ctx.y - 1, PICK_W, keys, labels,
                function()
                    local spell = TO:BlessingFor(cls)
                    return spell and TO:BlessingShort(spell) or "none"
                end,
                function(v) TO.char.blessings[cls] = v TO:RequestUpdate() end,
                "Blessing to give " .. self.CLASS_PLURALS[cls] .. " in your party"), true, blessingOn)
            ctx.row()
        end
        ctx.subhead("For every blessing")
        ctx.charCheck("Also when it's running out on someone", "partyExpiring", SUB,
            "Not only when someone is missing theirs: also when it has less than your warning time left "
            .. "(Display tab).", blessingOn)
        ctx.row()
        ctx.charCheck("In raids, check the whole raid", "wholeRaid", SUB,
            "In a raid, look at everyone, not just your own group.", blessingOn)
        ctx.row()
        ctx.note("Shows how many party members are missing their blessing. Click to bless the next one in range. "
            .. "A Greater Blessing, or the same blessing from another Paladin, counts.")
    end

    -- Weapon enhancement
    ctx.card("Weapon enhancement", class == "ROGUE" and "Min" or nil)
    local w = self:WeaponConfig()
    if w.kind == "spell" then
        local known = self:KnownOptions(w.cast)
        local sw = ctx.toggle("weapon:mh", "Weapon buff", true)
        if #known == 0 then
            NotLearned(sw, "Weapon buff")
        elseif #known > 1 then
            ctx.fit(sw, PICK_X)
            ctx.spellPick(known, function() return TO:WeaponConfig().spell end,
                function(v) TO.char.weapon.spell = v TO:RequestUpdate() end)
        end
        ctx.row()
    else
        for _, key in ipairs({ "mh", "oh" }) do
            ctx.fit(ctx.toggle("weapon:" .. key, key == "mh" and "Main hand" or "Off hand", true), PICK_X)
            local box = ctx.track(EditBox(c, PICK_W, PICK_X, ctx.y - 1, w[key], false, function(text)
                TO.char.weapon[key] = strtrim and strtrim(text) or text
                TO:RequestUpdate()
            end), true)
            T.Tooltip(box, key == "mh" and "Main hand" or "Off hand",
                "The poison, oil or stone to use on this weapon. Part of the name is enough. Blank: whatever "
                .. "sharpening stone, weightstone or oil (or poison) you carry for this weapon.")
            ctx.row()
        end
        if class == "ROGUE" then
            ctx.fit(ctx.toggle("charges", "Warn when poison charges run low", true))
            ctx.reagentMin("charges", self.CHARGES_DEFAULT_MIN,
                "You're warned when a poison has fewer charges than this. 0 turns the warning off.")
            ctx.row()
        end
        ctx.note("Item to use on each weapon, like Instant Poison or Wizard Oil. Blank: any sharpening stone "
            .. "(sharp weapons), weightstone (blunt ones) or oil in your bags. Your best rank is used.")
    end

    -- Well Fed
    ctx.card("Food buff")
    ctx.toggle("wellfed", "Well Fed", true, nil, "Reminds you when the buff from stat food is missing or running out.")
    ctx.row()
    ctx.charCheck("Only in dungeons and raids", "wellFedInstanceOnly", SUB, nil,
        function() return on("wellfed", true) end)
    ctx.row()
    ctx.note("Click the icon to eat your stat food (set on the Supplies tab).")

    -- Well-Rested, for those carrying the sleeping bag
    if self.bag and self.bag[self.RESTED.item] then
        ctx.card("Experience bonus")
        ctx.toggle("rested", "Well-Rested", true)
        ctx.row()
        ctx.note("From your Cozy Sleeping Bag. Shown when it's missing, running out or below "
            .. self.RESTED.stacks .. " stacks. Click the icon to unfurl the bag.")
    end

    -- Elixirs and flasks
    ctx.card("Elixirs and flasks")
    local shown = {}
    for _, el in ipairs(self.char.elixirs) do
        shown[el.name:lower()] = true
        ctx.fit(ctx.switch(el.name, function() return true end, function(v) TO:TrackElixir(el.name, v) end))
        ctx.row()
    end
    for _, e in ipairs(self:BagElixirs()) do
        if not shown[e.name:lower()] then
            ctx.fit(ctx.switch(e.name, function() return false end, function(v) TO:TrackElixir(e.name, v) end))
            ctx.row()
        end
    end
    if #self.char.elixirs == 0 and #self:BagElixirs() == 0 then
        ctx.text("|cff808080No elixirs or flasks in your bags.|r")
        ctx.row()
    end
    ctx.subhead("For every elixir and flask")
    ctx.charCheck("Only in dungeons and raids", "elixirInstanceOnly", SUB, nil,
        function() return #TO.char.elixirs > 0 end)
    ctx.row()
    ctx.note("Elixirs and flasks in your bags are listed here. Turn one on to be reminded when its buff is "
        .. "missing or running out. Click the icon to drink it.")
end

---------------------------------------------------------------------------
-- Supplies tab: auto-tracked food, water, potions; your own items; reagents
---------------------------------------------------------------------------
local function BuildSuppliesTab(self, ctx, class)
    local c = ctx.c

    ctx.card("Food, water, bandages and potions", "Min")
    self:UpdateAutoItems()
    local hasMana = self.MANA_CLASSES[class]
    local autoRows = {}
    -- A row is a kind of item, not one item: it names the best of the kind in your bags
    -- right now, or the last one you carried when you have none
    local function slotText(slot)
        local a = self.char.auto[slot.key]
        local kind = slot.label:lower()
        if not a then return "|cff808080No " .. kind .. " in your bags yet|r" end
        local e = self.bag and self.bag[a.name:lower()]
        if e and e.count > 0 then return "Best " .. kind .. " in your bags: " .. a.name end
        return "|cff808080No " .. kind .. " in your bags (last: " .. a.name .. ")|r"
    end
    for _, slot in ipairs(self.AUTO_SLOTS) do
        if not slot.mana or hasMana then
            local sw = ctx.fit(ctx.toggle("auto:" .. slot.key, slotText(slot), true))
            autoRows[slot.key] = { sw = sw, slot = slot }
            ctx.minBox(function()
                local a = TO.char.auto[slot.key]
                return a and a.min or TO.char.autoMins[slot.key] or slot.min
            end, function(n)
                TO.char.autoMins[slot.key] = n
                local now = TO.char.auto[slot.key]   -- (the item may have changed since the row was drawn)
                if now then now.min = n end
            end)
            ctx.row()
        end
    end
    -- Healthstone
    if class == "WARLOCK" then
        local sw = ctx.fit(ctx.toggle("healthstone", "Healthstone", true, nil,
            "Reminds you when you have none. Click the reminder to make one."))
        if not self:FirstKnown(self.HEALTHSTONE_SPELLS) then NotLearned(sw, "Healthstone") end
    else
        ctx.fit(ctx.toggle("healthstone", "Healthstone in dungeons, if a Warlock is along", true, nil,
            "In a dungeon or raid with a Warlock in your group, reminds you to ask for a Healthstone."))
    end
    ctx.row()
    ctx.text("Stat food for")
    local focusKeys = { false }
    for _, k in ipairs(self.STAT_KEYS) do focusKeys[#focusKeys + 1] = k end
    local function focusLabel(k)
        if not k then
            local prio, role = TO:AutoStatPriority()
            local who = role and TO.ROLE_LABELS[role] or "Automatic"
            return who .. ": " .. TO.STAT_LABELS[prio[1]]
        end
        return TO.STAT_LABELS[k] .. " (your pick)"
    end
    local focus = ctx.track(Dropdown(c, PICK_X, ctx.y - 1, PICK_W, focusKeys, focusLabel,
        function() return TO.char.statFocus or false end,
        function(k)
            TO:SetStatFocus(k or nil)
            TO:UpdateAutoItems()
            local row = autoRows.statfood
            if row then row.sw.label:SetText(slotText(row.slot)) end
        end), true)
    focus.menuTitle = "Stat food"
    focus.menuLabels = setmetatable({}, { __index = function(_, k)
        return k and TO.STAT_LABELS[k] or ("Automatic (" .. focusLabel(nil) .. ")")
    end })
    T.Tooltip(focus, "Stat food", "Automatic picks food for your role, and falls back to any stat food. "
        .. "Pick a stat yourself (like Strength for a Protection Paladin) to track only food with that stat.")
    ctx.row()
    ctx.note("Each row follows your bags: it's the best of its kind you're carrying (the one that restores "
        .. "the most), so it changes when you swap one for another. Stat food follows your talents (or group "
        .. "role). Turn one off to stop tracking it.")

    -- Mage conjures
    if class == "MAGE" then
        ctx.card("Conjured food, water and mana gem", "Min")
        for _, cj in ipairs(self.CONJURES) do
            local id = "conjure:" .. cj.key
            local sw = ctx.fit(ctx.toggle(id, cj.label, true))
            if not self:Knows(cj.spell) then NotLearned(sw, cj.label) end
            ctx.reagentMin(id, cj.min)
            ctx.row()
        end
        local gem
        for _, g in ipairs(self.MANA_GEMS) do if self:Knows(g.spell) then gem = g break end end
        local sw = ctx.fit(ctx.toggle("conjure:gem", gem and ("Mana gem: " .. gem.item) or "Mana gem", true, nil,
            "Reminds you when you have no mana gem."))
        if not gem then NotLearned(sw, "Mana gem") end
        ctx.row()
        ctx.note("Click to conjure your best rank.")
    end

    ctx.card("Your own items", "Min")
    if #self.char.custom > 0 then
        local h = Label(c, "Combat", COMBAT_X - 10, ctx.y + 18, "GameFontDisableSmall")
        h:SetWidth(50)
        h:SetJustifyH("CENTER")
    end
    for _, item in ipairs(self.char.custom) do
        local name = item.name
        ctx.fit(ctx.toggle("custom:" .. name:lower(), name, true), COMBAT_X)
        local inCombat = ctx.track(Toggle(c, "", COMBAT_X, ctx.y - 4, function() return item.combat and true or false end,
            function(v) item.combat = v or nil TO:RequestUpdate() end), true)
        T.Tooltip(inCombat, "On the combat bar", "Keep it on the combat bar, with your potions and Healthstone, "
            .. "while the reminders hide in combat.")
        ctx.minBox(function() return item.min end, function(n) item.min = n end)
        local x = ctx.track(Button(c, "X", 20, X_X, ctx.y - 2, function()
            TO:RemoveCustom(name)
            TO:ShowOptionsTab("supplies")
        end, 20), true)
        T.Tooltip(x, "Remove", "Stop checking " .. name .. ".")
        ctx.row()
    end
    -- Adding one: name, Min, then Enter or +
    ctx.text("Item", PAD)
    local nameBox, minEdit
    local function add()
        if TO:AddCustom(nameBox:GetText(), minEdit:GetText()) then
            TO:ShowOptionsTab("supplies")
        else
            TO.Print("type an item's name and a Min of 1 or more first.")
        end
    end
    nameBox = ctx.track(EditBox(c, MIN_X - 8 - (PAD + 38), PAD + 38, ctx.y - 1, "", false, nil, add), true)
    T.Tooltip(nameBox, "Item to add", "Its exact name, like Major Healing Potion. Then press Enter or +.")
    minEdit = ctx.track(EditBox(c, MIN_W, MIN_X, ctx.y - 1, "20", true, nil, add), true)
    T.Tooltip(minEdit, "Min", "You're reminded when you have fewer than this.")
    local plus = ctx.track(Button(c, "+", 20, X_X, ctx.y - 2, add, 20), true)
    T.Tooltip(plus, "Add", "Add this item to your list.")
    ctx.row()
    ctx.note("Anything else you want to keep stocked. Click an item's icon to use it.")

    ctx.card("Quick-use bar")
    ctx.charCheck("Always show food, water, potions and your own items", "customAlways", PAD,
        "Show them even when you have enough, dimmed, so you can click to use them. "
        .. "Low ones are bright with a red count.")
    ctx.row()
    ctx.note("Off: they only show when you're low.")

    local reagents = self.CLASS_REAGENTS[class] or {}
    local showAmmo = self.AMMO_CLASSES[class] or class == "WARRIOR" or class == "ROGUE"
    if #reagents > 0 or showAmmo then
        ctx.card("Reagents and ammo", "Min")
        for _, rg in ipairs(reagents) do
            local id = "reagent:" .. rg.id
            local sw = ctx.fit(ctx.toggle(id, rg.label, true))
            if not self:FirstKnown(rg.requires) then NotLearned(sw, rg.label) end
            ctx.reagentMin(id, rg.min)
            ctx.row()
        end
        if showAmmo then
            ctx.fit(ctx.toggle("ammo", "Ammo", self.AMMO_CLASSES[class] == true, nil,
                "Counts the ammo you have equipped."))
            ctx.reagentMin("ammo", self.AMMO_DEFAULT_MIN)
            ctx.row()
        end
    end

    ctx.card("At vendors and the bank")
    ctx.charCheck("Show a restock list at vendors", "restockAtVendor")
    ctx.row()
    ctx.charCheck("Show the repair button at vendors", "repairAtVendor")
    ctx.row()
    ctx.charCheck("Show what to take from the bank", "bankRestock")
    ctx.row()
    ctx.note("Beside the vendor or bank window: everything above that's below its Min and that this vendor "
        .. "sells, or that's in your bank. Nothing is bought or moved until you click.")
end

---------------------------------------------------------------------------
-- Pet & gear tab: pet, Soulstone, durability, bag space
---------------------------------------------------------------------------
local function BuildMoreTab(self, ctx, class)
    local c = ctx.c
    if self.PET_CLASSES[class] then
        ctx.card("Pet", class == "HUNTER" and "Min" or nil)
        if class == "HUNTER" then
            local sw = ctx.toggle("pet:summon", "Pet is out and alive", true)
            if not self:Knows(self.PET_SPELLS.call) then NotLearned(sw, "Pet is out and alive") end
            ctx.row()
            ctx.toggle("pet:happy", "Pet is happy", true, nil,
                "Reminds you when your pet is content or unhappy. Click to feed it.")
            ctx.row()
            ctx.fit(ctx.toggle("pet:food", "Pet food", true), PICK_X)
            local box = ctx.track(EditBox(c, MIN_X - 8 - PICK_X, PICK_X, ctx.y - 1, self.char.petFood or "", false,
                function(text)
                    TO.char.petFood = strtrim and strtrim(text) or text
                    TO:RequestUpdate()
                end), true)
            T.Tooltip(box, "Pet food", "Your pet's food, like Roasted Quail. Part of the name is enough.")
            ctx.reagentMin("pet:food", self.PET_FOOD_DEFAULT_MIN)
            ctx.row()
            ctx.note("Type your pet's food, like Roasted Quail. Then one click feeds your pet, "
                .. "and you're reminded when you're low.")
        else
            local known = self:KnownOptions(self.WARLOCK_PETS)
            local sw = ctx.toggle("pet:summon", "Demon is out", true)
            if #known == 0 then
                NotLearned(sw, "Demon is out")
            elseif #known > 1 then
                ctx.fit(sw, PICK_X)
                ctx.spellPick(known, function() return TO:PetSummonSpell() end,
                    function(v) TO.char.prefs.pet = v TO:RequestUpdate() end)
            end
            ctx.row()
        end
        ctx.note("Not shown while you're mounted. The reminder to call or summon your pet also waits "
            .. "while you're resting in a town or inn.")
    end

    if class == "WARLOCK" then
        ctx.card("Soulstone")
        local function stoneOn() return TO:IsEnabled("soulstone", true, TO:EditingOutside()) end
        local sw = ctx.toggle("soulstone", "When nobody in your group has one", true, nil,
            "In a group, reminds you when nobody has a Soulstone on them.")
        if not self:FirstKnown(self.SOULSTONE_SPELLS) then NotLearned(sw, "When nobody in your group has one") end
        ctx.row()
        ctx.charCheck("Only in dungeons and raids", "soulstoneInstanceOnly", SUB, nil, stoneOn)
        ctx.row()
        ctx.charCheck("In raids, check the whole raid", "wholeRaid", SUB,
            "In a raid, look at everyone, not just your own group.", stoneOn)
        ctx.row()
        ctx.note("Click to put your Soulstone on the healer (or your friendly target), or to make one.")
    end

    ctx.card("Gear & bags", "Min")
    ctx.fit(ctx.toggle("durability", "Low durability", true))
    ctx.row()
    ctx.note(("Warns when your most worn item is below %d%%. Change it on the Display tab (for all your characters).")
        :format(TO.db.durabilityPct))
    ctx.fit(ctx.toggle("bags", "Low bag space", true))
    ctx.reagentMin("bags", self.BAGS_DEFAULT_MIN,
        "You're warned when you have fewer free bag slots than this. 0 turns the warning off.")
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
    ctx.card("Dungeons and the open world")
    ctx.switch("Separate checks outside dungeons and raids",
        function() return TO.char.splitProfiles and true or false end,
        function(v)
            TO.char.splitProfiles = v
            TO.editOutside = false
            TO:RequestUpdate()
        end)
    ctx.row()
    ctx.note("Turn this on to have a lighter set of checks while questing. The Buffs, Supplies and "
        .. MoreTab()[1] .. " tabs then have an \"Editing\" choice at the top: turn checks on and off for dungeons "
        .. "and raids, or for everywhere else. Anything you don't change outside follows the dungeon setting. "
        .. "Only the on/off checks are separate; Min counts and other choices are shared.")

    ctx.card("Copy another character")
    local others = self:OtherCharacters()
    if #others == 0 then
        ctx.text("|cff808080No other characters yet. Log in with them once.|r")
        ctx.row()
    else
        local keys, labels = {}, {}
        for _, o in ipairs(others) do
            local cls = o.class and o.class:sub(1, 1) .. o.class:sub(2):lower() or "?"
            keys[#keys + 1] = o.key
            labels[o.key] = o.key .. " (" .. cls .. ")"
        end
        self.copySource = self.copySource or others[1].key
        local ok = false
        for _, o in ipairs(others) do if o.key == self.copySource then ok = true end end
        if not ok then self.copySource = others[1].key end
        Dropdown(c, PAD, ctx.y - 1, LIST_W - PAD * 2 - 100, keys, labels, function() return TO.copySource end,
            function(v) TO.copySource = v end)
        Button(c, "Copy", 90, LIST_W - PAD - 90, ctx.y - 1, function()
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
        .. "The Display and General tabs are already shared by all your characters.")
end

local LIST_BUILDERS = { buffs = BuildBuffsTab, supplies = BuildSuppliesTab, more = BuildMoreTab,
    profiles = BuildProfilesTab }

---------------------------------------------------------------------------
-- Display and General tabs: settings every character shares. Built once.
---------------------------------------------------------------------------
local function BuildDisplayTab(p)
    local rem = Card(p, "Reminders", 0, 0, PAGE_W, 150)
    Setting(rem, "Show reminders", 12, -30, "shown", "Also with /topoff show and /topoff hide, or a right-click "
        .. "on the minimap button.")
    Setting(rem, "Lock position", 12, -56, "locked", "Unlock to drag the reminders by the ToppedOff header above them.")
    Setting(rem, "Show header and frame", 12, -82, "showHeader",
        "The ToppedOff header and frame around the icons once they're locked. While unlocked they always show, "
        .. "so you can drag them: lock the position to choose.", function() return TO.char.locked end)
    Setting(rem, "Show only in instances", 284, -30, "onlyInInstance",
        "Dungeons, raids and battlegrounds. Elsewhere the reminders and the combat bar stay hidden.")
    Setting(rem, "Hide in combat", 284, -56, "hideInCombat",
        "Reminders can only change out of combat, so hiding them in combat keeps things tidy.")
    Setting(rem, "Keep potions in combat", 308, -82, "combatBar",
        "While the reminders are hidden in combat, your potions, mana gem, Healthstone, bandage and the items you "
        .. "mark Combat (Supplies tab) stay on screen in one row, with live counts and cooldowns. "
        .. "Needs Hide in combat on.", function() return TO.db.hideInCombat end)
    local reset = FlatButton(rem, "Reset position", 130)
    reset:SetPoint("TOPLEFT", 12, -114)
    reset:SetScript("OnClick", function() SlashCmdList.TOPPEDOFFFOREVER("reset") end)
    T.Note(rem, "Position changes wait until combat ends.", 154, -119)

    local size = Card(p, "Size", 0, -160, PAGE_W, 80)
    Slider(size, "Icon size", 12, -30, "iconSize", 20, 64, nil, "How big the reminder icons are.")
    Slider(size, "Icons per row", 284, -30, "iconsPerRow", 4, 16, nil,
        "Buffs, and things to top off, each wrap onto a new row after this many.")
    local warn = Card(p, "Warnings", 0, -250, PAGE_W, 80)
    Slider(warn, "Warn before buffs run out", 12, -30, "warnMinutes", 1, 10, " min",
        "Buffs, weapon enhancements, elixirs, Well Fed and party buffs get an orange border this long before "
        .. "they run out, and a red one near the end.")
    Slider(warn, "Durability warning below", 284, -30, "durabilityPct", 5, 75, "%",
        "You're warned when your most worn item drops below this.")
end

local function BuildGeneralTab(p)
    local chat = Card(p, "Chat reminders", 0, 0, PAGE_W, 110)
    Setting(chat, "On ready check", 12, -30, "readyCheck", "Lists anything missing in chat when a ready check starts.")
    Setting(chat, "On entering a dungeon or raid", 12, -56, "instanceReminder",
        "Lists anything missing in chat a few seconds after you enter a dungeon, raid or battleground.")
    Setting(chat, "Play a sound with chat reminders", 12, -82, "sound", "A raid warning sound with each chat reminder.")

    local other = Card(p, "Other", 0, -120, PAGE_W, 88)
    Setting(other, "Show minimap icon", 12, -30, "minimap",
        "Left-click it for these options, right-click to show or hide the reminders.")
    local check = FlatButton(other, "List my checks", 130)
    check:SetPoint("TOPLEFT", 12, -54)
    check:SetScript("OnClick", function() TO:Check() end)
    T.Note(other, "Lists this character's checks in chat, and whether each was found.", 154, -59)

    local cmds = Card(p, "Commands", 0, -218, PAGE_W, 167)
    local lines = {
        "|cffe8a040/topoff|r  open or close these options",
        "|cffe8a040/topoff toggle|r  show or hide the reminders",
        "|cffe8a040/topoff lock|r / |cffe8a040/topoff unlock|r  lock or unlock the reminders",
        "|cffe8a040/topoff check|r  list what's checked for your class",
        "|cffe8a040/topoff add 20 Item Name|r  keep an item stocked",
        "|cffe8a040/topoff remove Item Name|r  stop checking it",
        "|cffe8a040/topoff unhide|r  bring back reminders you hid (Shift + right-click)",
        "|cffe8a040/topoff reset|r  reset the reminders' position",
    }
    for i, l in ipairs(lines) do
        local fs = Text(cmds, l, "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 12, -26 - (i - 1) * 17)
    end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local lists = {}   -- tab key -> its scrolling list

-- Draws the list on the tab that's showing (nothing to do on Display and General).
-- A list drawn again while you're on it stays where you'd scrolled to.
function TO:BuildChecksList()
    self:NameMoreTab()
    local tab = self.optionsTab or "buffs"
    for key, other in pairs(lists) do if key ~= tab then other.shown = nil end end
    local scroll = lists[tab]
    if not scroll then return end
    local c = scroll.child
    ReleasePool(c)
    local ctx = Builder(c)
    if self.char.splitProfiles and tab ~= "profiles" then
        ctx.card("Editing checks for")
        Dropdown(c, PAD, ctx.y - 1, 220, { false, true },
            { [false] = "Dungeons and raids", [true] = "Everywhere else" },
            function() return TO.editOutside and true or false end,
            function(v)
                TO.editOutside = v
                TO:BuildChecksList()
            end, "Which set of on/off checks this page shows and changes.")
        ctx.row()
        ctx.note("Only the on/off checks are separate. Greyed-out settings are shared by both; "
            .. "change them while editing dungeons and raids.")
    end
    LIST_BUILDERS[tab](self, ctx, self:PlayerClass())
    c.applyStates()
    scroll:SetContent(LIST_W, ctx.finish(), scroll.shown == tab)
    scroll.shown = tab
end

function TO:ShowOptionsTab(key)
    self.optionsTab = key
    local win = self.config
    if not win then return end
    win:ShowTab(key)
end

-- The Supplies tab names the items the slots follow, and the Buffs tab lists the elixirs
-- in your bags. When they change while one is showing, draw it again; not while you're
-- typing in one of its boxes (returns false, and it's tried again at the next update).
function TO:RefreshLists()
    local tab = self.optionsTab
    if not (self.config and self.config:IsShown() and (tab == "supplies" or tab == "buffs")) then return true end
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus then return false end
    self:BuildChecksList()
    return true
end

-- A display setting changed outside the window (a slash command, the header menu, the
-- minimap button): the open window shows it
function TO:RefreshSettings()
    if self.config and self.config:IsShown() then RunRefreshers() end
end

function TO:RefreshConfig()
    if self.config and self.config:IsShown() then
        RunRefreshers()
        self:BuildChecksList()
    end
end

local TAB_ICONS = {
    buffs = "Interface\\Icons\\Spell_Holy_WordFortitude",
    supplies = "Interface\\Icons\\INV_Misc_Bag_08",
    more = "Interface\\Icons\\Ability_Hunter_BeastCall",
    profiles = "Interface\\Icons\\INV_Misc_Note_01",
}

-- Beside a page's title: who its settings are for
local function Scope(page, who)
    local fs = Text(page, who, "GameFontDisableSmall")
    fs:SetPoint("BOTTOMLEFT", page.title, "BOTTOMRIGHT", 8, 2)
end

function TO:BuildConfig()
    local tabs = {}
    for _, t in ipairs(TO.OPTION_TABS) do
        tabs[#tabs + 1] = { key = t.key, label = t.label, icon = TAB_ICONS[t.key], build = function(body, page)
            Scope(page, "this character")
            local scroll = T.ScrollArea(body, T.WINDOW.BODY_H)
            scroll.child.pool = {}
            lists[t.key] = scroll
        end }
    end
    tabs[#tabs + 1] = { key = "display", label = "Display", icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
        build = function(body, page) Scope(page, "all your characters") BuildDisplayTab(body) end }
    tabs[#tabs + 1] = { key = "general", label = "General", icon = "Interface\\Icons\\INV_Misc_Gear_01",
        build = function(body, page) Scope(page, "all your characters") BuildGeneralTab(body) end }

    self.config = T.Window({
        name = "ToppedOffForeverOptions",
        tabs = tabs,
        hint = "Shift + right-click a reminder to hide it for 10 minutes  -  /topoff unhide brings it back",
        version = function()
            local get = C_AddOns and C_AddOns.GetAddOnMetadata
            local v = get and get(ADDON, "Version")
            if type(v) == "string" and not v:find("@", 1, true) then return (v:gsub("^v", "")) end
        end,
        onShow = function()
            RunRefreshers()
            for _, scroll in pairs(lists) do scroll.shown = nil end   -- a reopened window starts at the top
            TO:ShowOptionsTab(TO.optionsTab or "buffs")
        end,
        -- Every way to a tab (a click, /topoff, opening the window) draws its list afresh
        onTab = function(key)
            if not TO.config then return end   -- the window is still being built
            TO.optionsTab = key
            TO:BuildChecksList()
        end,
    })
    self.config.lists = lists
    self:NameMoreTab()
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
