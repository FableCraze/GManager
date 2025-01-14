---@diagnostic disable: undefined-field, duplicate-set-field, undefined-global, redundant-parameter, deprecated, inject-field, param-type-mismatch
GManager = LibStub("AceAddon-3.0"):NewAddon("GManager", "AceConsole-3.0")
local TIMER = LibStub("AceTimer-3.0")
local AceGUI = LibStub("AceGUI-3.0")


local AceAddon = LibStub("AceAddon-3.0")
local EVENTS = AceAddon:NewAddon("EVENTS", "AceEvent-3.0")
local frameShown = false
local textStore
local gmessage
local keywords
local timerId
local spamTimerId
local playerToInv
local rankToPromote
local publicNoteToAdd
local officerNoteToAdd
local diff_to_set
local messageToSend
local ranks = {"asd","dfg"}
local guildName, guildRankName, guildRankIndex, realm = GetGuildInfo("player")
local function capitalize(str)
    return str:gsub("(%a)([%w_']*)", function(first, rest) return first:upper()..rest:lower() end)
end
local function GuildNameToIndex(name)
    name = string.lower(name)
    for i = 1,GetNumGuildMembers(true) do
        if string.lower((GetGuildRosterInfo(i))) == name then
            return i
        end
    end
end
local RestrictedZones = {"The Ruby Sanctum","Icecrown Citadel"}

local function CheckRestrictedZones(test)
    for _, zone in ipairs(RestrictedZones) do
        -- Check if the value of test matches any element in the table
        if test == zone then
            return true
        end
    end
    return false
end
local function GetDKP(string)
    local strings
    local containsOnlyAlphabetic = string.match(string, "^[A-Za-z]+$")
    if containsOnlyAlphabetic then
        for i = 1, GetNumGuildMembers(true) do -- Passing true includes offline members
            local name, _, _, _, _, _, officerNote, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if name == string then
                --local netNumbers2 = string.match(officerNote, "Net:(%d+) Tot:")
                strings = "Fix alt DKP"
            end
        end
    else
        local netNumbers = string.match(string, "Net:(%d+) Tot:")
        if netNumbers then
            strings = netNumbers .. " DKP"
        else strings = "FIX"
        end
    end
    return strings
end
GManager.db = {
    channelForSpam = 1,
    messageToSpam = "none",
    timerToSpam = 60
}
local PlayerCharacters = {}
local classCounts = {
    ["WARRIOR"] = 0,
    ["PALADIN"] = 0,
    ["HUNTER"] = 0,
    ["ROGUE"] = 0,
    ["PRIEST"] = 0,
    ["DEATHKNIGHT"] = 0,
    ["SHAMAN"] = 0,
    ["MAGE"] = 0,
    ["WARLOCK"] = 0,
    ["DRUID"] = 0
}
local classIcons = {
    ["WARRIOR"] = "Interface\\Icons\\ClassIcon_Warrior",
    ["PALADIN"] = "Interface\\Icons\\ClassIcon_Paladin",
    ["HUNTER"] = "Interface\\Icons\\ClassIcon_Hunter",
    ["ROGUE"] = "Interface\\Icons\\ClassIcon_Rogue",
    ["PRIEST"] = "Interface\\Icons\\ClassIcon_Priest",
    ["DEATHKNIGHT"] = "Interface\\Icons\\ClassIcon_DeathKnight",
    ["SHAMAN"] = "Interface\\Icons\\ClassIcon_Shaman",
    ["MAGE"] = "Interface\\Icons\\ClassIcon_Mage",
    ["WARLOCK"] = "Interface\\Icons\\ClassIcon_Warlock",
    ["DRUID"] = "Interface\\Icons\\ClassIcon_Druid",
}
local function CountClasses()
    classCounts = {
        ["WARRIOR"] = 0,
        ["PALADIN"] = 0,
        ["HUNTER"] = 0,
        ["ROGUE"] = 0,
        ["PRIEST"] = 0,
        ["DEATHKNIGHT"] = 0,
        ["SHAMAN"] = 0,
        ["MAGE"] = 0,
        ["WARLOCK"] = 0,
        ["DRUID"] = 0
    }
    for i = 1, GetNumGuildMembers(true) do
        local name, rankName, rankIndex, level, classDisplayName, zone, publicNote, officerNote, isOnline, status, class, achievementPoints, achievementRank, isMobile, canSoR, repStanding, guid = GetGuildRosterInfo(i)
        classCounts[class] = (classCounts[class] or 0) + 1
    end
