local wtChat
local valuedText = common.CreateValuedText()
local addonName = common.GetAddonName()

local OpenConfigButton
local Panel
local ItemDesc

local TalentIdByIndex = {}
local SelectTalentByIndexAfterCombat

local dndOn = false
local avatarId
local isInCombat = object.IsInCombat

local function LogToChat(text)
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
        valuedText:SetClassVal('color', 'LogColorYellow')
        valuedText:SetVal('text', text)
        valuedText:SetVal('addonName', userMods.ToWString('EMS: '))
        wtChat:PushFrontValuedText(valuedText)
    end
end

local function StripTags(s)
    return common.IsWString(s) and common.CreateValuedText { format = s }:ToWString() or s
end

local function BuildItemWidgetName(index)
    return 'MountTalent' .. tostring(index)
end

local function AddItem(unlock, index)
    local widget = mainForm:CreateWidgetByDesc(ItemDesc)
    widget:SetName(BuildItemWidgetName(index))
    widget:GetChildUnchecked('ImageItem', false):SetBackgroundTexture(unlock.image)

    local placementPlain = widget:GetPlacementPlain()
    placementPlain.posX = index * config['ICON_SIZE']
    placementPlain.sizeX = config['ICON_SIZE']
    placementPlain.sizeY = config['ICON_SIZE']
    widget:SetPlacementPlain(placementPlain)

    Panel:AddChild(widget)
end

local function SelectTalent(talentIndex)
    local exoMountId = mount.GetExoMount()
    local talents = mount.GetSelectedTalents(exoMountId)
    talents[#talents] = TalentIdByIndex[talentIndex]

    mount.SelectTalents(exoMountId, talents)
end

local function UpdateModuleAfterCombatIsFinished(params)
    if params.inCombat == false and SelectTalentByIndexAfterCombat ~= nil then
        SelectTalent(SelectTalentByIndexAfterCombat)
        SelectTalentByIndexAfterCombat = nil
    end
end

local function GetTalentIndex(reaction)
    return tonumber(string.sub(reaction.sender, 12))
end

local function OnItemClick(reaction)
    if dndOn == true then
        LogToChat('Выключи DnD')
        return
    end

    local talentIndex = GetTalentIndex(reaction)
    if TalentIdByIndex[talentIndex] == nil then
        return
    end

    if isInCombat(avatarId) then
        if SelectTalentByIndexAfterCombat == talentIndex then
            SelectTalentByIndexAfterCombat = nil
            LogToChat('Отмена установки модуля после боя')
        else
            SelectTalentByIndexAfterCombat = talentIndex
            local moduleName = StripTags(avatar.GetUnlockInfo(TalentIdByIndex[talentIndex]:GetInfo().unlock).name)
            LogToChat(moduleName .. ' будет установлен после боя')
        end
    else
        SelectTalentByIndexAfterCombat = nil
        SelectTalent(talentIndex)
    end
end

local function invertTable(t)
    local s={}
    for k,v in pairs(t) do
        s[v]=k
    end
    return s
end

local function LoadModulesToPanel()
    local availableTalents = mount.GetAvailableTalents(mount.GetExoMount())
    local modulesIndexesByNames = invertTable(modules)
    local modulesToDisplay = {}

    for _, talentId in pairs(availableTalents[#availableTalents].talents) do
        local unlock = avatar.GetUnlockInfo(talentId:GetInfo().unlock)
        local moduleName = userMods.FromWString(StripTags(unlock.name))
        if modulesIndexesByNames[moduleName] ~= nil then
            modulesToDisplay[modulesIndexesByNames[moduleName]] = {
                unlock = unlock,
                talentId = talentId,
            }
        end
    end

    local index = 0
    for _, talentInfo in pairs(modulesToDisplay) do
        AddItem(talentInfo.unlock, index)
        TalentIdByIndex[index] = talentInfo.talentId
        index = index + 1
    end

    return index
end

local function OnClickButton()
    if DnD:IsDragging() then
        return
    end

end

local function OnAoPanelClickButton(params)
    if params.sender ~= nil and params.sender ~= addonName then
        return
    end

    OnClickButton()
end

local function OnRightClickButton()
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

local function OnAoPanelRightClickButton(params)
    if params.sender ~= nil and params.sender ~= addonName then
        return
    end

    OnRightClickButton()
end

local function OnAoPanelStart()
    local SetVal = { val = userMods.ToWString('EMS') }
    local params = { header = SetVal, ptype = 'button', size = 30 }
    userMods.SendEvent('AOPANEL_SEND_ADDON', {
        name = addonName, sysName = addonName, param = params
    })

    common.RegisterEventHandler(OnAoPanelClickButton, 'AOPANEL_BUTTON_LEFT_CLICK')
    common.RegisterEventHandler(OnAoPanelRightClickButton, 'AOPANEL_BUTTON_RIGHT_CLICK')

    OpenConfigButton:Show(false)
end

local function CreatePanel()
    Panel = mainForm:GetChildUnchecked('ItemsPanel', false)
    Panel:SetBackgroundColor({ a = 0.0 })

    local Item = Panel:GetChildUnchecked('PanelItem', false)
    ItemDesc = Item:GetWidgetDesc()
    Item:DestroyWidget()

    DnD.Init(Panel, nil, true)
    DnD.Remove(Panel)

    local loaded = LoadModulesToPanel()
    local CommonPanelPlacement = Panel:GetPlacementPlain();
    CommonPanelPlacement.sizeY = config['ICON_SIZE']
    CommonPanelPlacement.sizeX = config['ICON_SIZE'] * loaded + 20
    Panel:SetPlacementPlain(CommonPanelPlacement)

    common.RegisterReactionHandler(OnItemClick, 'EVENT_ON_ITEM_CLICK')
end

local function CreateConfigButton()
    OpenConfigButton = mainForm:GetChildUnchecked('OpenConfigButton', false)
    DnD.Init(OpenConfigButton, nil, true)

    common.RegisterReactionHandler(OnRightClickButton, 'EVENT_ON_CONFIG_BUTTON_RIGHT_CLICK')
    common.RegisterEventHandler(OnAoPanelStart, 'AOPANEL_START')
end

local function Run()
    avatarId = avatar.GetId()

    mainForm:Show(false)

    CreatePanel()
    CreateConfigButton()

    common.RegisterEventHandler(UpdateModuleAfterCombatIsFinished, 'EVENT_OBJECT_COMBAT_STATUS_CHANGED', {objectId = avatarId})

    mainForm:Show(true)
end

Run()
