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

if not gadgetHandler:IsSyncedCode() then
	if DEBUG then 
		function gadget:DrawWorld()
			for i, unitID in pairs(Spring.GetAllUnits()) do 
				local mybuildspeed = Spring.GetUnitRulesParam(unitID, "mybuildspeed")
				if mybuildspeed then 
					--Spring.Echo("unitID", unitID," has buildspeed", mybuildspeed)
					local x,y,z = Spring.GetUnitPosition(unitID)
					gl.PushMatrix()
					gl.Translate(x,y+64, z)
					gl.Text(tostring(mybuildspeed),0,0,16,'n')
					gl.PopMatrix()
				end
			end
			
		end
	end
else

local CMD_PRIORITY = 34571

local stallMarginInc = 0.2 -- 
local stallMarginSto = 0.01

local passiveCons = {} -- passiveCons[teamID][builderID] = true for passive cons
local roundRobinIndexTeam = {} -- {teamID = roundRobinIndex}

local buildTargets = {} --{builtUnitID = builderUnitID} the unitIDs of build targets of passive builders, a -1 here indicates that this build target has Active builders too.

local canBuild = {} --builders[teamID][builderID], contains all builders
local maxBuildSpeed = {} -- {builderUnitID = buildSpeed} build speed of builderID, as in UnitDefs (contains all builders)
local currentBuildSpeed = {} -- {builderid = currentBuildSpeed} build speed of builderID for current interval, not accounting for buildOwners special speed (contains only passive builders)

-- NOTE: Explanation: Instead of using an individual table to store {unitID = {metal, energy, buildtime}}
-- We are using using a single table, where {unitID = metal, (unitID + energyOffset) = energy, (unitID+buildTimeOffset) = buildtime}
local costIDOverride = {}
local energyOffset = Game.maxUnits + 1
local buildTimeOffset = (Game.maxUnits + 1) * 2 
local ruleName = "builderPriority"

local resTable = {"metal","energy"} -- 1 = metal, 2 = energy

