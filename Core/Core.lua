local addon = EdsCustomAddon

addon.modules = addon.modules or {}
addon.moduleOrder = addon.moduleOrder or {}

local frame = CreateFrame("Frame", "EdsCustomAddonFrame")
addon.frame = frame

function addon:RegisterEvent(event)
    self.frame:RegisterEvent(event)
end

function addon:RegisterModule(module)
    if not module or not module.name then
        return
    end
    if self.modules[module.name] then
        return
    end
    self.modules[module.name] = module
    table.insert(self.moduleOrder, module)
end

function addon:GetModule(name)
    if not name then
        return nil
    end
    local exact = self.modules[name]
    if exact then
        return exact
    end
    local lowered = string.lower(name)
    for _, module in ipairs(self.moduleOrder) do
        if string.lower(module.name) == lowered then
            return module
        end
    end
    return nil
end

function addon:EnableModule(module)
    if type(module) == "string" then
        module = self:GetModule(module)
    end
    if not module then
        return
    end
    self:SetModuleEnabled(module.name, true)
    module.enabled = true
    if module.Enable then
        module:Enable()
    end
    if self.RefreshUI then
        self:RefreshUI()
    end
end

function addon:DisableModule(module)
    if type(module) == "string" then
        module = self:GetModule(module)
    end
    if not module then
        return
    end
    self:SetModuleEnabled(module.name, false)
    module.enabled = false
    if module.Disable then
        module:Disable()
    end
    if self.RefreshUI then
        self:RefreshUI()
    end
end

function addon:InitModules()
    for _, module in ipairs(self.moduleOrder) do
        if module.Init then
            module:Init(self)
        end
        if self:IsModuleEnabled(module.name) then
            module.enabled = true
            if module.Enable then
                module:Enable()
            end
        else
            module.enabled = false
        end
    end
end

function addon:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= self.ADDON_NAME or self.loaded then
            return
        end
        self.loaded = true
        self:LoadConfig()
        self:InitModules()
        if self.CreateUI then
            self:CreateUI()
        end
        self:Debug("loaded")
        return
    end

    for _, module in ipairs(self.moduleOrder) do
        if module.enabled and module.OnEvent then
            module:OnEvent(event, ...)
        end
    end
end

function addon:SlashHandler(msg)
    msg = self:Trim(msg or "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and string.lower(cmd) or ""
    rest = rest or ""

    if cmd == "" or cmd == "help" then
        self:Print("/eca ui")
        self:Print("/eca partyxp on|off|status")
        self:Print("/eca debug")
        return
    end

    if cmd == "ui" then
        self:ToggleUI()
        return
    end

    if cmd == "debug" then
        self.db.debug = not self.db.debug
        self:Print("debug " .. (self.db.debug and "on" or "off"))
        if self.RefreshUI then
            self:RefreshUI()
        end
        return
    end

    local module = self:GetModule(cmd)
    if module and module.Slash then
        module:Slash(rest)
        return
    end

    self:Print("unknown command: " .. cmd)
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
    addon:OnEvent(event, ...)
end)

SLASH_EDSCUSTOMADDON1 = "/eca"
SlashCmdList["EDSCUSTOMADDON"] = function(msg)
    addon:SlashHandler(msg)
end
