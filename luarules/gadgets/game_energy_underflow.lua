if not Spring.GetModOptions().energy_share_rework then
    return
end

function gadget:GetInfo()
    return {
        name    = "Energy Underflow",
        desc    = "Allows players to automatically help each other against E-stalling. No more than 10% of energy income is used. Each individual player can-opt out if this.",
        author  = "Tom Fyuri",
        date    = "2024",
        license = "GNU GPL v2",
        layer   = 0,
        enabled = true
    }
end
-- This gadget essentially introduces opposite overflow mechanics, something like 'underflow', if you will.
-- Complete widget version: https://discord.com/channels/549281623154229250/1134818304142360606
-- Suggestion to implement in base game: https://discord.com/channels/549281623154229250/1242954671312736366
-- How it works in short: IF you are energy rich on income you underflow a portion of your income to your allies so they die to E-stall less than they would otherwise.
-- You can opt-out of this pact with a small toggle near your energy icon on topbar UI.

-- Extra class based ruleset:
-- There are 3 energy classes: poor, healthy, rich.
-- Rich always donates to healthy and poor
-- Poor never donates to anyone

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local spEcho = Spring.Echo
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spSetTeamRulesParam = Spring.SetTeamRulesParam
local spGetPlayerInfo = Spring.GetPlayerInfo
local spShareTeamResource = Spring.ShareTeamResource
local spAreTeamsAllied = Spring.AreTeamsAllied
local spSendLuaUIMsg = Spring.SendLuaUIMsg
local spSendLuaRulesMsg = Spring.SendLuaRulesMsg
local spGetUnitHealth = Spring.GetUnitHealth
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamList = Spring.GetTeamList
local GaiaTeamID = Spring.GetGaiaTeamID()
local allTeamList = spGetTeamList()
local math_floor = math.floor
local math_ceil = math.ceil
local math_max = math.max
local math_round = math.round

-- TODO test that this gadget works fine when it runs faster or slower than 1 second interval - in theory it should be fine, but if there are issues they need to be fixed or interval should be set to once a second.
local FLOW_PULSE = 20 -- every 0.67 second (1 sec = 30 frames)
local FLOW_PULSE_FLOAT = math_round(FLOW_PULSE / 30, 4) -- 20/30, 0.6667, see above

local calamityCount = {} -- super weapon amount by teamID
local starfallCount = {} -- it needs 360k E to shoot omg...

local isFFA = false -- if true, this gadget does nothing
local ignoreList = {} -- ignore these teams, FFA or no allies on some teams, skip them
local teamIncomeClass = {} -- 0, 1, 2 -- 0 is poor, 1 is healthy, 2 is rich, 3 is illegal (ignore)
local currentMMsliderValue = {} -- metalmaker slider value cached
local allyTeamIsRich = {} -- whether entire ally team is rich or not

local underflowTeam = {} -- by teamID, enable pact: true/false,
local defaultState = true -- default: true (players)
local defaultStateForAI = true -- (AI)
-- condition A - healthy income
local energyThresholdDefault = 25 -- income (with loss) should be at least this much for you to be considered for redistribution
local storageThresholdDefaultMin = 1200 -- minimum E in storage before consider sending some to someone else - also minimum energy of storage to be considered 'healthy' instead of 'poor'
-- condition B - lots of energy stored but wasted (in other words - you are about to start burning stored energy or are already converting it into metal)
local energyThresholdDefaultB = -250 -- income (with loss) should be at least this much
local storageThresholdDefaultMax = 9000 -- maximum E in storage before its considered wasted for anti E-stall purposes
-- both of these are aware of player having calamity or any other superweapon, in which case storage absolutely minimum is set to 30k instead
-- income
local incomeUnderflowDefault = 0.10 -- how much of your income is reserved to be sent
local poolIfStorageWasted = 1000 -- how much to send to allies if condition B
local allyEnergyThresholdDefault = 0.12 -- less than 12% in storage means you are poor
-- we rely on mmLevel instead(!), however if it's unavailable then we use this value ^

-- once all conditions are true -- 'underflow' is happening.

