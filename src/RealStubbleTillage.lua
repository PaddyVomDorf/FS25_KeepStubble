RealStubbleTillage = {}
RealStubbleTillage.functionCache = {}
RealStubbleTillage.preserveModeActive = false
RealStubbleTillage.MOD_DIR = g_currentModDirectory

RealStubbleTillage.densityGridSize = 0.2

-- Fallback-Werte, falls ueberhaupt kein Profil geladen werden konnte
RealStubbleTillage.FALLBACK_PERCENT = 2
RealStubbleTillage.FALLBACK_STATE = -1
RealStubbleTillage.FALLBACK_VOLUNTEER_CHANCE = 50
RealStubbleTillage.SOWN_STATE = 2

RealStubbleTillage.pendingSownAreas = {}
RealStubbleTillage.lastKnownDay = nil
RealStubbleTillage.MAX_PENDING_AREAS = 300000

RealStubbleTillage.PROFILE_FILES = { "vanilla.xml", "custom1.xml", "custom2.xml" }
RealStubbleTillage.profileNames = { "Profil 1", "Profil 2", "Profil 3" }
RealStubbleTillage.activeProfileIndex = 1 -- Standard = Profil 1 (Vanilla)

RealStubbleTillage.fruitSettings = {}

local function getModSettingsPath()
    return getUserProfileAppPath() .. "modSettings/FS25_RealStubbleTillage.xml"
end

local function getProfilePath(index)
    local filename = RealStubbleTillage.PROFILE_FILES[index]
    if filename == nil then
        return nil
    end
    return RealStubbleTillage.MOD_DIR .. "profiles/" .. filename
end

local function scanProfileNames()
    for i, filename in ipairs(RealStubbleTillage.PROFILE_FILES) do
        local path = RealStubbleTillage.MOD_DIR .. "profiles/" .. filename
        if fileExists(path) then
            local xmlFile = XMLFile.load("rstProfileName", path)
            if xmlFile ~= nil then
                local name = xmlFile:getString("settings#name")
                if name ~= nil and name ~= "" then
                    RealStubbleTillage.profileNames[i] = name
                end
                xmlFile:delete()
            end
        else
            print(string.format("[RealStubbleTillage] WARNUNG: Profil-Datei nicht gefunden: %s", path))
        end
    end
end

local function loadProfile(index)
    local path = getProfilePath(index)
    RealStubbleTillage.fruitSettings = {}

    local fallback = { percent = RealStubbleTillage.FALLBACK_PERCENT, state = RealStubbleTillage.FALLBACK_STATE,
        volunteerGrain = true, volunteerGrainChance = RealStubbleTillage.FALLBACK_VOLUNTEER_CHANCE }

    if path == nil or not fileExists(path) then
        Logging.warning("[RealStubbleTillage] Profil-Datei nicht gefunden (Index %d): '%s' - nutze Fallback-Werte fuer alle Fruchtarten.", index, tostring(path))
        RealStubbleTillage.fruitSettings.__default = fallback
        return
    end

    local xmlFile = XMLFile.load("rstProfile", path)
    if xmlFile == nil then
        Logging.warning("[RealStubbleTillage] Konnte Profil-Datei nicht laden: %s", path)
        RealStubbleTillage.fruitSettings.__default = fallback
        return
    end

    local function parseState(stateStr)
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
        return state
    end

    local function parseBool(str, defaultValue)
        if str == nil then return defaultValue end
        local lower = tostring(str):lower()
        return lower == "true" or lower == "1" or lower == "yes"
    end

    local fruitCount = 0
    for _, key in xmlFile:iterator("settings.fruit") do
        local name = xmlFile:getString(key .. "#name")
        local percent = xmlFile:getInt(key .. "#densityReductionPercent")
        local stateStr = xmlFile:getString(key .. "#targetFoliageState")
        if name ~= nil and percent ~= nil and stateStr ~= nil then
            local volunteerGrain = parseBool(xmlFile:getString(key .. "#volunteerGrain"), true)
            local volunteerGrainChance = xmlFile:getInt(key .. "#volunteerGrainChance") or RealStubbleTillage.FALLBACK_VOLUNTEER_CHANCE
            RealStubbleTillage.fruitSettings[name:upper()] = {
                percent = percent,
                state = parseState(stateStr),
                volunteerGrain = volunteerGrain,
                volunteerGrainChance = volunteerGrainChance,
            }
            fruitCount = fruitCount + 1
        end
    end

    local defaultPercent = xmlFile:getInt("settings.default#densityReductionPercent") or RealStubbleTillage.FALLBACK_PERCENT
    local defaultStateStr = xmlFile:getString("settings.default#targetFoliageState")
    local defaultState = RealStubbleTillage.FALLBACK_STATE
    if defaultStateStr ~= nil then
        defaultState = parseState(defaultStateStr)
    end
    local defaultVolunteerGrain = parseBool(xmlFile:getString("settings.default#volunteerGrain"), true)
    local defaultVolunteerGrainChance = xmlFile:getInt("settings.default#volunteerGrainChance") or RealStubbleTillage.FALLBACK_VOLUNTEER_CHANCE
    RealStubbleTillage.fruitSettings.__default = {
        percent = defaultPercent, state = defaultState,
        volunteerGrain = defaultVolunteerGrain, volunteerGrainChance = defaultVolunteerGrainChance,
    }

    xmlFile:delete()

    print(string.format("[RealStubbleTillage] Profil '%s' geladen (Index %d): %d Fruchtarten, Default percent=%d state=%d volunteerGrain=%s(%d%%)",
        RealStubbleTillage.profileNames[index] or ("Profil " .. index), index, fruitCount, defaultPercent, defaultState,
        tostring(defaultVolunteerGrain), defaultVolunteerGrainChance))
