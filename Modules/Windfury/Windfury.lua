local addon = EdsCustomAddon

-- 3.3.5 Windfury Weapon ranks + Windfury Attack (extra hits).
local WINDFURY_IDS = {
    [8232] = true,
    [8235] = true,
    [10486] = true,
    [16362] = true,
    [25504] = true,
    [25505] = true,
    [33750] = true,
    [58790] = true,
    [58796] = true,
    [58801] = true,
    [58804] = true,
}

local PROC_GAP = 0.15

local Windfury = {
    name = "Windfury",
    title = "Windfury sound",
    tooltip = "Play a sound when your Windfury Weapon procs",
}

local function IsWindfury(spellId, spellName)
    if spellId and WINDFURY_IDS[spellId] then
        return true
    end
    if type(spellName) == "string" and spellName:find("Windfury") then
        return true
    end
    return false
end

function Windfury:Play()
    local path = self.addon.db.modules.Windfury.soundFile
    if path and path ~= "" then
        PlaySoundFile(path)
    else
        PlaySound("RaidWarning")
    end
end

function Windfury:OnProc()
    if not self.enabled then
        return
    end
    local now = GetTime()
    if self.lastPlay and (now - self.lastPlay) < PROC_GAP then
        return
    end
    self.lastPlay = now
    self:Play()
end

function Windfury:SavePath(text)
    text = addon:Trim(text or "")
    if not addon.db.modules.Windfury then
        addon.db.modules.Windfury = {}
    end
    addon.db.modules.Windfury.soundFile = text
end

function Windfury:BuildOptions(panel, y)
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
    label:SetText("Windfury sound file")
    y = y - 18

    local box = CreateFrame("EditBox", "ECA_WindfuryPath", panel, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetWidth(260)
    box:SetHeight(20)
    box:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
    box:SetText(addon.db.modules.Windfury.soundFile or "")
    box:SetScript("OnEnterPressed", function(self)
        Windfury:SavePath(self:GetText())
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(addon.db.modules.Windfury.soundFile or "")
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        Windfury:SavePath(self:GetText())
    end)
    panel.windfuryPath = box

    local test = CreateFrame("Button", "ECA_WindfuryTest", panel, "UIPanelButtonTemplate")
    test:SetWidth(52)
    test:SetHeight(22)
    test:SetPoint("LEFT", box, "RIGHT", 6, 0)
    test:SetText("Test")
    test:SetScript("OnClick", function()
        Windfury:SavePath(box:GetText())
        Windfury:Play()
    end)

    return y - 28
end

function Windfury:Init(owner)
    self.addon = owner
    owner:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function Windfury:Enable()
    self.enabled = true
end

function Windfury:Disable()
    self.enabled = false
end

function Windfury:OnEvent(event, ...)
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
        return
    end
    -- 3.3.5 has no CombatLogGetCurrentEventInfo.
    local _, subevent, sourceGUID, _, _, _, _, _, spellId, spellName = ...
    if sourceGUID ~= UnitGUID("player") then
        return
    end
    if subevent ~= "SPELL_EXTRA_ATTACKS" and subevent ~= "SPELL_DAMAGE" then
        return
    end
    if IsWindfury(spellId, spellName) then
        self:OnProc()
    end
end

function Windfury:Slash(rest)
    local arg, extra = addon:Trim(rest):match("^(%S*)%s*(.*)$")
    arg = string.lower(arg or "")
    extra = addon:Trim(extra)

    if arg == "on" then
        addon:EnableModule(self)
        addon:Print("Windfury sound on")
        return
    end
    if arg == "off" then
        addon:DisableModule(self)
        addon:Print("Windfury sound off")
        return
    end
    if arg == "test" then
        self:Play()
        addon:Print("Windfury sound test")
        return
    end
    if arg == "sound" then
        if extra == "" then
            addon:Print("usage: /eca windfury sound <path>")
            return
        end
        addon.db.modules.Windfury.soundFile = extra
        addon:Print("Windfury sound file: " .. extra)
        if addon.RefreshUI then
            addon:RefreshUI()
        end
        return
    end

    local path = addon.db.modules.Windfury.soundFile
    addon:Print(string.format(
        "Windfury sound %s | file=%s",
        self.enabled and "on" or "off",
        (path and path ~= "") and path or "RaidWarning"
    ))
end

addon:RegisterModule(Windfury)