end
local function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end
local function IsAlt(plrName)
    local PlayerIndex = GuildNameToIndex(plrName);
	local name,rank,rankindex,level,level,class,note,officernote,online,status,classFilename = GetGuildRosterInfo(PlayerIndex);
    local check = string.match(officernote,"%d+")
    if check == nil then return true
    else return false
    end
end
local function GetPlayerGuildRank(playerName)
    local playerInfo = {}
    local numGuildMembers = GetNumGuildMembers(true)

    for i = 1, numGuildMembers do
        local name, rankName, rankIndex, level, classDisplayName, zone, publicNote, officerNote, isOnline, status, class, achievementPoints, achievementRank, isMobile, canSoR, repStanding, guid = GetGuildRosterInfo(i)
        if name == playerName then
            playerInfo[1] = classDisplayName
            playerInfo[2] = class
            playerInfo[3] = rankName
            playerInfo[4] = publicNote
            playerInfo[5] = officerNote
            playerInfo[6] = zone
            playerInfo[7] = level
            break
        end
    end

    return playerInfo
end
local function GetClassColor(class)
    local classColor = RAID_CLASS_COLORS[class]
    if classColor then
        return string.format("ff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
    else
        return "ffffffff"  -- Default to white if class color not found
    end
end
local function FindChannelNumber(channelName)
    local numChannels = GetNumDisplayChannels()
    
    for i = 1, numChannels do
        local name, _, _, _, _, _, number = GetChannelDisplayInfo(i)
        if name == channelName then
            return number
        end
    end

    return nil  -- Channel not found
end
function TimerDone()
    SendChatMessage("Invite send to all 80 lvl online players", "GUILD")
    local guildSize = GetNumGuildMembers()
    for i = 1, guildSize do
        local playerName, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, level = GetGuildRosterInfo(i)
        InviteUnit(playerName)
        ConvertToRaid()
    end
end
function SendRecruitementMessage()
    local channelNumber = FindChannelNumber(channelForSpam)
    SendChatMessage(GManager.db.messageToSpam, "CHANNEL", nil, GManager.db.channelForSpam)
    spamTimerId = TIMER:ScheduleTimer(function()
        SendRecruitementMessage()
    end, GManager.db.timerToSpam)
end
function EVENTS:OnGuildChat(event, message, sender, _, _, _, _, _, _, _, _, _, guid)
    -- Your code to handle guild chat messages goes here
    if message == keywords then
        InviteUnit(sender)
        --print("Invite " .. sender)
    end
end
function EVENTS:OnWhisperReceived(event, message, sender, _, _, _, _, _, _, _, _, _, guid)
    -- Your code to handle guild chat messages goes here
    if message == keywords then
        InviteUnit(sender)
        --print("Invite " .. sender)
    end
end
function InvitePlayerToGroup(plrName)
    InviteUnit(plrName) 
end
function PMToPlayer(plrName)
    
    local popupFrame = AceGUI:Create("Frame")
    popupFrame:SetTitle("PM to: ".. plrName)
    popupFrame:SetWidth(500)
    popupFrame:SetHeight(150)
    popupFrame:SetLayout("Flow")

    local PMText = AceGUI:Create("EditBox")
    PMText:SetLabel("Message")
    PMText:SetWidth(450)
    PMText:SetFullWidth(true)
    PMText:SetCallback("OnEnterPressed", function(widget, event, text) messageToSend = text end)
    popupFrame:AddChild(PMText)

    -- Add a button to close the popup frame
    local closeButton = AceGUI:Create("Button")
    closeButton:SetText("Send")
    closeButton:SetWidth(100)
    closeButton:SetCallback("OnClick", function() 
        SendChatMessage(messageToSend, "WHISPER", nil, plrName)
        popupFrame:Release()
    end)
    popupFrame:AddChild(closeButton)

    popupFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 500)
    -- Show the popup frame
    popupFrame:Show()
