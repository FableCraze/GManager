---@diagnostic disable: undefined-global, undefined-field, deprecated

local ADDON_NAME = "GManager"
local GM = CreateFrame("Frame", "GManagerEventFrame")
_G.GManager = GM

local FONT = "Fonts\\FRIZQT__.TTF"
local FONT_BOLD = "Fonts\\FRIZQT__.TTF"
local WHITE = "|cffffffff"
local GOLD = "|cffffd100"
local GREEN = "|cff40ff40"
local RED = "|cffff4040"
local BLUE = "|cff69ccf0"
local ORANGE = "|cffffa500"
local GRAY = "|cffaaaaaa"
local RESET = "|r"

local CLASS_ORDER = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

local CLASS_ICONS = {
    WARRIOR = "Interface\\Icons\\ClassIcon_Warrior",
    PALADIN = "Interface\\Icons\\ClassIcon_Paladin",
    HUNTER = "Interface\\Icons\\ClassIcon_Hunter",
    ROGUE = "Interface\\Icons\\ClassIcon_Rogue",
    PRIEST = "Interface\\Icons\\ClassIcon_Priest",
    DEATHKNIGHT = "Interface\\Icons\\ClassIcon_DeathKnight",
    SHAMAN = "Interface\\Icons\\ClassIcon_Shaman",
    MAGE = "Interface\\Icons\\ClassIcon_Mage",
    WARLOCK = "Interface\\Icons\\ClassIcon_Warlock",
    DRUID = "Interface\\Icons\\ClassIcon_Druid",
}

local DEFAULTS = {
    version = 5,
    minimap = {
        hide = false,
        angle = 225,
        radius = 80,
    },
    window = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        locked = false,
    },
    ui = {
        lastPage = "overview",
        rosterOnlineOnly = true,
        rosterSearch = "",
    },
    invite = {
        delay = 15,
        guildMessage = "",
        keyword = "inv",
        level80Only = true,
    },
    recruit = {
        channel = 1,
        interval = 68,
        message = "",
    },
    kick = {
        search = "",
        inactiveOnly = false,
        inactiveDays = 30,
    },
    restrictedZones = {
        ["The Ruby Sanctum"] = true,
        ["Icecrown Citadel"] = true,
        ["Santuário Rubi"] = true,
        ["Cidadela da Coroa de Gelo"] = true,
    },
}

local UI = {
    frame = nil,
    headerTitle = nil,
    statusText = nil,
    pages = {},
    navButtons = {},
    currentPage = nil,
    minimapButton = nil,
    menuFrame = nil,
}

local runtime = {
    timers = {},
    massInviteActive = false,
    inviteQueue = nil,
    inviteQueueIndex = 1,
    massInviteEnds = nil,
    pendingAutoInvites = {},
    kickQueue = nil,
    kickQueueIndex = 1,
    rankJob = nil,
    rosterData = {},
    removeResults = {},
    removeSelection = {},
    refreshPending = false,
}

local function Trim(value)
    if value == nil then
        return ""
    end
    value = tostring(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Lower(value)
    return string.lower(Trim(value))
end

local function ShortName(name)
    if not name then
        return nil
    end
    return name:match("^[^-]+") or name
end

local function ContainsPlain(haystack, needle)
    haystack = Lower(haystack)
    needle = Lower(needle)
    if needle == "" then
        return false
    end
    return string.find(haystack, needle, 1, true) ~= nil
end

local function CopyDefaults(destination, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(destination[key]) ~= "table" then
                destination[key] = {}
            end
            CopyDefaults(destination[key], value)
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
end

local function ReplaceTable(destination, source)
    for key in pairs(destination) do
        destination[key] = nil
    end
    CopyDefaults(destination, source)
end

local function Round(value)
    return math.floor((value or 0) + 0.5)
end

local function GetClassColorCode(classToken)
    local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if not color then
        return "ffffffff"
    end
    return string.format(
        "ff%02x%02x%02x",
        Round(color.r * 255),
        Round(color.g * 255),
        Round(color.b * 255)
    )
end

local function ColorClassName(name, classToken)
    return "|c" .. GetClassColorCode(classToken) .. (name or "Desconhecido") .. RESET
end

local function IsInGuildSafe()
    if IsInGuild then
        return IsInGuild()
    end
    return GetGuildInfo("player") ~= nil
end

local function IsRaidGroup()
    return GetNumRaidMembers and GetNumRaidMembers() > 0
end

local function IsPartyGroup()
    return GetNumPartyMembers and GetNumPartyMembers() > 0
end

local function GetGuildCounts()
    local total, online = GetNumGuildMembers(true)
    total = tonumber(total) or 0
    online = tonumber(online)

    local countedOnline = 0
    local onlineMaxLevel = 0
    for index = 1, total do
        local _, _, _, level, _, _, _, _, isOnline = GetGuildRosterInfo(index)
        if isOnline then
            countedOnline = countedOnline + 1
            if tonumber(level) == 80 then
                onlineMaxLevel = onlineMaxLevel + 1
            end
        end
    end

    if online == nil then
        online = countedOnline
    end

    return total, online, onlineMaxLevel
end

local function GetGuildMember(index)
    local name, rankName, rankIndex, level, className, zone, publicNote,
        officerNote, online, status, classToken = GetGuildRosterInfo(index)

    if not name then
        return nil
    end

    local yearsOffline, monthsOffline, daysOffline, hoursOffline = 0, 0, 0, 0
    local lastOnlineKnown = online and true or false

    if not online and GetGuildRosterLastOnline then
        local years, months, days, hours = GetGuildRosterLastOnline(index)
        if years ~= nil or months ~= nil or days ~= nil or hours ~= nil then
            yearsOffline = tonumber(years) or 0
            monthsOffline = tonumber(months) or 0
            daysOffline = tonumber(days) or 0
            hoursOffline = tonumber(hours) or 0
            lastOnlineKnown = true
        end
    end

    -- A API do WotLK retorna o tempo separado em anos, meses, dias e horas.
    -- Para os filtros, convertemos o valor para uma quantidade aproximada de horas.
    local lastOnlineHours = 0
    if not online and lastOnlineKnown then
        lastOnlineHours = (((yearsOffline * 12) + monthsOffline) * 30.5 + daysOffline) * 24 + hoursOffline
    end

    return {
        index = index,
        name = name,
        shortName = ShortName(name),
        rankName = rankName or "-",
        rankIndex = tonumber(rankIndex) or 0,
        level = tonumber(level) or 0,
        className = className or "-",
        classToken = classToken,
        zone = zone or "-",
        publicNote = publicNote or "",
        officerNote = officerNote or "",
        online = online and true or false,
        status = status,
        lastOnlineKnown = lastOnlineKnown,
        yearsOffline = yearsOffline,
        monthsOffline = monthsOffline,
        daysOffline = daysOffline,
        hoursOffline = hoursOffline,
        lastOnlineHours = lastOnlineHours,
        lastOnlineDays = lastOnlineHours / 24,
    }
end

local function GetGuildMembers()
    local members = {}
    local total = select(1, GetGuildCounts())
    for index = 1, total do
        local member = GetGuildMember(index)
        if member then
            table.insert(members, member)
        end
    end
    return members
end

local function FindGuildMember(name)
    local search = Lower(ShortName(name))
    if search == "" then
        return nil
    end

    local members = GetGuildMembers()
    for _, member in ipairs(members) do
        if Lower(member.shortName) == search then
            return member
        end
    end
    return nil
end

local function GetDKPText(officerNote)
    officerNote = Trim(officerNote)
    if officerNote == "" then
        return "-"
    end

    local net = officerNote:match("[Nn][Ee][Tt]:%s*(-?%d+)")
    if net then
        return net .. " DKP"
    end

    if FindGuildMember(officerNote) then
        return "ALT"
    end

    return "-"
end

local function SetBackdrop(frame, bgColor, borderColor)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    if bgColor then
        frame:SetBackdropColor(unpack(bgColor))
    end
    if borderColor then
        frame:SetBackdropBorderColor(unpack(borderColor))
    end
end

local function CreateFont(parent, size, color, justify)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, size or 12, size and size >= 14 and "OUTLINE" or nil)
    text:SetTextColor(unpack(color or { 1, 1, 1, 1 }))
    text:SetJustifyH(justify or "LEFT")
    text:SetJustifyV("MIDDLE")
    return text
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 120, height or 28)
    SetBackdrop(button, { 0.09, 0.09, 0.11, 0.98 }, { 0.62, 0.42, 0.12, 1 })

    button.text = CreateFont(button, 12, { 1, 0.82, 0.10, 1 }, "CENTER")
    button.text:SetPoint("CENTER", 0, 0)
    button.text:SetText(text or "Button")

    button:SetScript("OnEnter", function(self)
        if self.enabled ~= false then
            self:SetBackdropColor(0.16, 0.13, 0.08, 1)
            self:SetBackdropBorderColor(1, 0.72, 0.15, 1)
        end
    end)
    button:SetScript("OnLeave", function(self)
        if self.enabled ~= false then
            self:SetBackdropColor(0.09, 0.09, 0.11, 0.98)
            self:SetBackdropBorderColor(0.62, 0.42, 0.12, 1)
        end
    end)

    function button:SetText(value)
        self.text:SetText(value or "")
    end

    function button:SetEnabledState(enabled)
        self.enabled = enabled and true or false
        self:EnableMouse(self.enabled)
        if self.enabled then
            self:SetBackdropColor(0.09, 0.09, 0.11, 0.98)
            self:SetBackdropBorderColor(0.62, 0.42, 0.12, 1)
            self.text:SetTextColor(1, 0.82, 0.10, 1)
        else
            self:SetBackdropColor(0.06, 0.06, 0.07, 0.75)
            self:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.8)
            self.text:SetTextColor(0.45, 0.45, 0.45, 1)
        end
    end

    button:SetEnabledState(true)
    return button
end

local function CreateLabel(parent, text, size, color, width, height, justify)
    local label = CreateFont(parent, size or 12, color or { 0.9, 0.9, 0.9, 1 }, justify or "LEFT")
    if width and height then
        label:SetSize(width, height)
    elseif width then
        label:SetWidth(width)
    end
    label:SetText(text or "")
    return label
end

local function CreateSection(parent, title, x, y, width, height)
    local section = CreateFrame("Frame", nil, parent)
    section:SetPoint("TOPLEFT", x, y)
    section:SetSize(width, height)
    SetBackdrop(section, { 0.045, 0.045, 0.055, 0.96 }, { 0.30, 0.30, 0.34, 1 })

    section.title = CreateLabel(section, title or "", 12, { 1, 0.82, 0.10, 1 }, width - 20, 20)
    section.title:SetPoint("TOPLEFT", 12, -7)

    section.separator = section:CreateTexture(nil, "ARTWORK")
    section.separator:SetTexture(1, 0.82, 0.10, 0.25)
    section.separator:SetPoint("TOPLEFT", 10, -29)
    section.separator:SetPoint("TOPRIGHT", -10, -29)
    section.separator:SetHeight(1)
    return section
end

