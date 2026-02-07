local addonName, addon = ...

-- Create the addon using AceAddon with mixins
local GrimoireFilter = LibStub("AceAddon-3.0"):NewAddon(addon, addonName,
    "AceEvent-3.0", "AceConsole-3.0")

-- Expose globally for macro support: /run GrimoireFilter:Toggle()
_G["GrimoireFilter"] = GrimoireFilter

-- Addon version
GrimoireFilter.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "1.0.0"

-- Default database values
local defaults = {
    profile = {
        enabled = true,
    },
}

function GrimoireFilter:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("GrimoireFilterDB", defaults, true)

    self:RegisterChatCommand("gf", "SlashCommand")
    self:RegisterChatCommand("grimoirefilter", "SlashCommand")

    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, self:GetOptionsTable())
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "GrimoireFilter")

    -- Create hidden scanning tooltip
    self.scanTip = CreateFrame("GameTooltip", "GrimoireFilterScanTip", nil, "GameTooltipTemplate")
    self.scanTip:SetOwner(UIParent, "ANCHOR_NONE")

    self:Print("GrimoireFilter v" .. self.version .. " loaded. Type /gf help for commands.")
end

function GrimoireFilter:OnEnable()
    hooksecurefunc("MerchantFrame_Update", function()
        self:FilterMerchantItems()
    end)
end

function GrimoireFilter:IsItemKnown(merchantIndex)
    self.scanTip:ClearLines()
    self.scanTip:SetMerchantItem(merchantIndex)

    for i = 1, self.scanTip:NumLines() do
        local line = _G["GrimoireFilterScanTipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text == ITEM_SPELL_KNOWN then
                return true
            end
        end
    end

    return false
end

function GrimoireFilter:FilterMerchantItems()
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

function GrimoireFilter:Toggle()
    self.db.profile.enabled = not self.db.profile.enabled
    if self.db.profile.enabled then
        self:Print("Filter |cFF00FF00ENABLED|r")
    else
        self:Print("Filter |cFFFF0000DISABLED|r")
    end
    self:RefreshMerchantFrame()
    return self.db.profile.enabled
end

function GrimoireFilter:SetEnabled(enabled)
    self.db.profile.enabled = enabled
    if enabled then
        self:Print("Filter |cFF00FF00ENABLED|r")
    else
        self:Print("Filter |cFFFF0000DISABLED|r")
    end
    self:RefreshMerchantFrame()
end

function GrimoireFilter:RefreshMerchantFrame()
    if MerchantFrame and MerchantFrame:IsShown() then
        MerchantFrame_Update()
    end
end

function GrimoireFilter:SlashCommand(input)
    local cmd = input:lower():trim()

    if cmd == "toggle" then
        self:Toggle()
    elseif cmd == "enable" or cmd == "on" then
        self:SetEnabled(true)
    elseif cmd == "disable" or cmd == "off" then
        self:SetEnabled(false)
    elseif cmd == "config" or cmd == "options" then
        Settings.OpenToCategory("GrimoireFilter")
    elseif cmd == "help" or cmd == "" then
        self:PrintHelp()
    else
        self:PrintHelp()
    end
end

function GrimoireFilter:PrintHelp()
    self:Print("GrimoireFilter Commands:")
    self:Print("  /gf toggle - Toggle filter on/off")
    self:Print("  /gf enable|on - Enable filter")
    self:Print("  /gf disable|off - Disable filter")
    self:Print("  /gf config - Open configuration panel")
    self:Print("Macro: /run GrimoireFilter:Toggle()")
end
