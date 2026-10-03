-- The shared look of severd8's WoW: Forever addons: flat dark panels, gold text,
-- red accents, the logo header bar, and the settings window with tabs down the
-- left. This same file ships in TauntMaster Forever, ToppedOff Forever and
-- Outfitter Forever. Change it in one, then copy it to the others.

local ADDON, ns = ...
local T = {}
ns.Theme = T

-- What each addon calls itself and where its logo is (inside its own folder)
local BRANDS = {
    TauntMasterForever = { name = "TauntMaster Forever", short = "TauntMaster", logo = "Media\\logo" },
    ToppedOffForever   = { name = "ToppedOff Forever",   short = "ToppedOff",   logo = "Media\\Icon" },
    OutfitterForever   = { name = "Outfitter Forever",   short = "Outfitter",   logo = "Textures\\Logo" },
}
local brand = BRANDS[ADDON] or { name = tostring(ADDON), short = tostring(ADDON), logo = "" }
T.NAME = brand.name     -- window titles, chat, tooltips
T.SHORT = brand.short   -- the header bar, where room is tight
T.LOGO = "Interface\\AddOns\\" .. tostring(ADDON) .. "\\" .. brand.logo
-- Chat lines start with the logo and the addon's name in orange
T.CHAT_PREFIX = "|T" .. T.LOGO .. ":0|t |cffe8a040" .. T.NAME .. "|r"

local C = {
    win     = { 0.07, 0.063, 0.063, 0.98 },
    side    = { 0.047, 0.04, 0.04, 1 },
    card    = { 0.10, 0.086, 0.078, 1 },
    field   = { 0.055, 0.047, 0.043, 1 },
    line    = { 0.17, 0.14, 0.10, 1 },
    edge    = { 0.35, 0.29, 0.19, 1 },
    fieldEdge = { 0.29, 0.24, 0.16, 1 },
    red     = { 0.48, 0.11, 0.06, 1 },
    redHi   = { 0.62, 0.16, 0.08, 1 },
    btnEdge = { 0.72, 0.53, 0.23, 1 },
    offTrack = { 0.23, 0.20, 0.19, 1 },
    onTrack = { 0.55, 0.14, 0.08, 1 },
    gold    = { 1, 0.82, 0, 1 },
    grey    = { 0.54, 0.50, 0.47, 1 },
    orange  = { 0.91, 0.63, 0.25 },
    muted   = { 0.81, 0.77, 0.68 },
    title   = { 0.95, 0.9, 0.78 },     -- window titles
    version = { 0.85, 0.65, 0.35 },    -- the small version beside them
    tabOn   = { 0.23, 0.06, 0.04, 1 }, -- selected tab
    accent  = { 0.89, 0.23, 0.13, 1 }, -- the bar beside it
    fill    = { 0.72, 0.2, 0.11, 1 },  -- the filled part of a slider
}

---------------------------------------------------------------------------
-- Basics
---------------------------------------------------------------------------
local function Fill(frame, color, layer, sub)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or -8)
    t:SetAllPoints()
    t:SetColorTexture(unpack(color))
    return t
end

