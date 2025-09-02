
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Seismic Dots and Advanced Radar",
		desc      = "When in Seismic LOS, reveal a wobbling radar dot. And allow for custom wobble if in LOS of an advanced radar",
		author    = "Kyle Anthony Shepherd (Itanthias)",
		date      = "Aug 7, 2025",
		license   = "GNU GPL, v2 or later, and anyone who uses this gadget has to email me a rabbit with a sword at kyleanthonyshepherd@gmail.com",
		layer     = -1, -- to run after most gadgets have handled their stuff
		enabled   = Spring.GetModOptions().sensor_rework
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- Golden Ratio/Angle magic to create "random" wobble without runs of no wobble
local goldenAngle = (2-(1 + math.sqrt(5))/2)*math.pi*2
local goldenSteps = {1,4,7,9,12,14}
local mRandom = math.random
local mSqrt = math.sqrt

local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spTraceRayGroundBetweenPositions = Spring.TraceRayGroundBetweenPositions
local spIsUnitInRadar = Spring.IsUnitInRadar
local spSetUnitLosState = Spring.SetUnitLosState
local spSetUnitLosMask = Spring.SetUnitLosMask
local spGetGameFrame = Spring.GetGameFrame
local spSetUnitPosErrorParams = Spring.SetUnitPosErrorParams
local spGetUnitIsStunned = Spring.GetUnitIsStunned

local allyteamlist = Spring.GetAllyTeamList()

local restoreUnitLOS = {} -- list of units to hand off los control back to engine after X frames

local advancedRadars = {} -- table to hold all advanced radars currently in the game, partitioned by allyTeam
for key, values in pairs(allyteamlist) do
	advancedRadars[values] = {} 
end

local inBasicRadar = {} -- table to hold units currently in basic radar, partitioned by allyTeam
local basicRadarUpdateRate = 90
for key, values in pairs(allyteamlist) do
	inBasicRadar[values] = {}
	for i=0,basicRadarUpdateRate-1 do
		inBasicRadar[values][i] = {} -- segment the table into #basicRadarUpdateRate slices
		-- improves performace by only iterating over a fraction of the units in radar each frame
	end
end

local inAdvancedRadar = {} -- table to hold units currently in advanced radar, partitioned by allyTeam
local advancedRadarUpdateRate = 180
for key, values in pairs(allyteamlist) do
	inAdvancedRadar[values] = {}
	for i=0,advancedRadarUpdateRate-1 do
		inAdvancedRadar[values][i] = {} -- segment the table into #advancedRadarUpdateRate slices
		-- improves performace by only iterating over a fraction of the units in radar each frame
	end
end

local unitInBasicRadar = {} -- table to lookup if allyTeam is seeing unitID in basic radar
for key, values in pairs(allyteamlist) do 
	unitInBasicRadar[values] = {} 
end

local unitInAdvancedRadar = {} -- table to lookup if allyTeam is seeing unitID in advanced radar
for key, values in pairs(allyteamlist) do 
	unitInAdvancedRadar[values] = {} 
end

local unitSpeeds = {}
local unitWobble = {}

local function customWobble(unitID,rate,radius)

	if radius == 0 then
		spSetUnitPosErrorParams(unitID,0,0,0,0,0,0,rate/15)
	end

	if unitWobble[unitID] == nil then
		unitWobble[unitID] = {}
		-- Create initial wobble location
		local posErrorVectorx = mRandom()*2 - 1
		local posErrorVectorz = mRandom()*2 - 1
		local mag = mSqrt(posErrorVectorx^2 + posErrorVectorz^2)
		unitWobble[unitID].posErrorVectorx = posErrorVectorx*radius/mag
		unitWobble[unitID].posErrorVectorz = posErrorVectorz*radius/mag
		unitWobble[unitID].wobbletime = spGetGameFrame()
	end

	if unitWobble[unitID].wobbletime <= spGetGameFrame()+1 then

		if rate == 0 then
			rate = math.random(4,15)*15 -- set speed of wobble drift
		end

		unitWobble[unitID].wobbletime = spGetGameFrame() + rate

		local basePointX, basePointY, basePointZ = spGetUnitPosition(unitID)

		local goldenStep = goldenSteps[math.random(6)] -- picks one of 6 pre-selected "irrational" rotation steps

		-- rotates the wobble/error vector
		local newposErrorVectorx = unitWobble[unitID].posErrorVectorx * math.cos(goldenStep*goldenAngle) - unitWobble[unitID].posErrorVectorz * math.sin(goldenStep*goldenAngle)
		local newposErrorVectorz = unitWobble[unitID].posErrorVectorx * math.sin(goldenStep*goldenAngle) + unitWobble[unitID].posErrorVectorz * math.cos(goldenStep*goldenAngle)

		-- set up drift vector
		local posErrorDeltax = (newposErrorVectorx - unitWobble[unitID].posErrorVectorx)/rate
		local posErrorDeltaz = (newposErrorVectorz - unitWobble[unitID].posErrorVectorz)/rate

		spSetUnitPosErrorParams(unitID,unitWobble[unitID].posErrorVectorx,0,unitWobble[unitID].posErrorVectorz,posErrorDeltax,0,posErrorDeltaz,1+rate/15)
		-- last parameter is in *number of slowupdates*

		unitWobble[unitID].posErrorVectorx = newposErrorVectorx
		unitWobble[unitID].posErrorVectorz = newposErrorVectorz

	end