end

local function getFruitSettings(fruitName)
    local entry = RealStubbleTillage.fruitSettings[fruitName]
    if entry == nil then
        entry = RealStubbleTillage.fruitSettings.__default
    end
    if entry == nil then
        return RealStubbleTillage.FALLBACK_PERCENT, RealStubbleTillage.FALLBACK_STATE, true, RealStubbleTillage.FALLBACK_VOLUNTEER_CHANCE
    end
    return entry.percent, entry.state, entry.volunteerGrain, entry.volunteerGrainChance
end

function RealStubbleTillage:loadSettings()
    scanProfileNames()

    local modSettingsPath = getModSettingsPath()
    if fileExists(modSettingsPath) then
        local xmlFile = XMLFile.load("rstModSettings", modSettingsPath)
        if xmlFile ~= nil then
            local index = xmlFile:getInt("settings#activeProfileIndex")
            if index ~= nil and index >= 1 and index <= #RealStubbleTillage.PROFILE_FILES then
                RealStubbleTillage.activeProfileIndex = index
            end
            xmlFile:delete()
        end
    end

    loadProfile(RealStubbleTillage.activeProfileIndex)
end

function RealStubbleTillage:saveSettings()
    local modSettingsPath = getModSettingsPath()
    createFolder(getUserProfileAppPath() .. "modSettings")

    local xmlFile = XMLFile.create("rstModSettings", modSettingsPath, "settings")
    if xmlFile == nil then
        Logging.warning("[RealStubbleTillage] Konnte Einstellungen nicht speichern: %s", modSettingsPath)
        return
    end

    xmlFile:setInt("settings#activeProfileIndex", RealStubbleTillage.activeProfileIndex)
    xmlFile:save()
    xmlFile:delete()

    print(string.format("[RealStubbleTillage] Aktives Profil gespeichert: %s (Index %d)",
        RealStubbleTillage.profileNames[RealStubbleTillage.activeProfileIndex] or "?", RealStubbleTillage.activeProfileIndex))
end

local function ensureFunctionData()
    local functionData = RealStubbleTillage.functionCache.data
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
    RealStubbleTillage.functionCache.data = functionData
    return functionData
end

