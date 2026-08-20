KeepStubble = {}
KeepStubble.functionCache = {}
KeepStubble.preserveModeActive = false
KeepStubble.MOD_DIR = g_currentModDirectory

KeepStubble.densityGridSize = 0.2
KeepStubble.debugLogged = 0

-- Fallback-Werte, falls ueberhaupt kein Profil geladen werden konnte
KeepStubble.FALLBACK_PERCENT = 2
KeepStubble.FALLBACK_STATE = -1

KeepStubble.PROFILE_FILES = { "vanilla.xml", "custom1.xml", "custom2.xml" }
KeepStubble.profileNames = { "Profil 1", "Profil 2", "Profil 3" }
KeepStubble.activeProfileIndex = 1 -- Standard = Profil 1

-- [fruitName] = { percent = X, state = Y }, plus fruitSettings.__default
KeepStubble.fruitSettings = {}

local function getModSettingsPath()
    return getUserProfileAppPath() .. "modSettings/FS25_KeepStubble.xml"
end

local function getProfilePath(index)
    local filename = KeepStubble.PROFILE_FILES[index]
    if filename == nil then
        return nil
    end
    return KeepStubble.MOD_DIR .. "profiles/" .. filename
end

local function scanProfileNames()
    for i, filename in ipairs(KeepStubble.PROFILE_FILES) do
        local path = KeepStubble.MOD_DIR .. "profiles/" .. filename
        if fileExists(path) then
            local xmlFile = XMLFile.load("keepStubbleProfileName", path)
            if xmlFile ~= nil then
                local name = xmlFile:getString("settings#name")
                if name ~= nil and name ~= "" then
                    KeepStubble.profileNames[i] = name
                end
                xmlFile:delete()
            end
        else
            print(string.format("[KeepStubble] WARNUNG: Profil-Datei nicht gefunden: %s", path))
        end
    end
end

local function loadProfile(index)
    local path = getProfilePath(index)
    KeepStubble.fruitSettings = {}

    if path == nil or not fileExists(path) then
        Logging.warning("[KeepStubble] Profil-Datei nicht gefunden (Index %d): '%s' - nutze Fallback-Werte fuer alle Fruchtarten.", index, tostring(path))
        KeepStubble.fruitSettings.__default = { percent = KeepStubble.FALLBACK_PERCENT, state = KeepStubble.FALLBACK_STATE }
        return
    end

    local xmlFile = XMLFile.load("keepStubbleProfile", path)
    if xmlFile == nil then
        Logging.warning("[KeepStubble] Konnte Profil-Datei nicht laden: %s", path)
        KeepStubble.fruitSettings.__default = { percent = KeepStubble.FALLBACK_PERCENT, state = KeepStubble.FALLBACK_STATE }
        return
    end

    local fruitCount = 0
    for _, key in xmlFile:iterator("settings.fruit") do
        local name = xmlFile:getString(key .. "#name")
        local percent = xmlFile:getInt(key .. "#densityReductionPercent")
        local stateStr = xmlFile:getString(key .. "#targetFoliageState")
        if name ~= nil and percent ~= nil and stateStr ~= nil then
            local state = tonumber(stateStr)
            if state == nil then
                local lower = stateStr:lower()
                if lower == "cut" or lower == "stubble" then
                    state = -1
                elseif lower == "withered" or lower == "dead" then
                    state = -2
                else
                    state = -1
                end
            end
            KeepStubble.fruitSettings[name:upper()] = { percent = percent, state = state }
            fruitCount = fruitCount + 1
        end
    end

    local defaultPercent = xmlFile:getInt("settings.default#densityReductionPercent") or KeepStubble.FALLBACK_PERCENT
    local defaultStateStr = xmlFile:getString("settings.default#targetFoliageState")
    local defaultState = KeepStubble.FALLBACK_STATE
    if defaultStateStr ~= nil then
        defaultState = tonumber(defaultStateStr) or KeepStubble.FALLBACK_STATE
    end
    KeepStubble.fruitSettings.__default = { percent = defaultPercent, state = defaultState }

    xmlFile:delete()

    print(string.format("[KeepStubble] Profil '%s' geladen (Index %d): %d Fruchtarten, Default percent=%d state=%d",
        KeepStubble.profileNames[index] or ("Profil " .. index), index, fruitCount, defaultPercent, defaultState))
