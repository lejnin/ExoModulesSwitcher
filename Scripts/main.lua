local wtChat
local valuedText = common.CreateValuedText()
local addonName = common.GetAddonName()

local OpenConfigButton
local Panel
local Settings
local ItemDesc
local SettingsRowDesc

local ConfigTalents
local TalentIdByIndex = {}
local TalentsBySender = {}
local wItems = {}

local dndOn = false

function LogToChat(text)
    if not wtChat then
        wtChat = stateMainForm:GetChildUnchecked("ChatLog", false)
        wtChat = wtChat:GetChildUnchecked("Container", true)
        local formatVT = "<html fontname='AllodsFantasy' fontsize='14' shadow='1'><rs class='color'><r name='addonName'/><r name='text'/></rs></html>"
        valuedText:SetFormat(userMods.ToWString(formatVT))
    end

    if wtChat and wtChat.PushFrontValuedText then
        if not common.IsWString(text) then
            text = userMods.ToWString(text)
        end

        valuedText:ClearValues()
        valuedText:SetClassVal("color", "LogColorYellow")
        valuedText:SetVal("text", text)
        valuedText:SetVal("addonName", userMods.ToWString("EMS: "))
        wtChat:PushFrontValuedText(valuedText)
    end
end

function CreateSettingsPanel()
    Settings = mainForm:GetChildUnchecked("Settings", false)
    Settings:Show(false)
    DnD.Init(Settings, Settings:GetChildUnchecked('WindowHeader', false), true)

    local headerText = Settings:GetChildUnchecked("HeaderText", true)
    local formatVT = "<html fontname='AllodsFantasy' alignx='center' fontsize='14' shadow='1'><rs class='color'><r name='text'/></rs></html>"
    headerText:SetFormat(userMods.ToWString(formatVT))
    headerText:SetVal("text", userMods.ToWString('EMS - Выбор модулей'))
    headerText:SetClassVal("color", "FullCollectionColor")

    local SettingsRow = mainForm:GetChildUnchecked('SettingsRow', true)
    SettingsRowDesc = SettingsRow:GetWidgetDesc()
    SettingsRow:DestroyWidget()

    LoadModulesListToSettingsPanel()

    common.RegisterReactionHandler(function()
        Settings:Show(false)
    end, 'cross_close')

    common.RegisterReactionHandler(OnSettingsRowPointing, 'onSettingsRowPointing')
    common.RegisterReactionHandler(OnSettingsRowClick, 'onSettingsRowClick')
end

function OnSettingsRowClick(reaction)
    local talentId = TalentsBySender[reaction.sender]
    if ConfigTalents[talentId] == nil then
        ConfigTalents[talentId] = true
    else
        ConfigTalents[talentId] = nil
    end

    SaveConfig()
    UpdatePanel()
end

function OnSettingsRowPointing(reaction)
    if reaction.active then
        reaction.widget:SetBackgroundColor({ a = 0.1 })
    else
        reaction.widget:SetBackgroundColor({ a = 0 })
    end
end

