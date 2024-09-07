local wtChat
local valuedText = common.CreateValuedText()
local addonName = common.GetAddonName()

local OpenConfigButton
local Panel
local ItemDesc

local TalentIdByIndex = {}
local SelectTalentByIndexAfterCombat

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

function CreateConfigButton()
    OpenConfigButton = mainForm:GetChildUnchecked('OpenConfigButton', false)
    DnD.Init(OpenConfigButton, nil, true)

    common.RegisterReactionHandler(OnRightClickButton, 'EVENT_ON_CONFIG_BUTTON_RIGHT_CLICK')
end

function CreatePanel()
    Panel = mainForm:GetChildUnchecked("ItemsPanel", false)
    Panel:SetBackgroundColor({ a = 0.0 })

    local Item = Panel:GetChildUnchecked("PanelItem", false)
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

function SelectTalent(talentIndex)
    local exoMountId = mount.GetExoMount()
    local talents = mount.GetSelectedTalents(exoMountId)
    talents[#talents] = TalentIdByIndex[talentIndex]

    mount.SelectTalents(exoMountId, talents)
end

function UpdateModuleAfterCombatIsFinished()
    common.UnRegisterEventHandler(UpdateModuleAfterCombatIsFinished, "EVENT_OBJECT_COMBAT_STATUS_CHANGED")

    if SelectTalentByIndexAfterCombat ~= nil then
        SelectTalent(SelectTalentByIndexAfterCombat)
        SelectTalentByIndexAfterCombat = nil
    end
end

function OnItemClick(reaction)
    if dndOn == true then
        LogToChat('Выключи DnD')
        return
    end

    local talentIndex = GetTalentIndex(reaction)
    if TalentIdByIndex[talentIndex] == nil then
        return
    end

    if object.IsInCombat(avatar.GetId()) then
        if SelectTalentByIndexAfterCombat == talentIndex then
            SelectTalentByIndexAfterCombat = nil
            LogToChat('Отмена установки модуля после боя')
        else
            SelectTalentByIndexAfterCombat = talentIndex
            local moduleName = StripTags(avatar.GetUnlockInfo(TalentIdByIndex[talentIndex]:GetInfo().unlock).name)
            LogToChat(moduleName .. ' будет установлен после боя')
        end

        common.RegisterEventHandler(UpdateModuleAfterCombatIsFinished, "EVENT_OBJECT_COMBAT_STATUS_CHANGED")
    else
        SelectTalentByIndexAfterCombat = nil
        SelectTalent(talentIndex)
    end
end

function table.invert(t)
    local s={}
    for k,v in pairs(t) do
        s[v]=k
    end
    return s
end

function LoadModulesToPanel()
    local availableTalents = mount.GetAvailableTalents(mount.GetExoMount())
    local modulesIndexesByNames = table.invert(modules)
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

function GetTalentIndex(reaction)
    return tonumber(string.sub(reaction.sender, 12))
end

function BuildItemWidgetName(index)
    return 'MountTalent' .. tostring(index)
end

function AddItem(unlock, index)
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

function OnEventAvatarCreated()
    mainForm:Show(false)

    CreatePanel()
    CreateConfigButton()

    mainForm:Show(true)
end

function StripTags(s)
    return common.IsWString(s) and common.CreateValuedText { format = s }:ToWString() or s
end

function Init()
    if avatar and avatar.IsExist() then
        OnEventAvatarCreated()
    else
        common.RegisterEventHandler(OnEventAvatarCreated, "EVENT_AVATAR_CREATED")
    end
end

Init()