-- please add super weapons here (hungry on energy ones)
local armvulcDefID = UnitDefNames.armvulc.id
local corbuzzDefID = UnitDefNames.corbuzz.id
local legministarfallDefID = UnitDefNames.legstarfall and UnitDefNames.legministarfall.id or nil
local legstarfallDefID = UnitDefNames.legstarfall and UnitDefNames.legstarfall.id or nil
local function isCalamity(unitDefID)
	return unitDefID and ((armvulcDefID == unitDefID) or (corbuzzDefID == unitDefID) or (legministarfallDefID == unitDefID))
end
local function isStarfall(unitDefID)
	return unitDefID and (legstarfallDefID == unitDefID)
end

local function recalculateStorageThreshold(teamID, eStorMy, storageThreshold)
    if (calamityCount[teamID] > 0) and (storageThreshold < 400000) then
        storageThreshold = 400000
    elseif (starfallCount[teamID] > 0) and (storageThreshold < 30000) then
        storageThreshold = 30000
    end
    if storageThreshold > eStorMy then
        storageThreshold = eStorMy
    end
    return storageThreshold
end

-- TODO might improve the algo slightly if we can mark whether everyone is rich on the same ally team so we can skip calling energyPulse func for that specific allyTeam altogether
local function checkIfTeamIsPoor(myTeamID)
    local eCurrMy, eStorMy,_ , eIncoMy, eExpeMy, eShareSlider, eSent, eReceived = spGetTeamResources(myTeamID, "energy")
    local transfered = eReceived - eSent
    local currentIncome = eIncoMy + transfered
    local currentIncomeWithLoss = eIncoMy + transfered - eExpeMy
    
    local storageThreshold = storageThresholdDefaultMin
    -- autofeed someone with hungry calamity because they cannot shoot
    storageThreshold = recalculateStorageThreshold(myTeamID, eStorMy, storageThreshold)

    local energyConverterThreshold = spGetTeamRulesParam(myTeamID, 'mmLevel') or allyEnergyThresholdDefault
    local energyConverterValue = allyEnergyThresholdDefault
    if (energyConverterThreshold ~= nil) then
        energyConverterValue = energyConverterThreshold - 0.02
        if (energyConverterValue > 0.5) then
            energyConverterValue = 0.5
        end
    end
    if (energyConverterValue > eShareSlider) then energyConverterValue = eShareSlider end
    currentMMsliderValue[myTeamID] = energyConverterThreshold

    -- if income is positive and current amount in storage > energyConverterThreshold = rich
    if (currentIncomeWithLoss > 0) and ((eCurrMy + currentIncomeWithLoss) > (eStorMy * energyConverterThreshold)) then
        teamIncomeClass[myTeamID] = 2
    -- if income is positive OR there is over storageThresholdDefaultMin in storage = healthy
    elseif (currentIncomeWithLoss > 0) or (eCurrMy >= storageThreshold) then
        teamIncomeClass[myTeamID] = 1
    -- test if illegal conversion value OR broken value
    elseif energyConverterThreshold <= 0.05 then
        teamIncomeClass[myTeamID] = 3
    -- player is poor - negative income or less than minimum safe amount of energy in storage
    else
        teamIncomeClass[myTeamID] = 0
    end
end

