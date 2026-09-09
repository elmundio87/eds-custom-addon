local addon = EdsCustomAddon

local ArathiBasin = {
    name = "ArathiBasin",
    title = "Arathi Basin timers",
    tooltip = "Show who holds each Arathi Basin base and 60s capture countdowns",
}

local ZONE_NAME = "Arathi Basin"
local CAPTURE_SECONDS = 60
local TIMER_TICK = 0.25
local LANDMARK_DEBOUNCE = 0.15
local FRAME_WIDTH = 250
local ROW_HEIGHT = 16
local PAD_TOP = 5
local PAD_BOTTOM = 5
local STATUS_WIDTH = 72
local BASE_ORDER = {
    "Stables",
    "Blacksmith",
    "Farm",
    "Lumber Mill",
    "Gold Mine",
}

local BASE_LOOKUP = {}
for i = 1, #BASE_ORDER do
    BASE_LOOKUP[BASE_ORDER[i]] = true
end

local COLOR_ALLIANCE = { 0.0, 0.44, 0.87 }
local COLOR_HORDE = { 0.77, 0.12, 0.23 }
local COLOR_NEUTRAL = { 0.75, 0.75, 0.75 }
local COLOR_ASSAULT = { 1.0, 0.82, 0.0 }

local function FrameHeight(rowCount)
    return PAD_TOP + (rowCount * ROW_HEIGHT) + PAD_BOTTOM
end

local function RowOffset(index)
    return -(PAD_TOP + ((index - 1) * ROW_HEIGHT))
end

local function PlaceRow(row, frame, index)
    local y = RowOffset(index)
    row.nameFs:ClearAllPoints()
    row.nameFs:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, y)
    row.nameFs:SetHeight(ROW_HEIGHT)
    row.nameFs:SetJustifyV("MIDDLE")
    if row.statusFs then
        row.statusFs:ClearAllPoints()
        row.statusFs:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -56, y)
        row.statusFs:SetHeight(ROW_HEIGHT)
        row.statusFs:SetJustifyV("MIDDLE")
    end
    row.timerFs:ClearAllPoints()
    row.timerFs:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, y)
    row.timerFs:SetHeight(ROW_HEIGHT)
    row.timerFs:SetJustifyV("MIDDLE")
end

local function GetConfig()
    if not addon.db.modules.ArathiBasin then
        addon.db.modules.ArathiBasin = {}
    end
    return addon.db.modules.ArathiBasin
end

local function FormatRemaining(deadline)
    local left = (deadline or 0) - GetTime()
    if left < 0 then
        left = 0
    end
    local sec = math.floor(left + 0.5)
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

function ArathiBasin:PlayerFaction()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if type(faction) == "string" then
        faction = string.lower(faction)
        if faction == "alliance" or faction == "horde" then
            return faction
        end
    end
    return nil
end

-- Landmark description is e.g. "Alliance Controlled" / "Horde Contested".
-- Contested descriptions name the assaulting faction; Controlled names the owner.
function ArathiBasin:ParseDescription(description)
    local desc = string.lower(description or "")
    local alliance = desc:find("alliance", 1, true)
    local horde = desc:find("horde", 1, true)
    local contested = desc:find("contest", 1, true)
        or desc:find("conflict", 1, true)
        or desc:find("assault", 1, true)
        or desc:find("attack", 1, true)
    local controlled = desc:find("control", 1, true)
    local unclaimed = desc:find("uncontrol", 1, true)
        or desc:find("neutral", 1, true)
        or desc == ""

    local named = nil
    if alliance and not horde then
        named = "alliance"
    elseif horde and not alliance then
        named = "horde"
    end

    if contested then
        return {
            kind = "assault",
            assaulting = named,
        }
    end
    if controlled and named then
        return {
            kind = "control",
            owner = named,
        }
    end
    if named then
        return {
            kind = "control",
            owner = named,
        }
    end
    if unclaimed then
        return { kind = "unclaimed", owner = "neutral" }
    end
    return { kind = "unclaimed", owner = "neutral" }
end

