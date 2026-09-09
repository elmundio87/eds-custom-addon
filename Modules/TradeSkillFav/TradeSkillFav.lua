local addon = EdsCustomAddon

local TradeSkillFav = {
    name = "TradeSkillFav",
    title = "Alchemy favorites",
    tooltip = "Favorite Alchemy recipes; filter and sort the trade skill list",
}

local ALCHEMY_NAME = "Alchemy"
-- Friz Quadrata has no ★; raid-target 1 is a yellow star in 3.3.5. Drawn as a
-- texture in the row indent: inline text would push the [n] count off the frame.
local STAR_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local STAR_SIZE = 12
local DISPLAYED = 8

local function GetConfig()
    return addon.db and addon.db.modules and addon.db.modules.TradeSkillFav
end

local function GetMode()
    local cfg = GetConfig()
    local mode = cfg and cfg.mode
    if mode == "only" then
        return "only"
    end
    -- Migrate removed "first" mode to "all".
    if cfg and mode == "first" then
        cfg.mode = "all"
    end
    return "all"
end

local function SetMode(mode)
    local cfg = GetConfig()
    if not cfg then
        return
    end
    if mode ~= "only" then
        mode = "all"
    end
    cfg.mode = mode
end

local function ModeLabel(mode)
    if mode == "only" then
        return "Favourites"
    end
    return "All"
end

function TradeSkillFav:GetProfessionFavorites()
    local cfg = GetConfig()
    if not cfg then
        return {}
    end
    if type(cfg.favorites) ~= "table" then
        cfg.favorites = {}
    end
    if type(cfg.favorites[ALCHEMY_NAME]) ~= "table" then
        cfg.favorites[ALCHEMY_NAME] = {}
    end
    return cfg.favorites[ALCHEMY_NAME]
end

function TradeSkillFav:IsAlchemy()
    local name = GetTradeSkillLine and GetTradeSkillLine()
    return name == ALCHEMY_NAME
end

function TradeSkillFav:RecipeKey(index)
    if not index or index < 1 then
        return nil
    end
    local link = GetTradeSkillItemLink and GetTradeSkillItemLink(index)
    if link then
        local itemId = link:match("item:(%d+)")
        if itemId then
            return "item:" .. itemId
        end
    end
    local name, skillType = GetTradeSkillInfo(index)
    if name and skillType and skillType ~= "header" then
        return "name:" .. name
    end
    return nil
end

function TradeSkillFav:IsFavoriteKey(key)
    if not key then
        return false
    end
    return self:GetProfessionFavorites()[key] and true or false
end

function TradeSkillFav:IsFavoriteIndex(index)
    return self:IsFavoriteKey(self:RecipeKey(index))
end

function TradeSkillFav:SetFavoriteKey(key, enabled)
    if not key then
        return
    end
    local favs = self:GetProfessionFavorites()
    if enabled then
        favs[key] = true
    else
        favs[key] = nil
    end
end

function TradeSkillFav:ToggleSelectedFavorite()
    if not self:IsAlchemy() then
        return
    end
    local index = GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex() or 0
    local key = self:RecipeKey(index)
    if not key then
        return
    end
    local now = not self:IsFavoriteKey(key)
    self:SetFavoriteKey(key, now)
    addon:Debug("TradeSkillFav: " .. (now and "fav " or "unfav ") .. key)
    self:Refresh()
end

function TradeSkillFav:ExpandAllHeaders()
    if not ExpandTradeSkillSubClass or not GetNumTradeSkills or not GetTradeSkillInfo then
        return
    end
    local i = GetNumTradeSkills()
    while i > 0 do
        local _, skillType, _, isExpanded = GetTradeSkillInfo(i)
        if skillType == "header" and not isExpanded then
            ExpandTradeSkillSubClass(i)
        end
        i = i - 1
    end
end