local function CreateEditBox(parent, labelText, width, height, multiline)
    local wrapper = CreateFrame("Frame", nil, parent)
    wrapper:SetSize(width, height or 50)

    wrapper.label = CreateLabel(wrapper, labelText or "", 11, { 0.95, 0.78, 0.16, 1 }, width, 16)
    wrapper.label:SetPoint("TOPLEFT", 0, 0)

    local boxHeight = multiline and ((height or 110) - 22) or 26
    local border = CreateFrame("Frame", nil, wrapper)
    border:SetPoint("TOPLEFT", 0, -20)
    border:SetSize(width, boxHeight)
    SetBackdrop(border, { 0.018, 0.018, 0.022, 1 }, { 0.28, 0.28, 0.32, 1 })

    local edit
    if multiline then
        local scroll = CreateFrame("ScrollFrame", nil, border, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 7, -6)
        scroll:SetPoint("BOTTOMRIGHT", -25, 6)

        edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFont(FONT, 12)
        edit:SetWidth(math.max(20, width - 45))
        edit:SetHeight(math.max(200, boxHeight * 4))
        edit:SetTextColor(0.95, 0.95, 0.95, 1)
        edit:SetJustifyH("LEFT")
        edit:SetJustifyV("TOP")
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scroll:SetScrollChild(edit)
        wrapper.scroll = scroll
    else
        edit = CreateFrame("EditBox", nil, border)
        edit:SetPoint("TOPLEFT", 8, -3)
        edit:SetPoint("BOTTOMRIGHT", -8, 3)
        edit:SetAutoFocus(false)
        edit:SetFont(FONT, 12)
        edit:SetTextColor(0.95, 0.95, 0.95, 1)
        edit:SetJustifyH("LEFT")
        edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    end

    edit:SetScript("OnEditFocusGained", function()
        border:SetBackdropBorderColor(0.90, 0.62, 0.14, 1)
    end)
    edit:HookScript("OnEditFocusLost", function()
        border:SetBackdropBorderColor(0.28, 0.28, 0.32, 1)
    end)

    wrapper.border = border
    wrapper.edit = edit
    return wrapper
end

local function CreateCheckBox(parent, text)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check.text = CreateLabel(check, text or "", 11, { 0.88, 0.88, 0.88, 1 })
    check.text:SetPoint("LEFT", check, "RIGHT", 2, 0)

    function check:SetLabel(value)
        self.text:SetText(value or "")
    end

    return check
end

local function CreateDropdown(parent, labelText, width)
    local wrapper = CreateFrame("Frame", nil, parent)
    wrapper:SetSize(width, 50)

    wrapper.label = CreateLabel(wrapper, labelText or "", 11, { 0.95, 0.78, 0.16, 1 }, width, 16)
    wrapper.label:SetPoint("TOPLEFT", 0, 0)

    wrapper.button = CreateButton(wrapper, "Selecione...", width, 27)
    wrapper.button:SetPoint("TOPLEFT", 0, -20)
    wrapper.options = {}
    wrapper.value = nil

    function wrapper:SetOptions(options)
        self.options = options or {}
    end

    function wrapper:SetValue(value, silent)
        self.value = value
        local display = nil
        for _, option in ipairs(self.options) do
            if option.value == value then
                display = option.text
                break
            end
        end
        self.button:SetText(display or "Selecione...")
        if not silent and self.OnValueChanged then
            self.OnValueChanged(value)
        end
    end

    wrapper.button:SetScript("OnClick", function()
        local menu = {}
        for _, option in ipairs(wrapper.options) do
            table.insert(menu, {
                text = option.text,
                value = option.value,
                checked = wrapper.value == option.value,
                func = function()
                    wrapper:SetValue(option.value, false)
                end,
            })
        end
        if #menu == 0 then
            table.insert(menu, { text = "Nenhuma opção disponível", disabled = true })
        end
        EasyMenu(menu, UI.menuFrame, wrapper.button, 0, 0, "MENU")
    end)

    return wrapper
end

local function CreatePage(parent, title, description)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    page.title = CreateLabel(page, title, 20, { 1, 0.82, 0.10, 1 }, 650, 28)
    page.title:SetPoint("TOPLEFT", 16, -12)

    page.description = CreateLabel(page, description or "", 11, { 0.62, 0.62, 0.66, 1 }, 650, 34)
    page.description:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -2)
    page.description:SetJustifyV("TOP")

    page.divider = page:CreateTexture(nil, "ARTWORK")
    page.divider:SetTexture(1, 0.82, 0.10, 0.28)
    page.divider:SetPoint("TOPLEFT", 16, -75)
    page.divider:SetPoint("TOPRIGHT", -16, -75)
    page.divider:SetHeight(1)

    page:Hide()
    return page
end

local function SetStatus(message, printToChat)
    message = message or "Pronto."
    if UI.statusText then
        UI.statusText:SetText(message)
    end
    if printToChat then
        DEFAULT_CHAT_FRAME:AddMessage(GOLD .. "GManager: " .. RESET .. message)
    end
end

local function ShowPopup(title, message, onAccept)
    if not StaticPopupDialogs.GMANAGER_CONFIRM then
        StaticPopupDialogs.GMANAGER_CONFIRM = {
            text = "%s",
            button1 = ACCEPT,
            button2 = CANCEL,
            OnAccept = function(self)
                if self.data and self.data.callback then
                    self.data.callback()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    local dialog = StaticPopup_Show("GMANAGER_CONFIRM", title .. "\n\n" .. message)
    if dialog then
        dialog.data = { callback = onAccept }
    end
end

local function ScheduleTimer(name, delay, callback, repeating)
    local safeDelay = math.max(0, tonumber(delay) or 0)
    runtime.timers[name] = {
        executeAt = GetTime() + safeDelay,
        interval = math.max(0.01, safeDelay),
        callback = callback,
        repeating = repeating and true or false,
    }
end

local function CancelTimer(name)
    runtime.timers[name] = nil
end

local function CancelAllTimers()
    for name in pairs(runtime.timers) do
        runtime.timers[name] = nil
    end
end

local function RequestGuildRoster()
    if not IsInGuildSafe() then
        return
    end
    if GuildRoster then
        GuildRoster()
    end
end

local function Atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end
    return 0
end

local function UpdateMinimapButtonPosition()
    if not UI.minimapButton or not GManagerDB then
        return
    end
    local angle = math.rad(GManagerDB.minimap.angle or 225)
    local radius = GManagerDB.minimap.radius or 80
    UI.minimapButton:ClearAllPoints()
    UI.minimapButton:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(angle) * radius,
        math.sin(angle) * radius
    )
end

local function SaveWindowPosition()
    if not UI.frame or not GManagerDB then
        return
    end
    local point, _, relativePoint, x, y = UI.frame:GetPoint(1)
    GManagerDB.window.point = point or "CENTER"
    GManagerDB.window.relativePoint = relativePoint or "CENTER"
    GManagerDB.window.x = Round(x or 0)
    GManagerDB.window.y = Round(y or 0)
end

local function RestoreWindowPosition()
    if not UI.frame or not GManagerDB then
        return
    end
    UI.frame:ClearAllPoints()
    UI.frame:SetPoint(
        GManagerDB.window.point or "CENTER",
        UIParent,
        GManagerDB.window.relativePoint or "CENTER",
        GManagerDB.window.x or 0,
        GManagerDB.window.y or 0
    )
end

local function FormatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local minutes = math.floor(seconds / 60)
    local remain = seconds % 60
    if minutes > 0 then
        return string.format("%dm %02ds", minutes, remain)
    end
    return remain .. "s"
end

-- -----------------------------------------------------------------------------
-- Janela principal e navegação
-- -----------------------------------------------------------------------------

local NAV_ITEMS = {
    { key = "overview", text = "Visão geral", icon = "Interface\\Icons\\INV_Misc_Note_05" },
    { key = "roster", text = "Membros", icon = "Interface\\Icons\\INV_Misc_GroupLooking" },
    { key = "member", text = "Convidar / Editar", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore" },
    { key = "remove", text = "Kickar Personagens", icon = "Interface\\Icons\\Ability_DualWield" },
    { key = "raid", text = "Montador de Grupos", icon = "Interface\\Icons\\Spell_Holy_PrayerOfSpirit" },
    { key = "recruit", text = "Recrutamento", icon = "Interface\\Icons\\INV_Letter_15" },
    { key = "settings", text = "Configurações", icon = "Interface\\Icons\\Trade_Engineering" },
}

local RefreshPage
local SelectPage
local ToggleFrame

local function CreateMainFrame()
    if UI.frame then
        return UI.frame
    end

    UI.menuFrame = CreateFrame("Frame", "GManagerNativeDropdownMenu", UIParent, "UIDropDownMenuTemplate")

    local frame = CreateFrame("Frame", "GManagerMainFrame", UIParent)
    UI.frame = frame
    frame:SetSize(900, 630)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    SetBackdrop(frame, { 0.018, 0.018, 0.024, 0.99 }, { 0.68, 0.46, 0.13, 1 })
    RestoreWindowPosition()

    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not GManagerDB.window.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        SaveWindowPosition()
    end)
    frame:SetScript("OnHide", function()
        SaveWindowPosition()
    end)

    local top = CreateFrame("Frame", nil, frame)
    top:SetPoint("TOPLEFT", 4, -4)
    top:SetPoint("TOPRIGHT", -4, -4)
    top:SetHeight(54)
    SetBackdrop(top, { 0.045, 0.038, 0.028, 1 }, { 0.32, 0.25, 0.12, 1 })

    local emblem = top:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(36, 36)
    emblem:SetPoint("LEFT", 12, 0)
    emblem:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    emblem:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    UI.headerTitle = CreateLabel(top, "Guild Manager", 16, { 1, 0.82, 0.10, 1 }, 600, 22)
    UI.headerTitle:SetPoint("LEFT", emblem, "RIGHT", 10, 8)

    local subtitle = CreateLabel(top, "Gerenciador de Guildas para World of Warcraft", 10, { 0.62, 0.62, 0.66, 1 }, 600, 18)
    subtitle:SetPoint("LEFT", emblem, "RIGHT", 10, -10)

    local close = CreateFrame("Button", nil, top, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() frame:Hide() end)

    local nav = CreateFrame("Frame", nil, frame)
    nav:SetPoint("TOPLEFT", 4, -62)
    nav:SetPoint("BOTTOMLEFT", 4, 34)
    nav:SetWidth(190)
    SetBackdrop(nav, { 0.028, 0.028, 0.035, 0.99 }, { 0.22, 0.22, 0.25, 1 })

    local navTitle = CreateLabel(nav, "NAVEGAÇÃO", 10, { 0.58, 0.58, 0.62, 1 }, 160, 18)
    navTitle:SetPoint("TOPLEFT", 15, -12)

    for index, item in ipairs(NAV_ITEMS) do
        local button = CreateFrame("Button", nil, nav)
        button:SetSize(166, 42)
        button:SetPoint("TOPLEFT", 12, -36 - ((index - 1) * 47))
        SetBackdrop(button, { 0.045, 0.045, 0.055, 0.90 }, { 0.16, 0.16, 0.18, 1 })
        button.pageKey = item.key

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(24, 24)
        button.icon:SetPoint("LEFT", 10, 0)
        button.icon:SetTexture(item.icon)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        button.label = CreateLabel(button, item.text, 11, { 0.82, 0.82, 0.84, 1 }, 118, 24)
        button.label:SetPoint("LEFT", button.icon, "RIGHT", 9, 0)

        button:SetScript("OnClick", function(self)
            SelectPage(self.pageKey)
        end)
        button:SetScript("OnEnter", function(self)
            if UI.currentPage ~= self.pageKey then
                self:SetBackdropColor(0.075, 0.065, 0.048, 0.98)
                self:SetBackdropBorderColor(0.45, 0.32, 0.12, 1)
            end
        end)
        button:SetScript("OnLeave", function(self)
            if UI.currentPage ~= self.pageKey then
                self:SetBackdropColor(0.045, 0.045, 0.055, 0.90)
                self:SetBackdropBorderColor(0.16, 0.16, 0.18, 1)
            end
        end)
        UI.navButtons[item.key] = button
    end

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 6, 0)
    content:SetPoint("BOTTOMRIGHT", -4, 34)
    SetBackdrop(content, { 0.026, 0.026, 0.033, 0.99 }, { 0.22, 0.22, 0.25, 1 })
    UI.content = content

    local status = CreateFrame("Frame", nil, frame)
    status:SetPoint("BOTTOMLEFT", 4, 4)
    status:SetPoint("BOTTOMRIGHT", -4, 4)
    status:SetHeight(26)
    SetBackdrop(status, { 0.035, 0.035, 0.042, 1 }, { 0.20, 0.20, 0.22, 1 })

    UI.statusText = CreateLabel(status, "Pronto.", 10, { 0.72, 0.72, 0.75, 1 }, 850, 18)
    UI.statusText:SetPoint("LEFT", 10, 0)

    frame:Hide()
    return frame
