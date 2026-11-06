local addonName, addon = ...

-- Create the addon using AceAddon with mixins
local HideKnownVendorItems = LibStub("AceAddon-3.0"):NewAddon(addon, addonName,
    "AceEvent-3.0", "AceConsole-3.0")

-- Expose globally for macro support: /run HideKnownVendorItems:Toggle()
_G["HideKnownVendorItems"] = HideKnownVendorItems

-- Addon version
HideKnownVendorItems.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "1.0.0"

-- Default database values
local defaults = {
    profile = {
        enabled = true,
    },
}

-- Check if any string in a C_TooltipInfo data table contains "Already known"
local function CheckTooltipDataForKnown(data)
    if not data or not data.lines then return false end
    -- Try SurfaceArgs if available
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        TooltipUtil.SurfaceArgs(data)
    end
    for _, line in ipairs(data.lines) do
        if TooltipUtil and TooltipUtil.SurfaceArgs then
            TooltipUtil.SurfaceArgs(line)
        end
        -- Check surfaced fields
        if line.leftText and strfind(line.leftText, ITEM_SPELL_KNOWN, 1, true) then
            return true
        end
        if line.rightText and strfind(line.rightText, ITEM_SPELL_KNOWN, 1, true) then
            return true
        end
        -- Check raw args (in case SurfaceArgs didn't work)
        if line.args then
            for _, arg in ipairs(line.args) do
                if arg.stringVal and strfind(arg.stringVal, ITEM_SPELL_KNOWN, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

-- Scan a tooltip frame for "Already known" text on any line (left or right)
local function ScanTooltipForKnown(tip, tipName)
    for i = 1, tip:NumLines() do
        local leftLine = _G[tipName .. "TextLeft" .. i]
        local rightLine = _G[tipName .. "TextRight" .. i]
        if leftLine then
            local text = leftLine:GetText()
            if text and strfind(text, ITEM_SPELL_KNOWN, 1, true) then
                return true
            end
        end
        if rightLine then
            local text = rightLine:GetText()
            if text and strfind(text, ITEM_SPELL_KNOWN, 1, true) then
                return true
            end
        end
    end
    return false
end

function HideKnownVendorItems:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("HideKnownVendorItemsDB", defaults, true)

    self:RegisterChatCommand("hkvi", "SlashCommand")
    self:RegisterChatCommand("hideknownvendoritems", "SlashCommand")

    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, self:GetOptionsTable())
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "HideKnownVendorItems")

    -- Create hidden scanning tooltip
    self.scanTip = CreateFrame("GameTooltip", "HideKnownVendorItemsScanTip", nil, "GameTooltipTemplate")
    self.scanTip:SetOwner(UIParent, "ANCHOR_NONE")

    self:Print("HideKnownVendorItems v" .. self.version .. " loaded. Type /hkvi help for commands.")
end

function HideKnownVendorItems:OnEnable()
    hooksecurefunc("MerchantFrame_Update", function()
        self:FilterMerchantItems()
    end)
end

function HideKnownVendorItems:IsItemKnown(merchantIndex)
    local link = GetMerchantItemLink(merchantIndex)

    -- Method 1: C_TooltipInfo.GetHyperlink (most reliable on modern clients)
    if link and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        if CheckTooltipDataForKnown(C_TooltipInfo.GetHyperlink(link)) then
            return true
        end
    end

    -- Method 2: C_TooltipInfo.GetMerchantItem (merchant-context tooltip)
    if C_TooltipInfo and C_TooltipInfo.GetMerchantItem then
        if CheckTooltipDataForKnown(C_TooltipInfo.GetMerchantItem(merchantIndex)) then
            return true
        end
    end

    -- Method 3: Scanning tooltip with SetMerchantItem
    self.scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    self.scanTip:ClearLines()
    self.scanTip:SetMerchantItem(merchantIndex)
    if ScanTooltipForKnown(self.scanTip, "HideKnownVendorItemsScanTip") then
        return true
    end

    -- Method 4: Scanning tooltip with SetHyperlink
    if link then
        self.scanTip:SetOwner(UIParent, "ANCHOR_NONE")
        self.scanTip:ClearLines()
        self.scanTip:SetHyperlink(link)
        if ScanTooltipForKnown(self.scanTip, "HideKnownVendorItemsScanTip") then
            return true
        end
    end

    return false
end