end
local function GetGuildRanks()
    local numRanks = GuildControlGetNumRanks()
    local ranks = {}

    for i = 1, numRanks do
        local rankName, _, _ = GuildControlGetRankName(i)
        table.insert(ranks, rankName)
    end

    return ranks
end
local function SetGuildRank(playerName, newRankIndex)
    GuildControlSetRank(newRankIndex)
end
local function SetPublicNote(playerName, newNote)
    local numGuildMembers = GetNumGuildMembers()
    for i = 1, numGuildMembers do
        local name, _, _, _, _, _, _, _, _, _, _, _, _, publicNote = GetGuildRosterInfo(i)
        if name == playerToInv then
            GuildRosterSetPublicNote(i, publicNote)
            return
        end
    end
    print(playerName.." is not in your guild.")
end
-- Function to set a player's officer note
local function SetOfficerNote(playerName, newNote)
    local numGuildMembers = GetNumGuildMembers()
    for i = 1, numGuildMembers do
        local name, _, _, _, _, _, _, officerNote = GetGuildRosterInfo(i)
        if name == playerToInv then
            GuildRosterSetOfficerNote(i, officerNote)
            return
        end
    end
end
-- invite player tab 
local function GInvitePlayer(container)
    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel("Player name:")
    editbox:SetWidth(330)
    editbox:SetFullWidth(true)
    editbox:SetCallback("OnEnterPressed", function(widget, event, text) playerToInv = text end)
    container:AddChild(editbox)

    local grank = AceGUI:Create("Dropdown")
    grank:SetLabel("Rank")
    grank:SetMultiselect(false)
    grank:SetCallback("OnValueChanged",function(widget,event,value) rankToPromote = value end)
    ranks = GetGuildRanks()
    grank:SetList(ranks)
    grank:SetWidth(330)
    grank:SetFullWidth(true)
    container:AddChild(grank)

    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel("Public note:")
    editbox:SetWidth(330)
    editbox:SetFullWidth(true)
    editbox:SetCallback("OnEnterPressed", function(widget, event, text) publicNoteToAdd = text end)
    container:AddChild(editbox)

    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel("Officer note:")
    editbox:SetWidth(330)
    editbox:SetFullWidth(true)
    editbox:SetCallback("OnEnterPressed", function(widget, event, text) officerNoteToAdd = text end)
    container:AddChild(editbox)

    local button = AceGUI:Create("Button")
    button:SetText("Invite player")
    button:SetWidth(330)
    button:SetFullWidth(true)
    button:SetCallback("OnClick", function()
        GuildInvite(playerToInv)
        print("Invite plyer: " .. playerToInv .. " with rank: " .. rankToPromote .. " Public Note: " .. publicNoteToAdd .. " Officer Note: " .. officerNoteToAdd)
        end)
    container:AddChild(button)

    local button2 = AceGUI:Create("Button")
    button2:SetText("Promote")
    button2:SetWidth(330)
    button2:SetFullWidth(true)
    button2:SetCallback("OnClick", function()
        SetGuildRank(playerToInv,rankToPromote)
        SetPublicNote(playerToInv,publicNoteToAdd)
        SetOfficerNote(playerToInv,officerNoteToAdd)
        end)
    container:AddChild(button2)