function ArathiBasin:ApplyDescription(state, description)
    state.description = description or ""
    local parsed = self:ParseDescription(state.description)
    if parsed.kind == "control" then
        state.owner = parsed.owner
        state.assaulting = nil
    elseif parsed.kind == "assault" then
        if parsed.assaulting then
            state.assaulting = parsed.assaulting
        end
        -- Keep prior owner so Taking vs Defending stays meaningful.
    elseif parsed.kind == "unclaimed" then
        state.owner = "neutral"
        state.assaulting = nil
    end
end

-- Relative to the player: Taking / Defending / Holding / Unclaimed / Occupied.
function ArathiBasin:StatusInfo(state)
    local player = self:PlayerFaction()
    local owner = (state and state.owner) or "neutral"
    local assaulting = state and state.assaulting
    local underAssault = (state and state.deadline) or assaulting

    if underAssault then
        if player and assaulting == player then
            return "Taking", player, COLOR_ASSAULT
        end
        if player and owner == player then
            return "Defending", player, COLOR_ASSAULT
        end
        if player and assaulting and assaulting ~= player then
            -- Enemy assaulting a base we do not own (e.g. neutral); still contested.
            return "Occupied", assaulting, self:FactionColor(assaulting)
        end
        return "Taking", assaulting or owner, COLOR_ASSAULT
    end

    if owner == "neutral" or not owner then
        return "Unclaimed", "neutral", COLOR_NEUTRAL
    end
    if player and owner == player then
        return "Holding", owner, self:FactionColor(owner)
    end
    return "Occupied", owner, self:FactionColor(owner)
end

function ArathiBasin:FactionColor(faction)
    if faction == "alliance" then
        return COLOR_ALLIANCE
    end
    if faction == "horde" then
        return COLOR_HORDE
    end
    return COLOR_NEUTRAL
end

function ArathiBasin:ApplyRowOwner(row, state)
    local label, _, color = self:StatusInfo(state)
    row.nameFs:SetTextColor(color[1], color[2], color[3])
    if row.statusFs then
        row.statusFs:SetText(label)
        row.statusFs:SetTextColor(color[1], color[2], color[3])
        row.statusFs:Show()
    end
    if state and state.deadline then
        row.timerFs:SetText(FormatRemaining(state.deadline))
        row.timerFs:SetTextColor(COLOR_ASSAULT[1], COLOR_ASSAULT[2], COLOR_ASSAULT[3])
    else
        row.timerFs:SetText("-")
        row.timerFs:SetTextColor(COLOR_NEUTRAL[1], COLOR_NEUTRAL[2], COLOR_NEUTRAL[3])
    end
end

function ArathiBasin:IsInArathiBasin()
    local _, instanceType = IsInInstance()
    if instanceType ~= "pvp" then
        return false
    end
    local zone = GetRealZoneText and GetRealZoneText() or ""
    return zone == ZONE_NAME
end

function ArathiBasin:GetFrameConfig()
    local cfg = GetConfig()
    if not cfg.frame then
        cfg.frame = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 160,
            fontSize = 12,
        }
    end
    return cfg.frame
end

function ArathiBasin:IsMoveEnabled()
    local cfg = GetConfig()
    return cfg.move and true or false
end

function ArathiBasin:SetMove(enabled)
    GetConfig().move = enabled and true or false
    self:ApplyDragMode()
    self:UpdateFrame()
end

function ArathiBasin:SavePosition()
    if not self.frame then
        return
    end
    local point, _, relativePoint, x, y = self.frame:GetPoint()
    local cfg = self:GetFrameConfig()
    cfg.point = point or "CENTER"
    cfg.relativePoint = relativePoint or "CENTER"
    cfg.x = x or 0
    cfg.y = y or 0
end

function ArathiBasin:ApplyPosition()
    if not self.frame then
        return
    end
    local cfg = self:GetFrameConfig()
    self.frame:ClearAllPoints()
    self.frame:SetPoint(
        cfg.point or "CENTER",
        UIParent,
        cfg.relativePoint or "CENTER",
        cfg.x or 0,
        cfg.y or 160
    )
end

function ArathiBasin:ApplyDragMode()
    if not self.frame then
        return
    end
    local frame = self.frame
    local move = self:IsMoveEnabled()
    if move then
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(f)
            f:StartMoving()
        end)
        frame:SetScript("OnDragStop", function(f)
            f:StopMovingOrSizing()
            ArathiBasin:SavePosition()
        end)
        frame:SetBackdropBorderColor(1, 0.82, 0, 1)
    else
        frame:SetMovable(false)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        frame:EnableMouse(false)
        frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end