function TradeSkillFav:BuildDisplayList()
    self.displayList = {}
    if not GetNumTradeSkills or not GetTradeSkillInfo then
        return self.displayList
    end

    local mode = GetMode()
    if mode ~= "all" then
        self:ExpandAllHeaders()
    end

    local favorites = {}
    local natural = {}

    local n = GetNumTradeSkills() or 0
    for i = 1, n do
        local name, skillType = GetTradeSkillInfo(i)
        if name and skillType and skillType ~= "header" then
            local entry = {
                index = i,
                name = name,
                key = self:RecipeKey(i),
            }
            table.insert(natural, entry)
            if self:IsFavoriteKey(entry.key) then
                table.insert(favorites, entry)
            end
        end
    end

    local function byName(a, b)
        return (a.name or "") < (b.name or "")
    end
    table.sort(favorites, byName)

    if mode == "only" then
        self.displayList = {
            { header = true, name = "Favourites" },
        }
        for i = 1, #favorites do
            table.insert(self.displayList, favorites[i])
        end
    else
        self.displayList = natural
    end
    return self.displayList
end

function TradeSkillFav:GetDisplayedCount()
    if TRADE_SKILLS_DISPLAYED and TRADE_SKILLS_DISPLAYED > 0 then
        return TRADE_SKILLS_DISPLAYED
    end
    return DISPLAYED
end

function TradeSkillFav:GetScrollOffset()
    if TradeSkillListScrollFrame and FauxScrollFrame_GetOffset then
        return FauxScrollFrame_GetOffset(TradeSkillListScrollFrame) or 0
    end
    return self.scrollOffset or 0
end

function TradeSkillFav:GetButtonText(button)
    if not button then
        return nil
    end
    local name = button.GetName and button:GetName()
    if name then
        local fs = _G[name .. "Text"]
        if fs and fs.GetText then
            return fs, fs:GetText() or ""
        end
    end
    if button.GetText then
        return button, button:GetText() or ""
    end
    return nil, ""
end

function TradeSkillFav:SetButtonLabel(button, label)
    local fs = self:GetButtonText(button)
    if fs and fs.SetText then
        fs:SetText(label)
    elseif button and button.SetText then
        button:SetText(label)
    end
end

-- Blizzard widens the name font string for headers and empty counts, which
-- would strand our [n] at the far right of a reused row.
function TradeSkillFav:SetButtonCount(button, numAvailable, label)
    local name = button and button.GetName and button:GetName()
    if not name then
        return
    end
    local textWidth = TRADE_SKILL_TEXT_WIDTH or 260
    local fs = _G[name .. "Text"]
    local count = _G[name .. "Count"]
    if not count or not count.SetText then
        return
    end
    if not numAvailable or numAvailable <= 0 then
        count:SetText("")
        if fs and fs.SetWidth then
            fs:SetWidth(textWidth)
        end
        return
    end
    count:SetText("[" .. numAvailable .. "]")
    if not fs or not fs.SetWidth then
        return
    end
    fs:SetWidth(0)
    if not label or not TradeSkillFrameDummyString or not count.GetWidth then
        return
    end
    TradeSkillFrameDummyString:SetText(label)
    local nameWidth = TradeSkillFrameDummyString:GetWidth() or 0
    local countWidth = count:GetWidth() or 0
    if nameWidth + 2 + countWidth > textWidth then
        fs:SetWidth(textWidth - 2 - countWidth)
    end
end

function TradeSkillFav:SetRowHighlightTexture(button, path)
    local name = button.GetName and button:GetName()
    local highlight = name and _G[name .. "Highlight"]
    if highlight and highlight.SetTexture then
        highlight:SetTexture(path)
    end
end

function TradeSkillFav:ApplyHeaderLook(button)
    if button.SetNormalTexture then
        button:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    end
    self:SetRowHighlightTexture(button, "Interface\\Buttons\\UI-PlusButton-Hilight")
    local tex = button.GetNormalTexture and button:GetNormalTexture()
    if tex and tex.SetPoint then
        tex:SetPoint("LEFT", button, "LEFT", 3, 0)
    end
    if button.UnlockHighlight then
        button:UnlockHighlight()
    end
    local name = button.GetName and button:GetName()
    local fs = name and _G[name .. "Text"]
    if fs and fs.SetPoint then
        fs:SetPoint("LEFT", 23, 0)
    end
    if fs and fs.SetTextColor then
        fs:SetTextColor(1, 0.82, 0)
    end