local function energyPulse(myTeamID)
    local eCurrMy, eStorMy, _ , eIncoMy, eExpeMy, eShareSlider, eSent, eReceived = spGetTeamResources(myTeamID, "energy")
    local myAllyTeamID = select(6,spGetTeamInfo(myTeamID, false))
    local teamList = spGetTeamList(myAllyTeamID)
    local transfered = eReceived - eSent
    local currentIncome = eIncoMy + transfered
    local currentIncomeWithLoss = eIncoMy + transfered - eExpeMy
    local alliesCount = 0
    local storageThreshold = storageThresholdDefaultMin
    local incomePart = incomeUnderflowDefault

    --[[local amIAI = select(4,spGetTeamInfo(myTeamID, false)) -- debug, uncomment to see how much you'll send to your AI ally in singleplayer
    if not amIAI then
        spEcho(myTeamID.." team - curr: "..eCurrMy.." exp: "..eExpeMy.." calcIncome: "..currentIncome.." isWasting: "..tostring(eCurrMy > (eStorMy*currentMMsliderValue[myTeamID])))
    end]]

    if (currentIncomeWithLoss < 0) then
        storageThreshold = storageThreshold + currentIncomeWithLoss
    end
    if (storageThreshold < 1) then return end -- nothing to give
    storageThreshold = recalculateStorageThreshold(myTeamID, eStorMy, storageThreshold)
    local storageThresholdMax = storageThresholdDefaultMax
    if (storageThresholdMax < storageThreshold) then storageThresholdMax = storageThreshold end
    
    local energyPool = 0
    -- you have several thousand enery in storage, please share it
    if (currentIncome >= energyThresholdDefaultB and eCurrMy >= storageThresholdDefaultMax) or ((eCurrMy > (eStorMy*currentMMsliderValue[myTeamID]) or eCurrMy > (eStorMy*eShareSlider)) and eCurrMy >= storageThresholdDefaultMax) then
        energyPool = math_floor(currentIncome * incomePart * FLOW_PULSE_FLOAT)

        if (energyPool < poolIfStorageWasted*2) then energyPool = poolIfStorageWasted*2
        elseif (energyPool < poolIfStorageWasted) then energyPool = poolIfStorageWasted end
    -- energyPool = 10% of income - default, a small donation
    elseif (currentIncome >= energyThresholdDefault and eCurrMy >= storageThreshold) then
        energyPool = math_floor(currentIncome * incomePart * FLOW_PULSE_FLOAT)
    else return end
    if (energyPool < 1) then return end
    -- ^ cannot spare anything right now

    --[[if not amIAI then
        spEcho(myTeamID.." team has energy to share amount: "..energyPool)
    end]]

    local alliesReceivers = {}
    for _, allyTeamID in ipairs(teamList) do
        if (allyTeamID ~= myTeamID) and teamIncomeClass[allyTeamID] < 2 then
            local _,playerID,isDead,isAI = spGetTeamInfo(allyTeamID, false)
            local name,active = spGetPlayerInfo(playerID, false)

            if not(isDead) and active and name then
                alliesCount = alliesCount + 1
                alliesReceivers[alliesCount] = allyTeamID
            end
        end
    end
	if 1 > alliesCount then return end

    local energyToSend = math_floor(energyPool / alliesCount)
    if (energyToSend < 1) then return end

    for i=1, alliesCount do
        if (energyPool < 1) then
            break
        end
        local allyTeamID = alliesReceivers[i]
        local aCurrMy, aStorMy, _ , aIncoMy, aExpeMy, aShareSlider, aSent, aReceived = spGetTeamResources(allyTeamID, "energy")
        local allyEnergyThreshold = currentMMsliderValue[allyTeamID]
        local transfered = aReceived - aSent
        local currentIncome = aIncoMy + transfered
        
        if (allyEnergyThreshold > 0.05) then
            if ((energyToSend+currentIncome+aCurrMy) >= (aStorMy*allyEnergyThreshold)) then
                energyToSend = math_floor((aStorMy*allyEnergyThreshold) - aCurrMy - currentIncome) -- never overfill
            end
            if energyToSend > 0 then
                spShareTeamResource(myTeamID, allyTeamID, "energy", energyToSend)
                --[[if not amIAI then
                    spEcho(myTeamID.." donates to "..allyTeamID.." some energy: "..energyToSend)
                end]]
                energyPool = energyPool - energyToSend
            end
        end
    end
end

