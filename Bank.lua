-- ToppedOff Forever: restock from the bank. Beside the bank window: what you're
-- short on (compared with your Min counts) that's in your bank. One click moves
-- enough stacks into your bags; nothing moves until you click.

local _, ns = ...
local TO = ns.TO
local T = ns.Theme

local WIDTH, ROW_H, MAX_ROWS = 260, 20, 12

-- Your bank's containers with slots: the purchased bank tabs (Forever's bank), and the
-- tab numbers as a fallback
function TO:BankContainers()
    local ids, seen = {}, {}
    local function add(id)
        id = self.Num(id)
        if id and not seen[id] and (self.Num(C_Container.GetContainerNumSlots(id)) or 0) > 0 then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    if C_Bank and C_Bank.FetchPurchasedBankTabData and Enum and Enum.BankType then
        local ok, tabs = pcall(C_Bank.FetchPurchasedBankTabData, Enum.BankType.Character)
        if ok and type(tabs) == "table" then
            for _, tab in ipairs(tabs) do add(type(tab) == "table" and tab.ID) end
        end
    end
    local first = Enum and Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1
    if first then
        for i = 0, 8 do add(first + i) end
    end
    return ids
end

-- Stacks in the bank by lowercase name: { { bag, slot, count, id, name, icon }, ... }
function TO:ScanBank()
    local stacks = {}
    for _, bag in ipairs(self:BankContainers()) do
        for slot = 1, (self.Num(C_Container.GetContainerNumSlots(bag)) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = type(info) == "table" and self.Num(info.itemID)
            local name = id and self.Str(C_Item.GetItemNameByID(id))
            if name then
                local key = name:lower()
                stacks[key] = stacks[key] or {}
                table.insert(stacks[key], { bag = bag, slot = slot, id = id, name = name,
                    count = self.Num(info.stackCount) or 1, icon = info.iconFileID })
            end
        end
    end
    return stacks
end

-- Rows to take: { name, icon, need, take, stacks = { ... } }. Whole stacks, biggest
-- first, until you have your Min (a stack can't be split from here, so you may get a few more).
function TO:BankPlan()
    local bank = self:ScanBank()
    local plan = {}
    for _, need in ipairs(self:RestockNeeds()) do
        local found = {}
        for _, n in ipairs(need.any or need.names) do
            for _, st in ipairs(bank[n:lower()] or {}) do found[#found + 1] = st end
        end
        table.sort(found, function(a, b) return a.count > b.count end)
        local take, use = 0, {}
        for _, st in ipairs(found) do
            if take >= need.need then break end
            use[#use + 1] = st
            take = take + st.count
        end
        if take > 0 then
            plan[#plan + 1] = { name = use[1].name, icon = use[1].icon, need = need.need, take = take, stacks = use }
        end
    end
    return plan
end

-- Moves the rows' stacks into your bags (a click on the button). Stops when your bags are full.
function TO:TakeFromBank(plan)
    local free = self:FreeBagSlots()
    local took, full = {}, false
    for _, row in ipairs(plan) do
        if not row.skip then
            local moved = 0
            for _, st in ipairs(row.stacks) do
                if free <= 0 then full = true break end
                C_Container.UseContainerItem(st.bag, st.slot)
                moved = moved + st.count
                free = free - 1
            end
            if moved > 0 then took[#took + 1] = moved .. " " .. row.name end
            if full then break end
        end
    end
    if #took > 0 then self.Print("took " .. table.concat(took, ", ") .. " from the bank.") end
    if full then self.Print("your bags are full.") end
    return took, full
end

local function Button(parent, text, width)
    local b = T.FlatButton(parent, text, width)
    local enable = b.SetEnabled
    function b:SetEnabled(on)
        enable(self, on)
        self:SetAlpha(on and 1 or 0.45)
    end
    return b
end

function TO:BuildBankPanel()
    local host = BankFrame or UIParent
    local f = CreateFrame("Frame", "ToppedOffForeverBank", host)
    f:SetSize(WIDTH, 100)
    if BankFrame then
        f:SetPoint("TOPLEFT", BankFrame, "TOPRIGHT", 6, -30)
    else
        f:SetPoint("CENTER")
    end
    T.Panel(f, 0.95)
    f:EnableMouse(true)
    f:Hide()

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(22)
    T.HeaderStrip(header, "ToppedOff: from the bank")
    header:FitLogo(22)

    -- Item rows: switch (take it or not), icon, "20 Sacred Candle (need 6)"
    f.rows, f.skipped = {}, {}
    for i = 1, MAX_ROWS do
        local r = T.SwitchWidget(f)
        r:SetPoint("TOPLEFT", 8, -28 - (i - 1) * ROW_H)
        r.icon = f:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(16, 16)
        r.icon:SetPoint("LEFT", r, "RIGHT", 6, 0)
        r.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
        r.text:SetWidth(WIDTH - 70)
        r.text:SetJustifyH("LEFT")
        r.text:SetWordWrap(false)
        r:SetScript("OnClick", function(self)
            self:SetOn(not self:IsOn())
            if self.row then
                self.row.skip = not self:IsOn()
                f.skipped[self.row.name] = self.row.skip or nil   -- remembered while the bank is open
            end
            TO:UpdateBankButton()
        end)
        r:Hide()
        f.rows[i] = r
    end

    f.take = Button(f, "Take from bank", WIDTH - 16)
    -- After moving, wait for the items to reach your bags before allowing another click
    f.take:SetScript("OnClick", function()
        if InCombatLockdown() then TO.Print("wait until combat ends.") return end
        TO:TakeFromBank(f.plan or {})
        f.waiting = true
        TO:UpdateBankButton()
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function() f.waiting = false TO:UpdateBankPanel() end)
        end
    end)
    self.bankPanel = f
end

function TO:UpdateBankButton()
    local f = self.bankPanel
    if not f or not f.plan then return end
    local any = false
    for _, row in ipairs(f.plan) do if not row.skip then any = true end end
    f.take:SetEnabled(any and not f.waiting)
end

-- Rebuilds the panel for the open bank (or hides it)
function TO:UpdateBankPanel()
    if not (self.bankOpen and self.char.bankRestock) then
        if self.bankPanel then self.bankPanel:Hide() end
        return
    end
    if not self.bankPanel then self:BuildBankPanel() end
    local f = self.bankPanel
    self:ScanBags()
    self:UpdateAutoItems()
    local plan = self:BankPlan()
    if #plan == 0 then
        f:Hide()
        return
    end
    while #plan > MAX_ROWS do table.remove(plan) end
    for _, row in ipairs(plan) do row.skip = f.skipped[row.name] end
    f.plan = plan
    for i, r in ipairs(f.rows) do
        local row = plan[i]
        r.row = row
        if row then
            r.icon:SetTexture(row.icon or self.ICONS.unknown)
            r.text:SetText(row.take .. " " .. row.name .. " |cff999999(need " .. row.need .. ")|r")
            r:SetOn(not row.skip)
            r:Show(); r.icon:Show(); r.text:Show()
        else
            r:Hide(); r.icon:Hide(); r.text:Hide()
        end
    end
    local y = -26 - #plan * ROW_H - 4
    f.take:ClearAllPoints()
    f.take:SetPoint("TOPLEFT", 8, y)
    self:UpdateBankButton()
    f:SetHeight(-y + 30)
    f:Show()
end

-- Bank events
local events = CreateFrame("Frame")
events:RegisterEvent("BANKFRAME_OPENED")
events:RegisterEvent("BANKFRAME_CLOSED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
events:SetScript("OnEvent", function(_, event)
    if not TO.char or not TO.built then return end
    if event == "BANKFRAME_OPENED" then
        TO.bankOpen = true
        if TO.bankPanel then TO.bankPanel.skipped, TO.bankPanel.waiting = {}, false end
        TO:UpdateBankPanel()
    elseif event == "BANKFRAME_CLOSED" then
        TO.bankOpen = false
        TO:UpdateBankPanel()
    elseif TO.bankOpen then
        if event == "BAG_UPDATE_DELAYED" and TO.bankPanel then TO.bankPanel.waiting = false end
        TO:UpdateBankPanel()
    end
end)
