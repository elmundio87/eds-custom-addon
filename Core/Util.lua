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
    local ready = {}
    for key, item in pairs(pending) do
        if now >= item.fireAt then
            table.insert(ready, key)
        end
    end
    for _, key in ipairs(ready) do
        local item = pending[key]
        if item and now >= item.fireAt then
            pending[key] = nil
            item.fn()
        end
    end
    if next(pending) == nil then
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

-- AzerothCore intercepts '.' on any chat type. SAY is blocked as a ghost.
function addon:SendServerCommand(command)
    local name = UnitName("player")
    if name and name ~= "" then
        SendChatMessage(command, "WHISPER", nil, name)
        return
    end
    if GetNumRaidMembers() > 0 then
        SendChatMessage(command, "RAID")
    elseif GetNumPartyMembers() > 0 then
        SendChatMessage(command, "PARTY")
    elseif not UnitIsDeadOrGhost("player") then
        SendChatMessage(command, "SAY")
    end
end
