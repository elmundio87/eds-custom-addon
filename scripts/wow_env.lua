-- Offline WoW 3.3.5a stub for loading Eds Custom Addon under LuaJIT/lupa.
wow = {
    time = 0,
    frames = {},
    sent = {},
    prints = {},
    sounds = {},
    specialFrames = {},
    state = {
        raidCount = 0,
        partyCount = 0,
        connected = {},
        isPlayer = {},
        xpDisabled = false,
        playerName = "Ed",
        playerGUID = "0x0000000000000001",
        ghost = false,
    },
}

tinsert = table.insert
UISpecialFrames = wow.specialFrames
SlashCmdList = {}
UIParent = { name = "UIParent" }

local Frame = {}
Frame.__index = Frame

local function newFrame(kind, name, parent)
    local frame = setmetatable({
        kind = kind or "Frame",
        name = name,
        parent = parent,
        shown = true,
        events = {},
        scripts = {},
        width = 0,
        height = 0,
        checked = nil,
        point = { "CENTER", nil, "CENTER", 0, 0 },
        children = {},
    }, Frame)
    table.insert(wow.frames, frame)
    if name then
        _G[name] = frame
    end
    return frame
end

function Frame:RegisterEvent(event)
    table.insert(self.events, event)
end

function Frame:SetScript(hook, fn)
    self.scripts[hook] = fn
end

function Frame:Show()
    self.shown = true
    if self.scripts.OnShow then
        self.scripts.OnShow(self)
    end
end

function Frame:Hide()
    self.shown = false
end

function Frame:IsShown()
    return self.shown and 1 or nil
end

function Frame:SetWidth(v) self.width = v end
function Frame:SetHeight(v) self.height = v end
function Frame:SetFrameStrata() end
function Frame:SetToplevel() end
function Frame:SetClampedToScreen() end
function Frame:SetMovable() end
function Frame:EnableMouse() end
function Frame:RegisterForDrag() end
function Frame:StartMoving() end
function Frame:StopMovingOrSizing() end
function Frame:SetBackdrop() end
function Frame:SetBackdropColor() end
function Frame:ClearAllPoints() end

function Frame:SetPoint(point, relativeTo, relativePoint, x, y)
    self.point = { point, relativeTo, relativePoint, x or 0, y or 0 }
end

function Frame:GetPoint()
    local p = self.point
    return p[1], p[2], p[3], p[4], p[5]
end

function Frame:CreateFontString()
    return newFrame("FontString", nil, self)
end

function Frame:SetText(text)
    self.text = text
end

function Frame:GetText()
    return self.text or ""
end

function Frame:SetAutoFocus() end
function Frame:SetFontObject() end
function Frame:SetMaxLetters() end
function Frame:ClearFocus() end
function Frame:SetFocus() end
function Frame:HighlightText() end

function Frame:SetChecked(value)
    if value and value ~= 0 then
        self.checked = 1
    else
        self.checked = nil
    end
end

function Frame:GetChecked()
    return self.checked
end

function CreateFrame(kind, name, parent, template)
    return newFrame(kind, name, parent, template)
end

function GetTime()
    return wow.time
end

function GetNumRaidMembers()
    return wow.state.raidCount
end

function GetNumPartyMembers()
    return wow.state.partyCount
end

function UnitIsConnected(unit)
    return wow.state.connected[unit] and 1 or nil
end

function UnitIsUnit(unit, other)
    if other == "player" then
        return wow.state.isPlayer[unit] and 1 or nil
    end
    return (unit == other) and 1 or nil
end

function UnitIsDeadOrGhost(unit)
    return wow.state.ghost and 1 or nil
end

function UnitName(unit)
    if unit == "player" then
        return wow.state.playerName
    end
    return unit
end

function UnitGUID(unit)
    if unit == "player" then
        return wow.state.playerGUID
    end
    return nil
end

function IsXPUserDisabled()
    return wow.state.xpDisabled and 1 or nil
end

function SendChatMessage(msg, chatType, _, target)
    chatType = chatType or "SAY"
    table.insert(wow.sent, {
        msg = msg,
        chatType = chatType,
        target = target,
    })
    -- Ghosts cannot /say; the client drops the line before the server.
    if chatType == "SAY" and wow.state.ghost then
        return
    end
    if msg == ".xp on" or msg == ".xp enable" then
        wow.state.xpDisabled = false
    elseif msg == ".xp off" or msg == ".xp disable" then
        wow.state.xpDisabled = true
    end
end

function PlaySoundFile(path)
    table.insert(wow.sounds, path)
end

function PlaySound(name)
    table.insert(wow.sounds, name)
end

DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, msg)
        table.insert(wow.prints, msg)
    end,
}

GameTooltip = {
    SetOwner = function() end,
    SetText = function() end,
    Show = function() end,
    Hide = function() end,
}

function wow.tick(elapsed)
    elapsed = elapsed or 0.05
    wow.time = wow.time + elapsed
    for _, frame in ipairs(wow.frames) do
        if frame.shown and frame.scripts.OnUpdate then
            frame.scripts.OnUpdate(frame, elapsed)
        end
    end
end

function wow.flushDebounce()
    wow.tick(0.25)
end

function wow.resetChat()
    wow.sent = {}
    wow.prints = {}
    wow.sounds = {}
end

function wow.setSolo()
    wow.state.raidCount = 0
    wow.state.partyCount = 0
    wow.state.connected = {}
    wow.state.isPlayer = {}
end

function wow.setParty(online)
    wow.state.raidCount = 0
    wow.state.partyCount = 1
    wow.state.connected = { party1 = online and true or false }
    wow.state.isPlayer = {}
end

function wow.setRaidSelfOnly()
    wow.state.raidCount = 1
    wow.state.partyCount = 0
    wow.state.connected = { raid1 = true }
    wow.state.isPlayer = { raid1 = true }
end

function wow.setRaidWithPartner(partnerOnline)
    wow.state.raidCount = 2
    wow.state.partyCount = 0
    wow.state.connected = {
        raid1 = true,
        raid2 = partnerOnline and true or false,
    }
    wow.state.isPlayer = { raid1 = true }
end
