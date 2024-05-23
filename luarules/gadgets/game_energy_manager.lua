function gadget:GetInfo()
    return {
        name    = "Emergy Manager",
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

local FLOW_PULSE = 20 -- every 0.67 second (1 sec = 30 frames)
local FLOW_PULSE_FLOAT = 0.67 -- 20/30, see above

local calamityCount = {} -- super weapon amount by teamID

local teamIncomeClass = {} -- 0, 1, 2 -- 0 is poor, 1 is healthy, 2 is rich

-- condition 1 is:
local underflowTeam = {} -- by teamID, enable pact: true/false,
local defaultState = true -- default: true
local energyThresholdDefault = 250 -- income (without loss) should be at least this for you to be considered 'Rich' -- condition 2
local storageThresholdDefault = 900 -- minimum E in storage before consider sending some to someone else -- condition 3
local storagePartDefault = 0.10 -- how much of your income is reserved to be sent (counted from storage capacity instead of actual income btw)
local allyEnergyThresholdDefault = 0.10 -- less than 12% in storage means you are poor -- condition 4
-- we rely on mmLevel instead(!), however if it's unavailable then we use this value ^

-- once all conditions are true -- 'underflow' is happening.

-- please add super weapons here
local armvulcDefID = UnitDefNames.armvulc.id
local corbuzzDefID = UnitDefNames.corbuzz.id
local function isCalamity(unitDefID)
	return ((armvulcDefID == unitDefID) or (corbuzzDefID == unitDefID))
end

local function checkIfTeamIsPoor(myTeamID)
    local eCurrMy, eStorMy,_ , eIncoMy, eExpeMy, eShare, eSent, eReceived = spGetTeamResources(myTeamID, "energy")
    local transfered = eShare + eSent + eReceived
    local currentIncome = eIncoMy + transfered
    local currentIncomeWithLoss = eIncoMy + transfered - eExpeMy
    
    local storageThreshold = storageThresholdDefault
    -- autofeed someone with hungry calamity because they cannot shoot
    if (calamityCount[myTeamID] > 0) then
        if (storageThreshold < 30000) then
            storageThreshold = 30000
        end
    end
    if storageThreshold > eStorMy then
        storageThreshold = eStorMy
    end

    local energyConverterThreshold = spGetTeamRulesParam(myTeamID, 'mmLevel')
    if (energyConverterThreshold == nil) then energyConverterThreshold = allyEnergyThresholdDefault
    else
        energyConverterThreshold = energyConverterThreshold - 0.02
        if (energyConverterThreshold > 0.5) then
            energyConverterThreshold = 0.5
        end
    end

    -- if income is positive and current amount in storage > energyConverterThreshold = rich
    if (currentIncomeWithLoss > 0) and ((eCurrMy + currentIncomeWithLoss) > (eStorMy * energyConverterThreshold)) then
        teamIncomeClass[myTeamID] = 2
    -- if income is positive OR there is over storageThresholdDefault in storage = healthy
    elseif (currentIncomeWithLoss > 0) or (eCurrMy >= storageThreshold) then
        teamIncomeClass[myTeamID] = 1
    -- player is poor
    else
        teamIncomeClass[myTeamID] = 0
    end
end

local function energyPulse(myTeamID)
    local eCurrMy, eStorMy,_ , eIncoMy, eExpeMy, eShare, eSent, eReceived = spGetTeamResources(myTeamID, "energy")
    local _,_,_,_,_,myAllyTeamID = spGetTeamInfo(myTeamID, false)
    local teamList = spGetTeamList(myAllyTeamID)
    local transfered = eShare + eSent + eReceived
    local currentIncome = eIncoMy + transfered
    local currentIncomeWithLoss = eIncoMy + transfered - eExpeMy
    local currentStorage = eCurrMy
    local alliesCount = 0 -- how many allies need help
    local energyThreshold = energyThresholdDefault
    local storageThreshold = storageThresholdDefault
    local storagePart = storagePartDefault

    if (currentIncomeWithLoss < 0) then
        storageThreshold = storageThreshold + currentIncomeWithLoss
    end
    if (storageThreshold < 1) then return end -- nothing to give

    if (calamityCount[myTeamID] > 0) then
        if (storageThreshold < 30000) then
            storageThreshold = 30000
        end
    end
    if storageThreshold > eStorMy then
        storageThreshold = eStorMy
    end

    -- energyPool = 10% of income - default
    local energyPool = math_floor((eCurrMy-eExpeMy) * storagePart * FLOW_PULSE_FLOAT)
    -- extra feature: if your income is crazy and you have lots in storage, you are slightly more socialist than you would otherwise be
    if (currentIncome >= 6000) then
        if (eStorMy >= 9000) and (energyPool < 1000) then
            energyPool = 1000
        end
    end

    local alliesReceivers = {}
    -- Check if there are allies eligible for energy distribution
    if currentIncome >= energyThreshold -- c2
        and currentStorage >= storageThreshold then -- c3

        for _, allyTeamID in ipairs(teamList) do
            if (allyTeamID ~= myTeamID) and teamIncomeClass[allyTeamID] ~= 2 then
                local _,playerID,isDead,isAI = spGetTeamInfo(allyTeamID, false)
                local name,active = spGetPlayerInfo(playerID, false)

                if not(isDead) and active and name then
                    alliesCount = alliesCount + 1
                    alliesReceivers[alliesCount] = allyTeamID
                end
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
        local aCurrMy, aStorMy, _, _, _, _,_,_ = spGetTeamResources(allyTeamID, "energy")
        local allyEnergyThreshold = spGetTeamRulesParam(allyTeamID, 'mmLevel')
        if (allyEnergyThreshold == nil) then allyEnergyThreshold = allyEnergyThresholdDefault
        else
            allyEnergyThreshold = allyEnergyThreshold - 0.02
            if (allyEnergyThreshold > 0.5) then
                allyEnergyThreshold = 0.5 -- more than 50% in storage? you'll be fine...
            end
        end
        if (allyEnergyThreshold > 0.05) then
            -- if ally somehow managed to set their mmLevel to 5% or below - never give them energy, they obviously don't need any...
            if ((energyToSend+aCurrMy) >= (aStorMy*allyEnergyThreshold)) then
                energyToSend = (aStorMy*allyEnergyThreshold) - aCurrMy -- never overfill
            end
            if energyToSend > 0 then
                spShareTeamResource(myTeamID, allyTeamID, "energy", energyToSend)
                --spEcho(myTeamID.." donates to "..allyTeamID.." some energy: "..math_floor(energyToSend))

                energyPool = energyPool - energyToSend
            end
        end
    end
end

function gadget:GameFrame(frame)
    if (frame % FLOW_PULSE) == 1 then
        for _, teamID in ipairs(allTeamList) do
            if underflowTeam[teamID] then
                checkIfTeamIsPoor(teamID)
                if teamIncomeClass[teamID] > 0 then
                    energyPulse(teamID)
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
end
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, _, _, _)
    if isCalamity(unitDefID) then
        calamityCount[unitTeam] = calamityCount[unitTeam] - 1
        if (calamityCount[unitTeam] < 0) then
            calamityCount[unitTeam] = 0
        end
    end