end

local function getFruitSettings(fruitName)
    local entry = KeepStubble.fruitSettings[fruitName]
    if entry == nil then
        entry = KeepStubble.fruitSettings.__default
    end
    if entry == nil then
        return KeepStubble.FALLBACK_PERCENT, KeepStubble.FALLBACK_STATE
    end
    return entry.percent, entry.state
end

function KeepStubble:loadSettings()
    scanProfileNames()

    local modSettingsPath = getModSettingsPath()
    if fileExists(modSettingsPath) then
        local xmlFile = XMLFile.load("keepStubbleModSettings", modSettingsPath)
        if xmlFile ~= nil then
            local index = xmlFile:getInt("settings#activeProfileIndex")
            if index ~= nil and index >= 1 and index <= #KeepStubble.PROFILE_FILES then
                KeepStubble.activeProfileIndex = index
            end
            xmlFile:delete()
        end
    end

    loadProfile(KeepStubble.activeProfileIndex)
end

function KeepStubble:saveSettings()
    local modSettingsPath = getModSettingsPath()
    createFolder(getUserProfileAppPath() .. "modSettings")

    local xmlFile = XMLFile.create("keepStubbleModSettings", modSettingsPath, "settings")
    if xmlFile == nil then
        Logging.warning("[KeepStubble] Konnte Einstellungen nicht speichern: %s", modSettingsPath)
        return
    end

    xmlFile:setInt("settings#activeProfileIndex", KeepStubble.activeProfileIndex)
    xmlFile:save()
    xmlFile:delete()

    print(string.format("[KeepStubble] Aktives Profil gespeichert: %s (Index %d)",
        KeepStubble.profileNames[KeepStubble.activeProfileIndex] or "?", KeepStubble.activeProfileIndex))
end

local function ensureFunctionData()
    local functionData = KeepStubble.functionCache.data
    if functionData ~= nil then
        return functionData
    end
    local terrainRootNode = g_currentMission.terrainRootNode
    local fieldGroundSystem = g_currentMission.fieldGroundSystem
    local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
    local groundAngleMapId, groundAngleFirstChannel, groundAngleNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_ANGLE)
    local sprayLevelMapId, sprayLevelFirstChannel, sprayLevelNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_LEVEL)
    local sprayLevelMaxValue = fieldGroundSystem:getMaxValue(FieldDensityMap.SPRAY_LEVEL)
    local stubbleTillageType = fieldGroundSystem:getFieldGroundValue(FieldGroundType.STUBBLE_TILLAGE)
    local seedbedType = fieldGroundSystem:getFieldGroundValue(FieldGroundType.SEEDBED)
    functionData = {
        modifier = DensityMapModifier.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels, terrainRootNode),
        modifierAngle = DensityMapModifier.new(groundAngleMapId, groundAngleFirstChannel, groundAngleNumChannels, terrainRootNode),
        fieldFilter = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels, terrainRootNode),
        sprayLevelModifier = DensityMapModifier.new(sprayLevelMapId, sprayLevelFirstChannel, sprayLevelNumChannels, terrainRootNode),
        sprayLevelFilter = DensityMapFilter.new(sprayLevelMapId, sprayLevelFirstChannel, sprayLevelNumChannels, terrainRootNode),
        stubbleTillageType = stubbleTillageType,
        seedbedType = seedbedType,
        fruitModifiers = {},
        fruitFilters = {},
    }
    functionData.fieldFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
    functionData.seedbedTypeFilter = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels, terrainRootNode)
    functionData.seedbedTypeFilter:setValueCompareParams(DensityValueCompareType.EQUAL, seedbedType)
    functionData.notStubbleTillageFilter = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels, terrainRootNode)
    functionData.notStubbleTillageFilter:setValueCompareParams(DensityValueCompareType.NOTEQUAL, stubbleTillageType)
    functionData.sprayLevelFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 0, sprayLevelMaxValue - 1)
    KeepStubble.functionCache.data = functionData
    return functionData
