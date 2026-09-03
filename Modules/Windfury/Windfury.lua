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
local LOW_HP_THRESHOLD = 0.20
local STREAK_WINDOW = 5
local TEXT_Y_OFFSET = 280
local RECENT_SOUND_CAP = 10
local DEFAULT_SOUND_DURATION = 0.5
local PROC_CATEGORY_PRIORITY = {
    default = 1,
    lowhp = 2,
    kill = 3,
}
local INVSLOT_MAINHAND = 16
local INVSLOT_OFFHAND = 17
local ALERT_TEXT = "RECAST WINDFURY"
local EXPIRY_WARN_SECONDS = 60
local EXPIRY_SCROLL_DISTANCE = 80
local ENCHANT_LOAD_GRACE = 3
local OTHER_IMBUE_PATTERNS = {
    "Flametongue",
    "Rockbiter",
    "Frostbrand",
    "Earthliving",
    "Earthen",
}

local PROC_POOLS = { "default", "lowhp", "kill" }
local PROC_POOL_LABELS = {
    default = "Default",
    lowhp = "Low HP",
    kill = "Kill",
}

local scanTooltip

local function GetScanTooltip()
    if scanTooltip then
        return scanTooltip
    end
    scanTooltip = CreateFrame("GameTooltip", "ECA_WindfuryScanTooltip", UIParent, "GameTooltipTemplate")
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    return scanTooltip
end

