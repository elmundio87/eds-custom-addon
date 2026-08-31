local addon = EdsCustomAddon

addon.defaults = {
    debug = false,
    ui = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
    xp = {
        enable = ".xp enable",
        disable = ".xp disable",
    },
    modules = {
        PartyXP = {
            enabled = true,
        },
    },
}

local function CopyDefaults(dest, src)
    if type(dest) ~= "table" then
        dest = {}
    end
    for key, value in pairs(src) do
        if type(value) == "table" then
            dest[key] = CopyDefaults(dest[key], value)
        elseif dest[key] == nil then
            dest[key] = value
        end
    end
    return dest
end

function addon:LoadConfig()
    EdsCustomAddonDB = CopyDefaults(EdsCustomAddonDB, self.defaults)
    self.db = EdsCustomAddonDB
end

function addon:IsModuleEnabled(name)
    local entry = self.db and self.db.modules and self.db.modules[name]
    if not entry then
        return true
    end
    return entry.enabled ~= false
end

function addon:SetModuleEnabled(name, enabled)
    if not self.db.modules[name] then
        self.db.modules[name] = {}
    end
    self.db.modules[name].enabled = enabled and true or false
end
