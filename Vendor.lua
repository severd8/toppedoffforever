-- ToppedOff Forever: restock and repair panel beside the vendor window.
-- Lists what you're short on (compared with your Min counts) that this vendor
-- sells. Nothing is bought until you click Restock; Repair all works the same way.

local _, ns = ...
local TO = ns.TO
local T = ns.Theme

local WIDTH, ROW_H, MAX_ROWS = 260, 20, 12

local function Money(copper)
    copper = math.floor(copper or 0)
    local coins = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString
    if coins then
        local ok, text = pcall(coins, copper)
        if ok and type(text) == "string" then return text end
    end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

-- A flat button that greys out while it can't be clicked
local function Button(parent, text, width)
    local b = T.FlatButton(parent, text, width)
    local enable = b.SetEnabled
    function b:SetEnabled(on)
        enable(self, on)
        self:SetAlpha(on and 1 or 0.45)
    end
    return b
end

function TO:BuildVendorPanel()
    local host = MerchantFrame or UIParent
    local f = CreateFrame("Frame", "ToppedOffForeverVendor", host)
    f:SetSize(WIDTH, 100)
    if MerchantFrame then
        f:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 6, -30)
    else
        f:SetPoint("CENTER")
    end
    T.Panel(f, 0.95)
    f:EnableMouse(true)
    f:Hide()

    -- Header bar, like the reminder frame's
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(22)
    T.HeaderStrip(header, "ToppedOff: restock")
    header:FitLogo(22)

    -- Item rows: switch (buy it or not), icon, "20 Sacred Candle", cost
    f.rows = {}
    f.skipped = {}
    for i = 1, MAX_ROWS do
        local r = T.SwitchWidget(f)
        r.SetChecked, r.GetChecked = r.SetOn, r.IsOn
        r:SetPoint("TOPLEFT", 8, -28 - (i - 1) * ROW_H)
        r.icon = f:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(16, 16)
        r.icon:SetPoint("LEFT", r, "RIGHT", 6, 0)
        r.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
        r.text:SetWidth(WIDTH - 160)
        r.text:SetJustifyH("LEFT")
        r.text:SetWordWrap(false)
        r.cost = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.cost:SetPoint("RIGHT", f, "TOPRIGHT", -8, -36 - (i - 1) * ROW_H)
        r.cost:SetJustifyH("RIGHT")
        r:SetScript("OnClick", function(self)
            self:SetOn(not self:IsOn())
            if self.row then
                self.row.skip = not self:GetChecked()
                f.skipped[self.row.name] = self.row.skip or nil   -- remembered while the vendor is open
            end
            TO:UpdateVendorTotals()
        end)
        r:Hide()
        f.rows[i] = r
    end

    f.none = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.none:SetPoint("TOPLEFT", 10, -30)
    f.none:SetText("You're topped off.")

    f.total = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.total:SetJustifyH("RIGHT")

    f.buy = Button(f, "Restock", 100)
    -- After buying, wait for the items to reach your bags before allowing another
    -- click, so the same list can't be bought twice.
    f.buy:SetScript("OnClick", function()
        TO:BuyRestock(f.plan or {})
        f.waiting = true
        f.buy:SetEnabled(false)
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function() f.waiting = false TO:UpdateVendorPanel() end)
        end
    end)

    f.repair = Button(f, "Repair all", WIDTH - 16)
    f.repair:SetScript("OnClick", function()
        if RepairAllItems then RepairAllItems() end
        if C_Timer and C_Timer.After then C_Timer.After(0.5, function() TO:UpdateVendorPanel() end) end
    end)

    self.vendor = f
end

function TO:UpdateVendorTotals()
    local f = self.vendor
    if not f or not f.plan then return end
    local total = 0
    for _, row in ipairs(f.plan) do
        if not row.skip then total = total + row.cost end
    end
    local money = TO.Num(GetMoney and GetMoney()) or 0
    local text = "Total: " .. Money(total)
    if total > money then text = "|cffff5555" .. text .. "|r" end
    f.total:SetText(text)
    f.buy:SetEnabled(total > 0 and not f.waiting)
end

-- Rebuilds the panel for the open vendor (or hides it)
function TO:UpdateVendorPanel()
    if not self.merchantOpen then
        if self.vendor then self.vendor:Hide() end
        return
    end
    if not self.vendor then self:BuildVendorPanel() end
    local f = self.vendor
    self:ScanBags()
    self:UpdateAutoItems()

    local plan = self.char.restockAtVendor and self:RestockPlan() or {}
    local repairCost, canRepair = 0, false
    if self.char.repairAtVendor and CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost then
        local cost, can = GetRepairAllCost()
        repairCost, canRepair = self.Num(cost) or 0, (not self.IsSecretValue(can)) and can and true or false
    end
    local showRepair = canRepair and repairCost > 0
    if #plan == 0 and not showRepair then
        f:Hide()
        return
    end

    -- Only what's shown can be bought
    while #plan > MAX_ROWS do table.remove(plan) end
    for _, row in ipairs(plan) do row.skip = f.skipped[row.name] end
    f.plan = plan
    local shown = #plan
    for i, r in ipairs(f.rows) do
        local row = plan[i]
        r.row = row
        if row then
            r.icon:SetTexture(row.icon or self.ICONS.unknown)
            r.text:SetText(row.count .. " " .. row.name)
            r.cost:SetText(Money(row.cost))
            r:SetChecked(not row.skip)
            r:Show(); r.icon:Show(); r.text:Show(); r.cost:Show()
        else
            r:Hide(); r.icon:Hide(); r.text:Hide(); r.cost:Hide()
        end
    end

    local y = -26 - shown * ROW_H
    f.none:SetShown(#plan == 0 and self.char.restockAtVendor)
    if #plan == 0 then y = y - (self.char.restockAtVendor and 18 or 0) end
    if #plan > 0 then
        y = y - 4
        f.buy:ClearAllPoints()
        f.buy:SetPoint("TOPLEFT", 8, y)
        f.total:ClearAllPoints()
        f.total:SetPoint("RIGHT", f, "TOPRIGHT", -8, y - 11)
        f.buy:Show(); f.total:Show()
        self:UpdateVendorTotals()
        y = y - 26
    else
        f.buy:Hide(); f.total:Hide()
    end
    if showRepair then
        f.repair:ClearAllPoints()
        f.repair:SetPoint("TOPLEFT", 8, y - 2)
        f.repair:SetText("Repair all (" .. Money(repairCost) .. ")")
        f.repair:Show()
        y = y - 28
    else
        f.repair:Hide()
    end
    f:SetHeight(-y + 6)
    f:Show()
end

-- Vendor events
local events = CreateFrame("Frame")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_CLOSED")
events:RegisterEvent("MERCHANT_UPDATE")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
events:RegisterEvent("PLAYER_MONEY")
events:SetScript("OnEvent", function(_, event)
    if not TO.char or not TO.built then return end
    if event == "MERCHANT_SHOW" then
        TO.merchantOpen = true
        if TO.vendor then TO.vendor.skipped, TO.vendor.waiting = {}, false end
        TO:UpdateVendorPanel()
    elseif event == "PLAYER_MONEY" then
        if TO.merchantOpen then TO:UpdateVendorTotals() end
    elseif event == "BAG_UPDATE_DELAYED" and TO.merchantOpen then
        if TO.vendor then TO.vendor.waiting = false end
        TO:UpdateVendorPanel()
    elseif event == "MERCHANT_CLOSED" then
        TO.merchantOpen = false
        TO:UpdateVendorPanel()
    elseif TO.merchantOpen then
        TO:UpdateVendorPanel()
    end
end)