end

function gadget:UnitSeismicPing(x,y,z,strength,allyteam,unitID,unitDefID)

	if (allyteam ~= spGetUnitAllyTeam(unitID)) and (spIsUnitInRadar(unitID,allyteam) == false) then
		-- only run if the unit is being seen by a different allyTeam, and is not in radar.

		if (restoreUnitLOS[unitID]==nil) then -- no need to repeatedly set UnitLosState and UnitLosMask on every ping
			spSetUnitLosState(unitID,allyteam,2) -- makes unit unconditionally show up as a radar dot
			spSetUnitLosMask(unitID,allyteam,2) -- stops engine from overwriting SetUnitLosState
			restoreUnitLOS[unitID] = {}
		end
		restoreUnitLOS[unitID][allyteam] = spGetGameFrame() + 60
		customWobble(unitID,0,1)
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	-- save unit speed on a quick reference local table, when unit is created
	unitSpeeds[unitID] = UnitDefs[unitDefID].speed

end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	-- if the unit is an advanced radar, save it to the local table
	if UnitDefs[unitDefID].customParams then
		if UnitDefs[unitDefID].customParams.advancedradar ~= nil then
			advancedRadars[spGetUnitAllyTeam(unitID)][unitID] = {}
			advancedRadars[spGetUnitAllyTeam(unitID)][unitID].radarEmitHeight = UnitDefs[unitDefID].radarEmitHeight
			advancedRadars[spGetUnitAllyTeam(unitID)][unitID].radarRadius = math.max(UnitDefs[unitDefID].radarRadius,UnitDefs[unitDefID].sonarRadius)
			advancedRadars[spGetUnitAllyTeam(unitID)][unitID].wobblereduction = tonumber(UnitDefs[unitDefID].customParams.advancedradar)
		end
	end

end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	-- remove dead advanced radars from the local table
	advancedRadars[spGetUnitAllyTeam(unitID)][unitID] = nil

	-- remove dead units from the InRadar lists
	for key, values in pairs(allyteamlist) do
		unitInAdvancedRadar[values][unitID] = nil
		unitInBasicRadar[values][unitID] = nil
	end

	unitSpeeds[unitID] = nil
	unitWobble[unitID] = nil
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)

	-- deal with any shared or captured T2 radars
	if UnitDefs[unitDefID].customParams then
		if UnitDefs[unitDefID].customParams.advancedradar ~= nil then
			advancedRadars[oldTeam][unitID]  = nil
			advancedRadars[newTeam][unitID] = {}
			advancedRadars[newTeam][unitID].radarEmitHeight = UnitDefs[unitDefID].radarEmitHeight
			advancedRadars[newTeam][unitID].radarRadius = math.max(UnitDefs[unitDefID].radarRadius,UnitDefs[unitDefID].sonarRadius)
			advancedRadars[newTeam][unitID].wobblereduction = tonumber(UnitDefs[unitDefID].customParams.advancedradar)
		end
	end

end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	-- TODO: be smarter about which units need their seismic signature removed. Tanks in shallow puddles should probably still have a signature
	Spring.SetUnitSeismicSignature(unitID,0)
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	Spring.SetUnitSeismicSignature(unitID,UnitDefs[unitDefID].seismicSignature)
end

