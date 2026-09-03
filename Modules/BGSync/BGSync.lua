local addon = EdsCustomAddon

local BGSync = {
    name = "BGSync",
    title = "BG Bot Sync",
    tooltip = "Set battleground players to your level and whisper autogear (/eca bgsync)",
}

local GEAR_COMMAND = "autogear"
local QUEUE_KEY = "BGSync.Queue"
local SCORE_KEY = "BGSync.Score"
local STEP_DELAY = 0.4
local SETTLE_DELAY = 1.0
local SCORE_TIMEOUT = 3.0
local PROGRESS_EVERY = 10

local function StripRealm(name)
    if not name or name == "" then
        return nil
    end
    local bare = name:match("^([^%-]+)")
    return bare or name
end

local function GetConfig()
    return addon.db and addon.db.modules and addon.db.modules.BGSync
end

local function GetStepDelay()
    local cfg = GetConfig()
    local delay = cfg and cfg.stepDelay
    if type(delay) == "number" and delay > 0 then
        return delay
    end
    return STEP_DELAY
end

local function GetSettleDelay()
    local cfg = GetConfig()
    local delay = cfg and cfg.settleDelay
    if type(delay) == "number" and delay > 0 then
        return delay
    end
    return SETTLE_DELAY
end

function BGSync:IsInBattleground()
    local _, kind = IsInInstance()
    return kind == "pvp"
end

function BGSync:LevelCommand(name)
    return string.format(".character level %s %d", name, self.level or 0)
end

function BGSync:FriendNames()
    local friends = {}
    local n = GetNumFriends() or 0
    for i = 1, n do
        local name = GetFriendInfo(i)
        name = StripRealm(name)
        if name and name ~= "" then
            friends[string.lower(name)] = true
        end
    end
    return friends
end

function BGSync:ResetState()
    self.active = false
    self.awaitingScores = false
    self.queue = {}
    self.phase = nil
    self.index = 0
    self.level = nil
    self.selfName = nil
    self.processed = 0
end

function BGSync:Cancel(reason)
    if not self.active and not self.awaitingScores then
        return
    end
    local wasActive = self.active or self.awaitingScores
    self:ResetState()
    if wasActive then
        if reason and reason ~= "" then
            addon:Print("BG Sync: Cancelled (" .. reason .. ").")
        else
            addon:Print("BG Sync: Cancelled.")
        end
    end
end

function BGSync:Finish()
    local count = self.processed or 0
    local level = self.level or UnitLevel("player") or 0
    self:ResetState()
    addon:Print(string.format(
        "BG Sync: Complete. Processed %d characters at level %d.",
        count,
        level
    ))
end

function BGSync:QueueBot(name)
    if not name or name == "" then
        return
    end
    table.insert(self.queue, name)
end

function BGSync:BuildRoster()
    if not self.awaitingScores then
        return
    end
    self.awaitingScores = false

    if not self:IsInBattleground() then
        self:Cancel("left battleground")
        return
    end

    local selfName = self.selfName or UnitName("player")
    local selfLower = selfName and string.lower(selfName) or ""
    local friends = self:FriendNames()
    local seen = {}
    local skippedFriends = 0
    self.queue = {}

    local count = GetNumBattlefieldScores() or 0
    for i = 1, count do
        local name = GetBattlefieldScore(i)
        name = StripRealm(name)
        if name and name ~= "" then
            local key = string.lower(name)
            if key ~= selfLower and not seen[key] then
                seen[key] = true
                if friends[key] then
                    skippedFriends = skippedFriends + 1
                    addon:Debug("BG Sync: skip friend " .. name)
                else
                    self:QueueBot(name)
                end
            end
        end
    end

    local found = #self.queue
    if skippedFriends > 0 then
        addon:Print(string.format(
            "BG Sync: Found %d other players (%d %s skipped).",
            found,
            skippedFriends,
            skippedFriends == 1 and "friend" or "friends"
        ))
    else
        addon:Print(string.format("BG Sync: Found %d other players.", found))
    end
    if found == 0 then
        self:Finish()
        return
    end

    self.processed = found
    self.phase = "level"
    self.index = 1
    self:ScheduleQueue(0)
end

function BGSync:ScheduleQueue(delay)
    local runId = self.runId
    addon:Debounce(QUEUE_KEY, delay or GetStepDelay(), function()
        BGSync:ProcessQueue(runId)
    end)
end