end
-- kick player tab
local function KickPlayers(container)
    
    local list = AceGUI:Create("MultiLineEditBox")
    list:SetLabel("List of all characters")
    list:SetWidth(330)
    --list.editBox:SetJustifyH("LEFT")
    list:SetFullWidth(true)
    list:SetFullHeight(true)
    list.frame:SetScript("OnKeyDown", function(self)
        -- Block any attempts to edit the text
        return true
    end)
    list.frame:SetScript("OnMouseDown", function(self)
        -- Block any attempts to set focus (clicking) on the edit box
        return true
    end)
    list:DisableButton(true)
    list:SetNumLines(15)

    local descc = AceGUI:Create("Label")
    descc:SetText("WARNING: DO NOT SHOW OFFLINE PLAYERS IN THE GUILD!")
    descc:SetColor(1, 0, 0)
    descc:SetFont("Fonts\\FRIZQT__.TTF", 14)
    --descc:SetJustifyH("CENTER")
    descc:SetFullWidth(true)
    container:AddChild(descc)

    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel("Player name:")
    editbox:SetWidth(330)
    editbox:SetFullWidth(true)
    editbox:SetCallback("OnEnterPressed", function(widget, event, text) textStore = firstToUpper(text) end)
    container:AddChild(editbox)

    local button = AceGUI:Create("Button")
    button:SetText("Find Player")
    button:SetWidth(330)
    button:SetFullWidth(true)
    button:SetCallback("OnClick", function()
        list:SetText("")
        PlayerCharacters = {}
        if IsAlt(textStore) == false then
            for i = 1, GetNumGuildMembers(true) do
                local name, _, _, _, _, _, note, officernote = GetGuildRosterInfo(i)
                if name == textStore or string.find(officernote, textStore) or string.find(note, textStore) then
                    local plrInfo = GetPlayerGuildRank(name)
                    table.insert(PlayerCharacters,name)
                    if list:GetText() == nil or list:GetText() == '' then
                        list:SetText(" |cff00ff00" .. name .. "|r " .. "|cff0070de" .. plrInfo[3] .. "|r " .. " |c" .. GetClassColor(plrInfo[2]).. plrInfo[1] .. "|r")
                    else
                        list:SetText(list:GetText() .. "\n".. " |cff00ff00" .. name .. "|r " .. "|cff0070de" .. plrInfo[3] .. "|r " .. " |c" .. GetClassColor(plrInfo[2]).. plrInfo[1] .. "|r")
                    end
                end
            end 
        else
            local PlayerIndex = GuildNameToIndex(textStore);
	        local name,rank,rankindex,level,level,class,note,officernote,online,status,classFilename = GetGuildRosterInfo(PlayerIndex);
            local MainCharacter = officernote
            for i = 1, GetNumGuildMembers(true) do
                local name, _, _, _, _, _, note, officernote = GetGuildRosterInfo(i)
                if name == MainCharacter or string.find(officernote, MainCharacter) or string.find(note, MainCharacter) then
                    local plrInfo = GetPlayerGuildRank(name)
                    table.insert(PlayerCharacters,name)
                    if list:GetText() == nil or list:GetText() == '' then
                        list:SetText(" |cff00ff00" .. name .. "|r " .. "|cff0070de" .. plrInfo[3] .. "|r " .. " |c" .. GetClassColor(plrInfo[2]).. plrInfo[1] .. "|r")
                    else
                        list:SetText(list:GetText() .. "\n".. " |cff00ff00" .. name .. "|r " .. "|cff0070de" .. plrInfo[3] .. "|r " .. " |c" .. GetClassColor(plrInfo[2]).. plrInfo[1] .. "|r")
                    end
                end
            end 
        end
        
        end)
    container:AddChild(button)
    container:AddChild(list)

    local buttonKick = AceGUI:Create("Button")
    buttonKick:SetText("Kick!")
    buttonKick:SetWidth(330)
    buttonKick:SetFullWidth(true)
    buttonKick:SetCallback("OnClick", function()
        for i = 1, GetNumGuildMembers(true) do
            local name, _, _, _, _, _, note, officernote = GetGuildRosterInfo(i)
            -- Check if the player's name or alt's name matches the provided playerName
            if name == textStore or string.find(officernote, textStore) or string.find(note, textStore) then
                -- Kick the player or alt
                GuildUninvite(name)
                SendChatMessage("Kicked "..name.." from the guild.", "GUILD")
            end
        end
        editbox:SetText("")
        list:SetText("")
        PlayerCharacters = {}
        end)
    container:AddChild(buttonKick)
