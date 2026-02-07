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
    self.scanTip:ClearLines()
    self.scanTip:SetMerchantItem(merchantIndex)

    for i = 1, self.scanTip:NumLines() do
        local line = _G["HideKnownVendorItemsScanTipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text == ITEM_SPELL_KNOWN then
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
            if self:IsItemKnown(merchantIndex) then
                button:Hide()
            end
        end
    end
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
    self:Print("Macro: /run HideKnownVendorItems:Toggle()")
end