end

function TradeSkillFav:ApplyRecipeLook(button)
    if button.SetNormalTexture then
        button:SetNormalTexture("")
    end
    self:SetRowHighlightTexture(button, "")
    local name = button.GetName and button:GetName()
    local fs = name and _G[name .. "Text"]
    if fs and fs.SetPoint then
        fs:SetPoint("LEFT", 23, 0)
    end
end

function TradeSkillFav:SetButtonStar(button, show)
    if not button.favStar then
        if not button.CreateTexture then
            return
        end
        local star = button:CreateTexture(nil, "OVERLAY")
        star:SetTexture(STAR_TEXTURE)
        star:SetWidth(STAR_SIZE)
        star:SetHeight(STAR_SIZE)
        star:SetPoint("LEFT", button, "LEFT", 8, 0)
        button.favStar = star
    end
    if show then
        button.favStar:Show()
    else
        button.favStar:Hide()
    end
end

function TradeSkillFav:PaintSkillButton(button, entry)
    if not button then
        return
    end
    if not entry then
        self:SetButtonStar(button, false)
        button:Hide()
        return
    end
    if entry.header then
        self:SetButtonStar(button, false)
        self:ApplyHeaderLook(button)
        self:SetButtonLabel(button, entry.name)
        self:SetButtonCount(button, 0, entry.name)
        if button.SetID then
            button:SetID(0)
        end
        button:Show()
        return
    end

    local index = entry.index
    local name, skillType, numAvailable = GetTradeSkillInfo(index)
    if not name then
        self:SetButtonStar(button, false)
        button:Hide()
        return
    end
    self:ApplyRecipeLook(button)
    self:SetButtonStar(button, self:IsFavoriteKey(entry.key))
    self:SetButtonLabel(button, name)
    self:SetButtonCount(button, numAvailable, name)
    if button.SetID then
        button:SetID(index)
    end
    button:Show()

    local fs = _G[(button.GetName and button:GetName() or "") .. "Text"]
    local target = fs or button
    if target and target.SetTextColor and TradeSkillTypeColor and skillType and TradeSkillTypeColor[skillType] then
        local c = TradeSkillTypeColor[skillType]
        target:SetTextColor(c.r, c.g, c.b)
    end
end

function TradeSkillFav:DecorateBlizzardList()
    local count = self:GetDisplayedCount()
    for i = 1, count do
        local button = _G["TradeSkillSkill" .. i]
        if button then
            local index = button.GetID and button:GetID()
            local skillType
            if index and index > 0 then
                _, skillType = GetTradeSkillInfo(index)
            end
            if button:IsShown() and skillType and skillType ~= "header" then
                -- Keep the name clear of the star's indent slot.
                self:ApplyRecipeLook(button)
                self:SetButtonStar(button, self:IsFavoriteIndex(index))
            else
                self:SetButtonStar(button, false)
            end
        end
    end
end

