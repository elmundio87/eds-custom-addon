-- Offline WoW 3.3.5a stub for loading Eds Custom Addon under LuaJIT/lupa.
wow = {
    time = 0,
    frames = {},
    sent = {},
    prints = {},
    sounds = {},
    combatText = {},
    specialFrames = {},
    state = {
        raidCount = 0,
        partyCount = 0,
        connected = {},
        isPlayer = {},
        xpDisabled = false,
        playerName = "Ed",
        playerGUID = "0x0000000000000001",
        playerClass = "SHAMAN",
        ghost = false,
        inventory = {},
        weaponEnchants = { main = false, off = false, mainExp = 0, offExp = 0 },
        targetGUID = nil,
        targetHealth = 0,
        targetHealthMax = 0,
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
function Frame:SetSize(w, h) self.width = w; self.height = h end
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
function Frame:SetBackdropBorderColor() end
function Frame:ClearAllPoints() end
function Frame:SetScrollChild(child)
    self.scrollChild = child
    if child then
        child.parent = self
    end
end
function Frame:SetHighlightTexture() end
function Frame:Disable() self.disabled = true end
function Frame:Enable() self.disabled = nil end

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

function Frame:SetTextColor(r, g, b, a)
    self.textColor = { r, g, b, a }
end

function Frame:SetFont(font, size, flags)
    self.font = font
    self.fontSize = size
    self.fontFlags = flags
end

function Frame:GetFont()
    return self.font or "Fonts\\FRIZQT__.TTF", self.fontSize or 12, self.fontFlags or ""
end

function Frame:SetAutoFocus() end
function Frame:SetFontObject() end
function Frame:SetNumeric() end
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
    if unit == "target" then
        return wow.state.targetGUID
    end
    return nil
end

function UnitHealth(unit)
    if unit == "target" then
        return wow.state.targetHealth or 0
    end
    return 0
end

function UnitHealthMax(unit)
    if unit == "target" then
        return wow.state.targetHealthMax or 0
    end
    return 0
end

function UnitClass(unit)
    if unit == "player" then
        return "Shaman", wow.state.playerClass or "SHAMAN"
    end
    return "Unknown", "UNKNOWN"
end

function GetInventoryItemLink(unit, slot)
    if unit ~= "player" then
        return nil
    end
    local item = wow.state.inventory[slot]
    if not item then
        return nil
    end
    return item.link or ("|cff9d9d9d|Hitem:" .. tostring(slot) .. ":0:0:0:0:0:0:0:0|h[Stub]|h|r")
end

function GetItemInfo(link)
    if wow.state.itemInfoDelayed then
        return nil
    end
    for _, item in pairs(wow.state.inventory) do
        if item.link == link then
            return item.name or "Stub",
                link,
                item.quality or 1,
                item.level or 1,
                item.reqLevel or 1,
                item.itemType or "Weapon",
                item.subType or "Axe",
                item.stackCount or 1,
                item.equipLoc or "INVTYPE_WEAPON"
        end
    end
    local slot = link and link:match("item:(%d+)")
    if slot then
        local item = wow.state.inventory[tonumber(slot)]
        if item then
            return item.name or "Stub",
                link,
                item.quality or 1,
                item.level or 1,
                item.reqLevel or 1,
                item.itemType or "Weapon",
                item.subType or "Axe",
                item.stackCount or 1,
                item.equipLoc or "INVTYPE_WEAPON"
        end
    end
    return nil
end

function GetWeaponEnchantInfo()
    if wow.state.weaponEnchantStale then
        return false, 0, 0, false, 0, 0
    end
    local enchants = wow.state.weaponEnchants or {}
    return enchants.main and true or false,
        enchants.mainExp or 0,
        0,
        enchants.off and true or false,
        enchants.offExp or 0,
        0
end

function GetInventorySlotInfo(slotName)
    if slotName == "MainHandSlot" then
        return 16
    end
    if slotName == "SecondaryHandSlot" then
        return 17
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

COMBAT_TEXT_SCROLL_FUNCTION = function() end
COMBAT_TEXT_TO_ANIMATE = {}
COMBAT_TEXT_LOCATIONS = { startX = 0, startY = 0, endX = 0, endY = 0 }

function CombatText_StandardScroll() end

local function newCombatTextLine(msg, r, g, b, displayType)
    local line = {
        msg = msg,
        hidden = false,
        alpha = 1,
        startX = 0,
        startY = 0,
        endY = 0,
        yPos = 0,
        scrollFunction = nil,
        GetText = function(self)
            return self.msg
        end,
        Hide = function(self)
            self.hidden = true
        end,
        SetAlpha = function(self, value)
            self.alpha = value
        end,
        ClearAllPoints = function() end,
        SetPoint = function(self, _, _, _, x, y)
            self.startX = x or 0
            self.startY = y or 0
            self.yPos = y or 0
        end,
    }
    return line
end

function CombatText_AddMessage(msg, scroll, r, g, b, displayType, staggered)
    local line = newCombatTextLine(msg, r, g, b, displayType)
    line.scrollFunction = scroll
    table.insert(COMBAT_TEXT_TO_ANIMATE, line)
    table.insert(wow.combatText, {
        msg = msg,
        r = r,
        g = g,
        b = b,
        displayType = displayType,
    })
end

function CombatText_RemoveMessage(line)
    for i = #COMBAT_TEXT_TO_ANIMATE, 1, -1 do
        if COMBAT_TEXT_TO_ANIMATE[i] == line then
            table.remove(COMBAT_TEXT_TO_ANIMATE, i)
            break
        end
    end
    line:Hide()
    line:SetAlpha(0)
    for i = #wow.combatText, 1, -1 do
        if wow.combatText[i].msg == line.msg then
            table.remove(wow.combatText, i)
            break
        end
    end
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

local function attachTooltipMethods(frame)
    frame.lines = frame.lines or {}
    frame.SetOwner = frame.SetOwner or function() end
    frame.Show = frame.Show or function() end
    frame.Hide = frame.Hide or function() end
    frame.ClearLines = function(self)
        self.lines = {}
    end
    frame.NumLines = function(self)
        return #self.lines
    end
    frame.SetInventoryItem = function(self, unit, slot)
        self.lines = {}
        if unit ~= "player" then
            return
        end
        local item = wow.state.inventory[slot]
        if not item then
            return
        end
        table.insert(self.lines, item.name or "Weapon")
        if item.extraLines then
            for _, extra in ipairs(item.extraLines) do
                table.insert(self.lines, extra)
            end
        elseif item.itemType == "Weapon" and not item.tooltipMinimal then
            table.insert(self.lines, item.statLine or "+10 Damage")
        end
        if item.enchantText and not wow.state.tooltipHideEnchant then
            table.insert(self.lines, item.enchantText)
        end
        for i, text in ipairs(self.lines) do
            local key = (self.name or "GameTooltip") .. "TextLeft" .. i
            local fs = _G[key]
            if not fs then
                fs = newFrame("FontString")
                fs.name = key
                _G[key] = fs
            end
            fs:SetText(text)
        end
    end
end

local baseCreateFrame = CreateFrame
function CreateFrame(kind, name, parent, template)
    local frame = baseCreateFrame(kind, name, parent, template)
    if kind == "GameTooltip" or name == "ECA_WindfuryScanTooltip" then
        frame.name = name
        attachTooltipMethods(frame)
    end
    return frame
end

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
    wow.combatText = {}
    COMBAT_TEXT_TO_ANIMATE = {}
    wow.state.targetGUID = nil
    wow.state.targetHealth = 0
    wow.state.targetHealthMax = 0
end

function wow.resetInventory()
    wow.state.inventory = {}
    wow.state.weaponEnchants = { main = false, off = false, mainExp = 0, offExp = 0 }
    wow.state.weaponEnchantStale = false
    wow.state.tooltipHideEnchant = false
    wow.state.itemInfoDelayed = false
    wow.state.playerClass = "SHAMAN"
end

function wow.setInventorySlot(slot, item)
    wow.state.inventory[slot] = item
    if item and item.enchantText and item.enchantText:find("Windfury") then
        local expMs = item.enchantExpirationMs or 1800000
        if slot == 16 then
            wow.state.weaponEnchants.main = true
            wow.state.weaponEnchants.mainExp = expMs
        elseif slot == 17 then
            wow.state.weaponEnchants.off = true
            wow.state.weaponEnchants.offExp = expMs
        end
    elseif slot == 16 then
        wow.state.weaponEnchants.main = false
        wow.state.weaponEnchants.mainExp = 0
    elseif slot == 17 then
        wow.state.weaponEnchants.off = false
        wow.state.weaponEnchants.offExp = 0
    end
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