local function advancedRadarCheck(unitID,allyTeam)
	-- this function determines if a specific unit can be seen by the advanced radars of the allyTeam
	local basePointX, basePointY, basePointZ -- not 100% sure if it is more performant to keep setting a local every time this function is called, or set the local outside this function. 
	local unitPointX, unitPointY, unitPointZ
	local advancedRadarFreeLineOfFire = false
	local wobblereduction = 0

	for advancedRadar, tableValues in pairs(advancedRadars[allyTeam]) do -- loop over every aradar on the allyTeam
		if spGetUnitIsStunned(advancedRadar) == false then
			advancedRadarFreeLineOfFire = false
			local radarEmitHeight = tableValues.radarEmitHeight
			local radarRadius = tableValues.radarRadius

			-- check if the unit is within cylinder distance of the radar
			local basePointX, basePointY, basePointZ = spGetUnitPosition(advancedRadar)
			local unitPointX, unitPointY, unitPointZ = spGetUnitPosition(unitID) -- use basepoint as radar "paints" the ground
			local dist2D = (basePointX-unitPointX)^2 + (basePointZ-unitPointZ)^2
			local dist3D = (basePointX-unitPointX)^2 + (basePointY+radarEmitHeight-unitPointY-1)^2 + (basePointZ-unitPointZ)^2

			-- check if the radar can see the unit without being obstructed by terrain
			local raylength,_,_,_ = spTraceRayGroundBetweenPositions(basePointX, basePointY+radarEmitHeight, basePointZ, unitPointX, unitPointY + 1, unitPointZ, false)
			if raylength == nil then -- returns nil if no ground collision detected
				advancedRadarFreeLineOfFire = ((radarRadius+unitSpeeds[unitID])^2 >= dist2D)
			end
			-- +1 on unitPointX to prevent false ground collision positives at the terminal point.
			-- +unitspeed on radarRadius to help catch units just walking into radar range, it seems unitspeed is accounted for when determining when to trigger UnitEnteredRadar

			if advancedRadarFreeLineOfFire == true then 
				wobblereduction = math.max(wobblereduction,tableValues.wobblereduction) -- use best wobblereduction of all advanced radars in range
			end
		end
	end

	if wobblereduction>0 then

		if restoreUnitLOS[unitID] == nil then -- don't call customWobble if recently seismic pinged, customWobble will be called after unit LOS control is restored to engine
			customWobble(unitID,advancedRadarUpdateRate,1-wobblereduction)
		end

		local framecycle = spGetGameFrame()%advancedRadarUpdateRate

		inAdvancedRadar[allyTeam][framecycle][unitID] = true -- check this unit on next framecycle if it is still seen by an advanced radar
		unitInAdvancedRadar[allyTeam][unitID] = framecycle -- lookup table for when a unit is scheduled to check for advanced radars again. Checked later to prevent a unit from being double scheduled
		unitInBasicRadar[allyTeam][unitID] = nil -- effectively remove unit from the faster updating InBasicRadar list.

	else
		local framecycle = spGetGameFrame()%basicRadarUpdateRate
		inBasicRadar[allyTeam][framecycle][unitID] = true -- check this unit on next framecycle if it is still seen by an advanced radar
		unitInBasicRadar[allyTeam][unitID] = framecycle -- lookup table for when a unit is scheduled to check for advanced radars again. Checked later to prevent a unit from being double scheduled
		unitInAdvancedRadar[allyTeam][unitID] = nil -- effectively remove unit from the slower updating InAdvancedRadar list.
	end
end

function gadget:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)

	advancedRadarCheck(unitID,allyTeam) -- figure out if the unit entered a T1 or T2 radar range

end

function gadget:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)
	-- effectively remove unit from the InRadar lists
	unitInAdvancedRadar[allyTeam][unitID] = nil
	unitInBasicRadar[allyTeam][unitID] = nil

end

function gadget:GameFrame(nn)

	local advancedRadarUpdateFrame = (nn+1)%advancedRadarUpdateRate
	local basicRadarUpdateFrame = (nn+1)%basicRadarUpdateRate

	for key, allyTeam in pairs(allyteamlist) do

		--check units in inAdvancedRadar scheduled to be re-checked on this frame
		for unitID, value in pairs(inAdvancedRadar[allyTeam][advancedRadarUpdateFrame]) do
			inAdvancedRadar[allyTeam][advancedRadarUpdateFrame][unitID] = nil
			if unitInAdvancedRadar[allyTeam][unitID] == advancedRadarUpdateFrame then -- if unit is actually scheduled to check for advanced radars again, and not a stale schedule, do the check.
				advancedRadarCheck(unitID,allyTeam)
			end
		end

		--check units in inBasicRadar scheduled to be re-checked on this frame
		for unitID, value in pairs(inBasicRadar[allyTeam][basicRadarUpdateFrame]) do
			inBasicRadar[allyTeam][basicRadarUpdateFrame][unitID] = nil
			if unitInBasicRadar[allyTeam][unitID] == basicRadarUpdateFrame then -- if unit is actually scheduled to check for advanced radars again, and not a stale schedule, do the check.
				advancedRadarCheck(unitID,allyTeam)
			end
		end
	end

	for unitID, allyteams in pairs(restoreUnitLOS) do -- check units that seismic pinged, to determine if enough time has passed to hand off radar control back to engine
		for allyteam, restoretime in pairs(allyteams) do
			if restoretime <= nn then
				spSetUnitLosMask(unitID,allyteam,0) -- returns unit los states to engine control
				restoreUnitLOS[unitID] = nil
				advancedRadarCheck(unitID,allyteam) -- check for advanced radars
			end
		end
	end
end

