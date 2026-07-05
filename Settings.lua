local YAB = _G.YAB

local SettingsFrame
local hoverModeLabel
local hoverScaleLabel
local minimapCheck
local npcInput
local statusText
local customList
local minimapCheckLabel
local levelExprBox
local levelExprInput
local levelExprHint
local displayHint
local displayContainer
local displayGroupChecks = {}
local displayItemChecks = {}
local displayLabels = {}
local displayColumnCount = 2
local displayColumnWidth = 132

local FRAME_BG_COLOR = { 0.03, 0.03, 0.04, 0.96 }
local PANEL_BG_COLOR = { 0.055, 0.055, 0.07, 0.94 }
local PANEL_ALT_BG_COLOR = { 0.04, 0.04, 0.05, 0.92 }
local BORDER_COLOR = { 0.24, 0.2, 0.12, 0.95 }
local INNER_BORDER_COLOR = { 0.22, 0.22, 0.24, 0.9 }
local TITLE_COLOR = { 1, 0.82, 0.2 }
local TEXT_COLOR = { 0.95, 0.95, 0.95 }
local SUBTEXT_COLOR = { 0.72, 0.72, 0.72 }

local function CreateText(parent, size, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local font, _, flags = text:GetFont()
    text:SetFont(font, size or 12, flags)
    text:SetJustifyH(justify or "LEFT")
    text:SetJustifyV("MIDDLE")
    return text
end

local function UpdateLevelExprVisual(valid)
    if not levelExprBox or not levelExprInput then
        return
    end
    if valid then
        levelExprBox:SetBackdropBorderColor(0.18, 0.18, 0.18, 0.95)
        levelExprInput:SetTextColor(0.95, 0.95, 0.95)
    else
        levelExprBox:SetBackdropBorderColor(0.85, 0.24, 0.24, 0.95)
        levelExprInput:SetTextColor(1, 0.55, 0.55)
    end
end

local function CommitLevelExpr(refresh)
    if not levelExprInput then
        return false
    end
    local valid, normalized, badToken = YAB.ValidateLevelExpr(levelExprInput:GetText())
    levelExprInput:SetText(normalized)
    UpdateLevelExprVisual(valid)
    if not valid then
        if statusText then
            statusText:SetText("等级过滤格式无效: " .. tostring(badToken or ""))
            statusText:SetTextColor(1, 0.3, 0.3)
        end
        return false
    end

    local ok = YAB.SetLevelFilterExpr(normalized)
    if ok and refresh and statusText then
        if normalized == "" or normalized == "0" then
            statusText:SetText("等级过滤已清除，当前显示全部等级角色。")
        else
            statusText:SetText("等级过滤已更新: " .. normalized)
        end
        statusText:SetTextColor(0.2, 0.9, 0.35)
    end
    return ok
end

local function SetBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(FRAME_BG_COLOR[1], FRAME_BG_COLOR[2], FRAME_BG_COLOR[3], FRAME_BG_COLOR[4])
    frame:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
end

local function SetPanelBackdrop(frame, useAlt)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    local bg = useAlt and PANEL_ALT_BG_COLOR or PANEL_BG_COLOR
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(INNER_BORDER_COLOR[1], INNER_BORDER_COLOR[2], INNER_BORDER_COLOR[3], INNER_BORDER_COLOR[4])
end

local function CreateSectionPanel(parent, titleText, width, height, useAlt)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(width, height)
    SetPanelBackdrop(panel, useAlt)

    panel.title = CreateText(panel, 12, "LEFT")
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
    panel.title:SetText(titleText or "")
    panel.title:SetTextColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])

    panel.divider = panel:CreateTexture(nil, "ARTWORK")
    panel.divider:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    panel.divider:SetHeight(1)
    panel.divider:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -8)
    panel.divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, 0)
    panel.divider:SetVertexColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], 0.5)

    return panel
end

local function CreateInsetBox(parent, width, height)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    box:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    box:SetBackdropColor(0.02, 0.02, 0.03, 0.84)
    box:SetBackdropBorderColor(0.16, 0.16, 0.18, 0.92)
    return box