function TradeSkillFav:PaintCustomList()
    local list = self.displayList or self:BuildDisplayList()
    local offset = self:GetScrollOffset()
    local count = self:GetDisplayedCount()
    local rowHeight = TRADE_SKILL_HEIGHT or 16
    if TradeSkillListScrollFrame and FauxScrollFrame_Update then
        FauxScrollFrame_Update(TradeSkillListScrollFrame, #list, count, rowHeight)
        offset = self:GetScrollOffset()
    end
    -- Blizzard anchors the selection bar by list position, which our reordered
    -- rows invalidate, so place it on the row actually holding the selection.
    local selection = GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex() or 0
    for i = 1, count do
        local button = _G["TradeSkillSkill" .. i]
        local entry = list[i + offset]
        self:PaintSkillButton(button, entry)
        local selected = entry and not entry.header and entry.index == selection
        if button then
            if selected then
                if TradeSkillHighlightFrame then
                    TradeSkillHighlightFrame:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
                    TradeSkillHighlightFrame:Show()
                end
                if button.LockHighlight then
                    button:LockHighlight()
                end
                button.isHighlighted = true
            else
                if button.UnlockHighlight then
                    button:UnlockHighlight()
                end
                button.isHighlighted = false
            end
        end
    end
end

function TradeSkillFav:OnTradeSkillUpdate()
    if not self.enabled or not self.activeAlchemy then
        return
    end
    if self.painting then
        return
    end
    self.painting = true
    local mode = GetMode()
    if mode == "all" then
        self:DecorateBlizzardList()
    else
        self:BuildDisplayList()
        self:PaintCustomList()
    end
    self:UpdateControls()
    self.painting = nil
end

function TradeSkillFav:Refresh()
    if not self.activeAlchemy then
        return
    end
    if TradeSkillFrame_Update then
        TradeSkillFrame_Update()
    else
        self:OnTradeSkillUpdate()
    end
end

function TradeSkillFav:EnsureControls()
    if self.controls or not TradeSkillFrame then
        return
    end

    -- Anchor on the detail pane (right side), never over the recipe list.
    local bar = CreateFrame("Frame", "ECA_TradeSkillFavBar", TradeSkillFrame)
    bar:SetSize(280, 28)
    if TradeSkillSkillName then
        bar:SetPoint("TOPLEFT", TradeSkillSkillName, "BOTTOMLEFT", 0, -6)
    elseif TradeSkillSkillIcon then
        bar:SetPoint("TOPLEFT", TradeSkillSkillIcon, "BOTTOMLEFT", 0, -4)
    else
        bar:SetPoint("TOPRIGHT", TradeSkillFrame, "TOPRIGHT", -36, -96)
    end
    bar:EnableMouse(false)

    local favBtn = CreateFrame("Button", "ECA_TradeSkillFavToggle", bar, "UIPanelButtonTemplate")
    favBtn:SetSize(24, 22)
    favBtn:SetPoint("LEFT", bar, "LEFT", 0, 0)
    favBtn:SetText("+")
    favBtn:SetScript("OnClick", function()
        TradeSkillFav:ToggleSelectedFavorite()
    end)
    favBtn:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Add or remove the selected recipe from Favourites", 1, 0.82, 0, 1, 1)
        GameTooltip:Show()
    end)
    favBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local filterLabel = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("LEFT", favBtn, "RIGHT", 10, 0)
    filterLabel:SetText("Filter")

    local drop = CreateFrame("Frame", "ECA_TradeSkillFavFilter", bar, "UIDropDownMenuTemplate")
    drop:SetPoint("LEFT", filterLabel, "RIGHT", -12, -2)
    UIDropDownMenu_SetWidth(drop, 100)
    UIDropDownMenu_Initialize(drop, function(_, level)
        if level and level ~= 1 then
            return
        end
        local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
        info.text = "All"
        info.func = function()
            SetMode("all")
            TradeSkillFav:Refresh()
        end
        info.checked = GetMode() == "all"
        UIDropDownMenu_AddButton(info, level or 1)

        info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
        info.text = "Favourites"
        info.func = function()
            SetMode("only")
            TradeSkillFav:Refresh()
        end
        info.checked = GetMode() == "only"
        UIDropDownMenu_AddButton(info, level or 1)
    end)
    UIDropDownMenu_SetText(drop, ModeLabel(GetMode()))

    self.controlBar = bar
    self.favButton = favBtn
    self.filterDropdown = drop
    self.controls = true
end

function TradeSkillFav:UpdateControls()
    if not self.controls then
        return
    end
    local show = self.enabled and self.activeAlchemy and true or false
    if show then
        self.controlBar:Show()
        self.favButton:Show()
        self.filterDropdown:Show()
        UIDropDownMenu_SetText(self.filterDropdown, ModeLabel(GetMode()))
        local index = GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex() or 0
        if self:IsFavoriteIndex(index) then
            self.favButton:SetText("-")
        else
            self.favButton:SetText("+")
        end
    else
        self.controlBar:Hide()
    end
end

function TradeSkillFav:SetAlchemyActive(active)
    self.activeAlchemy = active and true or false
    if active then
        self:EnsureControls()
        self:Refresh()
    else
        self:UpdateControls()
    end