end

local function UpdateNavigation()
    for key, button in pairs(UI.navButtons) do
        if key == UI.currentPage then
            button:SetBackdropColor(0.12, 0.09, 0.035, 1)
            button:SetBackdropBorderColor(0.95, 0.65, 0.12, 1)
            button.label:SetTextColor(1, 0.82, 0.10, 1)
        else
            button:SetBackdropColor(0.045, 0.045, 0.055, 0.90)
            button:SetBackdropBorderColor(0.16, 0.16, 0.18, 1)
            button.label:SetTextColor(0.82, 0.82, 0.84, 1)
        end
    end
end

-- -----------------------------------------------------------------------------
-- Página: visão geral
-- -----------------------------------------------------------------------------

local function CreateStatCard(parent, x, y, width, title, valueColor)
    local card = CreateFrame("Frame", nil, parent)
    card:SetPoint("TOPLEFT", x, y)
    card:SetSize(width, 82)
    SetBackdrop(card, { 0.042, 0.042, 0.052, 1 }, { 0.22, 0.22, 0.25, 1 })

    card.title = CreateLabel(card, title, 10, { 0.62, 0.62, 0.66, 1 }, width - 20, 18, "CENTER")
    card.title:SetPoint("TOP", 0, -10)
    card.value = CreateLabel(card, "0", 25, valueColor, width - 20, 32, "CENTER")
    card.value:SetPoint("TOP", card.title, "BOTTOM", 0, -3)
    return card
end

local function BuildOverviewPage()
    local page = CreatePage(
        UI.content,
        "Visão geral da guilda",
        "Resumo de membros, presença online e distribuição de classes."
    )

    local identity = CreateSection(page, "Guilda", 16, -88, 660, 72)
    identity.guildName = CreateLabel(identity, "Nome: -", 13, { 0.92, 0.92, 0.94, 1 }, 310, 26)
    identity.guildName:SetPoint("TOPLEFT", 15, -36)
    identity.rankName = CreateLabel(identity, "Seu rank: -", 13, { 0.92, 0.92, 0.94, 1 }, 310, 26)
    identity.rankName:SetPoint("TOPLEFT", 340, -36)

    page.totalCard = CreateStatCard(page, 16, -170, 208, "TOTAL DE MEMBROS", { 1, 0.82, 0.10, 1 })
    page.onlineCard = CreateStatCard(page, 234, -170, 208, "MEMBROS ONLINE", { 0.25, 1, 0.35, 1 })
    page.maxCard = CreateStatCard(page, 452, -170, 224, "ONLINE NÍVEL 80", { 0.41, 0.80, 0.94, 1 })

    local classes = CreateSection(page, "Distribuição por classe", 16, -262, 660, 210)
    page.classRows = {}
    for index, classToken in ipairs(CLASS_ORDER) do
        local col = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local item = CreateFrame("Frame", nil, classes)
        item:SetSize(300, 29)
        item:SetPoint("TOPLEFT", 16 + col * 320, -38 - row * 31)

        item.icon = item:CreateTexture(nil, "ARTWORK")
        item.icon:SetSize(22, 22)
        item.icon:SetPoint("LEFT", 0, 0)
        item.icon:SetTexture(CLASS_ICONS[classToken] or "Interface\\Icons\\INV_Misc_QuestionMark")
        item.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local className = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken] or classToken
        item.name = CreateLabel(item, className, 11, { 0.88, 0.88, 0.90, 1 }, 210, 22)
        item.name:SetPoint("LEFT", item.icon, "RIGHT", 8, 0)
        local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
        if classColor then
            item.name:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
        end

        item.count = CreateLabel(item, "0", 12, { 1, 1, 1, 1 }, 40, 22, "RIGHT")
        item.count:SetPoint("RIGHT", -4, 0)
        page.classRows[classToken] = item
    end

    page.refreshButton = CreateButton(page, "Atualizar dados", 160, 29)
    page.refreshButton:SetPoint("BOTTOMLEFT", 16, 14)
    page.refreshButton:SetScript("OnClick", function()
        RequestGuildRoster()
        SetStatus("Solicitando atualização da guilda...")
    end)

    page.rosterButton = CreateButton(page, "Abrir lista de membros", 190, 29)
    page.rosterButton:SetPoint("LEFT", page.refreshButton, "RIGHT", 10, 0)
    page.rosterButton:SetScript("OnClick", function()
        SelectPage("roster")
    end)

    UI.pages.overview = page
end

local function UpdateOverviewPage()
    local page = UI.pages.overview
    if not page then
        return
    end

    if not IsInGuildSafe() then
        page.title:SetText("Visão geral da guilda")
        page.description:SetText("O personagem atual não pertence a uma guilda.")
        page.totalCard.value:SetText("0")
        page.onlineCard.value:SetText("0")
        page.maxCard.value:SetText("0")
        return
    end

    local guildName, guildRankName = GetGuildInfo("player")
    local total, online, onlineMaxLevel = GetGuildCounts()
    page.description:SetText("Resumo de membros, presença online e distribuição de classes.")
    page.totalCard.value:SetText(total)
    page.onlineCard.value:SetText(online)
    page.maxCard.value:SetText(onlineMaxLevel)

    local identity = page:GetChildren()
    -- O primeiro filho criado é a seção de identidade; mantemos uma referência abaixo.
    for _, child in ipairs({ page:GetChildren() }) do
        if child.guildName and child.rankName then
            child.guildName:SetText(GOLD .. "Nome: " .. RESET .. (guildName or "-"))
            child.rankName:SetText(GOLD .. "Seu rank: " .. RESET .. (guildRankName or "-"))
            break
        end
    end

    local counts = {}
    for _, classToken in ipairs(CLASS_ORDER) do
        counts[classToken] = 0
    end
    for _, member in ipairs(GetGuildMembers()) do
        if member.classToken then
            counts[member.classToken] = (counts[member.classToken] or 0) + 1
        end
    end
    for classToken, item in pairs(page.classRows) do
        item.count:SetText(counts[classToken] or 0)
    end

    if UI.headerTitle then
        UI.headerTitle:SetText((guildName or "Guild") .. "  •  Guild Manager")
    end
end

-- -----------------------------------------------------------------------------
-- Página: membros
-- -----------------------------------------------------------------------------

local ROSTER_VISIBLE_ROWS = 8
local ROSTER_ROW_HEIGHT = 35