end

local function HoverModeCycle(current)
    if current == "full" then
        return "simple"
    elseif current == "simple" then
        return "off"
    end
    return "full"
end

local function HoverModeLabel(mode)
    if mode == "simple" then
        return "简易模式"
    elseif mode == "off" then
        return "关闭"
    end
    return "完整模式"
end

local function HoverScaleLabel(scale)
    local percent = math.floor(((tonumber(scale) or 1) * 100) + 0.5)
    return "悬停 UI 缩放: " .. tostring(percent) .. "%"
end

local function RaiseSettingsTooltip()
    if not GameTooltip then
        return
    end
    GameTooltip:SetToplevel(true)
    GameTooltip:SetFrameStrata("TOOLTIP")
    local settingsLevel = SettingsFrame and SettingsFrame.GetFrameLevel and SettingsFrame:GetFrameLevel() or 0
    GameTooltip:SetFrameLevel(math.max(GameTooltip:GetFrameLevel() or 0, settingsLevel + 40))
end

local function CreateCheckbox(parent, labelText)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    local label = CreateText(parent, 11, "LEFT")
    label:SetText(labelText or "")
    label:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])
    label:SetPoint("LEFT", check, "RIGHT", 4, 1)
    return check, label
end

local function SetCheckboxVisual(check, label, enabled)
    check:SetEnabled(enabled)
    if enabled then
        label:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])
    else
        label:SetTextColor(0.45, 0.45, 0.45)
    end
end