local function applyTargetFoliageStateGridded(functionData, terrainRootNode, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    local widthVecX = widthWorldX - startWorldX
    local widthVecZ = widthWorldZ - startWorldZ
    local widthLength = math.sqrt(widthVecX * widthVecX + widthVecZ * widthVecZ)
    local numSegments = math.max(1, math.floor(widthLength / math.max(RealStubbleTillage.densityGridSize, 0.05)))
    local segFracX = widthVecX / numSegments
    local segFracZ = widthVecZ / numSegments

    for index, desc in pairs(g_fruitTypeManager:getFruitTypes()) do
        if desc.terrainDataPlaneId ~= nil and desc.isCultivationAllowed then
            local modifier = functionData.fruitModifiers[index]
            local filter = functionData.fruitFilters[index]
            if modifier == nil then
                modifier = DensityMapModifier.new(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels, terrainRootNode)
                filter = DensityMapFilter.new(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels, terrainRootNode)
                functionData.fruitModifiers[index] = modifier
                functionData.fruitFilters[index] = filter
            end

            local percent, state, volunteerGrain, volunteerGrainChance = getFruitSettings(desc.name)

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

                local _, matchedArea = modifier:executeGet(filter)
                if matchedArea > 0 then
                    local destroyThisSegment = math.random(100) <= percent
                    if destroyThisSegment then

                        modifier:executeSet(0, filter)
                        if volunteerGrain and math.random(100) <= volunteerGrainChance
                            and #RealStubbleTillage.pendingSownAreas < RealStubbleTillage.MAX_PENDING_AREAS then
                            table.insert(RealStubbleTillage.pendingSownAreas, {
                                fruitIndex = index,
                                startX = segStartX, startZ = segStartZ,
                                widthX = segWidthX, widthZ = segWidthZ,
                                heightX = segHeightX, heightZ = segHeightZ,
                            })
                        end
                    else
                        modifier:executeSet(clampedState, filter)
                    end
                end
            end
        end
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
            if not RealStubbleTillage.preserveModeActive then
                return originalFunc(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, createField, limitFruitDestructionToField, angle, blockedSprayTypeIndex)
            end
            local ok, a, b = pcall(updateAreaKeepFoliage, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, createField, angle)
            if ok then
                return a, b
            end
            Logging.warning("[RealStubbleTillage] Fehler in %s, falle auf Original-Verhalten zurueck: %s", funcName, tostring(a))
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
    RealStubbleTillage.preserveModeActive = true
    local results = { superFunc(self, ...) }
    RealStubbleTillage.preserveModeActive = false
    return unpack(results)
end)

function RealStubbleTillage:addSettingsToMenu()
    if g_gui == nil or g_gui.screenControllers == nil or g_gui.screenControllers[InGameMenu] == nil then
        return
    end

    local inGameMenu = g_gui.screenControllers[InGameMenu]
    local settingsPage = inGameMenu.pageSettings
    if settingsPage == nil or settingsPage.multiVolumeVoiceBox == nil or settingsPage.gameSettingsLayout == nil then
        Logging.warning("[RealStubbleTillage] settingsPage/multiVolumeVoiceBox/gameSettingsLayout fehlt, Menuepunkt wird nicht hinzugefuegt.")
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
        sectionTitle:setText(g_i18n:hasText("rst_settingSection") and g_i18n:getText("rst_settingSection") or "Reale Stoppelbearbeitung")
    else
        sectionTitle = TextElement.new()
        sectionTitle:applyProfile("fs25_settingsSectionHeader", true)
        sectionTitle:setText(g_i18n:hasText("rst_settingSection") and g_i18n:getText("rst_settingSection") or "Reale Stoppelbearbeitung")
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
        profileBox.id = "rstProfileBox"

        local profileOption = profileBox.elements[1]
        profileOption.id = "rstProfileOption"
        profileOption.target = self
        profileOption:setCallback("onClickCallback", "onProfileChanged")
        profileOption:setDisabled(false)
        profileOption:setTexts(RealStubbleTillage.profileNames)
        profileOption:setState(RealStubbleTillage.activeProfileIndex)

        local profileLabel = profileBox.elements[2]
        if profileLabel ~= nil and profileLabel.setText ~= nil then
            profileLabel:setText(g_i18n:hasText("rst_profileLabel") and g_i18n:getText("rst_profileLabel") or "Stoppel-Profil")
        end

        local tooltipText = g_i18n:hasText("rst_profileTooltip") and g_i18n:getText("rst_profileTooltip")
            or "Waehlt, welches RealStubbleTillage-Profil (Ausduennung + Zielzustand + Ausfallgetreide pro Fruchtart) aktiv ist."
        if profileOption.elements ~= nil and profileOption.elements[1] ~= nil and profileOption.elements[1].setText ~= nil then
            profileOption.elements[1]:setText(tooltipText)
        else
            Logging.warning("[RealStubbleTillage] profileOption.elements[1] nicht wie erwartet, Tooltip nicht gesetzt.")
        end

        self.profileControl = profileOption
        updateFocusIds(profileBox)
        table.insert(settingsPage.controlsList, profileBox)
    end)

    if not ok then
        Logging.warning("[RealStubbleTillage] Fehler beim Hinzufuegen des Profil-Menuepunkts: %s", tostring(err))
    end

    settingsPage.gameSettingsLayout:invalidateLayout()