end
-- mass invite to raid tab
local function MassInviteToGroup(container)
    
    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel("Enter timer (in seconds):")
    editbox:SetWidth(330)
    editbox:SetFullWidth(true)
    editbox:SetCallback("OnEnterPressed", function(widget, event, text) textStore = tonumber(text) end)
    container:AddChild(editbox)

    local editbox2 = AceGUI:Create("EditBox")
    editbox2:SetLabel("Message in guild chat")
    editbox2:SetWidth(330)
    editbox2:SetFullWidth(true)
    editbox2:SetCallback("OnEnterPressed", function(widget, event, text) gmessage = text end)
    container:AddChild(editbox2)

    local editbox3 = AceGUI:Create("EditBox")
    editbox3:SetLabel("Words for autoinvite")
    editbox3:SetWidth(330)
    editbox3:SetFullWidth(true)
    editbox3:SetCallback("OnEnterPressed", function(widget, event, text) keywords = text end)
    container:AddChild(editbox3)

    local btnBeginTimer = AceGUI:Create("Button")
    btnBeginTimer:SetText("Start")
    btnBeginTimer:SetWidth(330)
    btnBeginTimer:SetFullWidth(true)
    btnBeginTimer:SetCallback("OnClick", function()
        if gmessage ~= nil then
            SendChatMessage(gmessage, "GUILD")
        end
        if keywords ~= nil then
            EVENTS:RegisterEvent("CHAT_MSG_GUILD", "OnGuildChat")
            EVENTS:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisperReceived")
            SendChatMessage("Type >> " .. keywords .. " << in guild chat or PM to get invited. Autoinvite will be send after " .. textStore .. " seconds. Leave your groups now!", "GUILD")
        end
        timerId = TIMER:ScheduleTimer(function()
            TimerDone()
        end, textStore)
        end)
    container:AddChild(btnBeginTimer)

    local btnBeginTimer2 = AceGUI:Create("Button")
    btnBeginTimer2:SetText("Reannounce")
    btnBeginTimer2:SetWidth(330)
    btnBeginTimer2:SetFullWidth(true)
    btnBeginTimer2:SetCallback("OnClick", function()
        if gmessage ~= nil then
            SendChatMessage(gmessage, "GUILD")
        end
        if keywords ~= nil then
            EVENTS:RegisterEvent("CHAT_MSG_GUILD", "OnGuildChat")
            EVENTS:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisperReceived")
            SendChatMessage("Type >> " .. keywords .. " << in guild chat or PM to get invited.", "GUILD")
        end
        end)
    container:AddChild(btnBeginTimer2)

    local btnStopTimer = AceGUI:Create("Button")
    btnStopTimer:SetText("Stop")
    btnStopTimer:SetWidth(330)
    btnStopTimer:SetFullWidth(true)
    btnStopTimer:SetCallback("OnClick", function()
            EVENTS:UnregisterEvent("CHAT_MSG_GUILD")
            EVENTS:UnregisterEvent("CHAT_MSG_WHISPER")
            TIMER:CancelTimer(timerId)
        end)
    container:AddChild(btnStopTimer)

    local head1 = AceGUI:Create("Heading")
    head1:SetText("Raid Controll")
    head1:SetFullWidth(true)
    head1:SetHeight(30)
    container:AddChild(head1)

    local RDiff = AceGUI:Create("Dropdown")
    RDiff:SetLabel("Raid Difficulty")
    RDiff:SetMultiselect(false)
    RDiff:SetCallback("OnValueChanged",function(widget,event,value) diff_to_set = value end)
    local diffs = {"10N","10HC","25N","25HC"}
    RDiff:SetList(diffs)
    RDiff:SetWidth(330)
    RDiff:SetFullWidth(true)
    container:AddChild(RDiff)

    local btnBeginTimer2 = AceGUI:Create("Button")
    btnBeginTimer2:SetText("Convert to RAID")
    btnBeginTimer2:SetWidth(330)
    btnBeginTimer2:SetFullWidth(true)
    btnBeginTimer2:SetCallback("OnClick", function()
        if not IsInRaid() then
            ConvertToRaid()
        end

        if diff_to_set == "10N" then
            SetLegacyRaidDifficulty(3)
        elseif diff_to_set == "10HC" then
            SetLegacyRaidDifficulty(5)
        elseif diff_to_set == "25N" then
            SetLegacyRaidDifficulty(4)
        elseif diff_to_set == "25HC" then
            SetLegacyRaidDifficulty(6)
        end
        end)
    container:AddChild(btnBeginTimer2)

    local btnDisb = AceGUI:Create("Button")
    btnDisb:SetText("Disband Group")
    btnDisb:SetWidth(330)
    btnDisb:SetFullWidth(true)
    btnDisb:SetCallback("OnClick", function()
            if IsInGroup() then
                for i = 1, GetNumGroupMembers() do
                    local unit = IsInRaid() and "raid" .. i or "party" .. i
                    UninviteUnit(unit)
                end
            end
        end)
    container:AddChild(btnDisb)