function LoadModulesListToSettingsPanel()
    local container = Settings:GetChildUnchecked('SettingsContainer', true)
    local exoMountId = mount.GetExoMount()
    local availableTalents = mount.GetAvailableTalents(exoMountId)
    local index = 0

    for _, talentId in ipairs(availableTalents[#availableTalents].talents) do
        local unlock = avatar.GetUnlockInfo(talentId:GetInfo().unlock)
        if unlock ~= nil then
            local columnIndex = index % 2 -- Определение номера колонки: 0 или 1
            local rowIndex = math.floor(index / 2) -- Определение номера строки

            local settingRow = mainForm:CreateWidgetByDesc(SettingsRowDesc)
            local wName = 'SI' .. tostring(index)
            settingRow:SetName(wName)
            TalentsBySender[wName] = talentId

            local placementPlain = settingRow:GetPlacementPlain()
            placementPlain.posX = columnIndex * placementPlain.sizeX -- Позиция по X
            placementPlain.posY = rowIndex * placementPlain.sizeY -- Позиция по Y
            settingRow:SetPlacementPlain(placementPlain)

            settingRow:GetChildUnchecked('SettingImageItem', false):SetBackgroundTexture(unlock.image)
            local text = settingRow:GetChildUnchecked('SettingsItemName', false)
            local str = '<body color="0xFFFFFFFF" fontsize="14" outline="1"><rs class="class"><r name="text"/></rs></body>'
            text:SetFormat(userMods.ToWString(str))
            text:SetVal('text', unlock.name)

            container:AddChild(settingRow)

            index = index + 1
        end
    end
end

function CreatePanel()
    Panel = mainForm:GetChildUnchecked("ItemsPanel", false)
    Panel:SetBackgroundColor({ a = 0.0 })

    -- задать общие размеры панели
    local CommonPanelPlacement = Panel:GetPlacementPlain();
    CommonPanelPlacement.sizeY = config['ICON_SIZE']
    CommonPanelPlacement.sizeX = config['ICON_SIZE'] * GetTableLength(modules) + 20
    Panel:SetPlacementPlain(CommonPanelPlacement)

    local Item = Panel:GetChildUnchecked("PanelItem", false)
    ItemDesc = Item:GetWidgetDesc()
    Item:DestroyWidget()

    -- восстановить расположение из настроек dnd
    DnD.Init(Panel, nil, true)
    DnD.Remove(Panel)

    common.RegisterReactionHandler(OnItemClick, 'EVENT_ON_ITEM_CLICK')
end

function OnItemClick(reaction)
    local talentIndex = GetTalentIndex(reaction)

    if TalentIdByIndex[talentIndex] == nil then
        return
    end

    local exoMountId = mount.GetExoMount()
    local talents = mount.GetSelectedTalents(exoMountId)
    talents[#talents] = TalentsBySender[reaction.sender]

    mount.SelectTalents(exoMountId, talents)
end

function OnItemPointing(params)

end

function CreateConfigButton()
    OpenConfigButton = mainForm:GetChildUnchecked("OpenConfigButton", false)
    OpenConfigButton:Show(true)

    DnD.Init(OpenConfigButton, nil, true)

    common.RegisterReactionHandler(OnClickButton, 'EVENT_ON_CONFIG_BUTTON_CLICK')
    common.RegisterReactionHandler(OnRightClickButton, 'EVENT_ON_CONFIG_BUTTON_RIGHT_CLICK')
    common.RegisterEventHandler(OnAoPanelStart, 'AOPANEL_START')
end

function BuildItemWidgetName(index)
    return 'MountTalent' .. tostring(index)
end

function GetTalentIndex(reaction)
    return tonumber(string.sub(reaction.sender, 12))
end

function AddItem(unlock, index)
    wItems[index] = mainForm:CreateWidgetByDesc(ItemDesc)
    wItems[index]:SetName(BuildItemWidgetName(index))
    wItems[index]:GetChildUnchecked('ImageItem', false):SetBackgroundTexture(unlock.image)

    local placementPlain = wItems[index]:GetPlacementPlain()
    placementPlain.posX = index * config['ICON_SIZE']
    placementPlain.sizeX = config['ICON_SIZE']
    placementPlain.sizeY = config['ICON_SIZE']
    wItems[index]:SetPlacementPlain(placementPlain)

    Panel:AddChild(wItems[index])
end

function GetCooldownReadableString(timerInMs)
    if timerInMs >= 86400000 then
        return tostring(math.floor(timerInMs / 86400000)) .. 'd'
    end

    if timerInMs >= 3600000 then
        return tostring(math.floor(timerInMs / 3600000)) .. 'h'
    end

    if timerInMs >= 60000 then
        return tostring(math.floor(timerInMs / 60000)) .. 'm'
    end

    return tostring(math.floor(timerInMs / 1000)) .. 's'
end

function UpdateTimers()

end

function OnSecondTimer()
    UpdateTimers()
end

function OnAoPanelStart()
    local SetVal = { val = userMods.ToWString('EMS') }
    local params = { header = SetVal, ptype = 'button', size = 30 }
    userMods.SendEvent('AOPANEL_SEND_ADDON', {
        name = addonName, sysName = addonName, param = params
    })

    common.RegisterEventHandler(OnAoPanelClickButton, 'AOPANEL_BUTTON_LEFT_CLICK')
    common.RegisterEventHandler(OnAoPanelRightClickButton, 'AOPANEL_BUTTON_RIGHT_CLICK')

    OpenConfigButton:Show(false)
end

function OnAoPanelClickButton(params)
    if params.sender ~= nil and params.sender ~= addonName then
        return
    end

    OnClickButton()
end

function OnAoPanelRightClickButton(params)
    if params.sender ~= nil and params.sender ~= addonName then
        return
    end

    OnRightClickButton()
end

function OnClickButton()
    if DnD:IsDragging() then
        return
    end

    if Settings == nil then
        return
    end

    Settings:Show(Settings:IsVisible() == false)
end

function OnRightClickButton()
    if DnD:IsDragging() then
        return
    end

    if dndOn then
        DnD.Remove(Panel)
        Panel:SetBackgroundColor({ r = 1; g = 1; b = 1; a = 0 })
        LogToChat('DnD off')
    else
        DnD.Init(Panel, nil, true)
        Panel:SetBackgroundColor({ r = 1; g = 1; b = 1; a = 0.4 })
        LogToChat('DnD on')
    end

    dndOn = not dndOn
end

function LoadConfig()
    ConfigTalents = userMods.GetAvatarConfigSection(addonName).talents or {}
end

function UpdatePanel()
    for index, w in pairs(wItems) do
        w:DestroyWidget()
        wItems[index] = nil
    end

    local index = 0
    for talentId, _ in pairs(ConfigTalents) do
        local unlock = avatar.GetUnlockInfo(talentId:GetInfo().unlock)
        AddItem(unlock, index)
        index = index + 1
    end

    local CommonPanelPlacement = Panel:GetPlacementPlain();
    CommonPanelPlacement.sizeY = config['ICON_SIZE']
    CommonPanelPlacement.sizeX = config['ICON_SIZE'] * GetTableLength(ConfigTalents) + 20
    Panel:SetPlacementPlain(CommonPanelPlacement)
end

function SaveConfig()
    local Config = userMods.GetAvatarConfigSection(addonName) or {}
    Config.talents = ConfigTalents
    userMods.SetAvatarConfigSection(addonName, Config)
end

function OnEventAvatarCreated()
    mainForm:Show(false)

    LoadConfig()

    CreatePanel()
    UpdatePanel()

    CreateSettingsPanel()
    CreateConfigButton()

    --LoadPanelItems()

    mainForm:Show(true)
end

function GetTableLength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function Init()
    if avatar and avatar.IsExist() then
        OnEventAvatarCreated()
    else
        common.RegisterEventHandler(OnEventAvatarCreated, "EVENT_AVATAR_CREATED")
    end
end

Init()
