local addon = EdsCustomAddon

local Fishing = {
    name = "Fishing",
    title = "Fishing button",
    tooltip = "Spawn a click-to-cast FISH button at the cursor while a fishing pole is equipped",
}

local FISHING_SPELL_ID = 7620
local BUTTON_WIDTH = 56
local BUTTON_HEIGHT = 22
local FADE_SECONDS = 1.5

local function FishingSpellName()
    local name = GetSpellInfo and GetSpellInfo(FISHING_SPELL_ID)
    if type(name) == "string" and name ~= "" then
        return name
    end
    return "Fishing"
end

function Fishing:CreateButton()
    if self.button then
        return
    end

    local button = CreateFrame("Button", "ECA_FishButton", UIParent, "SecureActionButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetFrameStrata("HIGH")
    button:SetClampedToScreen(true)
    button:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    button:SetBackdropColor(0, 0, 0, 0.8)
    button:SetBackdropBorderColor(0.3, 0.7, 1, 1)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("type", "spell")
    button:SetAttribute("spell", FishingSpellName())

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    label:SetText("FISH")
    button.label = label

    button:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to cast " .. FishingSpellName(), 1, 0.82, 0, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    -- PostClick/OnMouseUp leave the template's secure OnClick handler intact.
    button:SetScript("PostClick", function()
        Fishing:StartFade("click")
    end)
    button:SetScript("OnMouseUp", function()
        Fishing:StartFade("mouseup")
    end)
    button:Hide()

    self.button = button
end

function Fishing:StopFade()
    if not self.button then
        return
    end
    self.button:SetScript("OnUpdate", nil)
    self.button:SetAlpha(1)
    self.fadeStart = nil
end

function Fishing:HideButton()
    if not self.button then
        return
    end
    self.button:SetScript("OnUpdate", nil)
    self.fadeStart = nil
    if InCombatLockdown() then
        self.button:SetAlpha(0)
        return
    end
    self.button:Hide()
    self.button:SetAlpha(1)
end

function Fishing:StartFade(reason)
    if not self.button or not self.button:IsShown() or self.fadeStart then
        return
    end
    self.fadeStart = GetTime()
    self.button:SetScript("OnUpdate", function(button)
        local left = FADE_SECONDS - (GetTime() - (Fishing.fadeStart or 0))
        if left <= 0 then
            Fishing:HideButton()
            return
        end
        button:SetAlpha(left / FADE_SECONDS)
    end)
    addon:Debug("Fishing: button fading out (" .. tostring(reason) .. ")")
end

function Fishing:MoveToCursor()
    if not self.button or not GetCursorPosition then
        return
    end
    local scale = UIParent:GetEffectiveScale() or 1
    if scale == 0 then
        scale = 1
    end
    local x, y = GetCursorPosition()
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (x or 0) / scale, (y or 0) / scale)
end

-- Secure buttons cannot be shown, hidden or moved while in combat.
function Fishing:Update(recenter, force)
    if InCombatLockdown() then
        return
    end
    self:CreateButton()
    if not self.enabled or not addon:IsFishingPoleEquipped() then
        self:HideButton()
        return
    end
    -- Let a fade finish; bag updates while fishing must not resurrect it.
    if self.fadeStart and not force then
        return
    end
    self.button:SetAttribute("type", "spell")
    self.button:SetAttribute("spell", FishingSpellName())
    if recenter or not self.button:IsShown() then
        self:MoveToCursor()
    end
    self:StopFade()
    self.button:Show()
    addon:Debug("Fishing: button at cursor")
end

function Fishing:Init(owner)
    self.addon = owner
    owner:RegisterEvent("UNIT_INVENTORY_CHANGED")
    owner:RegisterEvent("PLAYER_ENTERING_WORLD")
    owner:RegisterEvent("PLAYER_REGEN_ENABLED")
    owner:RegisterEvent("UNIT_SPELLCAST_SENT")
    owner:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    owner:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
end

function Fishing:Enable()
    self.enabled = true
    self:Update(true, true)
end

function Fishing:Disable()
    self.enabled = false
    self:HideButton()
end

function Fishing:OnEvent(event, ...)
    if event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then
            self:Update(true)
        end
        return
    end
    -- Casting Fishing by any means retires the button until the next update.
    if event == "UNIT_SPELLCAST_SENT"
        or event == "UNIT_SPELLCAST_SUCCEEDED"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
    then
        local unit, spell = ...
        if unit == "player" and spell == FishingSpellName() then
            self:StartFade(event)
        end
        return
    end
    self:Update(false)
end

function Fishing:Slash(rest)
    local arg = string.lower(addon:Trim(rest or ""))
    if arg == "on" then
        addon:EnableModule(self)
        addon:Print("Fishing button on")
        return
    end
    if arg == "off" then
        addon:DisableModule(self)
        addon:Print("Fishing button off")
        return
    end
    if arg == "here" then
        self:Update(true, true)
        return
    end
    addon:Print(string.format(
        "Fishing button %s | pole=%s",
        self.enabled and "on" or "off",
        addon:IsFishingPoleEquipped() and "yes" or "no"
    ))
    if arg ~= "" and arg ~= "status" then
        addon:Print("/eca fishing [on|off|here|status]")
    end
end

addon:RegisterModule(Fishing)