local function RebuildDisplayControls()
    if not SettingsFrame or not displayContainer then
        return
    end

    for _, check in pairs(displayGroupChecks) do
        check:Hide()
    end
    for _, check in pairs(displayItemChecks) do
        check:Hide()
    end
    for key, label in pairs(displayLabels) do
        if not displayGroupChecks[key] and not displayItemChecks[key] then
            label:Hide()
        else
            label:Hide()
        end
    end

    local allTargets = YAB.GetAllBossList and YAB.GetAllBossList() or {}
    local targetsByGroup = {}
    for _, target in ipairs(allTargets) do
        local groupKey = target.group or "custom"
        targetsByGroup[groupKey] = targetsByGroup[groupKey] or {}
        targetsByGroup[groupKey][#targetsByGroup[groupKey] + 1] = target
    end

    local groups = YAB.GetDisplayGroups and YAB.GetDisplayGroups() or {}
    local columnHeights = {}
    local columnCount = math.max(displayColumnCount, 1)
    for index = 1, columnCount do
        columnHeights[index] = 0
    end

    for groupIndex, group in ipairs(groups) do
        local column = ((groupIndex - 1) % columnCount) + 1
        local columnX = (column - 1) * displayColumnWidth
        local groupCheck = displayGroupChecks[group.key]
        local groupLabel = displayLabels[group.key]
        if not groupCheck then
            groupCheck, groupLabel = CreateCheckbox(displayContainer, group.name)
            displayGroupChecks[group.key] = groupCheck
            displayLabels[group.key] = groupLabel
            groupCheck:SetScript("OnClick", function(self)
                YAB.SetDisplayGroupEnabled(group.key, self:GetChecked())
            end)
        end
        groupLabel:SetText(group.name)
        groupCheck:ClearAllPoints()
        groupCheck:SetPoint("TOPLEFT", displayContainer, "TOPLEFT", columnX, -columnHeights[column])
        groupCheck:Show()
        groupLabel:Show()
        columnHeights[column] = columnHeights[column] + 22
        for _, target in ipairs(targetsByGroup[group.key] or {}) do
            local itemCheck = displayItemChecks[target.key]
            local itemLabel = displayLabels[target.key]
            if not itemCheck then
                itemCheck, itemLabel = CreateCheckbox(displayContainer, target.name)
                displayItemChecks[target.key] = itemCheck
                displayLabels[target.key] = itemLabel
                itemCheck:SetScript("OnClick", function(self)
                    YAB.SetDisplayItemEnabled(target.key, self:GetChecked())
                end)
            end
            itemLabel:SetText(target.name)
            itemCheck:ClearAllPoints()
            itemCheck:SetPoint("TOPLEFT", displayContainer, "TOPLEFT", columnX + 18, -columnHeights[column])
            itemCheck:Show()
            itemLabel:Show()
            columnHeights[column] = columnHeights[column] + 18
        end
        columnHeights[column] = columnHeights[column] + 12
    end

    local maxHeight = 0
    for index = 1, columnCount do
        if columnHeights[index] > maxHeight then
            maxHeight = columnHeights[index]
        end
    end
    displayContainer:SetHeight(math.max(maxHeight, 180))
end

function YAB.RefreshSettingsUI()
    if not SettingsFrame then
        return
    end
    local minimap = YAB.GetMinimapConfig()
    minimapCheck:SetChecked(not minimap.hide)
    hoverModeLabel:SetText("悬停临时窗口: " .. HoverModeLabel(YAB.GetHoverMode()))
    if hoverScaleLabel then
        hoverScaleLabel:SetText(HoverScaleLabel(YAB.GetHoverScale and YAB.GetHoverScale() or 1))
    end
    if levelExprInput then
        levelExprInput:SetText(tostring(YAB.GetLevelFilterExpr() or ""))
        local valid = YAB.ValidateLevelExpr(levelExprInput:GetText())
        UpdateLevelExprVisual(valid)
    end
    if statusText then
        local levelExpr = tostring(YAB.GetLevelFilterExpr() or "")
        if levelExpr == "" or levelExpr == "0" then
            statusText:SetText("当前未启用等级过滤。")
        else
            statusText:SetText("当前等级过滤: " .. levelExpr)
        end
        statusText:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])
    end

    local customTargets = YiboAltoBossDB and YiboAltoBossDB.customTargets or {}
    local items = {}
    for _, item in pairs(customTargets) do
        items[#items + 1] = item.name .. " (NPC " .. item.id .. ")"
    end
    table.sort(items)
    if #items == 0 then
        customList:SetText("当前没有自定义 NPC。")
    else
        customList:SetText(table.concat(items, "\n"))
    end

    RebuildDisplayControls()

    local allTargets = YAB.GetAllBossList and YAB.GetAllBossList() or {}
    local targetsByGroup = {}
    for _, target in ipairs(allTargets) do
        local groupKey = target.group or "custom"
        targetsByGroup[groupKey] = targetsByGroup[groupKey] or {}
        targetsByGroup[groupKey][#targetsByGroup[groupKey] + 1] = target
    end

    for _, group in ipairs(YAB.GetDisplayGroups and YAB.GetDisplayGroups() or {}) do
        local groupCheck = displayGroupChecks[group.key]
        if groupCheck then
            groupCheck:SetChecked(YAB.IsDisplayGroupEnabled(group.key))
        end
        local groupEnabled = YAB.IsDisplayGroupEnabled(group.key)
        for _, target in ipairs(targetsByGroup[group.key] or {}) do
            local itemCheck = displayItemChecks[target.key]
            if itemCheck then
                itemCheck:SetChecked(YAB.IsDisplayItemChecked(target.key))
                SetCheckboxVisual(itemCheck, displayLabels[target.key], groupEnabled)
            end
        end
    end
end

function YAB.ToggleSettingsWindow()
    if not SettingsFrame then
        return
    end
    if SettingsFrame:IsShown() then
        SettingsFrame:Hide()
        YAB.SetSettingsShown(false)
    else
        SettingsFrame:SetFrameStrata("DIALOG")
        SettingsFrame:SetToplevel(true)
        SettingsFrame:Show()
        SettingsFrame:Raise()
        YAB.SetSettingsShown(true)
        YAB.RefreshSettingsUI()
    end
end

function YAB.InitializeSettings()
    if SettingsFrame then
        return
    end

    SettingsFrame = CreateFrame("Frame", "YiboAltoBossSettingsFrame", UIParent, "BackdropTemplate")
    SettingsFrame:SetSize(560, 560)
    SettingsFrame:SetPoint("CENTER", UIParent, "CENTER", 220, 0)
    SettingsFrame:SetFrameStrata("DIALOG")
    SettingsFrame:SetToplevel(true)
    SettingsFrame:SetMovable(true)
    SettingsFrame:EnableMouse(true)
    SettingsFrame:RegisterForDrag("LeftButton")
    SettingsFrame:SetScript("OnDragStart", SettingsFrame.StartMoving)
    SettingsFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:Raise()
    end)
    SettingsFrame:SetScript("OnHide", function()
        YAB.SetSettingsShown(false)
    end)
    SetBackdrop(SettingsFrame)
    SettingsFrame:Hide()

    local title = CreateText(SettingsFrame, 14, "LEFT")
    title:SetPoint("TOPLEFT", SettingsFrame, "TOPLEFT", 14, -12)
    title:SetText("YiboAltoBoss 设置")
    title:SetTextColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])

    local headerHint = CreateText(SettingsFrame, 11, "RIGHT")
    headerHint:SetPoint("TOPRIGHT", SettingsFrame, "TOPRIGHT", -14, -14)
    headerHint:SetText("按功能分区，便于快速扫描")
    headerHint:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    local generalPanel = CreateSectionPanel(SettingsFrame, "基础设置", 532, 164, false)
    generalPanel:SetPoint("TOPLEFT", SettingsFrame, "TOPLEFT", 14, -40)

    local displayPanel = CreateSectionPanel(SettingsFrame, "显示项配置", 324, 306, true)
    displayPanel:SetPoint("TOPLEFT", generalPanel, "BOTTOMLEFT", 0, -12)

    local customPanel = CreateSectionPanel(SettingsFrame, "自定义目标", 196, 306, true)
    customPanel:SetPoint("TOPRIGHT", generalPanel, "BOTTOMRIGHT", 0, -12)

    minimapCheck = CreateFrame("CheckButton", nil, generalPanel, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", generalPanel, "TOPLEFT", 12, -36)
    minimapCheckLabel = CreateText(generalPanel, 12, "LEFT")
    minimapCheckLabel:SetPoint("LEFT", minimapCheck, "RIGHT", 4, 1)
    minimapCheckLabel:SetText("显示小地图入口")
    minimapCheckLabel:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])
    minimapCheck:SetScript("OnClick", function(self)
        YAB.SetMinimapHidden(not self:GetChecked())
    end)

    local hoverButton = CreateFrame("Button", nil, generalPanel, "UIPanelButtonTemplate")
    hoverButton:SetSize(120, 22)
    hoverButton:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 4, -10)
    hoverButton:SetText("切换悬停模式")
    hoverButton:SetScript("OnClick", function()
        local nextMode = HoverModeCycle(YAB.GetHoverMode())
        YAB.SetHoverMode(nextMode)
        YAB.RefreshSettingsUI()
    end)

    hoverModeLabel = CreateText(generalPanel, 12, "LEFT")
    hoverModeLabel:SetPoint("LEFT", hoverButton, "RIGHT", 12, 0)
    hoverModeLabel:SetWidth(150)
    hoverModeLabel:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])

    local hoverScaleTitle = CreateText(generalPanel, 11, "LEFT")
    hoverScaleTitle:SetPoint("TOPLEFT", generalPanel, "TOPLEFT", 286, -38)
    hoverScaleTitle:SetText("悬停窗口缩放")
    hoverScaleTitle:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    local hoverScaleDownButton = CreateFrame("Button", nil, generalPanel, "UIPanelButtonTemplate")
    hoverScaleDownButton:SetSize(28, 22)
    hoverScaleDownButton:SetPoint("TOPLEFT", generalPanel, "TOPLEFT", 284, -58)
    hoverScaleDownButton:SetText("-")
    hoverScaleDownButton:SetScript("OnClick", function()
        YAB.SetHoverScale((YAB.GetHoverScale and YAB.GetHoverScale() or 1) - 0.1)
    end)

    local hoverScaleUpButton = CreateFrame("Button", nil, generalPanel, "UIPanelButtonTemplate")
    hoverScaleUpButton:SetSize(28, 22)
    hoverScaleUpButton:SetPoint("LEFT", hoverScaleDownButton, "RIGHT", 6, 0)
    hoverScaleUpButton:SetText("+")
    hoverScaleUpButton:SetScript("OnClick", function()
        YAB.SetHoverScale((YAB.GetHoverScale and YAB.GetHoverScale() or 1) + 0.1)
    end)

    local hoverScaleResetButton = CreateFrame("Button", nil, generalPanel, "UIPanelButtonTemplate")
    hoverScaleResetButton:SetSize(44, 22)
    hoverScaleResetButton:SetPoint("LEFT", hoverScaleUpButton, "RIGHT", 6, 0)
    hoverScaleResetButton:SetText("100%")
    hoverScaleResetButton:SetScript("OnClick", function()
        YAB.SetHoverScale(1)
    end)

    hoverScaleLabel = CreateText(generalPanel, 12, "LEFT")
    hoverScaleLabel:SetPoint("LEFT", hoverScaleResetButton, "RIGHT", 12, 0)
    hoverScaleLabel:SetWidth(140)
    hoverScaleLabel:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])

    local levelTitle = CreateText(generalPanel, 11, "LEFT")
    levelTitle:SetPoint("TOPLEFT", generalPanel, "TOPLEFT", 12, -94)
    levelTitle:SetText("等级过滤")
    levelTitle:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    levelExprBox = CreateInsetBox(generalPanel, 168, 28)
    levelExprBox:SetPoint("TOPLEFT", generalPanel, "TOPLEFT", 12, -112)

    levelExprInput = CreateFrame("EditBox", nil, levelExprBox, "InputBoxTemplate")
    levelExprInput:SetPoint("TOPLEFT", levelExprBox, "TOPLEFT", 6, -2)
    levelExprInput:SetPoint("BOTTOMRIGHT", levelExprBox, "BOTTOMRIGHT", -6, 2)
    levelExprInput:SetAutoFocus(false)
    levelExprInput:SetTextInsets(0, 0, 0, 0)

    local levelHelpButton = CreateFrame("Button", nil, generalPanel, "UIPanelButtonTemplate")
    levelHelpButton:SetSize(28, 22)
    levelHelpButton:SetPoint("LEFT", levelExprBox, "RIGHT", 8, 0)
    levelHelpButton:SetText("?")

    levelExprHint = CreateText(generalPanel, 11, "LEFT")
    levelExprHint:SetPoint("LEFT", levelHelpButton, "RIGHT", 12, 0)
    levelExprHint:SetPoint("RIGHT", generalPanel, "RIGHT", -12, 0)
    levelExprHint:SetJustifyH("LEFT")
    levelExprHint:SetText("支持 90、1-20、<=3、>=85、<=3,89,90；留空或 0 表示不过滤。")
    levelExprHint:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    levelExprInput:SetScript("OnEnterPressed", function(self)
        CommitLevelExpr(true)
        self:ClearFocus()
    end)
    levelExprInput:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    levelExprInput:SetScript("OnEditFocusLost", function()
        CommitLevelExpr(true)
    end)
    levelExprInput:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(YAB.GetLevelFilterExpr() or ""))
        UpdateLevelExprVisual(true)
        self:ClearFocus()
    end)

    levelHelpButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("等级过滤说明", 1, 0.82, 0.2)
        GameTooltip:AddLine("支持多个条件，分隔符只能使用英文逗号。", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine("可用格式: 90  1-20  <=3  >=85", 0.7, 0.85, 1, true)
        GameTooltip:AddLine("示例: <=3,89,90", 0.7, 1, 0.7, true)
        GameTooltip:AddLine("输入 0 或留空表示不过滤等级。", 1, 0.82, 0.25, true)
        GameTooltip:AddLine("输入后按回车或移开焦点即可生效。", 1, 0.82, 0.25, true)
        RaiseSettingsTooltip()
        GameTooltip:Show()
        GameTooltip:Raise()
    end)
    levelHelpButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    displayHint = CreateText(displayPanel, 11, "LEFT")
    displayHint:SetPoint("TOPLEFT", displayPanel, "TOPLEFT", 12, -34)
    displayHint:SetWidth(292)
    displayHint:SetWordWrap(true)
    displayHint:SetText("仅勾选的项目会显示在主窗口中。关闭显示会停止后续记录，但不会删除已有历史数据。")
    displayHint:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    displayContainer = CreateFrame("Frame", nil, displayPanel)
    displayContainer:SetPoint("TOPLEFT", displayHint, "BOTTOMLEFT", 0, -10)
    displayContainer:SetSize(292, 228)
    RebuildDisplayControls()

    local customHint = CreateText(customPanel, 11, "LEFT")
    customHint:SetPoint("TOPLEFT", customPanel, "TOPLEFT", 12, -34)
    customHint:SetPoint("RIGHT", customPanel, "RIGHT", -12, 0)
    customHint:SetWordWrap(true)
    customHint:SetText("补充监控列表之外的 NPC，便于临时追踪。")
    customHint:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    local npcLabel = CreateText(customPanel, 11, "LEFT")
    npcLabel:SetPoint("TOPLEFT", customPanel, "TOPLEFT", 12, -82)
    npcLabel:SetText("NPC ID")
    npcLabel:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    npcInput = CreateFrame("EditBox", nil, customPanel, "InputBoxTemplate")
    npcInput:SetSize(108, 24)
    npcInput:SetPoint("TOPLEFT", npcLabel, "BOTTOMLEFT", 0, -6)
    npcInput:SetAutoFocus(false)
    npcInput:SetNumeric(true)

    local addButton = CreateFrame("Button", nil, customPanel, "UIPanelButtonTemplate")
    addButton:SetSize(54, 22)
    addButton:SetPoint("LEFT", npcInput, "RIGHT", 8, 0)
    addButton:SetText("添加")
    addButton:SetScript("OnClick", function()
        local ok, err = YAB.AddCustomTarget(npcInput:GetText())
        if ok then
            statusText:SetText("已添加自定义目标。")
            statusText:SetTextColor(0.2, 0.9, 0.35)
            npcInput:SetText("")
        else
            statusText:SetText(err or "添加失败。")
            statusText:SetTextColor(1, 0.3, 0.3)
        end
        YAB.RefreshSettingsUI()
    end)

    statusText = CreateText(SettingsFrame, 11, "LEFT")
    statusText:SetPoint("BOTTOMLEFT", SettingsFrame, "BOTTOMLEFT", 16, 18)
    statusText:SetWidth(400)
    statusText:SetWordWrap(true)
    statusText:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])
    statusText:SetText("这里会把自定义目标加入 Boss 列表。")

    local customListTitle = CreateText(customPanel, 11, "LEFT")
    customListTitle:SetPoint("TOPLEFT", npcInput, "BOTTOMLEFT", 0, -44)
    customListTitle:SetText("当前自定义目标")
    customListTitle:SetTextColor(SUBTEXT_COLOR[1], SUBTEXT_COLOR[2], SUBTEXT_COLOR[3])

    local customListBox = CreateInsetBox(customPanel, 168, 124)
    customListBox:SetPoint("TOPLEFT", customListTitle, "BOTTOMLEFT", 0, -6)

    customList = CreateText(customListBox, 11, "LEFT")
    customList:SetPoint("TOPLEFT", customListBox, "TOPLEFT", 8, -8)
    customList:SetPoint("RIGHT", customListBox, "RIGHT", -8, 0)
    customList:SetWordWrap(true)
    customList:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])

    local closeButton = CreateFrame("Button", nil, SettingsFrame, "UIPanelButtonTemplate")
    closeButton:SetSize(70, 22)
    closeButton:SetPoint("BOTTOMRIGHT", SettingsFrame, "BOTTOMRIGHT", -14, 12)
    closeButton:SetText("关闭")
    closeButton:SetScript("OnClick", function()
        SettingsFrame:Hide()
    end)

    if YAB.GetUIState().settingsShown then
        SettingsFrame:SetFrameStrata("DIALOG")
        SettingsFrame:SetToplevel(true)
        SettingsFrame:Show()
        SettingsFrame:Raise()
    end
    YAB.RefreshSettingsUI()
end
