-- OUTLINE:
-- Low priority cons build either at their full speed or not at all.
-- The amount of res expense for high prio cons is calculated (as total expense - low prio cons expense) and the remainder is available to the low prio cons, if any.
-- We cycle through the low prio cons and allocate this expense until it runs out. All other low prio cons have their buildspeed set to 0.

-- ACTUALLY:
-- We only do the check every x frames (controlled by interval) and only allow low prio con(s) to act if doing so allows them to sustain their expense
--   until the next check, based on current expense allocations.
-- We allow the interval to be different for each team, because normally it would be wasteful to reconfigure every frame, but if a team has a high income and low
--   storage then not doing the check every frame would result in excessing resources that low prio builders could have used
-- We also pick one low prio con, per build target, and allow it a tiny build speed for 1 frame per interval, to prevent nanoframes that only have low prio cons
--   building them from decaying if a prolonged stall occurs.
-- We cache the buildspeeds of all low prio cons to prevent constant use of get/set callouts.

-- REASON:
-- AllowUnitBuildStep is damn expensive and is a serious perf hit if it is used for all this.

-- Done: Unify the usage of ruleName, to make it so that high prio = nil or false, low prio = assigned buildspeed

-- TODO: rewrite the whole goddamn thing as a multilevel queue!

--[[

Note to self, there are four outstanding issues with this approach:

	solars and makers cant be built by low-prio cons, would need a medium priority queue
	During round-robin iteration, units that were previously given resources do not free them.
	Still creates a non-zero amount of garbage by iterating over every stupid constructor
	Needs a proper multilevel queue implementation for this to make sense, with proper pop-back instructions, because there are factually 4 priority levels currently:

	High prio cons
	Low prio Cons building solars or makers
	low prio cons who are sole builders of a target
	low prio everyone else.

	Sets UnitUniformBuffers set for nanospray gl4


]]--




function gadget:GetInfo()
	return {
		name	  = 'Builder Priority', 	-- this once was named: Passive Builders v3
		desc	  = 'Builders marked as low priority only use resources after others builder have taken their share',
		author	= 'Beherith, Floris',
		date	  = '2023.12.28',
		license   = 'GNU GPL, v2 or later',
		layer	 = 0,
		enabled   = true
	}
end

local DEBUG = false -- will draw the buildSpeeds above builders. Perf heavy but its debugging only.
local VERBOSE = false -- will spam debug into infolog
local FORWARDUNIFORMS = false -- Needed for future nanospray GL4
-- Available Info to Widgets:
--Number is build speed number, and means low priority, otherwise nil means high
--Spring.GetUnitRulesParam(unitID, "builderPriorityLow")
local ruleName = "builderPriorityLow" -- So that non-nil means low prio, and the actual build speed number, nil means high

--TeamRulesParams
local totalBuildPowerRule = "totalBuildPower" -- total build power of a team
local highPrioBuildPowerRule = "highPrioBuildPower" -- The total buildpower of constructors set to high priority
local lowPrioBuildPowerRule = "lowPrioBuildPower"	-- The total buildpower of constructors set to low  priority 
local highPrioBuildPowerWantedRule = "highPrioBuildPowerWanted" -- The total buildpower of constructors set to high priority that are building things
local lowPrioBuildPowerWantedRule = "lowPrioBuildPowerWanted"  -- The total buildpower of constructors set to low priority that are building things
local highPrioBuildPowerUsedRule = "highPrioBuildPowerUsed" -- The total buildpower of constructors set to high priority that is actually spent on building stuff
local lowPrioBuildPowerUsedRule = "lowPrioBuildPowerUsed" -- The total buildpower of constructors set to low priority that is actually spent on building stuff

local highPrioNeededMetalRule = "highPrioNeededMetal"
local lowPrioNeededMetalRule = "lowPrioNeededMetal"
local highPrioNeededEnergyRule = "highPrioNeededEnergy"
local lowPrioNeededEnergyRule = "lowPrioNeededEnergy"

local lowPrioExpenseMetalRule = "lowPrioExpenseMetal"
local lowPrioExpenseEnergyRule = "lowPrioExpenseEnergy"


local totalNeedEnergyRule = "totalNeedEnergy"   ---xxx
local totalNeedMetalRule = "totalNeedMetal"

