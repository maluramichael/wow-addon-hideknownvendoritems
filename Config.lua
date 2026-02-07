local addonName, addon = ...
local HideKnownVendorItems = addon

function HideKnownVendorItems:GetOptionsTable()
    return {
        name = "HideKnownVendorItems",
        handler = HideKnownVendorItems,
        type = "group",
        args = {
            headerDesc = {
                type = "description",
                name = "HideKnownVendorItems v" .. self.version .. " - Hide known items from vendors\n\nMacro: /run HideKnownVendorItems:Toggle()",
                fontSize = "medium",
                order = 1,
            },
            enabled = {
                type = "toggle",
                name = "Hide Known Items at Vendors",
                desc = "Hide already-known grimoires, recipes, patterns, and other items from vendor windows",
                order = 10,
                get = function() return self.db.profile.enabled end,
                set = function(_, val)
                    self.db.profile.enabled = val
                    self:RefreshMerchantFrame()
                end,
                width = "full",
            },
        },
    }
end