end

local function applyTargetFoliageStateGridded(functionData, terrainRootNode, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    KeepStubble.griddedCallCount = (KeepStubble.griddedCallCount or 0) + 1
    local isFirstFewCalls = KeepStubble.griddedCallCount <= 10
    local widthVecX = widthWorldX - startWorldX
    local widthVecZ = widthWorldZ - startWorldZ
    local widthLength = math.sqrt(widthVecX * widthVecX + widthVecZ * widthVecZ)
    local numSegments = math.max(1, math.floor(widthLength / math.max(KeepStubble.densityGridSize, 0.05)))
    local segFracX = widthVecX / numSegments
    local segFracZ = widthVecZ / numSegments

    if isFirstFewCalls then
        print(string.format("[KeepStubble] DEBUG applyTargetFoliageStateGridded #%d: widthLength=%.3f numSegments=%d (Segmentbreite=%.2fm) aktivesProfil=%s",
            KeepStubble.griddedCallCount, widthLength, numSegments, widthLength / numSegments,
            KeepStubble.profileNames[KeepStubble.activeProfileIndex] or "?"))
    end

    local destroyedCount, keptCount = 0, 0
    local matchedFruitTypes = 0
    for index, desc in pairs(g_fruitTypeManager:getFruitTypes()) do
        if desc.terrainDataPlaneId ~= nil and desc.isCultivationAllowed then
            matchedFruitTypes = matchedFruitTypes + 1
            local modifier = functionData.fruitModifiers[index]
            local filter = functionData.fruitFilters[index]
            if modifier == nil then
                modifier = DensityMapModifier.new(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels, terrainRootNode)
                filter = DensityMapFilter.new(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels, terrainRootNode)
                functionData.fruitModifiers[index] = modifier
                functionData.fruitFilters[index] = filter
            end

            local percent, state = getFruitSettings(desc.name)

            local clampedState
            local maxState = desc.numFoliageStates or desc.numGrowthStates or 1
            if state == -1 then
                clampedState = desc.cutState or maxState
            elseif state == -2 then
                clampedState = desc.witheredState or desc.cutState or maxState
            elseif state == 0 then
                clampedState = 0
            else
                clampedState = math.min(state, maxState)
            end

            filter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
            for i = 0, numSegments - 1 do
                local segStartX = startWorldX + segFracX * i
                local segStartZ = startWorldZ + segFracZ * i
                local segWidthX = segStartX + segFracX
                local segWidthZ = segStartZ + segFracZ
                local segHeightX = heightWorldX + segFracX * i
                local segHeightZ = heightWorldZ + segFracZ * i
                modifier:setParallelogramWorldCoords(segStartX, segStartZ, segWidthX, segWidthZ, segHeightX, segHeightZ, DensityCoordType.POINT_POINT_POINT)
                local destroyThisSegment = math.random(100) <= percent
                modifier:executeSet(destroyThisSegment and 0 or clampedState, filter)
                if destroyThisSegment then destroyedCount = destroyedCount + 1 else keptCount = keptCount + 1 end
            end
        end
    end
    if (destroyedCount + keptCount) > 0 and KeepStubble.debugLogged < 30 then
        KeepStubble.debugLogged = KeepStubble.debugLogged + 1
        print(string.format("[KeepStubble] DEBUG Rasterdurchgang: %d Segmente (je %.2fm), %d geloescht, %d behalten",
            numSegments, widthLength / numSegments, destroyedCount, keptCount))
    end
end

local function updateAreaKeepFoliage(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, createField, angle)
    createField = Utils.getNoNil(createField, true)
    angle = angle or 0
    local terrainRootNode = g_currentMission.terrainRootNode
    local functionData = ensureFunctionData()
    local modifier = functionData.modifier
    local modifierAngle = functionData.modifierAngle
    local fieldFilter = functionData.fieldFilter
    local seedbedTypeFilter = functionData.seedbedTypeFilter
    local notStubbleTillageFilter = functionData.notStubbleTillageFilter
    local stubbleTillageType = functionData.stubbleTillageType
    if createField then
        fieldFilter = nil
    end
    local _, areaBeforeSeedbed, totalArea = modifier:executeGet(seedbedTypeFilter)
    modifier:setParallelogramWorldCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
    modifierAngle:setParallelogramWorldCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
    modifier:executeSet(stubbleTillageType, notStubbleTillageFilter, fieldFilter)
    modifierAngle:executeSet(angle, fieldFilter)
    applyTargetFoliageStateGridded(functionData, terrainRootNode, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    local _, areaAfterSeedbed, _ = modifier:executeGet(seedbedTypeFilter)
    FSDensityMapUtil.removeSprayArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, nil)
    if g_currentMission.missionInfo.weedsEnabled then
        FSDensityMapUtil.setSowingWeedArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
    else
        FSDensityMapUtil.removeWeedArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    end
    DensityMapHeightUtil.clearArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    local changedArea = areaAfterSeedbed - areaBeforeSeedbed
    return changedArea, totalArea
end

local function hookDensityFunction(funcName)
    if FSDensityMapUtil[funcName] ~= nil then
        local originalFunc = FSDensityMapUtil[funcName]
        FSDensityMapUtil[funcName] = function(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, createField, limitFruitDestructionToField, angle, blockedSprayTypeIndex)
            if not KeepStubble.preserveModeActive then
                return originalFunc(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, createField, limitFruitDestructionToField, angle, blockedSprayTypeIndex)
            end
            local ok, a, b = pcall(updateAreaKeepFoliage, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, createField, angle)
            if ok then
                return a, b
            end
            Logging.warning("[KeepStubble] Fehler in %s, falle auf Original-Verhalten zurueck: %s", funcName, tostring(a))
            return originalFunc(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, createField, limitFruitDestructionToField, angle, blockedSprayTypeIndex)
        end
    end
end

hookDensityFunction("updateDiscHarrowArea")
hookDensityFunction("updateStubbleTillageArea")

Cultivator.processCultivatorArea = Utils.overwrittenFunction(Cultivator.processCultivatorArea, function(self, superFunc, ...)
    local spec = self.spec_cultivator
    local isShallowMode = spec ~= nil and spec.useDeepMode == false
    local isPowerHarrow = self.typeName == "powerHarrow"
                       or self.typeName == "turnOnCultivator"
                       or (spec ~= nil and spec.isPowerHarrow == true)
    if not (isShallowMode and not isPowerHarrow) then
        return superFunc(self, ...)
    end
    KeepStubble.preserveModeActive = true
    local results = { superFunc(self, ...) }
    KeepStubble.preserveModeActive = false
    return unpack(results)
end)

function KeepStubble:addSettingsToMenu()
    print("[KeepStubble] DEBUG: addSettingsToMenu() aufgerufen.")
    if g_gui == nil or g_gui.screenControllers == nil or g_gui.screenControllers[InGameMenu] == nil then
        print("[KeepStubble] DEBUG: g_gui/InGameMenu nicht verfuegbar, breche ab.")
        return
    end

    local inGameMenu = g_gui.screenControllers[InGameMenu]
    local settingsPage = inGameMenu.pageSettings
    if settingsPage == nil or settingsPage.multiVolumeVoiceBox == nil or settingsPage.gameSettingsLayout == nil then
        print("[KeepStubble] DEBUG: settingsPage/multiVolumeVoiceBox/gameSettingsLayout fehlt, breche ab.")
        return
    end

    local originalBox = settingsPage.multiVolumeVoiceBox

    local sectionTitle = nil
    for _, elem in ipairs(settingsPage.gameSettingsLayout.elements) do
        if elem.name == "sectionHeader" then
            sectionTitle = elem:clone(settingsPage.gameSettingsLayout)
            break
        end
    end
    if sectionTitle ~= nil then
        sectionTitle:setText(g_i18n:hasText("ksm_settingSection") and g_i18n:getText("ksm_settingSection") or "Stoppeln erhalten")
    else
        sectionTitle = TextElement.new()
        sectionTitle:applyProfile("fs25_settingsSectionHeader", true)
        sectionTitle:setText(g_i18n:hasText("ksm_settingSection") and g_i18n:getText("ksm_settingSection") or "Stoppeln erhalten")
        sectionTitle.name = "sectionHeader"
        settingsPage.gameSettingsLayout:addElement(sectionTitle)
    end
    sectionTitle.focusId = FocusManager:serveAutoFocusId()
    table.insert(settingsPage.controlsList, sectionTitle)

    local function updateFocusIds(element)
        if not element then return end
        element.focusId = FocusManager:serveAutoFocusId()
        if element.elements ~= nil then
            for _, child in pairs(element.elements) do
                updateFocusIds(child)
            end
        end
    end

    local ok, err = pcall(function()
        local profileBox = originalBox:clone(settingsPage.gameSettingsLayout)
        profileBox.id = "keepStubbleProfileBox"

        local profileOption = profileBox.elements[1]
        profileOption.id = "keepStubbleProfileOption"
        profileOption.target = self
        profileOption:setCallback("onClickCallback", "onProfileChanged")
        profileOption:setDisabled(false)
        profileOption:setTexts(KeepStubble.profileNames)
        profileOption:setState(KeepStubble.activeProfileIndex)

        local profileLabel = profileBox.elements[2]
        if profileLabel ~= nil and profileLabel.setText ~= nil then
            profileLabel:setText(g_i18n:hasText("ksm_profileLabel") and g_i18n:getText("ksm_profileLabel") or "Stoppel-Profil")
        end

        local tooltipText = g_i18n:hasText("ksm_profileTooltip") and g_i18n:getText("ksm_profileTooltip")
            or "Waehlt, welches KeepStubble-Profil (Ausduennung + Zielzustand pro Fruchtart) aktiv ist."
        if profileOption.elements ~= nil and profileOption.elements[1] ~= nil and profileOption.elements[1].setText ~= nil then
            profileOption.elements[1]:setText(tooltipText)
        else
            print("[KeepStubble] DEBUG: profileOption.elements[1] nicht wie erwartet, Tooltip nicht gesetzt.")
        end

        self.profileControl = profileOption
        updateFocusIds(profileBox)
        table.insert(settingsPage.controlsList, profileBox)
        print("[KeepStubble] DEBUG: Profil-Menuepunkt erfolgreich hinzugefuegt.")
    end)

    if not ok then
        Logging.warning("[KeepStubble] Fehler beim Hinzufuegen des Profil-Menuepunkts: %s", tostring(err))
    end

    settingsPage.gameSettingsLayout:invalidateLayout()
end

function KeepStubble:onProfileChanged(state)
    if KeepStubble.PROFILE_FILES[state] == nil then return end
    KeepStubble.activeProfileIndex = state
    loadProfile(state)
    KeepStubble:saveSettings()
end

FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
    if gui == "ingameMenuSettings" then
        local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
        for _, control in ipairs({ KeepStubble.profileControl }) do
            if control ~= nil then
                local parent = control.parent or control
                if not parent.focusId or not FocusManager.currentFocusData.idToElementMapping[parent.focusId] then
                    FocusManager:loadElementFromCustomValues(parent, nil, nil, false, false)
                end
            end
        end
        settingsPage.gameSettingsLayout:invalidateLayout()
    end
end)

print("[KeepStubble] Hooks erfolgreich installiert (Version 1.2.3).")
function KeepStubble:loadMap()
    if g_dedicatedServerInfo ~= nil then return end
    self:loadSettings()

    if g_gui then
        self:addSettingsToMenu()
    end
end

addModEventListener(KeepStubble)