end

function ArathiBasin:CreateFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "ECA_ArathiBasin", UIParent)
    frame:SetSize(FRAME_WIDTH, FrameHeight(#BASE_ORDER))
    frame:SetFrameStrata("MEDIUM")
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.75)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    frame:Hide()

    frame.rows = {}
    for i = 1, #BASE_ORDER do
        local nameFs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFs:SetWidth(100)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetText(BASE_ORDER[i])

        local statusFs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusFs:SetWidth(STATUS_WIDTH)
        statusFs:SetJustifyH("RIGHT")
        statusFs:SetText("Unclaimed")

        local timerFs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        timerFs:SetWidth(44)
        timerFs:SetJustifyH("RIGHT")
        timerFs:SetText("-")

        local row = {
            name = BASE_ORDER[i],
            nameFs = nameFs,
            statusFs = statusFs,
            timerFs = timerFs,
        }
        PlaceRow(row, frame, i)
        frame.rows[i] = row
    end

    self.frame = frame
    self:ApplyPosition()
    self:ApplyDragMode()
end

function ArathiBasin:OrderedBaseNames()
    local seen = {}
    local names = {}
    for i = 1, #BASE_ORDER do
        local name = BASE_ORDER[i]
        if self.bases[name] then
            names[#names + 1] = name
            seen[name] = true
        end
    end
    local extras = {}
    for name, _ in pairs(self.bases) do
        if not seen[name] then
            extras[#extras + 1] = name
        end
    end
    table.sort(extras)
    for i = 1, #extras do
        names[#names + 1] = extras[i]
    end
    return names
end

function ArathiBasin:UpdateFrame()
    self:CreateFrame()
    local show = self.enabled and self:IsInArathiBasin()
    if not show then
        self.frame:Hide()
        return
    end

    local names = self:OrderedBaseNames()

    local rowCount = math.max(#names, 1)
    self.frame:SetHeight(FrameHeight(rowCount))

    for i = 1, #self.frame.rows do
        local row = self.frame.rows[i]
        local name = names[i]
        if name then
            row.name = name
            row.nameFs:SetText(name)
            PlaceRow(row, self.frame, i)
            self:ApplyRowOwner(row, self.bases[name])
            row.nameFs:Show()
            row.timerFs:Show()
            if row.statusFs then
                row.statusFs:Show()
            end
        else
            row.nameFs:Hide()
            row.timerFs:Hide()
            if row.statusFs then
                row.statusFs:Hide()
            end
        end
    end

    -- Grow row widgets if more landmarks than BASE_ORDER appear.
    for i = #self.frame.rows + 1, #names do
        local name = names[i]
        local nameFs = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFs:SetWidth(100)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetText(name)

        local statusFs = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusFs:SetWidth(STATUS_WIDTH)
        statusFs:SetJustifyH("RIGHT")
        statusFs:SetText("Unclaimed")

        local timerFs = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        timerFs:SetWidth(44)
        timerFs:SetJustifyH("RIGHT")
        timerFs:SetText("-")

        local row = {
            name = name,
            nameFs = nameFs,
            statusFs = statusFs,
            timerFs = timerFs,
        }
        PlaceRow(row, self.frame, i)
        self:ApplyRowOwner(row, self.bases[name])
        self.frame.rows[i] = row
    end

    self.frame:Show()
end

function ArathiBasin:LandmarksLookLikeAB()
    if not GetNumMapLandmarks or not GetMapLandmarkInfo then
        return false
    end
    local n = GetNumMapLandmarks() or 0
    for i = 1, n do
        local name = GetMapLandmarkInfo(i)
        if name and BASE_LOOKUP[name] then
            return true
        end
    end
    return false
end

function ArathiBasin:ReadLandmarks(forceSnap)
    local snapshot = {}
    if not GetNumMapLandmarks or not GetMapLandmarkInfo then
        return snapshot
    end

    local mapOpen = WorldMapFrame and WorldMapFrame:IsShown()
    if mapOpen then
        return self.cachedLandmarks or snapshot
    end

    -- SetMapToCurrentZone is expensive and fires WORLD_MAP_UPDATE; only call
    -- it when the map is not already showing AB landmarks.
    if forceSnap or not self:LandmarksLookLikeAB() then
        if SetMapToCurrentZone then
            self.readingMap = true
            SetMapToCurrentZone()
            self.readingMap = nil
        end
    end

    local n = GetNumMapLandmarks() or 0
    for i = 1, n do
        local name, description, textureIndex = GetMapLandmarkInfo(i)
        if name and name ~= "" and textureIndex then
            snapshot[name] = {
                index = textureIndex,
                description = description or "",
            }
        end
    end
    self.cachedLandmarks = snapshot
    return snapshot
end

function ArathiBasin:SaveTracking()
    local cfg = GetConfig()
    local now = (time and time()) or 0
    local tracking = {}
    for name, state in pairs(self.bases or {}) do
        local remaining = nil
        if state.deadline then
            remaining = state.deadline - GetTime()
            if remaining <= 0 then
                remaining = nil
                state.deadline = nil
            end
        end
        tracking[name] = {
            index = state.index,
            description = state.description or "",
            owner = state.owner,
            assaulting = state.assaulting,
            remaining = remaining,
            savedAt = now,
        }
    end
    cfg.tracking = tracking
end

function ArathiBasin:LoadTracking()
    local cfg = GetConfig()
    local tracking = cfg.tracking
    self.bases = {}
    if type(tracking) ~= "table" then
        return
    end
    local now = (time and time()) or 0
    for name, entry in pairs(tracking) do
        if type(name) == "string" and type(entry) == "table" and entry.index then
            local deadline = nil
            local remaining = tonumber(entry.remaining)
            local savedAt = tonumber(entry.savedAt)
            if remaining and savedAt and remaining > 0 then
                local left = remaining - (now - savedAt)
                if left > 0.5 then
                    deadline = GetTime() + left
                end
            end
            self.bases[name] = {
                index = entry.index,
                description = entry.description or "",
                owner = entry.owner,
                assaulting = entry.assaulting,
                deadline = deadline,
            }
            if not self.bases[name].owner and not self.bases[name].assaulting then
                self:ApplyDescription(self.bases[name], self.bases[name].description)
            end
        end
    end
end

function ArathiBasin:ClearTracking()
    self.bases = {}
    self.cachedLandmarks = nil
    GetConfig().tracking = {}
end

function ArathiBasin:ApplyLandmarkSnapshot(snapshot)
    self.bases = self.bases or {}
    for name, entry in pairs(snapshot) do
        local index = entry
        local description = ""
        if type(entry) == "table" then
            index = entry.index
            description = entry.description or ""
        end
        local state = self.bases[name]
        if not state then
            state = {
                index = index,
                deadline = nil,
            }
            self.bases[name] = state
            self:ApplyDescription(state, description)
            addon:Debug("ArathiBasin: first sight " .. name .. " index=" .. tostring(index))
        else
            if state.index ~= index then
                state.index = index
                if state.deadline then
                    state.deadline = nil
                    addon:Debug("ArathiBasin: cleared " .. name)
                else
                    state.deadline = GetTime() + CAPTURE_SECONDS
                    addon:Debug("ArathiBasin: timer " .. name .. " " .. CAPTURE_SECONDS .. "s")
                end
            end
            self:ApplyDescription(state, description)
        end
    end
    self:SaveTracking()
end

-- Expensive path: read landmarks (may snap the map). Event-driven only.
function ArathiBasin:Poll(forceSnap)
    if not self.enabled or not self:IsInArathiBasin() then
        self:UpdateFrame()
        return
    end
    local snapshot = self:ReadLandmarks(forceSnap)
    self:ApplyLandmarkSnapshot(snapshot)
    self:UpdateFrame()
end

function ArathiBasin:ScheduleLandmarkPoll()
    if not self.enabled or not self:IsInArathiBasin() then
        return
    end
    addon:Debounce("ArathiBasin.landmarks", LANDMARK_DEBOUNCE, function()
        ArathiBasin:Poll(false)
    end)
end

-- Cheap path: refresh countdown text only. No map API calls.
function ArathiBasin:TickTimers()
    if not self.enabled or not self.frame or not self.frame:IsShown() then
        return
    end
    local any = false
    local expired = false
    for _, state in pairs(self.bases or {}) do
        if state.deadline then
            if state.deadline <= GetTime() then
                state.deadline = nil
                expired = true
            else
                any = true
            end
        end
    end
    if expired then
        self:SaveTracking()
    end
    if not any and not expired then
        return
    end
    for i = 1, #self.frame.rows do
        local row = self.frame.rows[i]
        if row.nameFs:IsShown() and row.name then
            self:ApplyRowOwner(row, self.bases[row.name])
        end
    end
end

function ArathiBasin:DumpIndices()
    if not self:IsInArathiBasin() then
        addon:Print("Arathi Basin timers: not in Arathi Basin")
        return
    end
    local snapshot = self:ReadLandmarks(true)
    local names = {}
    for name, _ in pairs(snapshot) do
        names[#names + 1] = name
    end
    table.sort(names)
    if #names == 0 then
        addon:Print("Arathi Basin timers: no landmarks")
        return
    end
    for i = 1, #names do
        local name = names[i]
        local entry = snapshot[name]
        local index = type(entry) == "table" and entry.index or entry
        local desc = type(entry) == "table" and (entry.description or "") or ""
        addon:Print(string.format("Arathi: %s = %s (%s)", name, tostring(index), desc))
    end
end

function ArathiBasin:Init(owner)
    self.addon = owner
    self:LoadTracking()
    owner:RegisterEvent("PLAYER_ENTERING_WORLD")
    owner:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    owner:RegisterEvent("UPDATE_WORLD_STATES")
    -- WORLD_MAP_UPDATE is intentionally not used: SetMapToCurrentZone fires it
    -- and re-polling would hitch in a loop.

    if not self.pollTicker then
        local ticker = CreateFrame("Frame")
        ticker:Hide()
        ticker:SetScript("OnUpdate", function(_, elapsed)
            ArathiBasin.timerAccum = (ArathiBasin.timerAccum or 0) + elapsed
            if ArathiBasin.timerAccum < TIMER_TICK then
                return
            end
            ArathiBasin.timerAccum = 0
            ArathiBasin:TickTimers()
        end)
        self.pollTicker = ticker
    end
end

function ArathiBasin:Enable()
    self.enabled = true
    self:LoadTracking()
    if self.pollTicker then
        self.pollTicker:Show()
    end
    self:Poll(true)
end

function ArathiBasin:Disable()
    self.enabled = false
    self:SaveTracking()
    if self.pollTicker then
        self.pollTicker:Hide()
    end
    if self.frame then
        self.frame:Hide()
    end
end

function ArathiBasin:OnEvent(event)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if not self:IsInArathiBasin() then
            self:ClearTracking()
            self:UpdateFrame()
            return
        end
        self:LoadTracking()
        self:Poll(true)
        return
    end
    if event == "UPDATE_WORLD_STATES" then
        self:ScheduleLandmarkPoll()
    end
end

function ArathiBasin:BuildOptions(panel, y)
    local section = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    section:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
    section:SetText("Arathi Basin")
    y = y - 18

    local move = CreateFrame("CheckButton", "ECA_ArathiBasinMove", panel, "UICheckButtonTemplate")
    move:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
    local moveLabel = move:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    moveLabel:SetPoint("LEFT", move, "RIGHT", 2, 0)
    moveLabel:SetText("Move Arathi Basin timers")
    move:SetScript("OnClick", function(self)
        ArathiBasin:SetMove(self:GetChecked() and true or false)
    end)
    panel.arathiBasinMove = move
    return y - 28
end

function ArathiBasin:Slash(rest)
    local arg = string.lower(addon:Trim(rest or ""))
    if arg == "on" then
        addon:EnableModule(self)
        addon:Print("Arathi Basin timers on")
        return
    end
    if arg == "off" then
        addon:DisableModule(self)
        addon:Print("Arathi Basin timers off")
        return
    end
    if arg == "indices" then
        self:DumpIndices()
        return
    end
    local active = 0
    for _, state in pairs(self.bases or {}) do
        if state.deadline then
            active = active + 1
        end
    end
    addon:Print(string.format(
        "Arathi Basin timers %s | inAB=%s | active=%d",
        self.enabled and "on" or "off",
        self:IsInArathiBasin() and "yes" or "no",
        active
    ))
    if arg ~= "" and arg ~= "status" then
        addon:Print("/eca arathi [on|off|indices|status]")
    end
end

addon:RegisterModule(ArathiBasin)
