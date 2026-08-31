EdsCustomAddon = EdsCustomAddon or {}

local addon = EdsCustomAddon
addon.ADDON_NAME = "Eds Custom Addon"
addon.CHAT_PREFIX = "|cff33ff99ECA:|r "

function addon:Trim(value)
    if not value then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function addon:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(self.CHAT_PREFIX .. tostring(msg))
end

function addon:Debug(msg)
    if self.db and self.db.debug then
        self:Print("debug: " .. tostring(msg))
    end
end

-- 3.3.5 has no C_Timer. Debounce via a hidden OnUpdate frame.
local debounceFrame = CreateFrame("Frame")
local pending = {}

debounceFrame:Hide()
debounceFrame:SetScript("OnUpdate", function(self)
    local now = GetTime()
    local remaining = false
    for key, item in pairs(pending) do
        if now >= item.fireAt then
            pending[key] = nil
            item.fn()
        else
            remaining = true
        end
    end
    if not remaining then
        self:Hide()
    end
end)

function addon:Debounce(key, delay, fn)
    pending[key] = {
        fireAt = GetTime() + (delay or 0.2),
        fn = fn,
    }
    debounceFrame:Show()
end