local cmdPassiveDesc = {
	  id	  = CMD_PRIORITY,
	  name	= 'priority',
	  action  = 'priority',
	  type	= CMDTYPE.ICON_MODE,
	  tooltip = 'Builder Mode: Low Priority restricts build when stalling on resources',
	  params  = {1, 'Low Prio', 'High Prio'}
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
	cost[unitDefID				  ] = unitDef.metalCost
	cost[unitDefID +	energyOffset] = unitDef.energyCost
	cost[unitDefID + buildTimeOffset] = unitDef.buildTime
	
end

local function updateTeamList()
	teamList = spGetTeamList()
end

function gadget:Initialize()
	for _,unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
	updateTeamList()
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	if canPassive[unitDefID] or unitBuildSpeed[unitDefID] then
		canBuild[teamID] = canBuild[teamID] or {}
		canBuild[teamID][unitID] = true
		maxBuildSpeed[unitID] = unitBuildSpeed[unitDefID] or 0
	end
	if canPassive[unitDefID] then
		spInsertUnitCmdDesc(unitID, cmdPassiveDesc)
		if not passiveCons[teamID] then passiveCons[teamID] = {} end
		passiveCons[teamID][unitID] = spGetUnitRulesParam(unitID,ruleName) ~= 1 or nil
		currentBuildSpeed[unitID] = maxBuildSpeed[unitID]
		spSetUnitBuildSpeed(unitID, currentBuildSpeed[unitID]) -- to handle luarules reloads correctly
		if DEBUG then Spring.SetUnitRulesParam(unitID, "mybuildspeed", currentBuildSpeed[unitID], LOS_ACCESS)  end
	end

	costIDOverride[unitID +			   0] = cost[unitDefID]
	costIDOverride[unitID +	energyOffset] = cost[unitDefID + energyOffset]
	costIDOverride[unitID + buildTimeOffset] = cost[unitDefID + buildTimeOffset]
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	if passiveCons[oldTeamID] and passiveCons[oldTeamID][unitID] then
		passiveCons[newTeamID] = passiveCons[newTeamID] or {}
		passiveCons[newTeamID][unitID] = passiveCons[oldTeamID][unitID]
		passiveCons[oldTeamID][unitID] = nil
	end

	if canBuild[oldTeamID] and canBuild[oldTeamID][unitID] then
		canBuild[newTeamID] = canBuild[newTeamID] or {}
		canBuild[newTeamID][unitID] = true
		canBuild[oldTeamID][unitID] = nil
	end
end

function gadget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
	gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	canBuild[teamID] = canBuild[teamID] or {}
	canBuild[teamID][unitID] = nil

	if not passiveCons[teamID] then passiveCons[teamID] = {} end
	passiveCons[teamID][unitID] = nil
	maxBuildSpeed[unitID] = nil
	currentBuildSpeed[unitID] = nil

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
			cmdDesc.params[1] = cmdParams[1]
			spEditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
			spSetUnitRulesParam(unitID,ruleName,cmdParams[1])
			if not passiveCons[teamID] then passiveCons[teamID] = {} end
			if cmdParams[1] == 0 then --
				passiveCons[teamID][unitID] = true
			elseif maxBuildSpeed[unitID] then
				spSetUnitBuildSpeed(unitID, maxBuildSpeed[unitID])
				if DEBUG then spSetUnitRulesParam(unitID, "mybuildspeed",  maxBuildSpeed[unitID], LOS_ACCESS) end
				currentBuildSpeed[unitID] = maxBuildSpeed[unitID]
				passiveCons[teamID][unitID] = nil
			end
		end
		return false -- Allowing command causes command queue to be lost if command is unshifted
	end
	return true
end


local function UpdatePassiveBuilders(teamID, interval)

	-- calculate how much expense each passive con would require, and how much total expense the non-passive cons require
	local nonPassiveConsTotalExpenseEnergy = 0
	local nonPassiveConsTotalExpenseMetal = 0

	local passiveConsTotalExpenseEnergy = 0
	local passiveConsTotalExpenseMetal = 0

	passiveCons[teamID] = passiveCons[teamID] or {} -- alloc a table if not already

	local passiveConsTeam = passiveCons[teamID]
	if tracy then tracy.ZoneBeginN("UpdateStart") end 
	local numPassiveCons = 0

	local passiveExpense = {} -- once again, similar to the costIDOverride we are using a single table with offsets to store two values per unitID
	-- this is about 800 us
	if canBuild[teamID] then
		local canBuildTeam = canBuild[teamID]
		for builderID in pairs(canBuildTeam) do
			local builtUnit = spGetUnitIsBuilding(builderID)
			local expenseMetal = builtUnit and costIDOverride[builtUnit] or nil
			local maxbuildspeed = maxBuildSpeed[builderID]
			if builtUnit and expenseMetal and maxbuildspeed then	-- added check for maxBuildSpeed[builderID] else line below could error (unsure why), probably units that were newly created?

				local expenseEnergy = costIDOverride[builtUnit + energyOffset]
				local rate = maxbuildspeed / costIDOverride[builtUnit + buildTimeOffset]

				-- TODO: redo solar and basic MM no-stall logic
				
				if expenseMetal <= 1 then 
					expenseMetal = 0   -- metal maker costs 1 metal, don't stall because of that
				else
					expenseMetal = expenseMetal * rate
				end

				if expenseEnergy <= 1 then 
					expenseEnergy = 0   -- solar costs 0 energy, don't stall because of that
				else
					expenseEnergy = expenseEnergy * rate
				end

				if passiveConsTeam[builderID] then 
					passiveExpense[builderID] = expenseMetal
					passiveExpense[builderID+ energyOffset] = expenseEnergy
					buildTargets[builtUnit] = builderID 
					numPassiveCons = numPassiveCons + 1
					passiveConsTotalExpenseEnergy = passiveConsTotalExpenseEnergy + expenseEnergy
					passiveConsTotalExpenseMetal  = passiveConsTotalExpenseMetal  + expenseMetal
				else
					nonPassiveConsTotalExpenseEnergy = nonPassiveConsTotalExpenseEnergy + expenseEnergy
					nonPassiveConsTotalExpenseMetal  = nonPassiveConsTotalExpenseMetal  + expenseMetal
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
		local reservedExpense = (resName == 'energy' and nonPassiveConsTotalExpenseEnergy or nonPassiveConsTotalExpenseMetal) -- we don't want to touch this part of expense
		if resName == 'energy' then
			passiveEnergyLeft = currentLevel - max(income * stallMarginInc, storage * stallMarginSto) - 1 + (income - reservedExpense + received - sent) * intervalpersimspeed --amount of res available to assign to passive builders (in next interval); leave a tiny bit left over to avoid engines own "stall mode"
		else
			passiveMetalLeft =  currentLevel - max(income * stallMarginInc, storage * stallMarginSto) - 1 + (income - reservedExpense + received - sent) * intervalpersimspeed --amount of res available to assign to passive builders (in next interval); leave a tiny bit left over to avoid engines own "stall mode"
		end
	end
	
	
	-- How do we identify those units which we havent touched above yet?
	local passiveMetalStart = passiveMetalLeft
	local passiveEnergyStart = passiveEnergyLeft
	
	-- Round robining who gets a bit of the leftover resources:
	-- This is done in two passes around the pairs(passiveConsTeam), and initially, we ignore the first roundRobinIndex units, then in second pass ignore the last roundRobinIndex units. 
	local roundRobinIndex = roundRobinIndexTeam[teamID] or 1 -- this stores the first unit that _should_ get res
	local havePassiveResourcesLeft = (passiveEnergyLeft > 0) and (passiveMetalLeft > 0 )

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
				--if i >= roundRobinIndex then  
					if passiveExpense[builderID] then -- this builder is actually building
						local wantedBuildSpeed = 0 -- init at zero buildspeed
						if havePassiveResourcesLeft then 
							-- we still have res, so try to pull it
							local passivePullEnergy = passiveExpense[builderID + energyOffset] * intervalpersimspeed
							local passivePullMetal  = passiveExpense[builderID] * intervalpersimspeed
							roundRobinIndex = i -- So the next time we run around this exact table, we should give this con some res
							if passiveEnergyLeft < passivePullEnergy or passiveMetalLeft < passivePullMetal then 
								-- we ran out, time to save our roundrobin index, and bail
								havePassiveResourcesLeft = false 
								if VERBOSE then Spring.Echo(string.format("Ran out for %d at %i, RRI =%d, j=%d",builderID, i, roundRobinIndex,j)) end 
							else
								-- Yes we still have resources
								wantedBuildSpeed = maxBuildSpeed[builderID]
								passiveEnergyLeft = passiveEnergyLeft - passivePullEnergy
								passiveMetalLeft  = passiveMetalLeft  - passivePullMetal
								if VERBOSE then Spring.Echo(string.format("Had Some for %d at %i, RRI =%d, j=%d",builderID, i, roundRobinIndex,j)) end 
							end
						end
						
						if currentBuildSpeed[builderID] ~= wantedBuildSpeed then
							spSetUnitBuildSpeed(builderID, wantedBuildSpeed)
							currentBuildSpeed[builderID] = wantedBuildSpeed
							if DEBUG then spSetUnitRulesParam(builderID, "mybuildspeed", wantedBuildSpeed, LOS_ACCESS) end
						end
					end
				end
			end
			if not havePassiveResourcesLeft or j == 2 then 
				-- Either ran out of resources, or on our second pass
				roundRobinIndexTeam[teamID] = roundRobinIndex
				break 
			else
				-- We are gonna do a second pass then. 
				if j == 1 then 
					roundRobinIndex = 1
				end
			end
		end
	else
	-- Special case, we are completely and totally stalled, no resources left for passive builders. 
		for builderID in pairs(passiveConsTeam) do 
			if passiveExpense[builderID] then 
				if currentBuildSpeed[builderID] ~= 0 then
					spSetUnitBuildSpeed(builderID, 0)
					currentBuildSpeed[builderID] = 0
					if DEBUG then spSetUnitRulesParam(builderID, "mybuildspeed", 0, LOS_ACCESS) end
				end
			end
		end	
	end
	
	
	-- dont remove the resources given to a builder in a round-robin fashion just because they are build target owners
	-- take them off the buildTargets stack!
	
		-- override buildTargetOwners build speeds for a single frame; let them build at a tiny rate to prevent nanoframes from possibly decaying
	for buildTargetID, builderUnitID in pairs(buildTargets) do 
		-- if owner is passive, then give it a bit of BP
		-- TODO: this needs to be smarter
		-- This ensures that we at least build each unit a tiny bit.
		if currentBuildSpeed[builderUnitID] <= 0.001 then 
			-- This builderUnitID has been assigned as passive with no resources
			spSetUnitBuildSpeed(builderUnitID, max(currentBuildSpeed[builderUnitID], 0.001)) -- 
			if DEBUG then spSetUnitRulesParam(builderUnitID, "mybuildspeed", max(currentBuildSpeed[builderUnitID], 0.001), LOS_ACCESS) end
		else
			-- this builderUnitID has been assigned greater than 0 resources in the round robin pass, so remove it from the next frames clear pass
			buildTargets[buildTargetID] = nil
		end
	end 
	
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

	--- ----------------------------------------- OLD METHOD -------------------------------------------------
		
	-- work through passive cons allocating as much expense as we have left
	--[[
	for builderID in pairs(passiveConsTeam) do
		-- find out if we have used up all the expense available to passive builders yet
		local wouldStall = false

		if passiveExpense[builderID] then
		
			local passivePullEnergy = passiveExpense[builderID + energyOffset] * intervalpersimspeed
			if passiveEnergyLeft <= passivePullEnergy then
				wouldStall = true
			else
				passiveEnergyLeft = passiveEnergyLeft - passivePullEnergy
			end

			local passivePullMetal = passiveExpense[builderID] * intervalpersimspeed
			if passiveMetalLeft <= passivePullMetal then
				wouldStall = true
			else
				passiveMetalLeft = passiveMetalLeft - passivePullMetal
			end
		end

		-- TODO: we need better rotation among passive builders anyway, as their resuorce assigment is order dependent and thus unevely shitty.
		-- turn this passive builder on/off as appropriate
		local wantedBuildSpeed = (wouldStall or not passiveExpense[builderID]) and 0 or maxBuildSpeed[builderID]
		
		if currentBuildSpeed[builderID] ~= wantedBuildSpeed then
			spSetUnitBuildSpeed(builderID, wantedBuildSpeed)
			currentBuildSpeed[builderID] = wantedBuildSpeed
			if DEBUG then spSetUnitRulesParam(builderID, "mybuildspeed", wantedBuildSpeed, LOS_ACCESS) end
		end
	end

	-- override buildTargetOwners build speeds for a single frame; let them build at a tiny rate to prevent nanoframes from possibly decaying
	for buildTargetID, builderUnitID in pairs(buildTargets) do 
		-- if owner is passive, then give it a bit of BP
		-- TODO: this needs to be smarter
		-- This ensures that we at least build each unit a tiny bit.
		spSetUnitBuildSpeed(builderUnitID, max(currentBuildSpeed[builderUnitID], 0.001)) -- 
		if DEBUG then spSetUnitRulesParam(builderUnitID, "mybuildspeed", max(currentBuildSpeed[builderUnitID], 0.001), LOS_ACCESS) end
	end ]]--
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
	--Spring.Echo("interval: "..maxInterval)
	return maxInterval
end

function gadget:TeamDied(teamID)
	deadTeamList[teamID] = true
end

function gadget:TeamChanged(teamID)
	updateTeamList()
end

function gadget:GameFrame(n)
	
	-- Thus on the next frame, we can loop through build target owners and
	-- set their buildpower to what we wanted instead of 0.001 we had for 1 frame.
	if tracy then tracy.ZoneBeginN("redundant set") end
	for  builtUnit, builderID in pairs(buildTargets) do
		if spValidUnitID(builderID) and spGetUnitIsBuilding(builderID) == builtUnit then
			spSetUnitBuildSpeed(builderID, currentBuildSpeed[builderID])
			if DEBUG then spSetUnitRulesParam(builderID, "mybuildspeed", currentBuildSpeed[builderID], LOS_ACCESS) end
		end
	end
	
	
	--buildTargetOwners = {}
	buildTargets = (next(buildTargets) and {}) or buildTargets -- check if table is empty and if not reallocate it!
	
	if tracy then tracy.ZoneEnd() end
	for i=1, #teamList do
		local teamID = teamList[i]
		if teamID == 0 and not deadTeamList[teamID] then -- isnt dead
			if n == updateFrame[teamID] then
				local interval = GetUpdateInterval(teamID)
				UpdatePassiveBuilders(teamID, interval)
				updateFrame[teamID] = n + interval
			elseif not updateFrame[teamID] or updateFrame[teamID] < n then
				updateFrame[teamID] = n + GetUpdateInterval(teamID)
			end
		end
	end
end

end