local function BuildRosterPage()
    local page = CreatePage(
        UI.content,
        "Lista de membros",
        "Consulte rank, localização, DKP e ações dos personagens da guilda."
    )

    local filters = CreateSection(page, "Filtros - Buscar por nome, rank, zona ou nota", 16, -88, 660, 78)
    page.search = CreateEditBox(filters, "", 330, 47, false)
    page.search:SetPoint("TOPLEFT", 14, -20)
    page.search.edit:SetText(GManagerDB.ui.rosterSearch or "")
    page.search.edit:SetScript("OnTextChanged", function(self)
        GManagerDB.ui.rosterSearch = self:GetText() or ""
        ScheduleTimer("rosterSearch", 0.25, function()
            if UI.currentPage == "roster" then
                RefreshPage("roster")
            end
        end, false)
    end)

    page.onlineOnly = CreateCheckBox(filters, "Somente online")
    page.onlineOnly:SetPoint("TOPLEFT", 370, -42)
    page.onlineOnly:SetChecked(GManagerDB.ui.rosterOnlineOnly)
    page.onlineOnly:SetScript("OnClick", function(self)
        GManagerDB.ui.rosterOnlineOnly = self:GetChecked() and true or false
        RefreshPage("roster")
    end)

    page.refresh = CreateButton(filters, "Atualizar", 105, 27)
    page.refresh:SetPoint("TOPRIGHT", -14, -37)
    page.refresh:SetScript("OnClick", function()
        RequestGuildRoster()
        SetStatus("Atualizando lista de membros...")
    end)

    local tableFrame = CreateSection(page, "Membros encontrados: 0", 16, -176, 660, 345) --374
    page.listSection = tableFrame

    local header = CreateFrame("Frame", nil, tableFrame)
    header:SetPoint("TOPLEFT", 10, -34)
    header:SetPoint("TOPRIGHT", -26, -34)
    header:SetHeight(24)
    SetBackdrop(header, { 0.07, 0.07, 0.085, 1 }, { 0.18, 0.18, 0.20, 1 })

    local function HeaderText(text, x, width, justify)
        local label = CreateLabel(header, text, 10, { 0.68, 0.68, 0.72, 1 }, width, 20, justify or "LEFT")
        label:SetPoint("LEFT", x, 0)
        return label
    end

    HeaderText("MEMBRO", 34, 146)
    HeaderText("RANK", 182, 100)
    HeaderText("ZONA", 284, 142)
    HeaderText("DKP", 428, 70)
    HeaderText("AÇÕES", 506, 96, "CENTER")

    page.rows = {}
    for index = 1, ROSTER_VISIBLE_ROWS do
        local row = CreateFrame("Frame", nil, tableFrame)
        row:SetPoint("TOPLEFT", 10, -60 - ((index - 1) * ROSTER_ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", -26, -60 - ((index - 1) * ROSTER_ROW_HEIGHT))
        row:SetHeight(36)
        SetBackdrop(row, index % 2 == 0 and { 0.038, 0.038, 0.047, 0.95 } or { 0.028, 0.028, 0.036, 0.95 }, { 0.10, 0.10, 0.12, 1 })

        row.status = row:CreateTexture(nil, "ARTWORK")
        row.status:SetSize(7, 7)
        row.status:SetPoint("LEFT", 7, 0)
        row.status:SetTexture("Interface\\Buttons\\WHITE8X8")

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(25, 25)
        row.icon:SetPoint("LEFT", 18, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        row.name = CreateLabel(row, "", 11, { 1, 1, 1, 1 }, 126, 30)
        row.name:SetPoint("LEFT", 48, 0)

        row.rank = CreateLabel(row, "", 10, { 0.65, 0.80, 1, 1 }, 98, 30)
        row.rank:SetPoint("LEFT", 182, 0)

        row.zone = CreateLabel(row, "", 10, { 0.72, 0.72, 0.75, 1 }, 140, 30)
        row.zone:SetPoint("LEFT", 284, 0)

        row.dkp = CreateLabel(row, "", 10, { 1, 0.65, 0.10, 1 }, 68, 30)
        row.dkp:SetPoint("LEFT", 428, 0)

        row.invite = CreateButton(row, "INV", 42, 25)
        row.invite:SetPoint("LEFT", 506, 0)
        row.invite.text:SetFont(FONT_BOLD, 15, "OUTLINE")

        row.whisper = CreateButton(row, "W", 42, 25)
        row.whisper:SetPoint("LEFT", 554, 0)

        row:Hide()
        page.rows[index] = row
    end

    page.scroll = CreateFrame("ScrollFrame", "GManagerRosterScrollFrame", tableFrame, "FauxScrollFrameTemplate")
    page.scroll:SetPoint("TOPLEFT", 10, -35)
    page.scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    page.scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROSTER_ROW_HEIGHT, function()
            RefreshPage("roster")
        end)
    end)

    UI.pages.roster = page
end

local function UpdateRosterPage()
    local page = UI.pages.roster
    if not page then
        return
    end

    if not IsInGuildSafe() then
        page.listSection.title:SetText("Membros encontrados: 0")
        runtime.rosterData = {}
        for _, row in ipairs(page.rows) do
            row:Hide()
        end
        FauxScrollFrame_Update(page.scroll, 0, ROSTER_VISIBLE_ROWS, ROSTER_ROW_HEIGHT)
        return
    end

    local query = Lower(GManagerDB.ui.rosterSearch)
    local onlineOnly = GManagerDB.ui.rosterOnlineOnly
    local filtered = {}

    for _, member in ipairs(GetGuildMembers()) do
        local matchesOnline = not onlineOnly or member.online
        local matchesSearch = query == ""
            or ContainsPlain(member.name, query)
            or ContainsPlain(member.rankName, query)
            or ContainsPlain(member.zone, query)
            or ContainsPlain(member.publicNote, query)
            or ContainsPlain(member.officerNote, query)

        if matchesOnline and matchesSearch then
            table.insert(filtered, member)
        end
    end

    table.sort(filtered, function(a, b)
        if a.online ~= b.online then
            return a.online
        end
        if a.rankIndex ~= b.rankIndex then
            return a.rankIndex < b.rankIndex
        end
        return Lower(a.name) < Lower(b.name)
    end)

    runtime.rosterData = filtered
    page.listSection.title:SetText("Membros encontrados: " .. #filtered)
    FauxScrollFrame_Update(page.scroll, #filtered, ROSTER_VISIBLE_ROWS, ROSTER_ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(page.scroll)

    for index, row in ipairs(page.rows) do
        local member = filtered[offset + index]
        if member then
            row.member = member
            row.icon:SetTexture(CLASS_ICONS[member.classToken] or "Interface\\Icons\\INV_Misc_QuestionMark")
            if member.online then
                row.status:SetVertexColor(0.20, 1, 0.30, 1)
            else
                row.status:SetVertexColor(0.38, 0.38, 0.42, 1)
            end
            row.name:SetText(ColorClassName(member.shortName, member.classToken) .. "\n" .. GRAY .. "Nível " .. member.level .. RESET)
            row.rank:SetText(member.rankName)
            row.zone:SetText(member.zone)
            if GManagerDB.restrictedZones[member.zone] then
                row.zone:SetTextColor(1, 0.25, 0.25, 1)
            elseif member.online then
                row.zone:SetTextColor(0.35, 0.90, 0.45, 1)
            else
                row.zone:SetTextColor(0.58, 0.58, 0.62, 1)
            end
            row.dkp:SetText(GetDKPText(member.officerNote))
            row.invite:SetEnabledState(member.online)
            row.whisper:SetEnabledState(member.online)
            row.invite:SetScript("OnClick", function()
                InviteUnit(member.name)
                SetStatus("Convite de grupo enviado para " .. member.shortName .. ".")
            end)
            row.whisper:SetScript("OnClick", function()
                if ChatFrame_OpenChat then
                    ChatFrame_OpenChat("/w " .. member.name .. " ")
                else
                    DEFAULT_CHAT_FRAME.editBox:SetText("/w " .. member.name .. " ")
                    DEFAULT_CHAT_FRAME.editBox:SetFocus()
                end
            end)
            row:Show()
        else
            row.member = nil
            row:Hide()
        end
    end
end

-- -----------------------------------------------------------------------------
-- Página: convidar e editar membro
-- -----------------------------------------------------------------------------

local function GetRankOptions()
    local options = {}
    local numRanks = GuildControlGetNumRanks and GuildControlGetNumRanks() or 0

    if numRanks and numRanks > 1 then
        for controlIndex = 2, numRanks do
            local rankName = GuildControlGetRankName(controlIndex)
            table.insert(options, {
                value = controlIndex - 1,
                text = rankName or ("Rank " .. (controlIndex - 1)),
            })
        end
        return options
    end

    local discovered = {}
    for _, member in ipairs(GetGuildMembers()) do
        if member.rankIndex > 0 and not discovered[member.rankIndex] then
            discovered[member.rankIndex] = member.rankName
        end
    end
    local indexes = {}
    for rankIndex in pairs(discovered) do
        table.insert(indexes, rankIndex)
    end
    table.sort(indexes)
    for _, rankIndex in ipairs(indexes) do
        table.insert(options, { value = rankIndex, text = discovered[rankIndex] })
    end
    return options
end

local function ApplyMemberNotes(playerName, publicNote, officerNote)
    local member = FindGuildMember(playerName)
    if not member then
        SetStatus("O personagem precisa estar na guilda para receber notas.", true)
        return false
    end

    if GuildRosterSetPublicNote then
        GuildRosterSetPublicNote(member.index, publicNote or "")
    end
    if GuildRosterSetOfficerNote then
        GuildRosterSetOfficerNote(member.index, officerNote or "")
    end
    RequestGuildRoster()
    SetStatus("Notas atualizadas para " .. member.shortName .. ".", true)
    return true
end

local function StopRankJob(message)
    CancelTimer("rankJob")
    runtime.rankJob = nil
    if message then
        SetStatus(message, true)
    end
end

local function StartRankChange(playerName, targetRankIndex)
    playerName = Trim(playerName)
    targetRankIndex = tonumber(targetRankIndex)
    local member = FindGuildMember(playerName)

    if not member then
        SetStatus("Personagem não encontrado na guilda.", true)
        return
    end
    if not targetRankIndex then
        SetStatus("Selecione um rank de destino.", true)
        return
    end
    if targetRankIndex == 0 then
        SetStatus("A transferência de Guild Master não é executada pelo addon.", true)
        return
    end
    if member.rankIndex == targetRankIndex then
        SetStatus(member.shortName .. " já está no rank selecionado.")
        return
    end

    StopRankJob()
    runtime.rankJob = {
        name = member.name,
        shortName = member.shortName,
        target = targetRankIndex,
        attempts = 0,
    }

    ScheduleTimer("rankJob", 0.9, function()
        local job = runtime.rankJob
        if not job then
            CancelTimer("rankJob")
            return
        end

        job.attempts = job.attempts + 1
        local current = FindGuildMember(job.name)
        if not current then
            StopRankJob("O personagem não está mais disponível na guilda.")
            return
        end

        if current.rankIndex == job.target then
            StopRankJob("Rank de " .. job.shortName .. " atualizado com sucesso.")
            return
        end

        if job.attempts > 20 then
            StopRankJob("A alteração de rank não foi confirmada. Verifique suas permissões.")
            return
        end

        if current.rankIndex > job.target then
            GuildPromote(current.name)
        else
            GuildDemote(current.name)
        end
        RequestGuildRoster()
        SetStatus("Alterando rank de " .. job.shortName .. "... tentativa " .. job.attempts .. ".")
    end, true)
end

local function BuildMemberPage()
    local page = CreatePage(
        UI.content,
        "Convidar e editar membro",
        "Envie convite de guilda e gerencie rank, nota pública e nota de oficial."
    )

    local form = CreateSection(page, "Dados do personagem", 16, -88, 660, 310)

    page.memberName = CreateEditBox(form, "Nome do personagem", 300, 48, false)
    page.memberName:SetPoint("TOPLEFT", 16, -38)

    page.rankDropdown = CreateDropdown(form, "Rank de destino", 300)
    page.rankDropdown:SetPoint("TOPLEFT", 338, -38)

    page.publicNote = CreateEditBox(form, "Nota pública", 622, 48, false)
    page.publicNote:SetPoint("TOPLEFT", 16, -98)

    page.officerNote = CreateEditBox(form, "Nota de oficial", 622, 48, false)
    page.officerNote:SetPoint("TOPLEFT", 16, -158)

    page.memberInfo = CreateLabel(
        form,
        GRAY .. "Carregue um membro existente para preencher os dados atuais." .. RESET,
        11,
        { 0.70, 0.70, 0.74, 1 },
        620,
        42
    )
    page.memberInfo:SetPoint("TOPLEFT", 16, -220)
    page.memberInfo:SetJustifyV("TOP")

    page.loadButton = CreateButton(form, "Carregar membro", 145, 29)
    page.loadButton:SetPoint("BOTTOMLEFT", 16, 14)
    page.loadButton:SetScript("OnClick", function()
        local name = Trim(page.memberName.edit:GetText())
        local member = FindGuildMember(name)
        if not member then
            SetStatus("Personagem não encontrado na guilda.", true)
            return
        end
        page.memberName.edit:SetText(member.shortName)
        page.publicNote.edit:SetText(member.publicNote or "")
        page.officerNote.edit:SetText(member.officerNote or "")
        page.rankDropdown:SetOptions(GetRankOptions())
        page.rankDropdown:SetValue(member.rankIndex, true)
        page.memberInfo:SetText(
            ColorClassName(member.shortName, member.classToken)
                .. "  •  Nível " .. member.level
                .. "  •  " .. member.rankName
                .. "  •  " .. member.zone
        )
        SetStatus("Dados de " .. member.shortName .. " carregados.")
    end)

    page.clearButton = CreateButton(form, "Limpar formulário", 145, 29)
    page.clearButton:SetPoint("LEFT", page.loadButton, "RIGHT", 10, 0)
    page.clearButton:SetScript("OnClick", function()
        page.memberName.edit:SetText("")
        page.publicNote.edit:SetText("")
        page.officerNote.edit:SetText("")
        page.rankDropdown:SetValue(nil, true)
        page.memberInfo:SetText(GRAY .. "Carregue um membro existente para preencher os dados atuais." .. RESET)
    end)

    local actions = CreateSection(page, "Ações", 16, -410, 660, 112)

    page.guildInvite = CreateButton(actions, "Convidar para a guilda", 190, 32)
    page.guildInvite:SetPoint("TOPLEFT", 16, -42)
    page.guildInvite:SetScript("OnClick", function()
        local playerName = Trim(page.memberName.edit:GetText())
        if playerName == "" then
            SetStatus("Informe o nome do personagem.", true)
            return
        end
        GuildInvite(playerName)
        SetStatus("Convite de guilda enviado para " .. playerName .. ".", true)
    end)

    page.applyNotes = CreateButton(actions, "Aplicar notas", 155, 32)
    page.applyNotes:SetPoint("LEFT", page.guildInvite, "RIGHT", 12, 0)
    page.applyNotes:SetScript("OnClick", function()
        local playerName = Trim(page.memberName.edit:GetText())
        if playerName == "" then
            SetStatus("Informe o nome do personagem.", true)
            return
        end
        ApplyMemberNotes(
            playerName,
            page.publicNote.edit:GetText() or "",
            page.officerNote.edit:GetText() or ""
        )
    end)

    page.applyRank = CreateButton(actions, "Aplicar rank", 155, 32)
    page.applyRank:SetPoint("LEFT", page.applyNotes, "RIGHT", 12, 0)
    page.applyRank:SetScript("OnClick", function()
        local playerName = Trim(page.memberName.edit:GetText())
        StartRankChange(playerName, page.rankDropdown.value)
    end)

    page.help = CreateLabel(
        page,
        "O personagem precisa aceitar o convite antes que rank e notas possam ser aplicados. "
            .. "A alteração de rank é feita gradualmente pelas APIs GuildPromote e GuildDemote.",
        10,
        { 0.58, 0.58, 0.62, 1 },
        650,
        34
    )
    page.help:SetPoint("BOTTOMLEFT", 18, 12)
    page.help:SetJustifyV("TOP")

    UI.pages.member = page
end

local function UpdateMemberPage()
    local page = UI.pages.member
    if not page then
        return
    end
    local oldValue = page.rankDropdown.value
    page.rankDropdown:SetOptions(GetRankOptions())
    if oldValue then
        page.rankDropdown:SetValue(oldValue, true)
    end
end

-- -----------------------------------------------------------------------------
-- Página: kickar personagens
-- -----------------------------------------------------------------------------

local REMOVE_VISIBLE_ROWS = 7
local REMOVE_ROW_HEIGHT = 33

local INACTIVE_DAY_OPTIONS = {
    { value = 1, text = "1 dia ou mais" },
    { value = 7, text = "7 dias ou mais" },
    { value = 15, text = "15 dias ou mais" },
    { value = 30, text = "30 dias ou mais" },
    { value = 60, text = "60 dias ou mais" },
    { value = 90, text = "90 dias ou mais" },
    { value = 180, text = "180 dias ou mais" },
    { value = 365, text = "365 dias ou mais" },
}

local function FormatGuildLastOnline(member)
    if not member then
        return "-"
    end

    if member.online then
        return "Online agora"
    end

    if not member.lastOnlineKnown then
        return "Desconhecido"
    end

    local years = tonumber(member.yearsOffline) or 0
    local months = tonumber(member.monthsOffline) or 0
    local days = tonumber(member.daysOffline) or 0
    local hours = tonumber(member.hoursOffline) or 0

    if years > 0 then
        return string.format("%da %dm", years, months)
    elseif months > 0 then
        return string.format("%dm %dd", months, days)
    elseif days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh", hours)
    end

    return "Menos de 1h"
end

local function GetFilteredKickMembers()
    local query = Lower(GManagerDB.kick.search or "")
    local inactiveOnly = GManagerDB.kick.inactiveOnly and true or false
    local inactiveDays = math.max(0, tonumber(GManagerDB.kick.inactiveDays) or 30)
    local filtered = {}

    for _, member in ipairs(GetGuildMembers()) do
        local matchesSearch = query == ""
            or ContainsPlain(member.name, query)
            or ContainsPlain(member.rankName, query)
            or ContainsPlain(member.className, query)
            or ContainsPlain(member.zone, query)
            or ContainsPlain(member.publicNote, query)
            or ContainsPlain(member.officerNote, query)

        local matchesInactive = not inactiveOnly
            or (not member.online and member.lastOnlineKnown and member.lastOnlineDays >= inactiveDays)

        if matchesSearch and matchesInactive then
            table.insert(filtered, member)
        end
    end

    table.sort(filtered, function(a, b)
        if a.online ~= b.online then
            return not a.online
        end

        if a.lastOnlineHours ~= b.lastOnlineHours then
            return a.lastOnlineHours > b.lastOnlineHours
        end

        if a.rankIndex ~= b.rankIndex then
            return a.rankIndex < b.rankIndex
        end

        return Lower(a.name) < Lower(b.name)
    end)

    return filtered
end

local function StopKickQueue(message)
    CancelTimer("kickQueue")
    runtime.kickQueue = nil
    runtime.kickQueueIndex = 1
    if message then
        SetStatus(message, true)
    end
end

local function StartKickQueue(members)
    if not members or #members == 0 then
        SetStatus("Nenhum personagem selecionado para kick.", true)
        return
    end

    runtime.kickQueue = members
    runtime.kickQueueIndex = 1

    ScheduleTimer("kickQueue", 0.8, function()
        local member = runtime.kickQueue and runtime.kickQueue[runtime.kickQueueIndex]
        if not member then
            runtime.removeSelection = {}
            StopKickQueue("Kick em massa concluído.")
            RequestGuildRoster()
            ScheduleTimer("removeRefresh", 1.0, function()
                if UI.currentPage == "remove" then
                    RefreshPage("remove")
                end
            end, false)
            return
        end

        GuildUninvite(member.name)
        SetStatus("Kickando " .. member.shortName .. "...")
        runtime.kickQueueIndex = runtime.kickQueueIndex + 1
    end, true)
end

local function BuildRemovePage()
    local page = CreatePage(
        UI.content,
        "Kickar personagens",
        "Selecione personagens individualmente ou aplique filtros de inatividade para realizar kick em massa."
    )

    local filters = CreateSection(page, "Filtros", 16, -88, 660, 92)

    page.removeSearch = CreateEditBox(filters, "Buscar por nome, rank, classe, zona ou nota", 250, 48, false)
    page.removeSearch:SetPoint("TOPLEFT", 14, -36)
    page.removeSearch.edit:SetText(GManagerDB.kick.search or "")
    page.removeSearch.edit:SetScript("OnTextChanged", function(self)
        GManagerDB.kick.search = self:GetText() or ""
        ScheduleTimer("kickSearch", 0.25, function()
            if UI.currentPage == "remove" then
                RefreshPage("remove")
            end
        end, false)
    end)

    page.inactiveOnly = CreateCheckBox(filters, "Jogadores inativos")
    page.inactiveOnly:SetPoint("TOPLEFT", 278, -48)
    page.inactiveOnly:SetChecked(GManagerDB.kick.inactiveOnly)

    page.inactiveDays = CreateDropdown(filters, "Tempo sem entrar", 175)
    page.inactiveDays:SetPoint("TOPLEFT", 466, -36)
    page.inactiveDays:SetOptions(INACTIVE_DAY_OPTIONS)
    page.inactiveDays.OnValueChanged = function(value)
        GManagerDB.kick.inactiveDays = tonumber(value) or 30
        runtime.removeSelection = {}
        if UI.currentPage == "remove" then
            RefreshPage("remove")
        end
    end
    page.inactiveDays:SetValue(tonumber(GManagerDB.kick.inactiveDays) or 30, true)

    local function UpdateInactiveFilterState()
        local enabled = GManagerDB.kick.inactiveOnly and true or false
        page.inactiveDays.button:SetEnabledState(enabled)
        if enabled then
            page.inactiveDays.label:SetTextColor(0.95, 0.78, 0.16, 1)
        else
            page.inactiveDays.label:SetTextColor(0.48, 0.48, 0.50, 1)
        end
    end

    page.inactiveOnly:SetScript("OnClick", function(self)
        GManagerDB.kick.inactiveOnly = self:GetChecked() and true or false
        runtime.removeSelection = {}
        UpdateInactiveFilterState()
        RefreshPage("remove")
    end)
    UpdateInactiveFilterState()

    local results = CreateSection(page, "Personagens listados: 0", 16, -192, 660, 328)
    page.removeSection = results

    local header = CreateFrame("Frame", nil, results)
    header:SetPoint("TOPLEFT", 10, -34)
    header:SetPoint("TOPRIGHT", -26, -34)
    header:SetHeight(24)
    SetBackdrop(header, { 0.07, 0.07, 0.085, 1 }, { 0.18, 0.18, 0.20, 1 })

    local h1 = CreateLabel(header, "KICK", 10, { 0.68, 0.68, 0.72, 1 }, 50, 20, "CENTER")
    h1:SetPoint("LEFT", 0, 0)
    local h2 = CreateLabel(header, "PERSONAGEM", 10, { 0.68, 0.68, 0.72, 1 }, 158, 20)
    h2:SetPoint("LEFT", 52, 0)
    local h3 = CreateLabel(header, "RANK", 10, { 0.68, 0.68, 0.72, 1 }, 104, 20)
    h3:SetPoint("LEFT", 212, 0)
    local h4 = CreateLabel(header, "ÚLTIMO LOGIN", 10, { 0.68, 0.68, 0.72, 1 }, 118, 20)
    h4:SetPoint("LEFT", 318, 0)
    local h5 = CreateLabel(header, "NOTA", 10, { 0.68, 0.68, 0.72, 1 }, 168, 20)
    h5:SetPoint("LEFT", 438, 0)

    page.removeRows = {}
    for index = 1, REMOVE_VISIBLE_ROWS do
        local row = CreateFrame("Frame", nil, results)
        row:SetPoint("TOPLEFT", 10, -60 - ((index - 1) * REMOVE_ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", -26, -60 - ((index - 1) * REMOVE_ROW_HEIGHT))
        row:SetHeight(34)
        SetBackdrop(
            row,
            index % 2 == 0 and { 0.038, 0.038, 0.047, 0.95 } or { 0.028, 0.028, 0.036, 0.95 },
            { 0.10, 0.10, 0.12, 1 }
        )

        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetSize(24, 24)
        row.check:SetPoint("LEFT", 13, 0)

        row.name = CreateLabel(row, "", 11, { 1, 1, 1, 1 }, 156, 30)
        row.name:SetPoint("LEFT", 52, 0)

        row.rank = CreateLabel(row, "", 10, { 0.42, 0.72, 1, 1 }, 102, 30)
        row.rank:SetPoint("LEFT", 212, 0)

        row.lastOnline = CreateLabel(row, "", 10, { 0.68, 0.68, 0.72, 1 }, 116, 30)
        row.lastOnline:SetPoint("LEFT", 318, 0)

        row.note = CreateLabel(row, "", 10, { 0.68, 0.68, 0.72, 1 }, 166, 30)
        row.note:SetPoint("LEFT", 438, 0)

        row.check:SetScript("OnClick", function(self)
            if row.member then
                runtime.removeSelection[row.member.name] = self:GetChecked() and true or false
            end
        end)

        row:Hide()
        page.removeRows[index] = row
    end

    page.removeScroll = CreateFrame("ScrollFrame", "GManagerRemoveScrollFrame", results, "FauxScrollFrameTemplate")
    page.removeScroll:SetPoint("TOPLEFT", 10, -35)
    page.removeScroll:SetPoint("BOTTOMRIGHT", -28, 35)
    page.removeScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, REMOVE_ROW_HEIGHT, function()
            RefreshPage("remove")
        end)
    end)

    page.selectAll = CreateButton(page, "Selecionar filtrados", 165, 29)
    page.selectAll:SetPoint("BOTTOMLEFT", 21, 19)
    page.selectAll:SetScript("OnClick", function()
        local selfName = Lower(UnitName("player"))
        for _, member in ipairs(runtime.removeResults or {}) do
            local protected = member.rankIndex == 0 or Lower(member.shortName) == selfName
            runtime.removeSelection[member.name] = not protected
        end
        RefreshPage("remove")
    end)

    page.clearSelection = CreateButton(page, "Limpar seleção", 140, 29)
    page.clearSelection:SetPoint("LEFT", page.selectAll, "RIGHT", 10, 0)
    page.clearSelection:SetScript("OnClick", function()
        runtime.removeSelection = {}
        RefreshPage("remove")
    end)

    page.removeButton = CreateButton(page, "Kickar selecionados", 190, 29)
    page.removeButton:SetPoint("BOTTOMRIGHT", -25, 19)
    page.removeButton:SetScript("OnClick", function()
        local selected = {}
        local names = {}

        for _, member in ipairs(runtime.removeResults or {}) do
            if runtime.removeSelection[member.name] then
                table.insert(selected, member)
                table.insert(names, member.shortName)
            end
        end

        if #selected == 0 then
            SetStatus("Nenhum personagem está selecionado para kick.", true)
            return
        end

        ShowPopup(
            "Confirmar kick em massa",
            "Esta ação kickará " .. #selected .. " personagem(ns):\n\n"
                .. table.concat(names, ", ")
                .. "\n\nEsta ação não pode ser desfeita pelo addon.",
            function()
                StartKickQueue(selected)
            end
        )
    end)

    UI.pages.remove = page
end

local function UpdateRemovePage()
    local page = UI.pages.remove
    if not page then
        return
    end

    local results = GetFilteredKickMembers()
    runtime.removeResults = results

    local inactiveOnly = GManagerDB.kick.inactiveOnly and true or false
    local inactiveDays = tonumber(GManagerDB.kick.inactiveDays) or 30
    if inactiveOnly then
        page.removeSection.title:SetText(
            "Personagens inativos há " .. inactiveDays .. "+ dias: " .. #results
        )
    else
        page.removeSection.title:SetText("Personagens listados: " .. #results)
    end

    page.inactiveOnly:SetChecked(inactiveOnly)
    page.inactiveDays:SetValue(inactiveDays, true)
    page.inactiveDays.button:SetEnabledState(inactiveOnly)
    if inactiveOnly then
        page.inactiveDays.label:SetTextColor(0.95, 0.78, 0.16, 1)
    else
        page.inactiveDays.label:SetTextColor(0.48, 0.48, 0.50, 1)
    end

    FauxScrollFrame_Update(page.removeScroll, #results, REMOVE_VISIBLE_ROWS, REMOVE_ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(page.removeScroll)
    local selfName = Lower(UnitName("player"))

    for index, row in ipairs(page.removeRows) do
        local member = results[offset + index]
        if member then
            row.member = member
            local protected = member.rankIndex == 0 or Lower(member.shortName) == selfName

            row.check:SetChecked(runtime.removeSelection[member.name] and true or false)
            row.check:EnableMouse(not protected)
            row.check:SetAlpha(protected and 0.35 or 1)

            if protected then
                row.check:SetChecked(false)
                runtime.removeSelection[member.name] = false
            end

            row.name:SetText(ColorClassName(member.shortName, member.classToken))
            row.rank:SetText(member.rankName .. (protected and "  |cffff5555(protegido)|r" or ""))
            row.lastOnline:SetText(FormatGuildLastOnline(member))

            if member.online then
                row.lastOnline:SetTextColor(0.25, 1, 0.35, 1)
            elseif member.lastOnlineDays >= 365 then
                row.lastOnline:SetTextColor(1, 0.28, 0.28, 1)
            elseif member.lastOnlineDays >= 90 then
                row.lastOnline:SetTextColor(1, 0.62, 0.12, 1)
            else
                row.lastOnline:SetTextColor(0.68, 0.68, 0.72, 1)
            end

            local note = Trim(member.officerNote) ~= "" and member.officerNote or member.publicNote
            row.note:SetText(Trim(note) ~= "" and note or "Sem nota")
            row:Show()
        else
            row.member = nil
            row:Hide()
        end
    end
end

-- -----------------------------------------------------------------------------
-- Página: convite em massa e raid
-- -----------------------------------------------------------------------------

local function StopMassInvite(silent)
    runtime.massInviteActive = false
    runtime.inviteQueue = nil
    runtime.inviteQueueIndex = 1
    runtime.massInviteEnds = nil
    runtime.pendingAutoInvites = {}
    CancelTimer("massInviteDelay")
    CancelTimer("inviteQueue")
    CancelTimer("raidStatus")
    if not silent then
        SetStatus("Convite em massa e autoconvite interrompidos.", true)
    end
    if UI.pages.raid then
        RefreshPage("raid")
    end
end

local function InviteQueuedGuildMembers()
    local member = runtime.inviteQueue and runtime.inviteQueue[runtime.inviteQueueIndex]
    if not member then
        CancelTimer("inviteQueue")
        runtime.inviteQueue = nil
        runtime.inviteQueueIndex = 1
        SetStatus("Fila de convites concluída. O autoconvite por palavra-chave permanece ativo.", true)
        RefreshPage("raid")
        return
    end

    InviteUnit(member.name)
    SetStatus("Enviando convite para " .. member.shortName .. "...")
    runtime.inviteQueueIndex = runtime.inviteQueueIndex + 1
end

local function ExecuteMassInvite()
    if not runtime.massInviteActive then
        return
    end

    local queue = {}
    local queuedNames = {}
    local ownName = Lower(UnitName("player"))
    for _, member in ipairs(GetGuildMembers()) do
        local eligibleLevel = not GManagerDB.invite.level80Only or member.level == 80
        local memberKey = Lower(member.shortName)
        if member.online and eligibleLevel and memberKey ~= ownName then
            table.insert(queue, member)
            queuedNames[memberKey] = true
        end
    end

    -- Pedidos por palavra-chave recebidos durante a contagem também respeitam o atraso.
    for memberKey, memberName in pairs(runtime.pendingAutoInvites or {}) do
        if memberKey ~= ownName and not queuedNames[memberKey] then
            table.insert(queue, {
                name = memberName,
                shortName = ShortName(memberName) or memberName,
            })
            queuedNames[memberKey] = true
        end
    end
    runtime.pendingAutoInvites = {}

    table.sort(queue, function(a, b)
        return Lower(a.name) < Lower(b.name)
    end)

    runtime.inviteQueue = queue
    runtime.inviteQueueIndex = 1
    runtime.massInviteEnds = nil

    if #queue == 0 then
        SetStatus("Nenhum membro online corresponde aos filtros de convite.", true)
        RefreshPage("raid")
        return
    end

    SetStatus("Iniciando fila de " .. #queue .. " convite(s).", true)
    InviteQueuedGuildMembers()
    ScheduleTimer("inviteQueue", 0.45, InviteQueuedGuildMembers, true)
    RefreshPage("raid")
end

local function AnnounceMassInvite()
    local guildMessage = Trim(GManagerDB.invite.guildMessage)
    local keyword = Trim(GManagerDB.invite.keyword)
    local delay = math.max(0, tonumber(GManagerDB.invite.delay) or 0)

    if guildMessage ~= "" then
        SendChatMessage(guildMessage, "GUILD")
    end
    if keyword ~= "" then
        SendChatMessage(
            "Digite >> " .. keyword .. " << no chat da guilda ou por sussurro para receber convite. "
                .. "Os convites em massa começam em " .. delay .. " segundos.",
            "GUILD"
        )
    end
end

local function StartMassInvite()
    StopMassInvite(true)

    -- Lê o valor diretamente do campo ao clicar em Iniciar. Isso evita usar
    -- um valor antigo das SavedVariables quando o jogador acabou de editar o campo.
    local delayText
    if UI.pages.raid and UI.pages.raid.inviteDelay and UI.pages.raid.inviteDelay.edit then
        delayText = UI.pages.raid.inviteDelay.edit:GetText()
    else
        delayText = GManagerDB.invite.delay
    end

    delayText = tostring(delayText or ""):gsub(",", ".")
    local delay = tonumber(delayText)
    if not delay then
        SetStatus("Informe um atraso válido em segundos.", true)
        return
    end

    delay = math.max(0, delay)
    GManagerDB.invite.delay = delay
    GManagerDB.invite.keyword = Trim(GManagerDB.invite.keyword)
    if UI.pages.raid and UI.pages.raid.inviteDelay and UI.pages.raid.inviteDelay.edit then
        UI.pages.raid.inviteDelay.edit:SetText(tostring(delay))
        UI.pages.raid.inviteDelay.edit:ClearFocus()
    end

    runtime.massInviteActive = true
    runtime.massInviteEnds = GetTime() + delay
    AnnounceMassInvite()

    if delay <= 0 then
        ExecuteMassInvite()
    else
        ScheduleTimer("massInviteDelay", delay, ExecuteMassInvite, false)
    end
    ScheduleTimer("raidStatus", 1, function()
        if UI.currentPage == "raid" then
            RefreshPage("raid")
        end
    end, true)
    SetStatus("Autoconvite ativo. Convites em massa em " .. delay .. " segundos.", true)
    RefreshPage("raid")
end

local function SetRaidMode(difficulty)
    difficulty = tonumber(difficulty)
    if not difficulty or difficulty < 1 or difficulty > 4 then
        SetStatus("Selecione uma dificuldade válida.", true)
        return
    end
    if not SetRaidDifficulty then
        SetStatus("A API SetRaidDifficulty não está disponível neste cliente.", true)
        return
    end
    SetRaidDifficulty(difficulty)
    local names = {
        [1] = "10 jogadores - Normal",
        [2] = "25 jogadores - Normal",
        [3] = "10 jogadores - Heroico",
        [4] = "25 jogadores - Heroico",
    }
    SetStatus("Dificuldade definida para " .. names[difficulty] .. ".", true)
end

local function DisbandGroup()
    if not IsPartyGroup() and not IsRaidGroup() then
        SetStatus("Você não está em um grupo.", true)
        return
    end

    ShowPopup(
        "Desfazer grupo",
        "Remover todos os outros jogadores do grupo ou raid atual?",
        function()
            local names = {}
            if IsRaidGroup() then
                for index = 1, GetNumRaidMembers() do
                    local name = UnitName("raid" .. index)
                    if name and not UnitIsUnit("raid" .. index, "player") then
                        table.insert(names, name)
                    end
                end
            else
                for index = 1, GetNumPartyMembers() do
                    local name = UnitName("party" .. index)
                    if name then
                        table.insert(names, name)
                    end
                end
            end

            for _, name in ipairs(names) do
                UninviteUnit(name)
            end
            SetStatus("Comandos para desfazer o grupo enviados.", true)
        end
    )
end

local function BuildRaidPage()
    local page = CreatePage(
        UI.content,
        "Convite em massa e controle de raid",
        "Organize uma raid da guilda com palavra-chave, temporizador e dificuldade do WotLK."
    )

    local invite = CreateSection(page, "Convite em massa", 16, -88, 660, 292)

    page.inviteDelay = CreateEditBox(
        invite,
        "Atraso antes dos convites (segundos)",
        196,
        48,
        false
    )

    page.inviteDelay:SetPoint("TOPLEFT", 14, -38)
    page.inviteDelay.edit:SetText(tostring(GManagerDB.invite.delay))

    page.inviteDelay.edit:HookScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())

        if value then
            GManagerDB.invite.delay = math.max(0, value)
        end
    end)

    page.inviteKeyword = CreateEditBox(
        invite,
        "Palavra para autoconvite",
        196,
        48,
        false
    )

    page.inviteKeyword:SetPoint("TOPLEFT", 230, -38)
    page.inviteKeyword.edit:SetText(GManagerDB.invite.keyword or "")

    page.inviteKeyword.edit:HookScript("OnTextChanged", function(self)
        GManagerDB.invite.keyword = Trim(self:GetText())
    end)

    page.levelOnly = CreateCheckBox(invite, "Somente nível 80")
    page.levelOnly:SetPoint("TOPLEFT", 458, -51)
    page.levelOnly:SetChecked(GManagerDB.invite.level80Only)

    page.levelOnly:SetScript("OnClick", function(self)
        GManagerDB.invite.level80Only =
            self:GetChecked() and true or false
    end)

    page.guildMessage = CreateEditBox(
        invite,
        "Mensagem adicional no chat da guilda",
        622,
        48,
        false
    )

    page.guildMessage:SetPoint("TOPLEFT", 14, -102)
    page.guildMessage.edit:SetText(
        GManagerDB.invite.guildMessage or ""
    )

    page.guildMessage.edit:HookScript("OnTextChanged", function(self)
        GManagerDB.invite.guildMessage = self:GetText() or ""
    end)

    page.startInvite = CreateButton(invite, "Iniciar", 130, 31)
    page.startInvite:SetPoint("TOPLEFT", 14, -168)
    page.startInvite:SetScript("OnClick", StartMassInvite)

    page.reannounce = CreateButton(invite, "Reanunciar", 130, 31)
    page.reannounce:SetPoint(
        "LEFT",
        page.startInvite,
        "RIGHT",
        10,
        0
    )

    page.reannounce:SetScript("OnClick", function()
        if not runtime.massInviteActive then
            SetStatus("O autoconvite não está ativo.", true)
            return
        end

        AnnounceMassInvite()
        SetStatus("Mensagem de convite reenviada.")
    end)

    page.stopInvite = CreateButton(invite, "Parar", 130, 31)
    page.stopInvite:SetPoint(
        "LEFT",
        page.reannounce,
        "RIGHT",
        10,
        0
    )

    page.stopInvite:SetScript("OnClick", function()
        StopMassInvite(false)
    end)

    page.inviteState = CreateLabel(
        invite,
        "Estado: INATIVO",
        12,
        { 0.65, 0.65, 0.68, 1 },
        605,
        45
    )

    page.inviteState:SetPoint("TOPLEFT", 14, -220)
    page.inviteState:SetJustifyV("TOP")

    local raid = CreateSection(
        page,
        "Controle da raid",
        16,
        -392,
        660,
        130
    )

    page.convertRaid = CreateButton(
        raid,
        "Converter para raid",
        175,
        27
    )

    page.convertRaid:SetPoint("TOPLEFT", 14, -43)

    page.convertRaid:SetScript("OnClick", function()
        if IsPartyGroup() and not IsRaidGroup() then
            ConvertToRaid()
            SetStatus("Grupo convertido para raid.", true)

        elseif IsRaidGroup() then
            SetStatus("O grupo atual já é uma raid.")

        else
            SetStatus(
                "É necessário ter outro jogador no grupo para converter.",
                true
            )
        end
    end)

    page.difficulty = CreateDropdown(
        raid,
        "Dificuldade",
        240
    )

    page.difficulty:SetPoint("TOPLEFT", 205, -7)

    -- Altura total:
    -- 16 do título + 20 de espaço + 27 do botão = 63
    page.difficulty:SetSize(230, 63)

    -- Reposiciona o botão das opções 20 unidades abaixo do título.
    if page.difficulty.label and page.difficulty.button then
        page.difficulty.label:ClearAllPoints()
        page.difficulty.label:SetPoint(
            "TOPLEFT",
            page.difficulty,
            "TOPLEFT",
            0,
            0
        )

        page.difficulty.button:ClearAllPoints()
        page.difficulty.button:SetPoint(
            "TOPLEFT",
            page.difficulty.label,
            "BOTTOMLEFT",
            0,
            -20
        )
    end

    page.difficulty:SetOptions({
        {
            value = 1,
            text = "10 jogadores - Normal"
        },
        {
            value = 2,
            text = "25 jogadores - Normal"
        },
        {
            value = 3,
            text = "10 jogadores - Heroico"
        },
        {
            value = 4,
            text = "25 jogadores - Heroico"
        },
    })

    page.difficulty.OnValueChanged = SetRaidMode

    page.disband = CreateButton(
        raid,
        "Desfazer grupo",
        170,
        27
    )

    page.disband:SetPoint("TOPLEFT", 466, -43)
    page.disband:SetScript("OnClick", DisbandGroup)

    UI.pages.raid = page
end

local function UpdateRaidPage()
    local page = UI.pages.raid
    if not page then
        return
    end

    page.levelOnly:SetChecked(GManagerDB.invite.level80Only)
    if runtime.massInviteActive then
        local detail = GREEN .. "ATIVO" .. RESET
        if runtime.massInviteEnds then
            detail = detail .. "  •  Convites em " .. FormatDuration(runtime.massInviteEnds - GetTime())
        elseif runtime.inviteQueue then
            local remaining = math.max(0, #runtime.inviteQueue - runtime.inviteQueueIndex + 1)
            detail = detail .. "  •  Fila restante: " .. remaining
        else
            detail = detail .. "  •  Aguardando palavra-chave ou comando de parada"
        end
        page.inviteState:SetText("Estado: " .. detail)
    else
        page.inviteState:SetText("Estado: " .. GRAY .. "INATIVO" .. RESET)
    end

    if GetRaidDifficulty and page.difficulty then
        local difficulty = GetRaidDifficulty()
        if difficulty and difficulty >= 1 and difficulty <= 4 then
            page.difficulty:SetValue(difficulty, true)
        end
    end
end

-- -----------------------------------------------------------------------------
-- Página: recrutamento
-- -----------------------------------------------------------------------------

local function SendRecruitmentMessage()
    local channel = tonumber(GManagerDB.recruit.channel)
    local message = Trim(GManagerDB.recruit.message)
    if not channel or channel < 1 then
        SetStatus("Informe um número de canal válido.", true)
        CancelTimer("recruitment")
        runtime.recruitActive = false
        return false
    end
    if message == "" then
        SetStatus("Informe uma mensagem de recrutamento.", true)
        CancelTimer("recruitment")
        runtime.recruitActive = false
        return false
    end
    SendChatMessage(message, "CHANNEL", nil, channel)
    runtime.recruitNext = GetTime() + (tonumber(GManagerDB.recruit.interval) or 68)
    return true
end

local function StopRecruitment(silent)
    CancelTimer("recruitment")
    CancelTimer("recruitStatus")
    runtime.recruitActive = false
    runtime.recruitNext = nil
    if not silent then
        SetStatus("Recrutamento automático interrompido.", true)
    end
    if UI.pages.recruit then
        RefreshPage("recruit")
    end
end

local function StartRecruitment()
    StopRecruitment(true)
    local interval = tonumber(GManagerDB.recruit.interval) or 68
    if interval < 68 then
        interval = 68
    end
    GManagerDB.recruit.interval = interval

    if Trim(GManagerDB.recruit.message) == "" then
        SetStatus("Informe uma mensagem de recrutamento.", true)
        return
    end
    if not tonumber(GManagerDB.recruit.channel) or tonumber(GManagerDB.recruit.channel) < 1 then
        SetStatus("Informe um número de canal válido.", true)
        return
    end

    runtime.recruitActive = true
    if not SendRecruitmentMessage() then
        return
    end
    ScheduleTimer("recruitment", interval, SendRecruitmentMessage, true)
    ScheduleTimer("recruitStatus", 1, function()
        if UI.currentPage == "recruit" then
            RefreshPage("recruit")
        end
    end, true)
    SetStatus("Recrutamento automático iniciado a cada " .. interval .. " segundos.", true)
    RefreshPage("recruit")
end

local function BuildRecruitPage()
    local page = CreatePage(
        UI.content,
        "Recrutamento",
        "Envie periodicamente uma mensagem para um canal público com intervalo mínimo de 68 segundos."
    )

    local form = CreateSection(page, "Configuração", 16, -88, 660, 330)

    page.recruitChannel = CreateEditBox(form, "Número do canal", 200, 48, false)
    page.recruitChannel:SetPoint("TOPLEFT", 14, -38)
    page.recruitChannel.edit:SetText(tostring(GManagerDB.recruit.channel))
    page.recruitChannel.edit:HookScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value then
            GManagerDB.recruit.channel = value
        end
    end)

    page.recruitInterval = CreateEditBox(form, "Intervalo (mínimo 68 segundos)", 260, 48, false)
    page.recruitInterval:SetPoint("TOPLEFT", 232, -38)
    page.recruitInterval.edit:SetText(tostring(GManagerDB.recruit.interval))
    page.recruitInterval.edit:HookScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value then
            GManagerDB.recruit.interval = value
        end
    end)

    page.recruitMessage = CreateEditBox(form, "Mensagem de recrutamento", 622, 190, true)
    page.recruitMessage:SetPoint("TOPLEFT", 14, -102)
    page.recruitMessage.edit:SetText(GManagerDB.recruit.message or "")
    page.recruitMessage.edit:HookScript("OnTextChanged", function(self)
        GManagerDB.recruit.message = self:GetText() or ""
    end)

    local controls = CreateSection(page, "Controle", 16, -430, 660, 92)
    page.startRecruit = CreateButton(controls, "Iniciar recrutamento", 200, 32)
    page.startRecruit:SetPoint("TOPLEFT", 14, -42)
    page.startRecruit:SetScript("OnClick", StartRecruitment)

    page.stopRecruit = CreateButton(controls, "Parar recrutamento", 190, 32)
    page.stopRecruit:SetPoint("LEFT", page.startRecruit, "RIGHT", 12, 0)
    page.stopRecruit:SetScript("OnClick", function() StopRecruitment(false) end)

    page.recruitState = CreateLabel(controls, "INATIVO", 12, { 0.65, 0.65, 0.68, 1 }, 210, 30, "RIGHT")
    page.recruitState:SetPoint("RIGHT", -14, 0)

    UI.pages.recruit = page
end

local function UpdateRecruitPage()
    local page = UI.pages.recruit
    if not page then
        return
    end
    if runtime.recruitActive then
        local nextText = runtime.recruitNext and FormatDuration(runtime.recruitNext - GetTime()) or "-"
        page.recruitState:SetText(GREEN .. "ATIVO" .. RESET .. "\nPróximo envio: " .. nextText)
    else
        page.recruitState:SetText(GRAY .. "INATIVO" .. RESET)
    end
end

-- -----------------------------------------------------------------------------
-- Página: configurações
-- -----------------------------------------------------------------------------

local function ApplyMinimapVisibility()
    if not UI.minimapButton or not GManagerDB then
        return
    end
    if GManagerDB.minimap.hide then
        UI.minimapButton:Hide()
    else
        UI.minimapButton:Show()
        UpdateMinimapButtonPosition()
    end
end

local SyncSavedValuesToControls

local function BuildSettingsPage()
    local page = CreatePage(
        UI.content,
        "Configurações",
        "Preferências persistentes da interface e comportamento do addon."
    )

    local interface = CreateSection(page, "Interface", 16, -88, 660, 145)

    page.showMinimap = CreateCheckBox(interface, "Mostrar botão no minimapa")
    page.showMinimap:SetPoint("TOPLEFT", 16, -42)
    page.showMinimap:SetScript("OnClick", function(self)
        GManagerDB.minimap.hide = not (self:GetChecked() and true or false)
        ApplyMinimapVisibility()
    end)

    page.lockWindow = CreateCheckBox(interface, "Bloquear posição da janela")
    page.lockWindow:SetPoint("TOPLEFT", 300, -42)
    page.lockWindow:SetScript("OnClick", function(self)
        GManagerDB.window.locked = self:GetChecked() and true or false
    end)

    page.resetPosition = CreateButton(interface, "Centralizar janela", 165, 29)
    page.resetPosition:SetPoint("TOPLEFT", 16, -86)
    page.resetPosition:SetScript("OnClick", function()
        GManagerDB.window.point = "CENTER"
        GManagerDB.window.relativePoint = "CENTER"
        GManagerDB.window.x = 0
        GManagerDB.window.y = 0
        RestoreWindowPosition()
        SetStatus("Posição da janela restaurada.")
    end)

    page.resetMinimap = CreateButton(interface, "Resetar botão do minimapa", 210, 29)
    page.resetMinimap:SetPoint("LEFT", page.resetPosition, "RIGHT", 12, 0)
    page.resetMinimap:SetScript("OnClick", function()
        GManagerDB.minimap.angle = 225
        GManagerDB.minimap.radius = 80
        UpdateMinimapButtonPosition()
        SetStatus("Posição do botão do minimapa restaurada.")
    end)

    local behavior = CreateSection(page, "Comportamento", 16, -245, 660, 125)

    page.settingLevelOnly = CreateCheckBox(behavior, "Convite em massa somente para nível 80")
    page.settingLevelOnly:SetPoint("TOPLEFT", 16, -42)
    page.settingLevelOnly:SetScript("OnClick", function(self)
        GManagerDB.invite.level80Only = self:GetChecked() and true or false
        if UI.pages.raid then
            UI.pages.raid.levelOnly:SetChecked(GManagerDB.invite.level80Only)
        end
    end)

    page.updateRoster = CreateButton(behavior, "Atualizar roster agora", 190, 29)
    page.updateRoster:SetPoint("TOPRIGHT", -16, -47)
    page.updateRoster:SetScript("OnClick", function()
        RequestGuildRoster()
        SetStatus("Solicitando atualização da guilda...")
    end)

    local maintenance = CreateSection(page, "Manutenção", 16, -382, 660, 140)

    page.restoreDefaults = CreateButton(maintenance, "Restaurar configurações padrão", 255, 31)
    page.restoreDefaults:SetPoint("TOPLEFT", 16, -43)
    page.restoreDefaults:SetScript("OnClick", function()
        ShowPopup(
            "Restaurar configurações",
            "Restaurar todas as configurações do GManager para os valores padrão?",
            function()
                StopMassInvite(true)
                StopRecruitment(true)
                StopRankJob()
                StopKickQueue()
                ReplaceTable(GManagerDB, DEFAULTS)
                SyncSavedValuesToControls()
                RestoreWindowPosition()
                ApplyMinimapVisibility()
                UpdateMinimapButtonPosition()
                SetStatus("Configurações restauradas.", true)
                RefreshPage(UI.currentPage)
            end
        )
    end)

    page.reloadUI = CreateButton(maintenance, "Recarregar interface", 180, 31)
    page.reloadUI:SetPoint("LEFT", page.restoreDefaults, "RIGHT", 12, 0)
    page.reloadUI:SetScript("OnClick", function()
        ReloadUI()
    end)

    page.versionText = CreateLabel(
        maintenance,
        "Versão 1.0.0 por Valber\n"
            .. "https://github.com/FableCraze/GManager\n\nEste projeto é um fork idependente de https://github.com/brannik/GManager",
        10,
        { 0.58, 0.58, 0.62, 1 },
        620,
        42
    )
    page.versionText:SetPoint("TOPLEFT", 16, -88)
    page.versionText:SetJustifyV("TOP")

    UI.pages.settings = page
end

local function UpdateSettingsPage()
    local page = UI.pages.settings
    if not page then
        return
    end
    page.showMinimap:SetChecked(not GManagerDB.minimap.hide)
    page.lockWindow:SetChecked(GManagerDB.window.locked)
    page.settingLevelOnly:SetChecked(GManagerDB.invite.level80Only)
end

SyncSavedValuesToControls = function()
    if UI.pages.roster then
        UI.pages.roster.search.edit:SetText(GManagerDB.ui.rosterSearch or "")
        UI.pages.roster.onlineOnly:SetChecked(GManagerDB.ui.rosterOnlineOnly)
    end
    if UI.pages.raid then
        UI.pages.raid.inviteDelay.edit:SetText(tostring(GManagerDB.invite.delay or 15))
        UI.pages.raid.inviteKeyword.edit:SetText(GManagerDB.invite.keyword or "")
        UI.pages.raid.guildMessage.edit:SetText(GManagerDB.invite.guildMessage or "")
        UI.pages.raid.levelOnly:SetChecked(GManagerDB.invite.level80Only)
    end
    if UI.pages.recruit then
        UI.pages.recruit.recruitChannel.edit:SetText(tostring(GManagerDB.recruit.channel or 1))
        UI.pages.recruit.recruitInterval.edit:SetText(tostring(GManagerDB.recruit.interval or 68))
        UI.pages.recruit.recruitMessage.edit:SetText(GManagerDB.recruit.message or "")
    end
    if UI.pages.remove then
        UI.pages.remove.removeSearch.edit:SetText(GManagerDB.kick.search or "")
        UI.pages.remove.inactiveOnly:SetChecked(GManagerDB.kick.inactiveOnly)
        UI.pages.remove.inactiveDays:SetValue(tonumber(GManagerDB.kick.inactiveDays) or 30, true)
        UI.pages.remove.inactiveDays.button:SetEnabledState(GManagerDB.kick.inactiveOnly and true or false)
    end
    UpdateSettingsPage()
end

-- -----------------------------------------------------------------------------
-- Atualização das páginas e abertura da interface
-- -----------------------------------------------------------------------------

local function BuildAllPages()
    if not UI.pages.overview then BuildOverviewPage() end
    if not UI.pages.roster then BuildRosterPage() end
    if not UI.pages.member then BuildMemberPage() end
    if not UI.pages.remove then BuildRemovePage() end
    if not UI.pages.raid then BuildRaidPage() end
    if not UI.pages.recruit then BuildRecruitPage() end
    if not UI.pages.settings then BuildSettingsPage() end
end

RefreshPage = function(pageKey)
    pageKey = pageKey or UI.currentPage
    if not pageKey then
        return
    end

    if pageKey == "overview" then
        UpdateOverviewPage()
    elseif pageKey == "roster" then
        UpdateRosterPage()
    elseif pageKey == "member" then
        UpdateMemberPage()
    elseif pageKey == "remove" then
        UpdateRemovePage()
    elseif pageKey == "raid" then
        UpdateRaidPage()
    elseif pageKey == "recruit" then
        UpdateRecruitPage()
    elseif pageKey == "settings" then
        UpdateSettingsPage()
    end
end

SelectPage = function(pageKey)
    CreateMainFrame()
    BuildAllPages()

    if not UI.pages[pageKey] then
        pageKey = "overview"
    end

    for _, page in pairs(UI.pages) do
        page:Hide()
    end

    UI.currentPage = pageKey
    GManagerDB.ui.lastPage = pageKey
    UI.pages[pageKey]:Show()
    UpdateNavigation()
    RefreshPage(pageKey)
end

ToggleFrame = function(forcePage)
    local frame = CreateMainFrame()
    BuildAllPages()

    if forcePage then
        frame:Show()
        SelectPage(forcePage)
        RequestGuildRoster()
        return
    end

    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        RestoreWindowPosition()
        SelectPage(GManagerDB.ui.lastPage or "overview")
        RequestGuildRoster()
    end
end

-- -----------------------------------------------------------------------------
-- Botão nativo do minimapa
-- -----------------------------------------------------------------------------

local function CreateMinimapButton()
    if UI.minimapButton then
        return
    end

    local button = CreateFrame("Button", "GManagerMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(24, 24)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    button:SetScript("OnClick", function(self, mouseButton)
        if self.ignoreNextClick then
            self.ignoreNextClick = false
            return
        end
        if mouseButton == "RightButton" then
            ToggleFrame("settings")
        else
            ToggleFrame()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Guild Manager", 1, 0.82, 0.10)
        GameTooltip:AddLine("Clique esquerdo: abrir ou fechar", 1, 1, 1)
        GameTooltip:AddLine("Clique direito: configurações", 1, 1, 1)
        GameTooltip:AddLine("Arraste para reposicionar", 0.65, 0.65, 0.68)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function(dragButton)
            local scale = UIParent:GetEffectiveScale()
            local cursorX, cursorY = GetCursorPosition()
            cursorX = cursorX / scale
            cursorY = cursorY / scale
            local centerX, centerY = Minimap:GetCenter()
            if not centerX or not centerY then
                return
            end
            local angle = math.deg(Atan2(cursorY - centerY, cursorX - centerX))
            GManagerDB.minimap.angle = angle
            UpdateMinimapButtonPosition()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self.dragging = false
        self.ignoreNextClick = true
        self:SetScript("OnUpdate", nil)
    end)

    UI.minimapButton = button
    UpdateMinimapButtonPosition()
    ApplyMinimapVisibility()
end

-- -----------------------------------------------------------------------------
-- Timers e eventos nativos
-- -----------------------------------------------------------------------------

GM:SetScript("OnUpdate", function()
    local now = GetTime()
    local due = {}

    for name, timer in pairs(runtime.timers) do
        if now >= (timer.executeAt or now) then
            table.insert(due, name)
        end
    end

    for _, name in ipairs(due) do
        local timer = runtime.timers[name]
        if timer then
            if timer.repeating then
                timer.executeAt = now + timer.interval
            else
                runtime.timers[name] = nil
            end

            local callback = timer.callback
            if callback then
                local keepRunning = callback()
                if keepRunning == false then
                    runtime.timers[name] = nil
                end
            end
        end
    end
end)

local function HandleAutoInvite(message, sender)
    if not runtime.massInviteActive then
        return
    end

    local keyword = Lower(GManagerDB.invite.keyword)
    if keyword == "" or Lower(message) ~= keyword then
        return
    end

    local senderName = ShortName(sender)
    if not senderName or Lower(senderName) == Lower(UnitName("player")) then
        return
    end

    -- Durante a contagem regressiva, a palavra-chave não ignora o atraso.
    if runtime.massInviteEnds and GetTime() < runtime.massInviteEnds then
        runtime.pendingAutoInvites[Lower(senderName)] = senderName
        SetStatus(
            "Pedido de " .. senderName .. " recebido. Convite será enviado em "
                .. FormatDuration(runtime.massInviteEnds - GetTime()) .. "."
        )
        return
    end

    InviteUnit(senderName)
    SetStatus("Autoconvite enviado para " .. senderName .. ".")
end

GM:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= ADDON_NAME then
            return
        end

        if type(GManagerDB) ~= "table" then
            GManagerDB = {}
        end
        CopyDefaults(GManagerDB, DEFAULTS)

        SLASH_GMANAGER1 = "/gmgr"
        SLASH_GMANAGER2 = "/gmanager"
        SLASH_GMANAGER3 = "/guildmanager"
        SlashCmdList.GMANAGER = function(input)
            input = Lower(input)
            if input == "settings" or input == "config" then
                ToggleFrame("settings")
            elseif input == "roster" or input == "members" then
                ToggleFrame("roster")
            elseif input == "hide" then
                if UI.frame then UI.frame:Hide() end
            else
                ToggleFrame()
            end
        end

        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_GUILD_UPDATE")
        self:RegisterEvent("GUILD_ROSTER_UPDATE")
        self:RegisterEvent("CHAT_MSG_GUILD")
        self:RegisterEvent("CHAT_MSG_WHISPER")

    elseif event == "PLAYER_LOGIN" then
        CreateMinimapButton()
        ScheduleTimer("initialRoster", 1.5, RequestGuildRoster, false)

    elseif event == "PLAYER_ENTERING_WORLD" then
        ScheduleTimer("worldRoster", 2.0, RequestGuildRoster, false)

    elseif event == "PLAYER_GUILD_UPDATE" then
        RequestGuildRoster()
        ScheduleTimer("guildUpdateRefresh", 0.4, function()
            if UI.frame and UI.frame:IsShown() then
                RefreshPage(UI.currentPage)
            end
        end, false)

    elseif event == "GUILD_ROSTER_UPDATE" then
        ScheduleTimer("rosterRefresh", 0.35, function()
            if UI.frame and UI.frame:IsShown() then
                RefreshPage(UI.currentPage)
            end
        end, false)

    elseif event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_WHISPER" then
        local message, sender = ...
        HandleAutoInvite(message, sender)
    end
end)

GM:RegisterEvent("ADDON_LOADED")

-- API pública simples para outros addons ou macros.
function GM:Show(page)
    ToggleFrame(page)
end

function GM:Hide()
    if UI.frame then
        UI.frame:Hide()
    end
end

function GM:Refresh()
    RequestGuildRoster()
    RefreshPage(UI.currentPage)
end