end
-- guild info tab
local function GuildInfo(container)
    
    local head1 = AceGUI:Create("Heading")
    head1:SetText("Players")
    head1:SetFullWidth(true)
    head1:SetHeight(30)
    container:AddChild(head1)

    local desc2 = AceGUI:Create("Label")
    desc2:SetText("Total: " .. GetNumGuildMembers(true))
    desc2:SetColor(1, 1, 0)
    desc2:SetFont("Fonts\\FRIZQT__.TTF", 14)
    --desc2:SetJustifyH("CENTER")
    desc2:SetFullWidth(true)
    container:AddChild(desc2)

    local desc3 = AceGUI:Create("Label")
    desc3:SetText("Online: " .. GetNumGuildMembers())
    desc3:SetColor(1, 1, 0)
    desc3:SetFont("Fonts\\FRIZQT__.TTF", 14)
    --desc3:SetJustifyH("CENTER")
    desc3:SetFullWidth(true)
    container:AddChild(desc3)

    local head2 = AceGUI:Create("Heading")
    head2:SetText("Classes")
    head2:SetFullWidth(true)
    head2:SetHeight(30)
    container:AddChild(head2)

    CountClasses()

    local formattedClassCounts = {}
    for classz, count in pairs(classCounts) do
        formattedClassCounts[capitalize(classz)] = count
    end

    local simpleGroup = AceGUI:Create("SimpleGroup")
    simpleGroup:SetLayout("Flow")
    simpleGroup:SetFullWidth(true)
    -- Iterate over classCounts and create icon and label for each class
    for class, count in pairs(formattedClassCounts) do
        -- Create class icon
        local icon = AceGUI:Create("Icon")
        local iconPath = "Interface\\Icons\\ClassIcon_" .. class
        icon:SetImage("Interface\\Icons\\ClassIcon_" .. class)
        icon:SetWidth(10)
        icon:SetHeight(10)
    
        -- Get localized display name for the class
        local displayName = LOCALIZED_CLASS_NAMES_MALE[class] or class
    
        -- Create label for class count using localized display name
        local label = AceGUI:Create("Label")
        label:SetText(displayName .. ": " .. count)
    
        -- Add icon and label to the SimpleGroup
        simpleGroup:AddChildren(label)
    end
    container:AddChild(simpleGroup)
end
-- guild recruit tab
local function ReqruitMembers(container)

    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel("Channel NUMBER")
    editbox:SetWidth(330)
    editbox:SetFullWidth(true)
    editbox:SetText(GManager.db.channelForSpam)
    editbox:SetCallback("OnEnterPressed", function(widget, event, text) GManager.db.channelForSpam = tonumber(text) end)
    container:AddChild(editbox)

    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel("Time in seconds (min 68 sec)")
    editbox:SetWidth(330)
    editbox:SetText(GManager.db.timerToSpam)
    editbox:SetFullWidth(true)
    editbox:SetCallback("OnEnterPressed", function(widget, event, text) GManager.db.timerToSpam = tonumber(text) end)
    container:AddChild(editbox)

    local messageBox = AceGUI:Create("MultiLineEditBox")
    messageBox:SetLabel("Message")
    messageBox:SetWidth(330)
    messageBox:SetText(GManager.db.messageToSpam)
    messageBox:SetFullWidth(true)
    messageBox:SetCallback("OnEnterPressed", function(widget, event, text) GManager.db.messageToSpam = text end)
    container:AddChild(messageBox)

    local btnBeginTimer = AceGUI:Create("Button")
    btnBeginTimer:SetText("Start spam")
    btnBeginTimer:SetWidth(330)
    btnBeginTimer:SetFullWidth(true)
    btnBeginTimer:SetCallback("OnClick", function()
        spamTimerId = TIMER:ScheduleTimer(function()
            SendRecruitementMessage()
        end, GManager.db.timerToSpam)
        end)
    container:AddChild(btnBeginTimer)

    local btnStopTimer = AceGUI:Create("Button")
    btnStopTimer:SetText("Stop spam")
    btnStopTimer:SetWidth(330)
    btnStopTimer:SetFullWidth(true)
    btnStopTimer:SetCallback("OnClick", function()
            TIMER:CancelTimer(spamTimerId)
        end)
    container:AddChild(btnStopTimer)