local Windfury = {
    name = "Windfury",
    title = "Windfury proc",
    tooltip = "Play a random sound from Sounds/ on proc; shows RECAST WINDFURY when Windfury Weapon is missing",
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

local function GetSlotItemInfo(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then
        return nil
    end
    local _, _, _, _, _, itemType, subType, _, equipLoc = GetItemInfo(link)
    if not itemType then
        return nil
    end
    return {
        link = link,
        itemType = itemType,
        subType = subType,
        equipLoc = equipLoc,
    }
end

function Windfury:IsFishingPoleEquipped()
    local info = GetSlotItemInfo(INVSLOT_MAINHAND)
    if not info then
        return false
    end
    return info.subType == "Fishing Pole"
end

function Windfury:IsWeaponSlot(slot)
    local info = GetSlotItemInfo(slot)
    return info and info.itemType == "Weapon"
end

function Windfury:IsTwoHandWeapon(slot)
    local info = GetSlotItemInfo(slot)
    return info and info.equipLoc == "INVTYPE_2HWEAPON"
end

function Windfury:IsInEnchantGracePeriod()
    return self.lastZoneLoad and (GetTime() - self.lastZoneLoad) < ENCHANT_LOAD_GRACE
end

local function ClassifyTooltipImbue(text)
    if not text or text == "" then
        return nil
    end
    if text:find("Windfury") then
        return "windfury"
    end
    for i = 1, #OTHER_IMBUE_PATTERNS do
        if text:find(OTHER_IMBUE_PATTERNS[i]) then
            return "other"
        end
    end
    return nil
end

function Windfury:ScanSlotTooltipImbue(slot)
    local tip = GetScanTooltip()
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetInventoryItem("player", slot)

    local lineCount = tip:NumLines()
    if lineCount == 0 then
        tip:Hide()
        return "empty", false
    end

    for i = 1, lineCount do
        local left = _G["ECA_WindfuryScanTooltipTextLeft" .. i]
        if left then
            local state = ClassifyTooltipImbue(left:GetText())
            if state == "windfury" then
                tip:Hide()
                return "windfury", true
            end
            if state == "other" then
                tip:Hide()
                return "other", true
            end
        end
    end

    tip:Hide()
    if lineCount == 1 then
        return "unknown", true
    end
    return "none", true
end

function Windfury:SlotHasWindfury(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then
        return nil
    end

    local _, _, _, _, _, itemType = GetItemInfo(link)
    if not itemType then
        return nil
    end

    local imbue = self:ScanSlotTooltipImbue(slot)
    if imbue == "windfury" then
        return true
    end
    if imbue == "other" then
        return false
    end

    local hasEnchant = false
    if slot == INVSLOT_MAINHAND or slot == INVSLOT_OFFHAND then
        local hasMain, _, _, hasOff = GetWeaponEnchantInfo()
        if slot == INVSLOT_MAINHAND then
            hasEnchant = hasMain and true or false
        else
            hasEnchant = hasOff and true or false
        end
    end

    if hasEnchant then
        return nil
    end

    if imbue == "empty" or imbue == "unknown" or self:IsInEnchantGracePeriod() then
        return nil
    end

    return false
end

function Windfury:GetSlotEnchantRemaining(slot)
    local state = self:SlotHasWindfury(slot)
    if state ~= true then
        return nil
    end
    local hasMain, mainExp, _, hasOff, offExp = GetWeaponEnchantInfo()
    if slot == INVSLOT_MAINHAND then
        if not hasMain or not mainExp then
            return nil
        end
        return mainExp / 1000
    end
    if slot == INVSLOT_OFFHAND then
        if not hasOff or not offExp then
            return nil
        end
        return offExp / 1000
    end
    return nil
end

function Windfury:GetWindfuryWeaponSlots()
    local slots = {}
    if self:IsFishingPoleEquipped() or not self:IsWeaponSlot(INVSLOT_MAINHAND) then
        return slots
    end
    if self:IsTwoHandWeapon(INVSLOT_MAINHAND) then
        slots[#slots + 1] = { slot = INVSLOT_MAINHAND, label = "main hand" }
        return slots
    end
    slots[#slots + 1] = { slot = INVSLOT_MAINHAND, label = "main hand" }
    if self:IsWeaponSlot(INVSLOT_OFFHAND) then
        slots[#slots + 1] = { slot = INVSLOT_OFFHAND, label = "off hand" }
    end
    return slots
end

function Windfury:GetWindfuryAlertState()
    if select(2, UnitClass("player")) ~= "SHAMAN" then
        return nil
    end
    if self:IsFishingPoleEquipped() then
        return nil
    end
    if not self:IsWeaponSlot(INVSLOT_MAINHAND) then
        return nil
    end

    local missingMain = false
    local missingOff = false

    if self:IsTwoHandWeapon(INVSLOT_MAINHAND) then
        local mainState = self:SlotHasWindfury(INVSLOT_MAINHAND)
        if mainState == nil then
            return nil
        elseif mainState == false then
            missingMain = true
        end
    else
        local mainState = self:SlotHasWindfury(INVSLOT_MAINHAND)
        if mainState == nil then
            return nil
        elseif mainState == false then
            missingMain = true
        end
        if self:IsWeaponSlot(INVSLOT_OFFHAND) then
            local offState = self:SlotHasWindfury(INVSLOT_OFFHAND)
            if offState == nil then
                return nil
            elseif offState == false then
                missingOff = true
            end
        end
    end

    if not missingMain and not missingOff then
        return nil
    end

    local detail
    if missingMain and missingOff then
        detail = "Main hand and off hand missing Windfury Weapon"
    elseif missingMain then
        detail = "Main hand missing Windfury Weapon"
    else
        detail = "Off hand missing Windfury Weapon"
    end
    local missingCount = (missingMain and 1 or 0) + (missingOff and 1 or 0)
    return detail, missingCount
end

function Windfury:GetAlertLabelText(missingCount)
    if missingCount and missingCount >= 2 then
        return ALERT_TEXT .. " (x2)"
    end
    return ALERT_TEXT
end

function Windfury:GetAlertUIConfig()
    if not addon.db.modules.Windfury then
        addon.db.modules.Windfury = {}
    end
    local entry = addon.db.modules.Windfury
    if not entry.alert then
        entry.alert = {
            point = "TOPRIGHT",
            relativePoint = "TOPRIGHT",
            x = -36,
            y = -132,
            fontSize = 12,
        }
    elseif entry.alert.fontSize == nil then
        entry.alert.fontSize = 12
    end
    return entry.alert
end

function Windfury:GetAlertFontSize()
    local cfg = self:GetAlertUIConfig()
    local size = tonumber(cfg.fontSize) or 12
    if size < 8 then
        size = 8
    elseif size > 32 then
        size = 32
    end
    return size
end

function Windfury:SaveAlertFontSize(text)
    local size = tonumber(addon:Trim(text or "")) or 12
    if size < 8 then
        size = 8
    elseif size > 32 then
        size = 32
    end
    local cfg = self:GetAlertUIConfig()
    cfg.fontSize = size
    self:ApplyAlertFont()
end

function Windfury:ApplyAlertFont()
    if not self.alertFrame or not self.alertFrame.label then
        return
    end
    local size = self:GetAlertFontSize()
    local label = self.alertFrame.label
    local font, _, flags = label:GetFont()
    label:SetFont(font or "Fonts\\FRIZQT__.TTF", size, flags or "")
    local widthScale = 12
    if self.alertFrame.missingCount and self.alertFrame.missingCount >= 2 then
        widthScale = 14
    end
    local width = size * widthScale
    if width < 140 then
        width = 140
    end
    local height = size + 14
    if height < 26 then
        height = 26
    end
    self.alertFrame:SetSize(width, height)
end

function Windfury:IsAlertMoveEnabled()
    local entry = addon.db.modules.Windfury
    return entry and entry.alertMove and true or false
end

function Windfury:SaveAlertPosition()
    if not self.alertFrame then
        return
    end
    local point, _, relativePoint, x, y = self.alertFrame:GetPoint()
    local cfg = self:GetAlertUIConfig()
    cfg.point = point or "TOPRIGHT"
    cfg.relativePoint = relativePoint or "TOPRIGHT"
    cfg.x = x or 0
    cfg.y = y or 0
end

function Windfury:ApplyAlertPosition()
    if not self.alertFrame then
        return
    end
    local cfg = self:GetAlertUIConfig()
    self.alertFrame:ClearAllPoints()
    self.alertFrame:SetPoint(
        cfg.point or "TOPRIGHT",
        UIParent,
        cfg.relativePoint or "TOPRIGHT",
        cfg.x or -36,
        cfg.y or -132
    )
end

function Windfury:ApplyAlertDragMode()
    if not self.alertFrame then
        return
    end
    local frame = self.alertFrame
    local move = self:IsAlertMoveEnabled()
    if move then
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(f)
            f:StartMoving()
        end)
        frame:SetScript("OnDragStop", function(f)
            f:StopMovingOrSizing()
            Windfury:SaveAlertPosition()
        end)
        frame:SetBackdropBorderColor(1, 0.82, 0, 1)
    else
        frame:SetMovable(false)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        frame:SetBackdropBorderColor(1, 0.2, 0.2, 1)
    end
end

function Windfury:SetAlertMove(enabled)
    if not addon.db.modules.Windfury then
        addon.db.modules.Windfury = {}
    end
    addon.db.modules.Windfury.alertMove = enabled and true or false
    self:ApplyAlertDragMode()
    self:UpdateAlert()
end

function Windfury:CreateAlertFrame()
    if self.alertFrame then
        return
    end

    local     frame = CreateFrame("Frame", "ECA_WindfuryAlert", UIParent)
    frame:SetSize(140, 26)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.1, 0, 0, 0.85)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetTextColor(1, 0.35, 0.35)
    label:SetText(ALERT_TEXT)
    frame.label = label

    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if self.moveHint then
            GameTooltip:SetText(self.moveHint, 1, 0.82, 0, 1, 1)
        elseif self.detail then
            GameTooltip:SetText(self.detail, 1, 0.82, 0, 1, 1)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.alertFrame = frame
    self:ApplyAlertPosition()
    self:ApplyAlertFont()
    self:ApplyAlertDragMode()
    frame:Hide()
end

function Windfury:ScheduleAlertRecheck()
    local function recheck()
        if Windfury.enabled then
            Windfury:UpdateAlert()
            Windfury:CheckEnchantExpiry()
        end
    end
    addon:Debounce("windfury_alert_recheck_short", 0.5, recheck)
    addon:Debounce("windfury_alert_recheck_long", 2.0, recheck)
end

function Windfury:OnWindfuryCast()
    self.expiryWarned = {}
    self.lastRemaining = {}
    addon:Debug("Windfury: cast -> refresh alert")
    self:UpdateAlert()
    self:ScheduleAlertRecheck()
end

function Windfury:UpdateAlert()
    if not self.enabled then
        if self.alertFrame then
            self.alertFrame:Hide()
        end
        return
    end

    local detail, missingCount = self:GetWindfuryAlertState()
    local moveMode = self:IsAlertMoveEnabled()
    if not detail and not moveMode then
        if self.alertFrame then
            self.alertFrame:Hide()
        end
        addon:Debug("Windfury: alert hidden")
        return
    end

    self:CreateAlertFrame()
    self.alertFrame.missingCount = missingCount or 0
    self:ApplyAlertDragMode()
    self:ApplyAlertFont()
    self.alertFrame.detail = detail
    self.alertFrame.moveHint = nil
    self.alertFrame.label:SetText(self:GetAlertLabelText(missingCount))
    if moveMode and not detail then
        self.alertFrame.moveHint = "Drag to reposition " .. ALERT_TEXT .. " badge"
        addon:Debug("Windfury: alert move mode")
    elseif detail then
        addon:Debug("Windfury: alert shown (" .. detail .. ")")
    end
    self.alertFrame:Show()
end

local function WindfuryFixedScroll(value)
    return value.startX, value.startY
end

local function PinWindfuryCombatText(message, targetY)
    if not COMBAT_TEXT_TO_ANIMATE then
        return
    end
    for i = #COMBAT_TEXT_TO_ANIMATE, 1, -1 do
        local line = COMBAT_TEXT_TO_ANIMATE[i]
        if line and line.GetText and line:GetText() == message then
            line.scrollFunction = WindfuryFixedScroll
            if targetY then
                line.startY = targetY
                line.endY = targetY
                line.yPos = targetY
                line:ClearAllPoints()
                line:SetPoint("TOP", WorldFrame, "BOTTOM", line.startX, targetY)
            else
                line.endY = line.startY
            end
            return
        end
    end
end

local function ClearWindfuryCombatText()
    if not COMBAT_TEXT_TO_ANIMATE then
        return
    end
    local cleared = false
    for i = #COMBAT_TEXT_TO_ANIMATE, 1, -1 do
        local line = COMBAT_TEXT_TO_ANIMATE[i]
        local text = line and line.GetText and line:GetText()
        if text and text:find("^WINDFURY") then
            cleared = true
            if CombatText_RemoveMessage then
                CombatText_RemoveMessage(line)
            else
                line:Hide()
                if line.SetAlpha then
                    line:SetAlpha(0)
                end
                table.remove(COMBAT_TEXT_TO_ANIMATE, i)
            end
        end
    end
    if cleared then
        addon:Debug("Windfury: cleared previous combat text")
    end
end

function Windfury:GetSoundPool(category)
    if category == "lowhp" then
        local pool = WindfurySoundsLowHp
        if type(pool) == "table" and #pool > 0 then
            return pool, "recentSoundsLowHp"
        end
    elseif category == "kill" then
        local pool = WindfurySoundsKill
        if type(pool) == "table" and #pool > 0 then
            return pool, "recentSoundsKill"
        end
    end
    return WindfurySounds, "recentSounds"
end

local function GetRecentQueueMax(count)
    if count <= 1 then
        return 0
    end
    return math.min(count - 1, RECENT_SOUND_CAP)
end

function Windfury:PickSoundPath(category)
    category = category or "default"
    local sounds, recentKey = self:GetSoundPool(category)
    if type(sounds) == "table" then
        local count = #sounds
        if count > 0 then
            self[recentKey] = self[recentKey] or {}
            local recent = self[recentKey]

            local blocked = {}
            for i = 1, #recent do
                blocked[recent[i]] = true
            end

            local eligible = {}
            for i = 1, count do
                local path = sounds[i]
                if not blocked[path] then
                    eligible[#eligible + 1] = path
                end
            end

            if #eligible == 0 then
                self[recentKey] = {}
                recent = self[recentKey]
                for i = 1, count do
                    eligible[#eligible + 1] = sounds[i]
                end
            end

            local pick = eligible[math.random(#eligible)]

            local recentMax = GetRecentQueueMax(count)
            if recentMax > 0 then
                if #recent >= recentMax then
                    table.remove(recent, 1)
                end
                recent[#recent + 1] = pick
            end

            addon:Debug(string.format(
                "Windfury: picked %s sound (queue=%d) %s",
                category,
                #recent,
                pick
            ))

            return pick
        end
    end
    if category ~= "default" then
        return self:PickSoundPath("default")
    end
    local path = self.addon.db.modules.Windfury.soundFile
    if path and path ~= "" then
        return path
    end
    return nil
end

function Windfury:GetProcCategory(destGUID, amount, overkill)
    amount = amount or 0
    overkill = overkill or 0

    if overkill > 0 then
        return "kill"
    end
    if destGUID and destGUID == UnitGUID("target") then
        local max = UnitHealthMax("target")
        if max and max > 0 then
            local after = UnitHealth("target") or 0
            if after <= 0 then
                return "kill"
            end
            local before = after + amount
            if before / max <= LOW_HP_THRESHOLD then
                return "lowhp"
            end
        end
    end
    return "default"
end

function Windfury:GetSoundDuration(path)
    if path and type(WindfurySoundDurations) == "table" then
        local seconds = WindfurySoundDurations[path]
        if type(seconds) == "number" and seconds > 0 then
            return seconds
        end
    end
    return DEFAULT_SOUND_DURATION
end

function Windfury:IsKillSoundPath(path)
    if not path or path == "" then
        return false
    end
    if type(WindfurySoundsKill) == "table" then
        for i = 1, #WindfurySoundsKill do
            if WindfurySoundsKill[i] == path then
                return true
            end
        end
    end
    local name = path:match("([^\\]+)$") or path
    name = name:gsub("%.mp3$", ""):gsub("%.wav$", ""):lower()
    return name:sub(1, 5) == "kill-"
end

function Windfury:TryPlayFile(path, category)
    local now = GetTime()
    local incomingKill = category == "kill"
    if self.soundBusyUntil and now < self.soundBusyUntil then
        if not (incomingKill and not self.soundBusyIsKill) then
            addon:Debug(string.format(
                "Windfury: sound skipped (busy %.3fs left)",
                self.soundBusyUntil - now
            ))
            return false
        end
        addon:Debug("Windfury: kill overrides non-kill lock")
    end
    if path and path ~= "" then
        addon:Debug("Windfury: PlaySoundFile " .. path)
        PlaySoundFile(path)
        self.soundBusyUntil = now + self:GetSoundDuration(path)
    else
        addon:Debug("Windfury: PlaySound RaidWarning (no file)")
        PlaySound("RaidWarning")
        self.soundBusyUntil = now + DEFAULT_SOUND_DURATION
    end
    self.soundBusyIsKill = incomingKill and true or false
    return true
end

function Windfury:Play(category)
    category = category or "default"
    local path = self:PickSoundPath(category)
    self:TryPlayFile(path, category)
end

function Windfury:GetStreakMessage(now)
    if self.lastStreakProc and (now - self.lastStreakProc) <= STREAK_WINDOW then
        self.streakCount = (self.streakCount or 1) + 1
    else
        self.streakCount = 1
    end
    self.lastStreakProc = now
    if self.streakCount > 1 then
        return "WINDFURY x" .. self.streakCount
    end
    return "WINDFURY"
end

function Windfury:ShowCombatText(message)
    if not CombatText_AddMessage then
        addon:Debug("Windfury: CombatText_AddMessage unavailable")
        return
    end
    message = message or "WINDFURY"
    ClearWindfuryCombatText()
    local scroll = COMBAT_TEXT_SCROLL_FUNCTION or CombatText_StandardScroll
    local saved = COMBAT_TEXT_LOCATIONS
    local targetY
    if saved then
        targetY = saved.startY + TEXT_Y_OFFSET
        local x = saved.startX
        -- Pin start/end so crit zooms in place instead of scrolling up.
        COMBAT_TEXT_LOCATIONS = {
            startX = x,
            startY = targetY,
            endX = x,
            endY = targetY,
        }
    end
    CombatText_AddMessage(message, scroll, 1, 0.82, 0, "crit", nil)
    PinWindfuryCombatText(message, targetY)
    if saved then
        COMBAT_TEXT_LOCATIONS = saved
    end
    addon:Debug("Windfury: CombatText " .. message)
end

function Windfury:ShowExpiryCombatText(message)
    if not CombatText_AddMessage then
        addon:Debug("Windfury: CombatText_AddMessage unavailable")
        return
    end
    message = message or ALERT_TEXT
    local scroll = COMBAT_TEXT_SCROLL_FUNCTION or CombatText_StandardScroll
    local saved = COMBAT_TEXT_LOCATIONS
    if saved then
        local x = saved.startX
        local startY = saved.startY + TEXT_Y_OFFSET
        COMBAT_TEXT_LOCATIONS = {
            startX = x,
            startY = startY,
            endX = x,
            endY = startY + EXPIRY_SCROLL_DISTANCE,
        }
    end
    CombatText_AddMessage(message, scroll, 1, 0.65, 0.15, nil, nil)
    if saved then
        COMBAT_TEXT_LOCATIONS = saved
    end
    addon:Debug("Windfury: expiry CombatText " .. message)
end

function Windfury:CheckEnchantExpiry()
    if not self.enabled then
        return
    end
    if select(2, UnitClass("player")) ~= "SHAMAN" then
        return
    end

    self.expiryWarned = self.expiryWarned or {}
    self.lastRemaining = self.lastRemaining or {}
    local slots = self:GetWindfuryWeaponSlots()
    local seen = {}

    for _, entry in ipairs(slots) do
        local slot = entry.slot
        seen[slot] = true
        local state = self:SlotHasWindfury(slot)
        if state == true then
            local remaining = self:GetSlotEnchantRemaining(slot)
            if remaining then
                local last = self.lastRemaining[slot]
                if last and remaining > last + 5 then
                    self.expiryWarned[slot] = nil
                end
                self.lastRemaining[slot] = remaining

                if remaining > 0 and remaining <= EXPIRY_WARN_SECONDS and not self.expiryWarned[slot] then
                    self.expiryWarned[slot] = true
                    local msg = ALERT_TEXT
                    if #slots > 1 then
                        msg = msg .. " (" .. entry.label .. ")"
                    end
                    self:ShowExpiryCombatText(msg)
                    addon:Debug(string.format(
                        "Windfury: expiry warning %s (%.0fs left)",
                        entry.label,
                        remaining
                    ))
                end
            end
        elseif state == false then
            self.expiryWarned[slot] = nil
            self.lastRemaining[slot] = nil
        end
    end

    for slot, _ in pairs(self.expiryWarned) do
        if not seen[slot] then
            self.expiryWarned[slot] = nil
            self.lastRemaining[slot] = nil
        end
    end
end

function Windfury:PreviewProc(category)
    category = category or self:GetPreviewProcPool()
    local now = GetTime()
    self:Play(category)
    self:ShowCombatText(self:GetStreakMessage(now))
end

function Windfury:SetPreviewProcPool(category)
    self.previewProcPool = category or "default"
end

function Windfury:GetPreviewProcPool()
    return self.previewProcPool or "default"
end

function Windfury:UpdatePreviewProcPoolHighlight(panel)
    local buttons = panel and panel.windfuryProcPoolButtons
    if not buttons then
        return
    end
    local selected = self:GetPreviewProcPool()
    for pool, btn in pairs(buttons) do
        if pool == selected then
            btn:Disable()
        else
            btn:Enable()
        end
    end
end

function Windfury:GetSoundList()
    local list = {}
    local function addFrom(pool)
        if type(pool) ~= "table" then
            return
        end
        for i = 1, #pool do
            list[#list + 1] = pool[i]
        end
    end
    addFrom(WindfurySounds)
    addFrom(WindfurySoundsLowHp)
    addFrom(WindfurySoundsKill)
    return list
end

function Windfury:GetSoundLabel(path)
    if not path or path == "" then
        return ""
    end
    local name = path:match("([^\\]+)$") or path
    name = name:gsub("%.mp3$", ""):gsub("%.wav$", "")
    local lower = name:lower()
    if lower:sub(1, 5) == "kill-" then
        return "[kill] " .. name:sub(6)
    end
    if lower:sub(1, 6) == "lowhp-" then
        return "[lowhp] " .. name:sub(7)
    end
    return name
end

function Windfury:PreviewSound(path)
    local category = self:IsKillSoundPath(path) and "kill" or "default"
    if not path or path == "" then
        addon:Debug("Windfury: PreviewSound (no path)")
        self:TryPlayFile(nil, category)
        return
    end
    addon:Debug("Windfury: PreviewSound " .. path)
    self:TryPlayFile(path, category)
end

function Windfury:SetPreviewSoundIndex(index)
    self.previewSoundIndex = index
end

function Windfury:GetPreviewSoundPath()
    local sounds = self:GetSoundList()
    local index = self.previewSoundIndex or 1
    return sounds[index]
end

function Windfury:PreviewSelectedSound()
    self:PreviewSound(self:GetPreviewSoundPath())
end

function Windfury:UpdatePreviewSoundHighlight(panel)
    local rows = panel and panel.windfurySoundRows
    if not rows then
        return
    end
    local selected = self.previewSoundIndex or 1
    for i, row in ipairs(rows) do
        local fs = row.label
        if fs then
            if i == selected then
                fs:SetTextColor(1, 0.82, 0)
            else
                fs:SetTextColor(1, 1, 1)
            end
        end
    end
end

function Windfury:CompareProcCategory(a, b)
    return (PROC_CATEGORY_PRIORITY[a] or 1) > (PROC_CATEGORY_PRIORITY[b] or 1)
end

function Windfury:PlayProcSound(category)
    if not self.enabled then
        addon:Debug("Windfury: proc ignored (module off)")
        return
    end
    addon:Debug("Windfury: proc -> play " .. tostring(category))
    self:Play(category)
end

function Windfury:BeginProcBurst()
    if not self.enabled then
        addon:Debug("Windfury: proc ignored (module off)")
        return
    end
    if not self.procBurstActive then
        self.procBurstActive = true
        self.procBurstCategory = "default"
        local now = GetTime()
        self:ShowCombatText(self:GetStreakMessage(now))
    end
    addon:Debounce("windfury_proc_burst", PROC_GAP, function()
        Windfury:FinishProcBurst()
    end)
end

function Windfury:MergeProcCategory(category)
    category = category or "default"
    if not self.procBurstCategory or self:CompareProcCategory(category, self.procBurstCategory) then
        self.procBurstCategory = category
    end
end

function Windfury:FinishProcBurst()
    if not self.procBurstActive then
        return
    end
    local category = self.procBurstCategory or "default"
    self.procBurstActive = nil
    self.procBurstCategory = nil
    self.pendingProcDest = nil
    self:PlayProcSound(category)
end

function Windfury:OnExtraAttacks(destGUID)
    self.pendingProcDest = destGUID
    self:BeginProcBurst()
end

function Windfury:OnProcDamage(category, destGUID)
    self.pendingProcDest = destGUID
    self:BeginProcBurst()
    if self.procBurstActive then
        self:MergeProcCategory(category)
    end
end

function Windfury:SavePath(text)
    text = addon:Trim(text or "")
    if not addon.db.modules.Windfury then
        addon.db.modules.Windfury = {}
    end
    addon.db.modules.Windfury.soundFile = text
end

function Windfury:BuildOptions(panel, y)
    local section = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    section:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
    section:SetText("Windfury")
    y = y - 18

    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
    label:SetText("Sound file (fallback if Sounds/ is empty)")
    y = y - 18

    local box = CreateFrame("EditBox", "ECA_WindfuryPath", panel, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetWidth(320)
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
    y = y - 26

    local test = CreateFrame("Button", "ECA_WindfuryTest", panel, "UIPanelButtonTemplate")
    test:SetWidth(80)
    test:SetHeight(22)
    test:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
    test:SetText("Test proc")
    test:SetScript("OnClick", function()
        Windfury:SavePath(box:GetText())
        Windfury:PreviewProc()
    end)
    panel.windfuryTest = test

    local poolLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    poolLabel:SetPoint("LEFT", test, "RIGHT", 8, 0)
    poolLabel:SetText("Pool")

    panel.windfuryProcPoolButtons = {}
    local poolX = 118
    for i, pool in ipairs(PROC_POOLS) do
        local poolBtn = CreateFrame("Button", "ECA_WindfuryPool_" .. pool, panel, "UIPanelButtonTemplate")
        poolBtn:SetWidth(54)
        poolBtn:SetHeight(22)
        poolBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", poolX + (i - 1) * 58, y)
        poolBtn:SetText(PROC_POOL_LABELS[pool] or pool)
        poolBtn.pool = pool
        poolBtn:SetScript("OnClick", function(self)
            Windfury:SetPreviewProcPool(self.pool)
            Windfury:UpdatePreviewProcPoolHighlight(panel)
        end)
        panel.windfuryProcPoolButtons[pool] = poolBtn
    end
    self:SetPreviewProcPool(self:GetPreviewProcPool())
    self:UpdatePreviewProcPoolHighlight(panel)
    y = y - 28

    local soundsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    soundsLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
    soundsLabel:SetText("Test individual sounds")
    y = y - 18

    local SOUND_LIST_HEIGHT = 120
    local SOUND_ROW_HEIGHT = 18
    local scroll = CreateFrame("ScrollFrame", "ECA_WindfurySoundScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetWidth(340)
    scroll:SetHeight(SOUND_LIST_HEIGHT)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)

    local content = CreateFrame("Frame", "ECA_WindfurySoundList", scroll)
    content:SetWidth(320)
    scroll:SetScrollChild(content)
    panel.windfurySoundScroll = scroll
    panel.windfurySoundList = content
    panel.windfurySoundRows = {}

    local sounds = self:GetSoundList()
    if #sounds == 0 then
        content:SetHeight(SOUND_ROW_HEIGHT)
        local empty = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        empty:SetPoint("TOPLEFT", content, "TOPLEFT", 4, 0)
        empty:SetText("No sounds in Sounds/ (run make lint)")
        panel.windfurySoundEmpty = empty
    else
        self.previewSoundIndex = self.previewSoundIndex or 1
        if self.previewSoundIndex > #sounds then
            self.previewSoundIndex = 1
        end
        content:SetHeight(#sounds * SOUND_ROW_HEIGHT)
        for i, path in ipairs(sounds) do
            local row = CreateFrame("Button", "ECA_WindfurySound_" .. i, content)
            row:SetWidth(300)
            row:SetHeight(SOUND_ROW_HEIGHT)
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * SOUND_ROW_HEIGHT)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("LEFT", row, "LEFT", 4, 0)
            label:SetText(self:GetSoundLabel(path))
            row.label = label
            row.soundIndex = i
            row:SetScript("OnClick", function()
                Windfury:SetPreviewSoundIndex(i)
                Windfury:UpdatePreviewSoundHighlight(panel)
            end)
            panel.windfurySoundRows[i] = row
        end
        self:UpdatePreviewSoundHighlight(panel)
    end
    y = y - SOUND_LIST_HEIGHT - 4

    local soundTest = CreateFrame("Button", "ECA_WindfurySoundTest", panel, "UIPanelButtonTemplate")
    soundTest:SetWidth(80)
    soundTest:SetHeight(22)
    soundTest:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
    soundTest:SetText("Test sound")
    soundTest:SetScript("OnClick", function()
        Windfury:PreviewSelectedSound()
    end)
    if #sounds == 0 then
        soundTest:Disable()
    end
    panel.windfurySoundTest = soundTest
    y = y - 28

    local move = CreateFrame("CheckButton", "ECA_WindfuryAlertMove", panel, "UICheckButtonTemplate")
    move:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
    local moveLabel = move:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    moveLabel:SetPoint("LEFT", move, "RIGHT", 2, 0)
    moveLabel:SetText("Move " .. ALERT_TEXT .. " badge")
    move:SetScript("OnClick", function(self)
        Windfury:SetAlertMove(self:GetChecked() and true or false)
    end)
    panel.windfuryAlertMove = move
    y = y - 36

    local sizeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    sizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
    sizeLabel:SetText(ALERT_TEXT .. " font size")
    y = y - 18

    local sizeBox = CreateFrame("EditBox", "ECA_WindfuryAlertFontSize", panel, "InputBoxTemplate")
    sizeBox:SetAutoFocus(false)
    sizeBox:SetWidth(48)
    sizeBox:SetHeight(20)
    sizeBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
    sizeBox:SetNumeric(true)
    sizeBox:SetMaxLetters(2)
    sizeBox:SetText(tostring(Windfury:GetAlertFontSize()))
    sizeBox:SetScript("OnEnterPressed", function(self)
        Windfury:SaveAlertFontSize(self:GetText())
        self:SetText(tostring(Windfury:GetAlertFontSize()))
        self:ClearFocus()
    end)
    sizeBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(Windfury:GetAlertFontSize()))
        self:ClearFocus()
    end)
    sizeBox:SetScript("OnEditFocusLost", function(self)
        Windfury:SaveAlertFontSize(self:GetText())
        self:SetText(tostring(Windfury:GetAlertFontSize()))
    end)
    panel.windfuryAlertFontSize = sizeBox

    return y - 26
end

function Windfury:Init(owner)
    self.addon = owner
    owner:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    owner:RegisterEvent("UNIT_INVENTORY_CHANGED")
    owner:RegisterEvent("PLAYER_ENTERING_WORLD")
    owner:RegisterEvent("PLAYER_REGEN_DISABLED")
    owner:RegisterEvent("PLAYER_REGEN_ENABLED")
    owner:RegisterEvent("AUCTION_HOUSE_CLOSED")
    owner:RegisterEvent("BANKFRAME_CLOSED")
    owner:RegisterEvent("MERCHANT_CLOSED")

    if not self.expiryTicker then
        local ticker = CreateFrame("Frame")
        ticker:Hide()
        ticker:SetScript("OnUpdate", function(_, elapsed)
            Windfury.expiryAccum = (Windfury.expiryAccum or 0) + elapsed
            if Windfury.expiryAccum < 1 then
                return
            end
            Windfury.expiryAccum = 0
            Windfury:CheckEnchantExpiry()
            Windfury:UpdateAlert()
        end)
        self.expiryTicker = ticker
    end
end

function Windfury:Enable()
    self.enabled = true
    self.expiryWarned = {}
    self.lastRemaining = {}
    self:UpdateAlert()
    if self.expiryTicker then
        self.expiryTicker:Show()
    end
end

function Windfury:Disable()
    self.enabled = false
    if self.alertFrame then
        self.alertFrame:Hide()
    end
    if self.expiryTicker then
        self.expiryTicker:Hide()
    end
end

function Windfury:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        self.lastZoneLoad = GetTime()
        self.expiryWarned = {}
        self.lastRemaining = {}
        self:UpdateAlert()
        self:CheckEnchantExpiry()
        self:ScheduleAlertRecheck()
        return
    end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        self:UpdateAlert()
        self:CheckEnchantExpiry()
        return
    end
    if event == "AUCTION_HOUSE_CLOSED"
        or event == "BANKFRAME_CLOSED"
        or event == "MERCHANT_CLOSED"
    then
        self:ScheduleAlertRecheck()
        return
    end
    if event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then
            self.expiryWarned = {}
            self.lastRemaining = {}
            self:UpdateAlert()
            self:CheckEnchantExpiry()
        end
        return
    end
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
        return
    end
    -- 3.3.5 has no CombatLogGetCurrentEventInfo.
    local _, subevent, sourceGUID, _, _, destGUID, _, _, spellId, spellName, _, amount, overkill = ...
    if sourceGUID ~= UnitGUID("player") then
        return
    end
    if subevent == "SPELL_CAST_SUCCESS" then
        if IsWindfury(spellId, spellName) then
            addon:Debug(string.format(
                "Windfury: cleu sub=%s id=%s name=%s match=yes",
                tostring(subevent),
                tostring(spellId),
                tostring(spellName)
            ))
            self:OnWindfuryCast()
        end
        return
    end
    if subevent == "SPELL_EXTRA_ATTACKS" then
        if IsWindfury(spellId, spellName) then
            addon:Debug(string.format(
                "Windfury: cleu sub=%s id=%s name=%s match=yes",
                tostring(subevent),
                tostring(spellId),
                tostring(spellName)
            ))
            self:OnExtraAttacks(destGUID)
        end
        return
    end
    if subevent == "SPELL_DAMAGE" then
        local match = IsWindfury(spellId, spellName)
        if match then
            addon:Debug(string.format(
                "Windfury: cleu sub=%s id=%s name=%s match=yes",
                tostring(subevent),
                tostring(spellId),
                tostring(spellName)
            ))
            local category = self:GetProcCategory(destGUID, amount, overkill)
            self:OnProcDamage(category, destGUID)
        end
        return
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
        self:PreviewProc()
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