function HideKnownVendorItems:IsPetSpellKnown(merchantIndex)
    local link = GetMerchantItemLink(merchantIndex)
    if not link then return false end

    local spellName, spellID = GetItemSpell(link)
    if not spellName then return false end

    -- IsSpellKnown with true checks pet spells even without a pet summoned
    if spellID and IsSpellKnown(spellID, true) then
        return true
    end

    -- Fallback: check active pet spellbook if a pet is out
    local numPetSpells = HasPetSpells()
    if numPetSpells and numPetSpells > 0 then
        for i = 1, numPetSpells do
            local name = GetSpellBookItemName(i, BOOKTYPE_PET)
            if name and name == spellName then
                return true
            end
        end
    end

    return false
end

function HideKnownVendorItems:FilterMerchantItems()
    if not self.db.profile.enabled then return end

    local numItems = GetMerchantNumItems()
    local page = MerchantFrame.page or 1
    local startIndex = (page - 1) * MERCHANT_ITEMS_PER_PAGE

    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local merchantIndex = startIndex + i
        local button = _G["MerchantItem" .. i]

        if button and merchantIndex <= numItems then
            if self:IsItemKnown(merchantIndex) or self:IsPetSpellKnown(merchantIndex) then
                button:Hide()
            end
        end
    end
end

function HideKnownVendorItems:DebugMerchantItem(merchantIndex)
    self:Print("=== Debug merchant item #" .. merchantIndex .. " ===")

    local link = GetMerchantItemLink(merchantIndex)
    self:Print("Link: " .. (link or "nil"))

    -- GetItemSpell info
    if link then
        local spellName, spellID = GetItemSpell(link)
        self:Print("GetItemSpell: name=" .. tostring(spellName) .. " id=" .. tostring(spellID))
        if spellID then
            self:Print("IsSpellKnown(id, true): " .. tostring(IsSpellKnown(spellID, true)))
            self:Print("IsSpellKnown(id, false): " .. tostring(IsSpellKnown(spellID, false)))
        end
    end

    -- HasPetSpells
    local numPetSpells = HasPetSpells()
    self:Print("HasPetSpells: " .. tostring(numPetSpells))

    -- C_TooltipInfo availability
    self:Print("C_TooltipInfo: " .. tostring(C_TooltipInfo ~= nil))
    if C_TooltipInfo then
        self:Print("  .GetHyperlink: " .. tostring(C_TooltipInfo.GetHyperlink ~= nil))
        self:Print("  .GetMerchantItem: " .. tostring(C_TooltipInfo.GetMerchantItem ~= nil))
    end
    self:Print("TooltipUtil: " .. tostring(TooltipUtil ~= nil))
    if TooltipUtil then
        self:Print("  .SurfaceArgs: " .. tostring(TooltipUtil.SurfaceArgs ~= nil))
    end

    -- C_TooltipInfo.GetHyperlink dump
    if link and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local data = C_TooltipInfo.GetHyperlink(link)
        if data then
            if TooltipUtil and TooltipUtil.SurfaceArgs then
                TooltipUtil.SurfaceArgs(data)
            end
            self:Print("--- GetHyperlink lines ---")
            if data.lines then
                for j, line in ipairs(data.lines) do
                    if TooltipUtil and TooltipUtil.SurfaceArgs then
                        TooltipUtil.SurfaceArgs(line)
                    end
                    local left = line.leftText or "(nil)"
                    local right = line.rightText or "(nil)"
                    local argStr = ""
                    if line.args then
                        for _, arg in ipairs(line.args) do
                            if arg.stringVal then
                                argStr = argStr .. " arg:\"" .. arg.stringVal .. "\""
                            end
                        end
                    end
                    self:Print("  " .. j .. " L:\"" .. left .. "\" R:\"" .. right .. "\"" .. argStr)
                end
            else
                self:Print("  (no lines)")
            end
        else
            self:Print("  GetHyperlink returned nil")
        end
    end

    -- C_TooltipInfo.GetMerchantItem dump
    if C_TooltipInfo and C_TooltipInfo.GetMerchantItem then
        local data = C_TooltipInfo.GetMerchantItem(merchantIndex)
        if data then
            if TooltipUtil and TooltipUtil.SurfaceArgs then
                TooltipUtil.SurfaceArgs(data)
            end
            self:Print("--- GetMerchantItem lines ---")
            if data.lines then
                for j, line in ipairs(data.lines) do
                    if TooltipUtil and TooltipUtil.SurfaceArgs then
                        TooltipUtil.SurfaceArgs(line)
                    end
                    local left = line.leftText or "(nil)"
                    local right = line.rightText or "(nil)"
                    local argStr = ""
                    if line.args then
                        for _, arg in ipairs(line.args) do
                            if arg.stringVal then
                                argStr = argStr .. " arg:\"" .. arg.stringVal .. "\""
                            end
                        end
                    end
                    self:Print("  " .. j .. " L:\"" .. left .. "\" R:\"" .. right .. "\"" .. argStr)
                end
            else
                self:Print("  (no lines)")
            end
        else
            self:Print("  GetMerchantItem returned nil")
        end
    end

    -- Scanning tooltip with SetMerchantItem
    self.scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    self.scanTip:ClearLines()
    self.scanTip:SetMerchantItem(merchantIndex)
    self:Print("--- ScanTip SetMerchantItem (" .. self.scanTip:NumLines() .. " lines) ---")
    for i = 1, self.scanTip:NumLines() do
        local leftLine = _G["HideKnownVendorItemsScanTipTextLeft" .. i]
        local rightLine = _G["HideKnownVendorItemsScanTipTextRight" .. i]
        local left = leftLine and leftLine:GetText() or "(nil)"
        local right = rightLine and rightLine:GetText() or "(nil)"
        self:Print("  " .. i .. " L:\"" .. left .. "\" R:\"" .. right .. "\"")
    end

    -- Scanning tooltip with SetHyperlink
    if link then
        self.scanTip:SetOwner(UIParent, "ANCHOR_NONE")
        self.scanTip:ClearLines()
        self.scanTip:SetHyperlink(link)
        self:Print("--- ScanTip SetHyperlink (" .. self.scanTip:NumLines() .. " lines) ---")
        for i = 1, self.scanTip:NumLines() do
            local leftLine = _G["HideKnownVendorItemsScanTipTextLeft" .. i]
            local rightLine = _G["HideKnownVendorItemsScanTipTextRight" .. i]
            local left = leftLine and leftLine:GetText() or "(nil)"
            local right = rightLine and rightLine:GetText() or "(nil)"
            self:Print("  " .. i .. " L:\"" .. left .. "\" R:\"" .. right .. "\"")
        end
    end

    self:Print("ITEM_SPELL_KNOWN = \"" .. tostring(ITEM_SPELL_KNOWN) .. "\"")
    self:Print("=== End debug ===")