end
-- settings tab
local function Settings(container)
    local desc = AceGUI:Create("Label")
    desc:SetText("Settings")
    desc:SetColor(1, 1, 0)
    desc:SetFont("Fonts\\FRIZQT__.TTF", 18)
    --desc:SetJustifyH("CENTER")
    desc:SetFullWidth(true)
    container:AddChild(desc)
end
local function Rooster(container)
    local head2 = AceGUI:Create("Heading")
    head2:SetText("Rooster")
    head2:SetFullWidth(true)
    head2:SetHeight(30)
    container:AddChild(head2)

    local simpleGroup = AceGUI:Create("SimpleGroup")
    simpleGroup:SetLayout("Fill")
    simpleGroup:SetFullWidth(true)
    simpleGroup:SetFullHeight(true)
    simpleGroup:SetHeight(300)
    simpleGroup:SetWidth(480)
    
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow") -- probably?
    scroll:SetFullWidth(true)
    --scroll:SetFullHeight(true)
    scroll:SetHeight(300)
    scroll:SetWidth(480)
    simpleGroup:AddChild(scroll)

    local numTotalMembers = GetNumGuildMembers()


    --playerInfo[1] = classDisplayName
    --playerInfo[2] = class
    --playerInfo[3] = rankName
    --playerInfo[4] = publicNote
    --playerInfo[5] = officerNote
    --playerInfo[6] = zone
    --playerInfo[7] = level

    for i = 1, numTotalMembers do
        local name, rank, _, _, class, _, _, _, online = GetGuildRosterInfo(i)
        if online then
            local plrInfo = GetPlayerGuildRank(name)
            local simpleInnerGroup = AceGUI:Create("SimpleGroup")
            simpleInnerGroup:SetLayout("Flow")
            simpleInnerGroup:SetFullWidth(true)
            simpleInnerGroup:SetHeight(50)
            
            local classIconImage = AceGUI:Create("Icon")
            --classIconImage:SetImage(ClassIconPath[cls])
            local icn = classIcons[string.upper(plrInfo[2])]
            --print("DEBUG: " .. string.upper(class) .. "\n" .. icn)
            classIconImage:SetImage(icn)
            classIconImage:SetImageSize(28,28)
            classIconImage:SetLabel("[" .. plrInfo[7] .. "]|c" .. GetClassColor(plrInfo[2]).. name .. "|r")
            simpleInnerGroup:AddChild(classIconImage)

            local part1, part2 = string.match(plrInfo[4], "MS:%s*(.-)%s*OS:%s*(.-)$")

            local MSIcon = AceGUI:Create("Icon")
            MSIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
            MSIcon:SetImageSize(28,28)
            MSIcon:SetLabel(part1)
            MSIcon:SetWidth(40)
            MSIcon:SetCallback("OnClick", function()
                print("MS Change")
            end)
            simpleInnerGroup:AddChild(MSIcon)

            local OSIcon = AceGUI:Create("Icon")
            OSIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
            OSIcon:SetImageSize(28,28)
            OSIcon:SetLabel(part2)
            OSIcon:SetWidth(40)
            OSIcon:SetCallback("OnClick", function()
                print("OS Change")
            end)
            simpleInnerGroup:AddChild(OSIcon)

            local BTNInv = AceGUI:Create("Icon")
            BTNInv:SetImage("Interface\\Icons\\INV_Misc_GroupNeedMore")
            BTNInv:SetWidth(50)
            BTNInv:SetImageSize(40,40)
            BTNInv:SetCallback("OnClick", function()
                InvitePlayerToGroup(name)
            end)
            simpleInnerGroup:AddChild(BTNInv)

            local BTNPm = AceGUI:Create("Icon")
            BTNPm:SetImage("Interface\\ChatFrame\\UI-ChatWhisperIcon")
            BTNPm:SetWidth(50)
            BTNPm:SetImageSize(50,50)
            BTNPm:SetCallback("OnClick", function()
                PMToPlayer(name)
            end)
            simpleInnerGroup:AddChild(BTNPm)

            local LabDKP = AceGUI:Create("Label")
            LabDKP:SetWidth(120)
            LabDKP:SetText("|cffffa500 " .. GetDKP(plrInfo[5]) .. "|r")
            LabDKP:SetFont("Fonts\\FRIZQT__.TTF", 15)
            --charName:SetJustifyH("LEFT")
            simpleInnerGroup:AddChild(LabDKP)

            local LabZone = AceGUI:Create("Label")
            LabZone:SetWidth(200)
            if CheckRestrictedZones(plrInfo[6]) then
                LabZone:SetText("|cffff0000 " .. plrInfo[6] .. "|r")
            else
                LabZone:SetText("|cff00ff00 " .. plrInfo[6] .. "|r")
            end
            
            LabZone:SetFont("Fonts\\FRIZQT__.TTF", 12)
            --charName:SetJustifyH("LEFT")
            simpleInnerGroup:AddChild(LabZone)

            scroll:AddChild(simpleInnerGroup)
        end
    end

    container:AddChild(simpleGroup)