end

function RealStubbleTillage:onProfileChanged(state)
    if RealStubbleTillage.PROFILE_FILES[state] == nil then return end
    RealStubbleTillage.activeProfileIndex = state
    loadProfile(state)
    RealStubbleTillage:saveSettings()
end

FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
    if gui == "ingameMenuSettings" then
        local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
        for _, control in ipairs({ RealStubbleTillage.profileControl }) do
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

RealStubbleTillage.areasToProcess = {}
RealStubbleTillage.PROCESS_PER_FRAME = 200

local function startProcessingPendingSownAreas()
    if #RealStubbleTillage.pendingSownAreas == 0 then
        return
    end

    for _, area in ipairs(RealStubbleTillage.pendingSownAreas) do
        table.insert(RealStubbleTillage.areasToProcess, area)
    end
    RealStubbleTillage.pendingSownAreas = {}
end

local function processQueuedAreasThisFrame()
    if #RealStubbleTillage.areasToProcess == 0 then
        return
    end

    local functionData = RealStubbleTillage.functionCache.data
    if functionData == nil then
        RealStubbleTillage.areasToProcess = {}
        return
    end

    local count = math.min(RealStubbleTillage.PROCESS_PER_FRAME, #RealStubbleTillage.areasToProcess)
    for i = 1, count do
        local area = table.remove(RealStubbleTillage.areasToProcess)
        local modifier = functionData.fruitModifiers[area.fruitIndex]
        if modifier ~= nil then
            modifier:setParallelogramWorldCoords(area.startX, area.startZ, area.widthX, area.widthZ, area.heightX, area.heightZ, DensityCoordType.POINT_POINT_POINT)
            modifier:executeSet(RealStubbleTillage.SOWN_STATE)
        end
    end
end

function RealStubbleTillage:update(dt)
    if g_currentMission == nil or g_currentMission.environment == nil then
        return
    end

    local currentDay = g_currentMission.environment.currentDay
    if currentDay ~= nil then
        if RealStubbleTillage.lastKnownDay == nil then
            RealStubbleTillage.lastKnownDay = currentDay
        elseif currentDay ~= RealStubbleTillage.lastKnownDay then
            RealStubbleTillage.lastKnownDay = currentDay
            local ok, err = pcall(startProcessingPendingSownAreas)
            if not ok then
                Logging.warning("[RealStubbleTillage] Fehler beim Uebernehmen der Ausfallgetreide-Flaechen: %s", tostring(err))
            end
        end
    end

    if #RealStubbleTillage.areasToProcess > 0 then
        local ok, err = pcall(processQueuedAreasThisFrame)
        if not ok then
            Logging.warning("[RealStubbleTillage] Fehler beim Verarbeiten der Ausfallgetreide-Flaechen: %s", tostring(err))
            RealStubbleTillage.areasToProcess = {}
        end
    end
end

print("[RealStubbleTillage] Hooks erfolgreich installiert (Version 1.5.3).")
function RealStubbleTillage:loadMap()
    if g_dedicatedServerInfo ~= nil then return end
    self:loadSettings()

    if g_gui then
        self:addSettingsToMenu()
    end
end

addModEventListener(RealStubbleTillage)