local currentFrame = 0
local lastUpdatedFrame = 0
local cicleNumber = 0
if not gadgetHandler:IsSyncedCode() then
	if DEBUG then 
		
		local canPassive = {} -- canPassive[unitDefID] = nil / true
		for unitDefID, unitDef in pairs(UnitDefs) do
			canPassive[unitDefID] = ((unitDef.canAssist and unitDef.buildSpeed > 0) or #unitDef.buildOptions > 0)
		end
		
		function gadget:DrawWorld()
			for i, unitID in pairs(Spring.GetAllUnits()) do 
				if Spring.IsUnitInView(unitID) and canPassive[Spring.GetUnitDefID(unitID)] then  
					local lowPriority = Spring.GetUnitRulesParam(unitID, ruleName)
				
					local x,y,z = Spring.GetUnitPosition(unitID)
					gl.PushMatrix()
					gl.Translate(x,y+64, z)
					
					gl.Text(((lowPriority and "L:"..tostring(lowPriority)) or "High"),0,0,16,'n')
					gl.PopMatrix()

				end
			end
		end
		
		function gadget:DrawScreen()
			local myTeam = Spring.GetMyTeamID()
			local myPrioUpdateRate = Spring.GetTeamRulesParam(myTeam, "builderUpdateInterval")
			if myPrioUpdateRate then 
				local vsx, vsy = Spring.GetViewGeometry()
				gl.Text(string.format("Update Interval = %.2f",myPrioUpdateRate), vsx/2, 16,16)
			end
		end
		
	end
	if FORWARDUNIFORMS then 
		local uniformCache = {0}
		local function BuildSpeedsChanged(cmdname, countx2, ...)
			local vararg = {...}
			for i= 1, countx2, 2 do 
				uniformCache[1] = vararg[i+1]
				gl.SetUnitBufferUniforms(vararg[i], uniformCache, 1)
				--Spring.Echo(vararg[i], vararg[i+1])
			end
			
		end
		
		function gadget:Initialize()
			gadgetHandler:AddSyncAction("BuildSpeedsChanged", BuildSpeedsChanged)
		end

		function gadget:Shutdown()
			gadgetHandler:RemoveSyncAction("BuildSpeedsChanged")
		end
	end

else

local CMD_PRIORITY = 34571

local stallMarginInc = 0.2 -- 
local stallMarginSto = 0.01

local buildPowerMinimum = 0.001 -- A small amount of buildpower we allocate to each build target owner to ensure that nanoframes dont vanish 

local passiveCons = {} -- passiveCons[teamID][builderID] = true for passive cons
local roundRobinIndexTeam = {} -- {teamID = roundRobinIndex}
local roundRobinLastRoundTeamBuilders = {} -- {teamID = {builderID = true}} -- this is for taking away the resources of previous RR recipients
local canBuild = {} --builders[teamID][builderID], contains all builders

local buildTargets = {} --{builtUnitID = builderUnitID} the unitIDs of build targets of passive builders, a -1 here indicates that this build target has Active builders too.

local maxBuildSpeed = {} -- {builderUnitID = buildSpeed} build speed of builderID, as in UnitDefs (contains all builders)
local currentBuildSpeed = {} -- {builderid = currentBuildSpeed} build speed of builderID for current interval, not accounting for buildOwners special speed (contains only passive builders)

-- NOTE: Explanation: Instead of using an individual table to store {unitID = {metal, energy, buildtime}}
-- We are using using a single table, where {unitID = metal, (unitID + energyOffset) = energy, (unitID+buildTimeOffset) = buildtime}
local costIDOverride = {}
local energyOffset = Game.maxUnits + 1
local buildTimeOffset = (Game.maxUnits + 1) * 2 

local resTable = {"metal","energy"} -- 1 = metal, 2 = energy

local cmdPassiveDesc = {
	  id	  = CMD_PRIORITY,
	  name	= 'priority',
	  action  = 'priority',
	  type	= CMDTYPE.ICON_MODE,
	  tooltip = 'Builder Mode: Low Priority restricts build when stalling on resources',
	  params  = {1, 'Low Prio', 'High Prio'}, -- cmdParams[1], where 0 == Low Prio, 1 == High prio
}

local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spEditUnitCmdDesc = Spring.EditUnitCmdDesc
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamList = Spring.GetTeamList
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spValidUnitID = Spring.ValidUnitID
local spGetTeamInfo = Spring.GetTeamInfo
local simSpeed = Game.gameSpeed
local LOS_ACCESS = {inlos = true}

local max = math.max
local floor = math.floor

local updateFrame = {}

local teamList
local deadTeamList = {}
local canPassive = {} -- canPassive[unitDefID] = nil / true

-- Uses a flattened table as per costIDOverride
local cost = {} -- cost = {unitDefID = metal, (unitDefID + energyOffset) = energy, (unitDefID+buildTimeOffset) = buildtime}, this is now keyed on integers for better cache
-- Is there any point in the approximate 100Kb of RAM savings? Probably no 

local unitBuildSpeed = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.buildSpeed > 0 then
		unitBuildSpeed[unitDefID] = unitDef.buildSpeed
	end
	-- build the list of which unitdef can have low prio mode
	canPassive[unitDefID] = ((unitDef.canAssist and unitDef.buildSpeed > 0) or #unitDef.buildOptions > 0)
	-- build a list of the unit costs
	cost[unitDefID				  ] = unitDef.metalCost
	cost[unitDefID +	energyOffset] = unitDef.energyCost
	cost[unitDefID + buildTimeOffset] = unitDef.buildTime
end

local function updateTeamList()
	teamList = spGetTeamList()
	for _, teamID in ipairs(teamList) do
		passiveCons[teamID] = {} -- passiveCons[teamID][builderID] = true for passive cons
		roundRobinIndexTeam[teamID] = 1 -- {teamID = roundRobinIndex}
		roundRobinLastRoundTeamBuilders[teamID] = {} -- {teamID = {builderID = true}} -- this is for taking away the resources of previous RR recipients
		canBuild[teamID] = {} --builders[teamID][builderID], contains all builders
		Spring.SetTeamRulesParam(teamID, totalBuildPowerRule, 0)
		Spring.SetTeamRulesParam(teamID, highPrioBuildPowerRule, 0)
		Spring.SetTeamRulesParam(teamID, lowPrioBuildPowerRule, 0)
		Spring.SetTeamRulesParam(teamID, highPrioBuildPowerUsedRule, 0)
		Spring.SetTeamRulesParam(teamID, lowPrioBuildPowerUsedRule, 0)

		Spring.SetTeamRulesParam(teamID, highPrioNeededMetalRule, 0)
		Spring.SetTeamRulesParam(teamID, lowPrioNeededMetalRule, 0)
		Spring.SetTeamRulesParam(teamID, highPrioNeededEnergyRule, 0)
		Spring.SetTeamRulesParam(teamID, lowPrioNeededEnergyRule, 0)


		Spring.SetTeamRulesParam(teamID, lowPrioExpenseMetalRule, 0)
		Spring.SetTeamRulesParam(teamID, lowPrioExpenseEnergyRule, 0)


		Spring.SetTeamRulesParam(teamID, totalNeedEnergyRule, 0)
		Spring.SetTeamRulesParam(teamID, totalNeedMetalRule, 0)
	end
end

function gadget:Initialize()
	updateTeamList()
	for _,unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end

local nCBS = 0
local changedBuildSpeeds = {}

local function MaybeSetWantedBuildSpeed(builderID, wantedSpeed, force)
	if (currentBuildSpeed[builderID] ~= wantedSpeed) or force then
		spSetUnitBuildSpeed(builderID, wantedSpeed) -- 100 ns per call
		spSetUnitRulesParam(builderID, ruleName, wantedSpeed)  -- 300 ns per call
		currentBuildSpeed[builderID] = wantedSpeed
		if FORWARDUNIFORMS then 
			changedBuildSpeeds[nCBS + 1] = builderID
			changedBuildSpeeds[nCBS + 2] = wantedSpeed
			nCBS = nCBS + 2
		end
	end
end

local function SetBuilderPriority(builderID, lowPriority)
	if lowPriority then  -- low prio immediately sets it to 0 buildspeed
		MaybeSetWantedBuildSpeed(builderID, 0, true)
	else -- set to high
		-- clear all our passive status
		spSetUnitBuildSpeed(builderID, maxBuildSpeed[builderID]) 
		spSetUnitRulesParam(builderID, ruleName, nil) 
		currentBuildSpeed[builderID] = maxBuildSpeed[builderID]
		
		if FORWARDUNIFORMS then 
			changedBuildSpeeds[nCBS + 1] = builderID
			changedBuildSpeeds[nCBS + 2] = maxBuildSpeed[builderID]
			nCBS = nCBS + 2
		end
	end
end

local function BuildSpeedsChanged()
	if nCBS > 0 then 
		-- Note: we are pretty much pushing an entire unpacked table onto sendtounsynced
		-- the max amound of stuff we can send here is like <8000 elements. 
		-- todo: actually check that we dont send more, and if we do, then split it into multiple calls.
		SendToUnsynced("BuildSpeedsChanged", nCBS, unpack(changedBuildSpeeds))
		changedBuildSpeeds = {}
		nCBS = 0
	end
end


local function UDN(unitID) --get unit name
	return UnitDefs[Spring.GetUnitDefID(unitID)].name
end


function gadget:UnitCreated(unitID, unitDefID, teamID)
	if unitBuildSpeed[unitDefID] then
		canBuild[teamID][unitID] = true
		maxBuildSpeed[unitID] = unitBuildSpeed[unitDefID]
	end
	if canPassive[unitDefID] then
		spInsertUnitCmdDesc(unitID, cmdPassiveDesc)
		local lowPriority = spGetUnitRulesParam(unitID, ruleName) or nil -- non-nil rule means passive
		passiveCons[teamID][unitID] = lowPriority
		SetBuilderPriority(unitID, lowPriority)

		if VERBOSE then 
			Spring.Echo(string.format("UnitID %i of def %s has been set to %s = %s",
					unitID, UnitDefs[unitDefID].name, ruleName, tostring(passiveCons[teamID][unitID])))
		end
	end
	--here we start tracking the unit, that is beeing built until it is finished. We use it to calculate the resources wanted by the constructors
	costIDOverride[unitID +			   0] = cost[unitDefID]  --  
	costIDOverride[unitID +	energyOffset] = cost[unitDefID + energyOffset]
	costIDOverride[unitID + buildTimeOffset] = cost[unitDefID + buildTimeOffset]
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	gadget:UnitDestroyed(unitID, unitDefID, oldTeamID)
	gadget:UnitCreated(unitID, unitDefID, newTeamID)
end

function gadget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
	gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	-- Clear Team stuff
	canBuild[teamID][unitID] = nil
	roundRobinLastRoundTeamBuilders[teamID][unitID] = nil
	passiveCons[teamID][unitID] = nil
	
	-- clear unit data
	maxBuildSpeed[unitID] = nil
	currentBuildSpeed[unitID] = nil

	costIDOverride[unitID +			   0] = nil
	costIDOverride[unitID +	energyOffset] = nil
	costIDOverride[unitID + buildTimeOffset] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	-- as its no longer being built, clear cache of its costs
	costIDOverride[unitID +			   0] = nil
	costIDOverride[unitID +	energyOffset] = nil
	costIDOverride[unitID + buildTimeOffset] = nil
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- track which cons are set to passive
	if cmdID == CMD_PRIORITY and canPassive[unitDefID] then
		local cmdIdx = spFindUnitCmdDesc(unitID, CMD_PRIORITY)
		if cmdIdx then
			local cmdDesc = spGetUnitCmdDescs(unitID, cmdIdx, cmdIdx)[1]
			cmdDesc.params[1] = cmdParams[1] -- cmdParams[1] where 0 == Low Prio, 1 == High prio
			spEditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
			local lowPriority = (cmdParams[1] == 0) -- if the parameter eaquals 0 this will be true
			
			SetBuilderPriority(unitID, lowPriority) -- if lowPriority == true the function will set the BP value to 0
			passiveCons[teamID][unitID] = lowPriority or nil
			roundRobinLastRoundTeamBuilders[teamID][unitID] = nil -- this is to ensure that mid-update changes carry over

			if VERBOSE then 
				Spring.Echo(string.format("UnitID %i of def %s has been set to %s = %s (%s)",
						unitID, UnitDefs[unitDefID].name, ruleName, tostring(passiveCons[teamID][unitID]), tostring(cmdParams[1])))
			end
		end
		return false -- Allowing command causes command queue to be lost if command is unshifted
	end
	return true
end

local function UpdatePassiveBuilders(teamID, interval)
	cicleNumber = cicleNumber + 1
	if currentFrame ~= lastUpdatedFrame then
		lastUpdatedFrame = currentFrame
		cicleNumber = 1
	end
	-- calculate how much expense each passive con would require, and how much total expense the non-passive cons require

	local passiveConsTeam = passiveCons[teamID]
	if tracy then tracy.ZoneBeginN("UpdateStart") end 
	local numPassiveCons = 0

	
	local passiveExpense = {} -- once again, similar to the costIDOverride we are using a single table with offsets to store two values per unitID
	local totalBuildPower = 0
	local highPrioBuildPower = 0
	local lowPrioBuildPower = 0
	local highPrioBuildPowerWanted = 0
	local lowPrioBuildPowerWanted = 0
	local highPrioBuildPowerUsed = 0
	local lowPrioBuildPowerUsed = 0

	local lowPrioExpenseMetal = 0  
	local lowPrioExpenseEnergy = 0
	
	local highPrioNeededEnergy = 0
	local highPrioNeededMetal = 0

	local lowPrioNeededEnergy = 0
	local lowPrioNeededMetal = 0

	local totalNeedEnergy = 0   ---xxx
	local totalNeedMetal = 0

	
	-- Dont count solars and mm's as stalling:
	local midPrioSolarMaker = {} -- builderID to negative metal, positive energy cost
	-- this is about 800 us
	if canBuild[teamID] then
		local canBuildTeam = canBuild[teamID]
		for builderID in pairs(canBuildTeam) do
			local builtUnit = spGetUnitIsBuilding(builderID)
			local expenseMetal = builtUnit and costIDOverride[builtUnit] or nil -- sets expenseMetal to the metal cost of the built unit
			local maxbuildspeed = maxBuildSpeed[builderID]
			totalBuildPower = totalBuildPower + maxbuildspeed
			local isPassive = passiveConsTeam[builderID]
			if isPassive then 
				lowPrioBuildPower = lowPrioBuildPower + maxbuildspeed
			else
				highPrioBuildPower = highPrioBuildPower + maxbuildspeed
			end
			
			if builtUnit and expenseMetal and maxbuildspeed then	-- added check for maxBuildSpeed[builderID] else line below could error (unsure why), probably units that were newly created?

				local expenseEnergy = costIDOverride[builtUnit + energyOffset]
				local rate = maxbuildspeed / costIDOverride[builtUnit + buildTimeOffset] -- calculates the max fraction of the unit that can be built by the current constructor

				-- TODO: redo solar and basic MM no-stall logic
				
				-- metal maker costs 1 metal, don't stall because of that, so we will set the metalExpense to 0 if it is 1 or less
				expenseMetal = (expenseMetal <=1) and 0 or expenseMetal * rate  -- now we know how much the constructor actually wants to spend
				totalNeedMetal = totalNeedMetal + expenseMetal --careful is this just the help value? should I add it in the if expenseEnergy == 0 constraint? aswell?
				-- solar costs 0 energy, don't stall because of that (is this really needed? 0 stays 0)
				expenseEnergy = (expenseEnergy <=1) and 0 or expenseEnergy * rate
				totalNeedEnergy = totalNeedEnergy + expenseEnergy

				if isPassive then 
					passiveExpense[builderID] = expenseMetal  -- here it still shows the wanted metal, not the actually spent metal
					passiveExpense[builderID+ energyOffset] = expenseEnergy
					numPassiveCons = numPassiveCons + 1
					lowPrioNeededEnergy = lowPrioNeededEnergy + expenseEnergy
					lowPrioNeededMetal  = lowPrioNeededMetal  + expenseMetal
					buildTargets[builtUnit] = builderID 
					
					if expenseMetal == 0 then
						midPrioSolarMaker[builderID] = expenseEnergy 
					end
					if expenseEnergy == 0 then 
						midPrioSolarMaker[builderID] = -1 * expenseMetal
					end
					lowPrioBuildPowerWanted = lowPrioBuildPowerWanted + maxbuildspeed
					
				else
					highPrioBuildPowerWanted = highPrioBuildPowerWanted + maxbuildspeed
					highPrioNeededEnergy = highPrioNeededEnergy + expenseEnergy
					highPrioNeededMetal  = highPrioNeededMetal  + expenseMetal
				end
				
			end
			
			
		end
	end
	local intervalpersimspeed = interval/simSpeed
	if tracy then tracy.ZoneEnd() end 

	-- calculate how much expense passive cons will be allowed, this can be negative
	local passiveEnergyLeft, passiveMetalLeft

	for _,resName in pairs(resTable) do
		local currentLevel, storage, pull, income, expense, share, sent, received = spGetTeamResources(teamID, resName)
		storage = storage * share -- consider capacity only up to the share slider
		local reservedExpense = (resName == 'energy' and highPrioNeededEnergy or highPrioNeededMetal) -- we don't want to touch this part of expense
		if resName == 'energy' then -- not sure if the way to calculate passiveEnergyLeft is totally correct
			passiveEnergyLeft = currentLevel - max(income * stallMarginInc, storage * stallMarginSto) - 1 + (income - reservedExpense + received - sent) * intervalpersimspeed --amount of res available to assign to passive builders (in next interval); leave a tiny bit left over to avoid engines own "stall mode"
			--Spring.Echo("Formula: passiveEnergyLeft = currentLevel - max(income * stallMarginInc, storage * stallMarginSto) - 1 + (income - reservedExpense + received - sent) * intervalpersimspeed")
			--local test = max(income * stallMarginInc, storage * stallMarginSto)
			--Spring.Echo(" max(income * stallMarginInc, storage * stallMarginSto) "  ..test)
			--Spring.Echo("Numbers: passiveEnergyLeft = " .. tostring(currentLevel) .. " - max(" .. tostring(income) .. " * " .. tostring(stallMarginInc) .. ", " .. tostring(storage) .. " * " .. tostring(stallMarginSto) .. ") - 1 + (" .. tostring(income) .. " - " .. tostring(reservedExpense) .. " + " .. tostring(received) .. " - " .. tostring(sent) .. ")" ..tostring(intervalpersimspeed))
			--Spring.Echo("Passive Energy Left: " .. tostring(passiveEnergyLeft))
			local actualPassiveEnergyLeft = currentLevel + ( 0 - max(income * stallMarginInc, storage * stallMarginSto) + (income - reservedExpense + received)) * intervalpersimspeed
		else
			passiveMetalLeft =  currentLevel - max(income * stallMarginInc, storage * stallMarginSto) - 1 + (income - reservedExpense + received - sent) -- * intervalpersimspeed is not needed --amount of res available to assign to passive builders (in next interval); leave a tiny bit left over to avoid engines own "stall mode"
		end
	end

	local passiveMetalStart = passiveMetalLeft
	local passiveEnergyStart = passiveEnergyLeft

	local havePassiveResourcesLeft = (passiveEnergyLeft > 0) and (passiveMetalLeft > 0 )
	if havePassiveResourcesLeft then 
		highPrioBuildPowerUsed = highPrioBuildPowerWanted
	else
		highPrioNeededMetal = math.max(highPrioNeededMetal, 1)
		highPrioNeededEnergy = math.max(highPrioNeededEnergy, 1)
		local highPrioMetalSpend = (highPrioNeededMetal + math.min(0, passiveMetalLeft)) / highPrioNeededMetal
		local highPrioEnergySpend = (highPrioNeededEnergy + math.min(0, passiveEnergyLeft)) / highPrioNeededEnergy
		local highPrioMetalSpend1 = (highPrioNeededMetal + passiveMetalLeft) / highPrioNeededMetal
		highPrioBuildPowerUsed = highPrioBuildPowerWanted * math.min(highPrioMetalSpend, highPrioEnergySpend)
	end

	
	
	-- Allow passive cons to build solars and makers as a medium priority
	for builderID, costtype in pairs(midPrioSolarMaker) do 
		if costtype < 0 then -- metal
			if (passiveMetalLeft > -1 * costtype) then 
				passiveMetalLeft = passiveMetalLeft + costtype
				MaybeSetWantedBuildSpeed(builderID, maxBuildSpeed[builderID])
				lowPrioBuildPowerUsed = lowPrioBuildPowerUsed + maxBuildSpeed[builderID]
				lowPrioExpenseMetal = lowPrioExpenseMetal - costtype
			else
				midPrioSolarMaker[builderID] = nil -- remove them if we cant give them resources here
			end
		else -- energy
			if (passiveEnergyLeft > costtype) then
				passiveEnergyLeft = passiveEnergyLeft - costtype
				MaybeSetWantedBuildSpeed(builderID, maxBuildSpeed[builderID])
				lowPrioBuildPowerUsed = lowPrioBuildPowerUsed + maxBuildSpeed[builderID]
				lowPrioExpenseEnergy = lowPrioExpenseEnergy + costtype
			else
				midPrioSolarMaker[builderID] = nil	-- remove them if we cant give them resources here
			end
		end
	end
	
	-- Take away the resources allocated in a round-robin way in the previous pass:
	local previousRoundRobinBuilders = 	roundRobinLastRoundTeamBuilders[teamID] 
	for builderID, _ in pairs(previousRoundRobinBuilders) do 
		MaybeSetWantedBuildSpeed(builderID, 0)
		previousRoundRobinBuilders[builderID] = nil
	end
	
	-- !!!!!! Important Explanation !!!!!
	-- Iterating over a hash table has a random, but fixed order
	-- If we just iterated over passive cons once, naively, then the first cons would always get the leftover resources
	-- We want to do a round-robin of leftover resources distribution, where all cons approximately evenly get resources
	-- We also want to minimize buildspeed changes, so the trivial solution of assigning fractional buildpower to all is undesired. 
	-- Thus we need to store which index of hash table we doled out the last leftovers in the previous pass.
	-- Then we need to iterate over passive cons twice
	-- This is done in two passes around the pairs(passiveConsTeam), 
		-- First Pass: we ignore the first roundRobinIndex units, and if there are still resources left over, we start a second pass
		-- Second Pass: then in second pass ignore the last roundRobinIndex units. 
		
	local roundRobinIndex = roundRobinIndexTeam[teamID] or 1 -- this stores the first unit that _should_ get res
	havePassiveResourcesLeft = (passiveEnergyLeft > 0) and (passiveMetalLeft > 0 )

	if havePassiveResourcesLeft then 
		-- on the first pass, ignore everything < roundRobinLimit
		-- on the second pass, ignore everything >= roundRobinLimit
		local roundRobinLimit = roundRobinIndex
		
		for j=1, 2 do
			local i = 0
			local firstpass = (j == 1) 
			for builderID in pairs(passiveConsTeam) do 
				i = i + 1
				if (firstpass and i >= roundRobinLimit) or ((not firstpass) and i < roundRobinLimit) then
				----- can I just look at the resources: current, pull (including share), income (including share) if current smol and pull similar to income then stall
				----- if stall take the resources of one high prio builder to know the percentage
				--if i >= roundRobinIndex then  
					if passiveExpense[builderID] and not midPrioSolarMaker[builderID] then -- this builder is actually building, and wasnt given resources for solar or maker
						local wantedBuildSpeed = 0 -- init at zero buildspeed
						if havePassiveResourcesLeft then 
							-- we still have res, so try to pull it
							local passivePullEnergy = passiveExpense[builderID + energyOffset] * intervalpersimspeed
							local passivePullMetal  = passiveExpense[builderID] * intervalpersimspeed
							roundRobinIndex = i -- So the next time we run around this exact table, we should give this con some res
							if passiveEnergyLeft < passivePullEnergy or passiveMetalLeft < passivePullMetal then 
								-- we ran out, time to save our roundrobin index, and bail
								havePassiveResourcesLeft = false 
								if VERBOSE then Spring.Echo(string.format("Ran out for %d at %i, RRI =%d, j=%d",builderID, i, roundRobinIndex, j)) end 
								break
							else
								-- Yes we still have resources
								wantedBuildSpeed = maxBuildSpeed[builderID]
								passiveEnergyLeft = passiveEnergyLeft - passivePullEnergy
								passiveMetalLeft  = passiveMetalLeft  - passivePullMetal
								previousRoundRobinBuilders[builderID] = true
								if VERBOSE then Spring.Echo(string.format("Had Some for %d at %i, RRI =%d, j=%d",builderID, i, roundRobinIndex, j)) end 
							end
						end
						MaybeSetWantedBuildSpeed(builderID, wantedBuildSpeed)
						lowPrioBuildPowerUsed = lowPrioBuildPowerUsed + wantedBuildSpeed
						lowPrioExpenseMetal = lowPrioExpenseMetal + passiveExpense[builderID]
						lowPrioExpenseEnergy = lowPrioExpenseEnergy + passiveExpense[builderID + energyOffset]
					end
				end
			end
			if (not havePassiveResourcesLeft) or (not firstpass) then 
				-- Either ran out of resources, or on our second pass
				roundRobinIndexTeam[teamID] = roundRobinIndex
				break 
			else
				-- We still have resources left over after completing the first pass, so do a second pass too 
				if firstpass then 
					roundRobinIndex = 1
				end
			end
		end
	else
	-- Special case, we are completely and totally stalled, no resources left for passive builders. 

		for builderID in pairs(passiveConsTeam) do 
			if passiveExpense[builderID] and not midPrioSolarMaker[builderID] then  
				MaybeSetWantedBuildSpeed(builderID, 0)
			end
		end	
	end
	
	-- override buildTarget builders build speeds for a single frame; let them build at a tiny rate to prevent nanoframes from possibly decaying (yes this is confirmed to happen)
	-- dont remove the resources given to a builder in a round-robin fashion just because they are build target owners
	-- and take them off the buildTargets queue!
	for buildTargetID, builderUnitID in pairs(buildTargets) do 
		-- if owner is passive, then give it a bit of BP
		-- This ensures that we at least build each unit a tiny bit.
		if currentBuildSpeed[builderUnitID] < buildPowerMinimum then 
			-- This builderUnitID has been assigned as passive with no resources, so give it a little bit
			MaybeSetWantedBuildSpeed(builderUnitID, buildPowerMinimum)
		else
			-- this builderUnitID has been assigned greater than 0 resources in the round robin pass, so remove it from the next frames clear pass
			buildTargets[buildTargetID] = nil
		end
	end 
	
	
	Spring.SetTeamRulesParam(teamID, totalBuildPowerRule, totalBuildPower)
	Spring.SetTeamRulesParam(teamID, highPrioBuildPowerRule, highPrioBuildPower)
	Spring.SetTeamRulesParam(teamID, lowPrioBuildPowerRule, lowPrioBuildPower)
	Spring.SetTeamRulesParam(teamID, highPrioBuildPowerWantedRule, highPrioBuildPowerWanted)
	Spring.SetTeamRulesParam(teamID, lowPrioBuildPowerWantedRule, lowPrioBuildPowerWanted)
	Spring.SetTeamRulesParam(teamID, highPrioBuildPowerUsedRule, highPrioBuildPowerUsed)
	Spring.SetTeamRulesParam(teamID, lowPrioBuildPowerUsedRule, lowPrioBuildPowerUsed)

	Spring.SetTeamRulesParam(teamID, highPrioNeededMetalRule, highPrioNeededMetal)
	Spring.SetTeamRulesParam(teamID, lowPrioNeededMetalRule, lowPrioNeededMetal)
	Spring.SetTeamRulesParam(teamID, highPrioNeededEnergyRule, highPrioNeededEnergy)
	Spring.SetTeamRulesParam(teamID, lowPrioNeededEnergyRule, lowPrioNeededEnergy)

	
	Spring.SetTeamRulesParam(teamID, lowPrioExpenseMetalRule, lowPrioExpenseMetal)
	Spring.SetTeamRulesParam(teamID, lowPrioExpenseEnergyRule, lowPrioExpenseEnergy)
	

	Spring.SetTeamRulesParam(teamID, totalNeedEnergyRule, totalNeedEnergy)
	Spring.SetTeamRulesParam(teamID, totalNeedMetalRule, totalNeedMetal)
	
	if VERBOSE then 
		Spring.Echo(string.format("%d Pstart = %.1f/%.0f Pleft = %.1f/%.0f RRI=%d #passive=%d Stalled=%d", 
			Spring.GetGameFrame(),
			passiveMetalStart, passiveEnergyStart,
			passiveMetalLeft, passiveEnergyLeft, 
			roundRobinIndex, 
			numPassiveCons,
			havePassiveResourcesLeft and 0 or 1
			)
		)
	end
end

local function GetUpdateInterval(teamID)
	local maxInterval = 1
	for _,resName in pairs(resTable) do
		local _, stor, _, inc = spGetTeamResources(teamID, resName)
		local resMaxInterval
		if inc > 0 then
			resMaxInterval = floor(stor*simSpeed/inc)+1 -- how many frames would it take to fill our current storage based on current income?
		else
			resMaxInterval = 6
		end
		if resMaxInterval > maxInterval then
			maxInterval = resMaxInterval
		end
	end
	if maxInterval > 6 then maxInterval = 6 end
	Spring.SetTeamRulesParam(teamID, "builderUpdateInterval", maxInterval)
	return maxInterval
end

function gadget:TeamDied(teamID)
	deadTeamList[teamID] = true
end

function gadget:TeamChanged(teamID)
	updateTeamList()
end

function gadget:GameFrame(n)
	currentFrame = n
	-- During the previous UpdatePassiveBuilders, we set build target owners to buildPowerMinimum so that the nanoframes dont die
	-- Now we can set their buildpower to what we wanted instead of buildPowerMinimum we had for 1 frame.
	for builtUnit, builderID in pairs(buildTargets) do
		if spValidUnitID(builderID) and spGetUnitIsBuilding(builderID) == builtUnit then
			MaybeSetWantedBuildSpeed(builderID, 0)

		end
	end
	
	buildTargets = (next(buildTargets) and {}) or buildTargets -- check if table is empty and if not reallocate it!
	
	for i=1, #teamList do
		local teamID = teamList[i]
		if not deadTeamList[teamID] then -- isnt dead
			if n == updateFrame[teamID] then
				local interval = GetUpdateInterval(teamID)
				UpdatePassiveBuilders(teamID, interval)
				updateFrame[teamID] = n + interval
			elseif not updateFrame[teamID] or updateFrame[teamID] < n then
				updateFrame[teamID] = n + GetUpdateInterval(teamID)
			end
		end
	end
	if FORWARDUNIFORMS then 
		BuildSpeedsChanged()
	end
end

end
