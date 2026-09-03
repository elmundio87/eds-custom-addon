local addon = EdsCustomAddon

local PANEL_WIDTH = 380
local HEADER = 44
local ROW = 36
local PAD = 16

local function ApplyTooltip(frame, text)
    if not text or text == "" then
        frame:SetScript("OnEnter", nil)
        frame:SetScript("OnLeave", nil)
        return
    end
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 0.82, 0, 1, 1)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function addon:SaveUIPosition()
    if not self.ui or not self.db or not self.db.ui then
        return
    end
    local point, _, relativePoint, x, y = self.ui:GetPoint()
    self.db.ui.point = point or "CENTER"
    self.db.ui.relativePoint = relativePoint or "CENTER"
    self.db.ui.x = x or 0
    self.db.ui.y = y or 0
end

function addon:RefreshUI()
    local panel = self.ui
    if not panel or not panel.checks then
        return
    end
    for _, check in ipairs(panel.checks) do
        check:SetChecked(check.module.enabled and 1 or nil)
    end
    if panel.debugCheck then
        panel.debugCheck:SetChecked(self.db.debug and 1 or nil)
    end
    if panel.windfuryPath and self.db.modules.Windfury then
        panel.windfuryPath:SetText(self.db.modules.Windfury.soundFile or "")
    end
    if panel.partyxpPause and self.db.modules.PartyXP then
        panel.partyxpPause:SetChecked(self.db.modules.PartyXP.paused and 1 or nil)
    end
    if panel.partyxpForce then
        local party = self:GetModule("PartyXP")
        panel.partyxpForce:SetChecked(party and party.forceXP and 1 or nil)
    end
    if panel.windfuryAlertMove and self.db.modules.Windfury then
        panel.windfuryAlertMove:SetChecked(self.db.modules.Windfury.alertMove and 1 or nil)
    end
    if panel.windfuryAlertFontSize and self.db.modules.Windfury then
        local wf = self:GetModule("Windfury")
        local size = wf and wf:GetAlertFontSize() or 12
        panel.windfuryAlertFontSize:SetText(tostring(size))
    end
    if panel.windfuryProcPoolButtons then
        local wf = self:GetModule("Windfury")
        if wf then
            wf:UpdatePreviewProcPoolHighlight(panel)
        end
    end
end

function addon:ToggleUI()
    if not self.ui then
        return
    end
    if self.ui:IsShown() then
        self.ui:Hide()
    else
        self.ui:Show()
    end
end

function addon:CreateUI()
    if self.ui then
        return
    end

    local rows = #self.moduleOrder + 1
    local panel = CreateFrame("Frame", "ECA_Panel", UIParent)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetHeight(HEADER + rows * ROW + PAD + 50)
    panel:SetFrameStrata("DIALOG")
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        addon:SaveUIPosition()
    end)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0, 0, 0, 0.9)

    local ui = self.db.ui or {}
    panel:ClearAllPoints()
    panel:SetPoint(
        ui.point or "CENTER",
        UIParent,
        ui.relativePoint or "CENTER",
        ui.x or 0,
        ui.y or 0
    )
    panel:Hide()

    tinsert(UISpecialFrames, "ECA_Panel")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -14)
    title:SetText("Eds Custom Addon")

    panel.checks = {}
    local y = -HEADER
    for i, module in ipairs(self.moduleOrder) do
        local check = CreateFrame("CheckButton", "ECA_Check_" .. module.name, panel, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y)
        check.module = module

        local label = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("LEFT", check, "RIGHT", 2, 0)
        label:SetText(module.title or module.name)
        ApplyTooltip(check, module.tooltip)

        check:SetScript("OnClick", function(self)
            if self:GetChecked() then
                addon:EnableModule(self.module)
            else
                addon:DisableModule(self.module)
            end
        end)

        panel.checks[i] = check
        y = y - ROW
    end

    local debugCheck = CreateFrame("CheckButton", "ECA_Check_Debug", panel, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y)
    local debugLabel = debugCheck:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    debugLabel:SetPoint("LEFT", debugCheck, "RIGHT", 2, 0)
    debugLabel:SetText("Debug")
    ApplyTooltip(debugCheck, "Print extra addon messages in chat.")
    debugCheck:SetScript("OnClick", function(self)
        addon.db.debug = self:GetChecked() and true or false
    end)
    panel.debugCheck = debugCheck
    y = y - ROW

    for _, module in ipairs(self.moduleOrder) do
        if module.BuildOptions then
            y = module:BuildOptions(panel, y)
        end
    end
    panel:SetHeight(-y + PAD)

    panel:SetScript("OnShow", function()
        addon:RefreshUI()
    end)

    self.ui = panel
end