end
function gadget:UnitFinished(unitID, unitDefID, unitTeam)
    if isCalamity(unitDefID) then
        calamityCount[unitTeam] = calamityCount[unitTeam] + 1
    end
end
function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
    gadget:UnitDestroyed(unitID, unitDefID, oldTeam, nil, nil, nil)
end

function gadget:RecvLuaMsg(msg, playerID)
    local _, _, mySpec, msgFromTeamID = spGetPlayerInfo(playerID, false)

    if mySpec then return end

    local words = {}
    for word in msg:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if words[1] == "underflowToggle" then
        underflowTeam[msgFromTeamID] = not underflowTeam[msgFromTeamID]
        if underflowTeam[msgFromTeamID] == false then
            teamIncomeClass[msgFromTeamID] = 2 -- greedy player means rich player
        end
    elseif words[1] == "underflowEnable" then
        underflowTeam[msgFromTeamID] = true
    elseif words[1] == "underflowDisable" then
        underflowTeam[msgFromTeamID] = false
    end
end

function gadget:Initialize()
    underflowTeam = {}
    for _, teamID in ipairs(allTeamList) do
        calamityCount[teamID] = 0
        if teamID == GaiaTeamID then
            underflowTeam[teamID] = false
        else
            underflowTeam[teamID] = defaultState
        end
        teamIncomeClass[teamID] = 0
    end
end