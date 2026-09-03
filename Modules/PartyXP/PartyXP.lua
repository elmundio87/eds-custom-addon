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
    if self.forceXP then
        wantEnabled = true
    end
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

    local entry = addon.db.modules.PartyXP
    if entry and entry.paused then
        if not IsXPLocked() then
            addon:Debug("PartyXP: paused -> disabling XP")
            addon:SendServerCommand(addon.db.xp.disable)
        else
            addon:Debug("PartyXP: paused (XP already off)")
        end
        return
    end

    if self.forceXP then
        if IsXPLocked() then
            addon:Debug("PartyXP: force -> enabling XP")
            addon:SendServerCommand(addon.db.xp.enable)
        else
            addon:Debug("PartyXP: force (XP already on)")
        end
        return
    end

    local wantEnabled = ShouldEnableXP()
    local locked = IsXPLocked()

    if wantEnabled and locked then
        addon:Debug("PartyXP: enabling XP")
        addon:SendServerCommand(addon.db.xp.enable)
    elseif not wantEnabled and not locked then
        addon:Debug("PartyXP: disabling XP")
        addon:SendServerCommand(addon.db.xp.disable)
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

function PartyXP:SetPaused(paused)
    if not addon.db.modules.PartyXP then
        addon.db.modules.PartyXP = {}
    end
    addon.db.modules.PartyXP.paused = paused and true or false
    if addon.db.modules.PartyXP.paused then
        self.forceXP = false
        if addon.ui and addon.ui.partyxpForce then
            addon.ui.partyxpForce:SetChecked(nil)
        end
    end
    if self.enabled then
        self:SyncXP()
    end
end

function PartyXP:SetForceXP(force)
    self.forceXP = force and true or false
    if self.forceXP then
        if not addon.db.modules.PartyXP then
            addon.db.modules.PartyXP = {}
        end
        addon.db.modules.PartyXP.paused = false
        if addon.ui and addon.ui.partyxpPause then
            addon.ui.partyxpPause:SetChecked(nil)
        end
    end
    if self.enabled then
        self:SyncXP()
    end
end

function PartyXP:BuildOptions(panel, y)
    local check = CreateFrame("CheckButton", "ECA_PartyXP_Pause", panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
    local label = check:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetText("Hold XP off (ignore party)")
    check:SetScript("OnClick", function(self)
        PartyXP:SetPaused(self:GetChecked() and true or false)
    end)
    panel.partyxpPause = check
    y = y - 36

    local force = CreateFrame("CheckButton", "ECA_PartyXP_Force", panel, "UICheckButtonTemplate")
    force:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
    local forceLabel = force:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    forceLabel:SetPoint("LEFT", force, "RIGHT", 2, 0)
    forceLabel:SetText("Force XP on (this session)")
    force:SetScript("OnClick", function(self)
        PartyXP:SetForceXP(self:GetChecked() and true or false)
    end)
    panel.partyxpForce = force
    return y - 36
end

function PartyXP:Init(owner)
    self.addon = owner
    owner:RegisterEvent("PARTY_MEMBERS_CHANGED")
    owner:RegisterEvent("RAID_ROSTER_UPDATE")
    owner:RegisterEvent("PARTY_MEMBER_DISABLE")
    owner:RegisterEvent("PARTY_MEMBER_ENABLE")
    owner:RegisterEvent("PLAYER_ENTERING_WORLD")
    owner:RegisterEvent("PLAYER_ALIVE")
    owner:RegisterEvent("PLAYER_UNGHOST")
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
        or event == "PLAYER_ALIVE"
        or event == "PLAYER_UNGHOST"
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
    if arg == "pause" then
        self:SetPaused(true)
        addon:Print("PartyXP paused")
        return
    end
    if arg == "unpause" then
        self:SetPaused(false)
        local wantEnabled, locked, group = self:DescribeState()
        addon:Print(string.format(
            "PartyXP unpaused | group=%s | wantXP=%s | serverXP=%s",
            group,
            wantEnabled and "on" or "off",
            locked and "off" or "on"
        ))
        return
    end
    if arg == "force" then
        self:SetForceXP(true)
        addon:Print("PartyXP forcing XP on (this session)")
        return
    end
    if arg == "unforce" then
        self:SetForceXP(false)
        local wantEnabled, locked, group = self:DescribeState()
        addon:Print(string.format(
            "PartyXP force released | group=%s | wantXP=%s | serverXP=%s",
            group,
            wantEnabled and "on" or "off",
            locked and "off" or "on"
        ))
        return
    end

    local wantEnabled, locked, group = self:DescribeState()
    local entry = addon.db.modules.PartyXP
    local paused = entry and entry.paused and true or false
    addon:Print(string.format(
        "PartyXP %s | paused=%s | force=%s | group=%s | wantXP=%s | serverXP=%s",
        self.enabled and "on" or "off",
        paused and "yes" or "no",
        self.forceXP and "yes" or "no",
        group,
        wantEnabled and "on" or "off",
        locked and "off" or "on"
    ))
end

addon:RegisterModule(PartyXP)