end
-- Callback function for OnGroupSelected
local function SelectGroup(container, event, group)
    container:ReleaseChildren()
    if group == "tab1" then
        GInvitePlayer(container)
    elseif group == "tab2" then
        KickPlayers(container)
    elseif group == "tab3" then
        MassInviteToGroup(container)
    elseif group == "tab4" then
        GuildInfo(container)
    elseif group == "tab5" then
        ReqruitMembers(container)
    elseif group == "tab6" then
        Settings(container)
    elseif group == "tab7" then
        Rooster(container)
    end
end
-- Create the frame container
local function showFrame()
    if frameShown then
      return
    end
    frameShown = true
    local frame = AceGUI:Create("Frame")
    frame:SetHeight(500)
    frame:SetWidth(700)
    if guildName ~= nil then
        frame:SetTitle(guildName)
    else
        frame:SetTitle("Guild Menager")
    end
    frame:SetLayout("Fill")
    frame:SetCallback("OnClose",function(widget) AceGUI:Release(widget) frameShown = false end)
    local tab =  AceGUI:Create("TabGroup")
    tab:SetLayout("List")
    -- Setup which tabs to show
    tab:SetTabs({{text="Invite", value="tab1"}, {text="Kick", value="tab2"},{text="Mass Invite",value="tab3"},{text="Guild Info",value="tab4"},{text="Rooster",value="tab7"},{text="Recruit",value="tab5"},{text="Settings",value="tab6"}})
    -- Register callback
    tab:SetCallback("OnGroupSelected", SelectGroup)
    -- Set initial Tab (this will fire the OnGroupSelected callback)
    tab:SelectTab("tab7")
    -- add to the frame container
    frame:AddChild(tab)
  end
-- MINIMAP BUTTON
local miniButton = LibStub("LibDataBroker-1.1"):NewDataObject("GManagerIcon", {
    type = "data source",
    text = "Guild Management System",
    icon = "Interface\\HELPFRAME\\HelpIcon-KnowledgeBase",
    OnClick = function(self, btn)
        -- OnClick code goes here
        showFrame()
    end,
    OnTooltipShow = function(tooltip)
        if not tooltip or not tooltip.AddLine then return end
        tooltip:AddLine("Guild Management System")
    end,
    })
    local icon = LibStub("LibDBIcon-1.0", true)
    icon:Register("GManagerIcon", miniButton, GManagerDB)
-- MINIMAP BUTTON
function GManager:OnInitialize()
	-- Called when the addon is loaded
    
end
function GManager:OnEnable()
	-- Called when the addon is enabled
end
function GManager:OnDisable()
	-- Called when the addon is disabled
end

function GManager:HandleGMCommand(input)
    showFrame()
end

GManager:RegisterChatCommand("gmgr", "HandleGMCommand")