function gadget:GameFrame(frame)
    if not isFFA and (frame % FLOW_PULSE) == 1 then
        for allyTeamID, _ in ipairs(allyTeamIsRich) do
            allyTeamIsRich[allyTeamID] = true
        end
        for _, teamID in ipairs(allTeamList) do
            if underflowTeam[teamID] and not ignoreList[teamID] then
                checkIfTeamIsPoor(teamID)
                if teamIncomeClass[teamID] < 2 then
                    local allyTeamID = select(6, spGetTeamInfo(teamID, false))
                    allyTeamIsRich[allyTeamID] = false
                end
            end
        end
        
        for _, teamID in ipairs(allTeamList) do
            if underflowTeam[teamID] and not ignoreList[teamID] then
                local allyTeamID = select(6, spGetTeamInfo(teamID, false))
                if allyTeamIsRich[allyTeamID] == false then
                    if teamIncomeClass[teamID] > 0 then
                        energyPulse(teamID)
                    end
                end
            end
        end
    end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
    if isCalamity(unitDefID) then
        local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
        if (buildProgress >= 1) then
            calamityCount[newTeam] = calamityCount[newTeam] + 1
        end
    end
    if isStarfall(unitDefID) then
        local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
        if (buildProgress >= 1) then
            starfallCount[newTeam] = starfallCount[newTeam] + 1
        end
    end
end
function gadget:UnitDestroyed(unitID, unitDefID, teamID, _, _, _)
    if isCalamity(unitDefID) then
        calamityCount[teamID] = calamityCount[teamID] - 1
        if (calamityCount[teamID] < 0) then
            calamityCount[teamID] = 0
        end
    end
    if isStarfall(unitDefID) then
        starfallCount[teamID] = starfallCount[teamID] - 1
        if (starfallCount[teamID] < 0) then
            starfallCount[teamID] = 0
        end
    end
end
function gadget:UnitFinished(unitID, unitDefID, teamID)
    if isCalamity(unitDefID) then
        calamityCount[teamID] = calamityCount[teamID] + 1
    end
    if isStarfall(unitDefID) then
        starfallCount[teamID] = starfallCount[teamID] + 1
    end
end
function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
    gadget:UnitDestroyed(unitID, unitDefID, oldTeam, nil, nil, nil)
end

function gadget:RecvLuaMsg(msg, playerID)
    local _, _, mySpec, teamID = spGetPlayerInfo(playerID, false)

    if mySpec then return end

    local words = {}
    for word in msg:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if words[1] == "underflowToggle" then
        underflowTeam[teamID] = not underflowTeam[teamID]
        if underflowTeam[teamID] == false then
            teamIncomeClass[teamID] = 2 -- greedy player means rich player, they won't receive anything, they won't send underflow either
        end
        spSetTeamRulesParam(teamID, "underflowStatus", underflowTeam[teamID])
    elseif words[1] == "underflowEnable" then
        underflowTeam[teamID] = true
        spSetTeamRulesParam(teamID, "underflowStatus", underflowTeam[teamID])
    elseif words[1] == "underflowDisable" then
        underflowTeam[teamID] = false
        spSetTeamRulesParam(teamID, "underflowStatus", underflowTeam[teamID])
    end
end

function gadget:Initialize()
    local allyTeamCounts = {}
    local maxAlliesDetected = 0
    for _, teamID in ipairs(allTeamList) do
        local allyTeamID = select(6, spGetTeamInfo(teamID))
        if not allyTeamCounts[allyTeamID] then
            allyTeamCounts[allyTeamID] = 0
        end
        allyTeamCounts[allyTeamID] = allyTeamCounts[allyTeamID] + 1
        if allyTeamCounts[allyTeamID] > maxAlliesDetected then
            maxAlliesDetected = allyTeamCounts[allyTeamID]
        end
    end

    for _, teamID in ipairs(allTeamList) do
        calamityCount[teamID] = 0
        starfallCount[teamID] = 0
        if teamID == GaiaTeamID then
            underflowTeam[teamID] = false
        else
            local isAI = select(4,spGetTeamInfo(teamID, false))
            if isAI then
                underflowTeam[teamID] = defaultStateForAI
            else
                underflowTeam[teamID] = defaultState
            end
        end
        spSetTeamRulesParam(teamID, "underflowStatus", underflowTeam[teamID])
        teamIncomeClass[teamID] = 0
        currentMMsliderValue[teamID] = 0.5

        local allyTeamID = select(6, spGetTeamInfo(teamID))
        allyTeamIsRich[allyTeamID] = true
        if allyTeamCounts[allyTeamID] == 1 then
            ignoreList[teamID] = true
        else
            ignoreList[teamID] = false
        end
    end

    if maxAlliesDetected <= 1 then
        isFFA = true
    end
end