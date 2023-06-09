local wtChat
local valuedText = common.CreateValuedText()
local addonName = common.GetAddonName()

local OpenConfigButton
local Panel
local ItemDesc

local TalentIdByIndex = {}
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

function CreateConfigButton()
    OpenConfigButton = mainForm:GetChildUnchecked('OpenConfigButton', false)
    DnD.Init(OpenConfigButton, nil, true)

    common.RegisterReactionHandler(OnRightClickButton, 'EVENT_ON_CONFIG_BUTTON_RIGHT_CLICK')
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

    DnD.Init(Panel, nil, true)
    DnD.Remove(Panel)

    LoadModulesToPanel()

    common.RegisterReactionHandler(OnItemClick, 'EVENT_ON_ITEM_CLICK')
end

function OnItemClick(reaction)
    local talentIndex = GetTalentIndex(reaction)

    if TalentIdByIndex[talentIndex] == nil then
        return
    end

    local exoMountId = mount.GetExoMount()
    local talents = mount.GetSelectedTalents(exoMountId)
    talents[#talents] = TalentIdByIndex[talentIndex]

    mount.SelectTalents(exoMountId, talents)
end


function LoadModulesToPanel()
    local exoMountId = mount.GetExoMount()
    local availableTalents = mount.GetAvailableTalents(exoMountId)
    local index = 0

    for talentIndex, _ in pairs(modules) do
        if availableTalents[#availableTalents].talents[talentIndex] ~= nil then
            local talentId = availableTalents[#availableTalents].talents[talentIndex]
            local unlock = avatar.GetUnlockInfo(talentId:GetInfo().unlock)

            AddItem(unlock, index)
            TalentIdByIndex[index] = talentId

            index = index + 1
        end
    end
end

function GetTalentIndex(reaction)
    return tonumber(string.sub(reaction.sender, 12))
end

function BuildItemWidgetName(index)
    return 'MountTalent' .. tostring(index)
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