end

function HideKnownVendorItems:Toggle()
    self.db.profile.enabled = not self.db.profile.enabled
    if self.db.profile.enabled then
        self:Print("Filter |cFF00FF00ENABLED|r")
    else
        self:Print("Filter |cFFFF0000DISABLED|r")
    end
    self:RefreshMerchantFrame()
    return self.db.profile.enabled
end

function HideKnownVendorItems:SetEnabled(enabled)
    self.db.profile.enabled = enabled
    if enabled then
        self:Print("Filter |cFF00FF00ENABLED|r")
    else
        self:Print("Filter |cFFFF0000DISABLED|r")
    end
    self:RefreshMerchantFrame()
end

function HideKnownVendorItems:RefreshMerchantFrame()
    if MerchantFrame and MerchantFrame:IsShown() then
        MerchantFrame_Update()
    end
end

function HideKnownVendorItems:SlashCommand(input)
    local cmd = input:lower():trim()

    if cmd == "toggle" then
        self:Toggle()
    elseif cmd == "enable" or cmd == "on" then
        self:SetEnabled(true)
    elseif cmd == "disable" or cmd == "off" then
        self:SetEnabled(false)
    elseif cmd == "config" or cmd == "options" then
        Settings.OpenToCategory("HideKnownVendorItems")
    elseif cmd == "debug" then
        if MerchantFrame and MerchantFrame:IsShown() then
            self:DebugMerchantItem(1)
        else
            self:Print("Open a vendor first, then run /hkvi debug")
        end
    elseif cmd == "help" or cmd == "" then
        self:PrintHelp()
    else
        self:PrintHelp()
    end
end

function HideKnownVendorItems:PrintHelp()
    self:Print("HideKnownVendorItems Commands:")
    self:Print("  /hkvi toggle - Toggle filter on/off")
    self:Print("  /hkvi enable|on - Enable filter")
    self:Print("  /hkvi disable|off - Disable filter")
    self:Print("  /hkvi config - Open configuration panel")
    self:Print("  /hkvi debug - Debug first merchant item (with vendor open)")
    self:Print("Macro: /run HideKnownVendorItems:Toggle()")
end
