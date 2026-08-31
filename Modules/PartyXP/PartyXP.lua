local addon = EdsCustomAddon

local PartyXP = {
    name = "PartyXP",
    title = "Party XP",
    tooltip = "Enable XP only in a party or raid with an online member",
}

local SYNC_DELAY = 0.2

local function ShouldEnableXP()
    local count = GetNumRaidMembers()
    local prefix = "raid"
    if count == 0 then
        count = GetNumPartyMembers()
        prefix = "party"
    end
    if count == 0 then
        return false
    end

    -- Raid tokens include the player; party tokens do not.
    for i = 1, count do
        local unit = prefix .. i
        if not UnitIsUnit(unit, "player") and UnitIsConnected(unit) then
            return true
        end
    end
    return false
end

local function IsXPLocked()
    return IsXPUserDisabled() and true or false
end

function PartyXP:DescribeState()
    local wantEnabled = ShouldEnableXP()
    local locked = IsXPLocked()
    local group
    if GetNumRaidMembers() > 0 then
        group = "raid (" .. GetNumRaidMembers() .. ")"
    elseif GetNumPartyMembers() > 0 then
        group = "party (" .. GetNumPartyMembers() .. ")"
    else
        group = "solo"
    end
    return wantEnabled, locked, group
end

function PartyXP:SyncXP()
    if not self.enabled then
        return
    end

    local wantEnabled = ShouldEnableXP()
    local locked = IsXPLocked()

    if wantEnabled and locked then
        addon:Debug("PartyXP: enabling XP")
        SendChatMessage(".xp on", "SAY")
    elseif not wantEnabled and not locked then
        addon:Debug("PartyXP: disabling XP")
        SendChatMessage(".xp off", "SAY")
    else
        addon:Debug("PartyXP: no change (want=" .. tostring(wantEnabled) .. " locked=" .. tostring(locked) .. ")")
    end
end

function PartyXP:RequestSync()
    if not self.enabled then
        return
    end
    addon:Debounce("PartyXP.Sync", SYNC_DELAY, function()
        PartyXP:SyncXP()
    end)
end

function PartyXP:Init(owner)
    self.addon = owner
    owner:RegisterEvent("PARTY_MEMBERS_CHANGED")
    owner:RegisterEvent("RAID_ROSTER_UPDATE")
    owner:RegisterEvent("PARTY_MEMBER_DISABLE")
    owner:RegisterEvent("PARTY_MEMBER_ENABLE")
    owner:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function PartyXP:Enable()
    self.enabled = true
    self:RequestSync()
end

function PartyXP:Disable()
    self.enabled = false
end

function PartyXP:OnEvent(event)
    if event == "PARTY_MEMBERS_CHANGED"
        or event == "RAID_ROSTER_UPDATE"
        or event == "PARTY_MEMBER_DISABLE"
        or event == "PARTY_MEMBER_ENABLE"
        or event == "PLAYER_ENTERING_WORLD"
    then
        self:RequestSync()
    end
end

function PartyXP:Slash(rest)
    local arg = string.lower(addon:Trim(rest))
    if arg == "on" then
        addon:EnableModule(self)
        addon:Print("PartyXP on")
        return
    end
    if arg == "off" then
        addon:DisableModule(self)
        addon:Print("PartyXP off")
        return
    end

    local wantEnabled, locked, group = self:DescribeState()
    addon:Print(string.format(
        "PartyXP %s | group=%s | wantXP=%s | serverXP=%s",
        self.enabled and "on" or "off",
        group,
        wantEnabled and "on" or "off",
        locked and "off" or "on"
    ))
end

addon:RegisterModule(PartyXP)