local function Border(frame, color)
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(unpack(color))
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(1)
        else
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(1)
        end
        edges[#edges + 1] = t
    end
    return edges
end

local function Text(parent, text, template, color, size)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    if size then
        local font, _, flags = fs:GetFont()
        if font then fs:SetFont(font, size, flags) end
    end
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    fs:SetJustifyH("LEFT")
    fs:SetText(text or "")
    return fs
end

-- Flat red button with gold text
local function FlatButton(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 100, height or 22)
    b.bg = Fill(b, C.red)
    Border(b, C.btnEdge)
    local fs = Text(b, "", "GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetJustifyH("CENTER")
    b:SetFontString(fs)
    b:SetText(text)
    function b:SetHover(on) self.bg:SetColorTexture(unpack(on and C.redHi or C.red)) end
    b:SetScript("OnEnter", function(self) self:SetHover(true) end)
    b:SetScript("OnLeave", function(self) self:SetHover(false) end)
    return b
end

-- Hover tooltip: a title line and/or a wrapped white one. Keeps a button's own
-- hover colour working.
function T.Tooltip(widget, title, body)
    widget:SetScript("OnEnter", function(self)
        if self.SetHover then self:SetHover(true) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title then GameTooltip:AddLine(title) end
        if body then GameTooltip:AddLine(body, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function(self)
        if self.SetHover then self:SetHover(false) end
        GameTooltip:Hide()
    end)
end

-- Red gradient used by window headers and banners
function T.HeaderGradient(tex)
    tex:SetColorTexture(1, 1, 1, 1)
    local ok = CreateColor and pcall(tex.SetGradient, tex, "HORIZONTAL",
        CreateColor(0.35, 0.075, 0.047, 1), CreateColor(0.11, 0.03, 0.024, 1))
    if not ok then tex:SetColorTexture(0.25, 0.06, 0.04, 1) end
end

-- On/off switch widget. b:SetOn(bool) paints it; b:IsOn() reads it.
function T.SwitchWidget(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(30, 16)
    b.isSwitch = true
    local track = b:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    local knob = b:CreateTexture(nil, "ARTWORK")
    knob:SetSize(12, 12)
    function b:SetOn(on)
        self.on = on and true or false
        track:SetColorTexture(unpack(self.on and C.onTrack or C.offTrack))
        knob:SetColorTexture(unpack(self.on and C.gold or C.grey))
        knob:ClearAllPoints()
        knob:SetPoint("LEFT", self, "LEFT", self.on and 16 or 2, 0)
    end
    function b:IsOn() return self.on end
    b:SetOn(false)
    return b
end

T.C, T.Fill, T.Border, T.Text, T.FlatButton = C, Fill, Border, Text, FlatButton

---------------------------------------------------------------------------
-- An on-screen panel (behind icons, beside the vendor window): dark, see-through,
-- with the thin edge every window has.
---------------------------------------------------------------------------
function T.Panel(frame, alpha)
    frame.bg = Fill(frame, { C.win[1], C.win[2], C.win[3], alpha or 0.9 })
    Border(frame, C.edge)
    return frame
end

---------------------------------------------------------------------------
-- The header bar above an on-screen frame: logo, then the name in gold on red.
-- Adds .bg, .logo and .text to the frame it's given. The logo is a square as
-- tall as the bar allows, so set the frame's height before or after freely.
---------------------------------------------------------------------------
function T.HeaderStrip(frame, text)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(unpack(C.red))
    Border(frame, C.edge)
    frame.logo = frame:CreateTexture(nil, "ARTWORK")
    frame.logo:SetPoint("TOPLEFT", 3, -2)
    frame.logo:SetPoint("BOTTOMLEFT", 3, 2)
    frame.logo:SetTexture(T.LOGO)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.text:SetPoint("LEFT", frame.logo, "RIGHT", 4, 0)
    frame.text:SetPoint("RIGHT", -4, 0)
    frame.text:SetJustifyH("LEFT")
    frame.text:SetWordWrap(false)
    frame.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    frame.text:SetText(text or T.SHORT)
    function frame:FitLogo(height)   -- keep the logo square
        self.logo:SetWidth(math.max(1, height - 4))
    end
    frame:FitLogo(frame:GetHeight() or 16)
    return frame
end

---------------------------------------------------------------------------
-- Widgets for a settings page
---------------------------------------------------------------------------
-- The small gold arrow at the right of anything that opens a menu
function T.MenuArrow(button, inset)
    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", -inset, 0)
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    arrow:SetVertexColor(C.orange[1], C.orange[2], C.orange[3])
    return arrow
end

-- Card: a panel with a small orange uppercase title. Content starts at y = -28.
function T.Card(parent, title, x, y, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", x, y)
    f:SetSize(w, h)
    Fill(f, C.card)
    Border(f, C.line)
    f.title = Text(f, title and title:upper() or "", "GameFontNormalSmall", C.orange)
    f.title:SetPoint("TOPLEFT", 12, -10)
    return f
end

function T.Note(parent, text, x, y, width)
    local n = Text(parent, text, "GameFontDisableSmall")
    n:SetPoint("TOPLEFT", x, y)
    if width then n:SetWidth(width); n:SetWordWrap(true) end
    return n
end

function T.RowLabel(parent, text, x, y)
    local fs = Text(parent, text, "GameFontHighlight", C.muted)
    fs:SetPoint("TOPLEFT", x, y - 4)
    return fs
end

-- A switch with its label to the right. Returns the switch and the label.
function T.LabeledSwitch(parent, text, x, y, labelWidth)
    local b = T.SwitchWidget(parent)
    b:SetPoint("TOPLEFT", x, y)
    local label = Text(parent, text, "GameFontHighlight")
    label:SetPoint("TOPLEFT", b, "TOPRIGHT", 8, 1)
    if labelWidth then label:SetWidth(labelWidth); label:SetWordWrap(true) end
    b.label = label
    return b, label
end

-- Dropdown: shows the current choice; click for a menu of the choices (or step
-- to the next one where the game has no menus). labels[key] is the text shown.
function T.Dropdown(parent, width, keys, labels, getter, setter)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 22)
    Fill(b, C.field)
    Border(b, C.fieldEdge)
    local fs = Text(b, "", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", 8, 0)
    fs:SetPoint("RIGHT", -20, 0)
    b:SetFontString(fs)
    T.MenuArrow(b, 6)
    b.keys, b.labels, b.getter, b.setter = keys, labels, getter, setter

    local function label(k)
        if type(b.labels) == "function" then return b.labels(k) end
        return b.labels[k] or tostring(k)
    end
    local function refresh() b:SetText(label(b.getter())) end
    local function choose(k) b.setter(k); refresh() end
    b:SetScript("OnClick", function(self)
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(_, root)
                if self.menuTitle then root:CreateTitle(self.menuTitle) end
                for _, k in ipairs(self.keys) do
                    root:CreateRadio(self.menuLabels and self.menuLabels[k] or label(k),
                        function() return self.getter() == k end, function() choose(k) end)
                end
            end)
        else
            local cur, nextIdx = self.getter(), 1
            for i, k in ipairs(self.keys) do
                if k == cur then nextIdx = (i % #self.keys) + 1 break end
            end
            if self.keys[nextIdx] ~= nil then choose(self.keys[nextIdx]) end
        end
    end)
    b.Refresh = refresh
    b.Choose = choose
    return b
end

-- Flat slider: label on the left, value on the right, thin track with a gold
-- knob. get() reads the setting, set(v) saves it; s.Refresh() repaints it.
function T.Slider(parent, text, x, y, width, get, set, min, max, suffix, step, fmt)
    suffix, step, fmt = suffix or "", step or 1, fmt or "%d"
    local title = Text(parent, text, "GameFontHighlight", C.muted)
    title:SetPoint("TOPLEFT", x, y)
    local value = Text(parent, "", "GameFontNormal")
    value:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y)
    value:SetJustifyH("RIGHT")

    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(width, 14)
    s:SetPoint("TOPLEFT", x, y - 18)
    s:SetHitRectInsets(0, 0, -6, -6)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetHeight(4)
    track:SetPoint("LEFT"); track:SetPoint("RIGHT")
    track:SetColorTexture(unpack(C.offTrack))
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(10, 14)
    thumb:SetColorTexture(unpack(C.gold))
    s:SetThumbTexture(thumb)
    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(4)
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")
    fill:SetColorTexture(unpack(C.fill))
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    if s.SetObeyStepsOnDrag then s:SetObeyStepsOnDrag(true) end   -- missing on Forever

    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        if step >= 1 then v = math.floor(v + 0.5) end
        value:SetText(fmt:format(v) .. suffix)
        if get() ~= v then set(v) end
    end)
    function s.Refresh()
        s:SetValue(get())
        value:SetText(fmt:format(get()) .. suffix)
    end
    return s
end

-- Flat text box
function T.EditBox(parent, width)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(width, 22)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetTextInsets(6, 6, 0, 0)
    Fill(eb, C.field)
    Border(eb, C.fieldEdge)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return eb
end

-- A page that can outgrow the window: scrolls with the mouse wheel or the thin
-- bar at its right. Put the content in scroll.child, then call
-- scroll:SetContent(width, height) whenever it changes.
function T.ScrollArea(parent, viewHeight)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -12, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(10, 10)
    scroll:SetScrollChild(child)
    scroll.child = child

    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(6)
    bar:SetPoint("TOPRIGHT")
    bar:SetPoint("BOTTOMRIGHT")
    Fill(bar, C.offTrack)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(6, 40)
    thumb:SetColorTexture(unpack(C.btnEdge))
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", function(_, v) scroll:SetVerticalScroll(v) end)
    scroll.bar = bar

    local range = 0
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue(math.max(0, math.min(range, (bar:GetValue() or 0) - delta * 40)))
    end)
    -- keepPlace: stay where the reader was (when the same content is drawn again)
    function scroll:SetContent(width, height, keepPlace)
        child:SetSize(width, height)
        range = math.max(0, height - viewHeight)
        local at = keepPlace and math.min(bar:GetValue() or 0, range) or 0
        bar:SetMinMaxValues(0, range)
        bar:SetShown(range > 0)
        bar:SetValue(at)
        self:SetVerticalScroll(at)
    end
    return scroll
end

---------------------------------------------------------------------------
-- The settings window: a red header (logo, name, version, X) you drag it by,
-- tabs down the left, one page per tab, and a footer with a hint and Close.
--   opts.name     global frame name (Escape closes it)
--   opts.tabs     { { key =, label =, icon =, build = function(body, page) }, ... }
--   opts.hint     footer text
--   opts.version  function returning the version shown beside the name
--   opts.onShow / onHide / onTab(key)   optional
-- Returns the window, with .pages[key], .tabButtons[key], :ShowTab(key) and .currentTab
---------------------------------------------------------------------------
T.WINDOW = { W = 740, H = 540, HEADER = 52, FOOTER = 40, SIDE = 170, PAGE_W = 540 }
T.WINDOW.BODY_H = T.WINDOW.H - T.WINDOW.HEADER - T.WINDOW.FOOTER - 54   -- what's left for a page's content

function T.Window(opts)
    local W, H, HEADER, FOOTER, SIDE = T.WINDOW.W, T.WINDOW.H, T.WINDOW.HEADER, T.WINDOW.FOOTER, T.WINDOW.SIDE
    local win = CreateFrame("Frame", opts.name, UIParent)
    win:SetSize(W, H)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:Hide()
    table.insert(UISpecialFrames, opts.name)
    Fill(win, C.win)
    Border(win, C.edge)
    win.pages, win.tabButtons = {}, {}

    -- Header: drag to move
    local header = CreateFrame("Frame", nil, win)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(HEADER)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() win:StartMoving() end)
    header:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)
    local hbg = header:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    T.HeaderGradient(hbg)
    local hline = header:CreateTexture(nil, "BORDER")
    hline:SetPoint("BOTTOMLEFT"); hline:SetPoint("BOTTOMRIGHT"); hline:SetHeight(1)
    hline:SetColorTexture(unpack(C.edge))
    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(36, 36)
    logo:SetPoint("LEFT", 14, 0)
    logo:SetTexture(T.LOGO)
    local title = Text(header, T.NAME, "GameFontNormalLarge", C.title, 18)
    title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    local ver = Text(header, "", "GameFontNormalSmall", C.version)
    ver:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
    local x = FlatButton(header, "X", 24, 24)
    x:SetPoint("RIGHT", -12, 0)
    x:SetScript("OnClick", function() win:Hide() end)
    win.header, win.logo, win.title, win.version = header, logo, title, ver

    win:SetScript("OnShow", function()
        local v = opts.version and opts.version()
        ver:SetText(v and ("v" .. v) or "")
        if opts.onShow then opts.onShow() end
    end)
    win:SetScript("OnHide", function() if opts.onHide then opts.onHide() end end)

    function win:ShowTab(key)
        self.currentTab = key
        for k, page in pairs(self.pages) do page:SetShown(k == key) end
        for k, b in pairs(self.tabButtons) do
            local sel = (k == key)
            b.selBg:SetShown(sel)
            b.accent:SetShown(sel)
            b.icon:SetDesaturated(not sel)
            b.icon:SetAlpha(sel and 1 or 0.7)
            local c = sel and C.gold or C.muted
            b.label:SetTextColor(c[1], c[2], c[3])
        end
        if opts.onTab then opts.onTab(key) end
    end

    -- Sidebar tabs
    local side = CreateFrame("Frame", nil, win)
    side:SetPoint("TOPLEFT", 1, -(HEADER + 1))
    side:SetPoint("BOTTOMLEFT", 1, FOOTER + 1)
    side:SetWidth(SIDE)
    Fill(side, C.side)
    local sline = side:CreateTexture(nil, "BORDER")
    sline:SetPoint("TOPRIGHT"); sline:SetPoint("BOTTOMRIGHT"); sline:SetWidth(1)
    sline:SetColorTexture(unpack(C.line))
    for i, t in ipairs(opts.tabs) do
        local b = CreateFrame("Button", nil, side)
        b:SetSize(SIDE - 1, 36)
        b:SetPoint("TOPLEFT", 0, -8 - (i - 1) * 36)
        b.selBg = b:CreateTexture(nil, "BACKGROUND")
        b.selBg:SetAllPoints()
        b.selBg:SetColorTexture(unpack(C.tabOn))
        b.accent = b:CreateTexture(nil, "ARTWORK")
        b.accent:SetPoint("TOPLEFT"); b.accent:SetPoint("BOTTOMLEFT"); b.accent:SetWidth(3)
        b.accent:SetColorTexture(unpack(C.accent))
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.05)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(18, 18)
        b.icon:SetPoint("LEFT", 16, 0)
        b.icon:SetTexture(t.icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local fs = Text(b, "", "GameFontHighlight")
        fs:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
        b:SetFontString(fs)
        b.label = fs
        b:SetText(t.label)
        b:SetScript("OnClick", function() win:ShowTab(t.key) end)
        win.tabButtons[t.key] = b
    end

    -- Pages
    for _, t in ipairs(opts.tabs) do
        local page = CreateFrame("Frame", nil, win)
        page:SetPoint("TOPLEFT", SIDE + 16, -(HEADER + 14))
        page:SetPoint("BOTTOMRIGHT", -16, FOOTER + 10)
        page.title = Text(page, t.label, "GameFontNormalLarge", C.gold, 17)
        page.title:SetPoint("TOPLEFT", 0, 0)
        local body = CreateFrame("Frame", nil, page)
        body:SetPoint("TOPLEFT", 0, -30)
        body:SetPoint("BOTTOMRIGHT")
        page.body = body
        win.pages[t.key] = page
        t.build(body, page)
    end

    -- Footer
    local foot = CreateFrame("Frame", nil, win)
    foot:SetPoint("BOTTOMLEFT", 1, 1)
    foot:SetPoint("BOTTOMRIGHT", -1, 1)
    foot:SetHeight(FOOTER)
    Fill(foot, C.side)
    local fline = foot:CreateTexture(nil, "BORDER")
    fline:SetPoint("TOPLEFT"); fline:SetPoint("TOPRIGHT"); fline:SetHeight(1)
    fline:SetColorTexture(unpack(C.line))
    local hint = Text(foot, opts.hint or "", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 14, 0)
    local close = FlatButton(foot, "Close", 90)
    close:SetPoint("RIGHT", -14, 0)
    close:SetScript("OnClick", function() win:Hide() end)
    win.footer = foot

    win:ShowTab(opts.tabs[1].key)
    return win
end