function BGSync:ProcessQueue(runId)
    if not self.active or runId ~= self.runId then
        return
    end
    if not self:IsInBattleground() then
        self:Cancel("left battleground")
        return
    end

    local queue = self.queue
    local total = #queue
    if self.index > total then
        if self.phase == "level" then
            self.phase = "gear"
            self.index = 1
            addon:Debug("BG Sync: settling before autogear")
            self:ScheduleQueue(GetSettleDelay())
            return
        end
        if self.phase == "gear" then
            self:Finish()
        end
        return
    end

    local name = queue[self.index]
    if self.phase == "level" then
        addon:Debug("BG Sync: level " .. name)
        addon:SendServerCommand(self:LevelCommand(name))
    elseif self.phase == "gear" then
        addon:Debug("BG Sync: autogear " .. name)
        SendChatMessage(GEAR_COMMAND, "WHISPER", nil, name)
    else
        addon:Debug("BG Sync: skip tick (phase=" .. tostring(self.phase) .. ")")
        return
    end

    if self.index == 1 or self.index % PROGRESS_EVERY == 0 or self.index == total then
        addon:Print(string.format(
            "BG Sync: %s %d/%d (%s)...",
            self.phase == "level" and "Level" or "Autogear",
            self.index,
            total,
            name
        ))
    end

    self.index = self.index + 1
    self:ScheduleQueue(GetStepDelay())
end

function BGSync:Start()
    if not self.enabled then
        addon:Print("BG Sync: Module is disabled.")
        return
    end
    if self.active or self.awaitingScores then
        addon:Print("BG Sync: A sync is already running.")
        return
    end
    if not self:IsInBattleground() then
        addon:Print("BG Sync: You are not currently in a battleground.")
        return
    end

    self.runId = (self.runId or 0) + 1
    self.active = true
    self.awaitingScores = true
    self.queue = {}
    self.phase = nil
    self.index = 0
    self.processed = 0
    self.level = UnitLevel("player") or 0
    self.selfName = UnitName("player")

    addon:Print("BG Sync: Reading battleground roster...")
    RequestBattlefieldScoreData()

    local runId = self.runId
    addon:Debounce(SCORE_KEY, SCORE_TIMEOUT, function()
        if BGSync.awaitingScores and BGSync.runId == runId then
            addon:Debug("BG Sync: score timeout, using cached data")
            BGSync:BuildRoster()
        end
    end)
end

function BGSync:Init(owner)
    self.addon = owner
    self.runId = 0
    self:ResetState()
    owner:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
    owner:RegisterEvent("PLAYER_ENTERING_WORLD")
    owner:RegisterEvent("PLAYER_LEAVING_WORLD")
end

function BGSync:Enable()
    self.enabled = true
end

function BGSync:Disable()
    self.enabled = false
    self:Cancel("module disabled")
end

function BGSync:OnEvent(event)
    if event == "UPDATE_BATTLEFIELD_SCORE" then
        if self.awaitingScores then
            self:BuildRoster()
        end
        return
    end
    if event == "PLAYER_LEAVING_WORLD" then
        self:Cancel("leaving world")
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        if (self.active or self.awaitingScores) and not self:IsInBattleground() then
            self:Cancel("left battleground")
        end
    end
end

function BGSync:Slash(rest)
    local arg = string.lower(addon:Trim(rest))
    if arg == "on" then
        addon:EnableModule(self)
        addon:Print("BG Sync on")
        return
    end
    if arg == "off" then
        addon:DisableModule(self)
        addon:Print("BG Sync off")
        return
    end
    if arg == "cancel" then
        if self.active or self.awaitingScores then
            self:Cancel("manual")
        else
            addon:Print("BG Sync: No sync is running.")
        end
        return
    end
    if arg == "status" then
        local cfg = GetConfig()
        local step = GetStepDelay()
        local settle = GetSettleDelay()
        if self.active or self.awaitingScores then
            addon:Print(string.format(
                "BG Sync %s | active=%s | phase=%s | progress=%d/%d | level=%s | step=%.1fs | settle=%.1fs",
                self.enabled and "on" or "off",
                self.awaitingScores and "awaiting scores" or "yes",
                tostring(self.phase or "pending"),
                math.max(0, (self.index or 1) - 1),
                self.queue and #self.queue or 0,
                tostring(self.level or "?"),
                step,
                settle
            ))
        else
            addon:Print(string.format(
                "BG Sync %s | idle | step=%.1fs | settle=%.1fs | enabledDB=%s",
                self.enabled and "on" or "off",
                step,
                settle,
                (cfg and cfg.enabled ~= false) and "yes" or "no"
            ))
        end
        return
    end
    if arg == "" or arg == "start" then
        self:Start()
        return
    end
    addon:Print("/eca bgsync [start|cancel|status|on|off]")
end

addon:RegisterModule(BGSync)