end

-- Selecting a recipe repaints its row after our pass, so repaint next frame.
function TradeSkillFav:SchedulePaint()
    if not self.enabled or not self.activeAlchemy then
        return
    end
    if not self.repaintFrame then
        local frame = CreateFrame("Frame")
        frame:Hide()
        frame:SetScript("OnUpdate", function(selfFrame)
            selfFrame:Hide()
            TradeSkillFav:OnTradeSkillUpdate()
        end)
        self.repaintFrame = frame
    end
    self.repaintFrame:Show()
end

function TradeSkillFav:HookTradeSkillUpdate()
    if self.updateHooked then
        return
    end
    if not TradeSkillFrame_Update then
        return
    end
    if hooksecurefunc then
        hooksecurefunc("TradeSkillFrame_Update", function()
            TradeSkillFav:OnTradeSkillUpdate()
        end)
        if TradeSkillFrame_SetSelection then
            hooksecurefunc("TradeSkillFrame_SetSelection", function()
                TradeSkillFav:SchedulePaint()
            end)
        end
    else
        local orig = TradeSkillFrame_Update
        TradeSkillFrame_Update = function(...)
            orig(...)
            TradeSkillFav:OnTradeSkillUpdate()
        end
        local origSelect = TradeSkillFrame_SetSelection
        if origSelect then
            TradeSkillFrame_SetSelection = function(...)
                origSelect(...)
                TradeSkillFav:SchedulePaint()
            end
        end
    end
    self.updateHooked = true
end

function TradeSkillFav:Init(owner)
    self.addon = owner
    owner:RegisterEvent("TRADE_SKILL_SHOW")
    owner:RegisterEvent("TRADE_SKILL_CLOSE")
    owner:RegisterEvent("TRADE_SKILL_UPDATE")
    self:HookTradeSkillUpdate()
end

function TradeSkillFav:Enable()
    self.enabled = true
    if TradeSkillFrame and TradeSkillFrame:IsShown() and self:IsAlchemy() then
        self:SetAlchemyActive(true)
    end
end

function TradeSkillFav:Disable()
    self.enabled = false
    self.activeAlchemy = false
    self:UpdateControls()
    if TradeSkillFrame_Update and TradeSkillFrame and TradeSkillFrame:IsShown() then
        TradeSkillFrame_Update()
    end
end

function TradeSkillFav:OnEvent(event)
    if event == "TRADE_SKILL_SHOW" then
        self:HookTradeSkillUpdate()
        if self:IsAlchemy() then
            self:SetAlchemyActive(true)
        else
            self:SetAlchemyActive(false)
        end
        return
    end
    if event == "TRADE_SKILL_CLOSE" then
        self:SetAlchemyActive(false)
        return
    end
    if event == "TRADE_SKILL_UPDATE" then
        if self.activeAlchemy then
            self:UpdateControls()
        end
        return
    end
end

function TradeSkillFav:Slash(rest)
    local arg = string.lower(addon:Trim(rest or ""))
    if arg == "on" then
        addon:EnableModule(self)
        addon:Print("Alchemy favorites on")
        return
    end
    if arg == "off" then
        addon:DisableModule(self)
        addon:Print("Alchemy favorites off")
        return
    end
    if arg == "all" then
        SetMode("all")
        addon:Print("Alchemy favorites filter=All")
        self:Refresh()
        return
    end
    if arg == "favourites" or arg == "favorites" or arg == "only" then
        SetMode("only")
        addon:Print("Alchemy favorites filter=Favourites")
        self:Refresh()
        return
    end
    local count = 0
    local favs = self:GetProfessionFavorites()
    for _ in pairs(favs) do
        count = count + 1
    end
    addon:Print(string.format(
        "Alchemy favorites %s | filter=%s | count=%d",
        self.enabled and "on" or "off",
        ModeLabel(GetMode()),
        count
    ))
    if arg ~= "" and arg ~= "status" then
        addon:Print("/eca tradeskillfav [on|off|all|favourites|status]")
    end
end

addon:RegisterModule(TradeSkillFav)
