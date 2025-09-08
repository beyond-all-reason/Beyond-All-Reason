
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

-- Golden Ratio/Angle magic
-- This is my overengineered solution to prevent statistical "runs"
-- of identical wobble locations that occur with standard use of RNG.
-- We choose the next location of the wobble based on the Golden Angle, the "most irrational" number
-- To remove any clockwise rotation bias, on each wobble advance a random number of Golden Angle "steps", from a small set of possible "steps", the set selected to:
-- A. Average to approximately 180 degree rotation per wobble
-- B. Rotate more than 90 degrees per step
-- https://github.com/beyond-all-reason/Beyond-All-Reason/pull/5693#discussion_r2296246178
local goldenAngle = (2-(1 + math.sqrt(5))/2)*math.pi*2
local goldenSteps = {1,4,7,9,12,14} 

-- hyperparameter for wobble drift time for seismic dots, in slowUpdates (15 frame increments)
-- 4 seems like reasonable minimum (2 second drift time), any faster looks weird to me.
-- 15 is the drift time of standard radar wobble. Seismic is desired to wobble as fast or faster than radar, so this is a reasonable max drift time.  
local minRandDriftTime = 4
local maxRandDriftTime = 15

-- How long a seismic dot should last after last seismic ping, in frames
-- (after target leaves seismic range or stops moving)
local seismicDotTime = 2 * Game.gameSpeed

local mRandom = math.random
local mSqrt = math.sqrt
local mCos = math.cos
local mSin = math.sin
local mMax = math.max

local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spTraceRayGroundBetweenPositions = Spring.TraceRayGroundBetweenPositions
local spIsUnitInRadar = Spring.IsUnitInRadar
local spSetUnitLosState = Spring.SetUnitLosState
local spSetUnitLosMask = Spring.SetUnitLosMask
local spGetGameFrame = Spring.GetGameFrame
local spSetUnitPosErrorParams = Spring.SetUnitPosErrorParams
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spSetUnitSeismicSignature = Spring.SetUnitSeismicSignature

local allyteamlist = Spring.GetAllyTeamList()

local restoreUnitLOS = {} -- list of units to hand off los control back to engine after X frames

local advancedRadars = {} -- table to hold all advanced radars currently in the game, partitioned by allyTeam
for key, values in pairs(allyteamlist) do
	advancedRadars[values] = {} 
end

local inBasicRadar = {} -- table to hold units currently in basic radar, partitioned by allyTeam
local basicRadarUpdateRate = 3 * Game.gameSpeed
for key, values in pairs(allyteamlist) do
	inBasicRadar[values] = {}
	for i=0,basicRadarUpdateRate-1 do
		inBasicRadar[values][i] = {} -- segment the table into #basicRadarUpdateRate slices
		-- improves performace by only iterating over a fraction of the units in radar each frame
	end
end

local inAdvancedRadar = {} -- table to hold units currently in advanced radar, partitioned by allyTeam
local advancedRadarUpdateRate = 6 * Game.gameSpeed
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

--cache UnitDefs at start
local unitDefSpeeds = {}
local unitDefSeismicSignature = {}
local unitDefRadarEmitHeight = {}
local unitDefRadarRadius = {}
local unitDefWobbleReduction = {}
local unitDefIsHover = {}
for unitDefID, unitDef in pairs(UnitDefs) do

	unitDefSpeeds[unitDefID] = UnitDefs[unitDefID].speed
	unitDefSeismicSignature[unitDefID] = UnitDefs[unitDefID].seismicSignature

	if UnitDefs[unitDefID].customParams then
		if UnitDefs[unitDefID].customParams.advancedradarwobblereduction ~= nil then
			unitDefRadarEmitHeight[unitDefID] = UnitDefs[unitDefID].radarEmitHeight
			unitDefRadarRadius[unitDefID] = mMax(UnitDefs[unitDefID].radarRadius,UnitDefs[unitDefID].sonarRadius)
			unitDefWobbleReduction[unitDefID] = UnitDefs[unitDefID].customParams.advancedradarwobblereduction
		end
	end

	if unitDef.moveDef.smClass == Game.speedModClasses.Hover then --units must have "hover" in their movedef name in order to be treated as hovercraft
		unitDefIsHover[unitDefID] = true
	end

end

local function customWobble(unitID,driftTime,wobbleRadiusFraction)

	if wobbleRadiusFraction == 0 then
		spSetUnitPosErrorParams(unitID,0,0,0,0,0,0,1+driftTime/15)
		-- Please note, final parameter of SetUnitPosErrorParams is in number of slowUpdates, 15 frame intervals.
		-- and 1+ because engine checks as `if ((--nextPosErrorUpdate) > 0)`
		return 0
	end

	if unitWobble[unitID] == nil then
		unitWobble[unitID] = {}
	end

	if unitWobble[unitID].wobbleRadiusFraction ~= wobbleRadiusFraction then
		-- Create initial wobble location
		local posErrorVectorx = mRandom()*2 - 1
		local posErrorVectorz = mRandom()*2 - 1
		local mag = mSqrt(posErrorVectorx^2 + posErrorVectorz^2)
		unitWobble[unitID].posErrorVectorx = posErrorVectorx*wobbleRadiusFraction/mag
		unitWobble[unitID].posErrorVectorz = posErrorVectorz*wobbleRadiusFraction/mag
		-- Please note, posErrorVector is in fraction of current team radar error radius (96 by engine and BAR default)
		unitWobble[unitID].wobbletime = spGetGameFrame()
		unitWobble[unitID].wobbleRadiusFraction = wobbleRadiusFraction
	end

	if unitWobble[unitID].wobbletime <= spGetGameFrame() then

		if driftTime == 0 then -- avoid divide by zero errors by setting a random drift time
			driftTime = mRandom(minRandDriftTime,maxRandDriftTime)*15 -- randomly set time of wobble drift, in frames
		end

		unitWobble[unitID].wobbletime = spGetGameFrame() + driftTime

		local basePointX, basePointY, basePointZ = spGetUnitPosition(unitID)

		local goldenStep = goldenSteps[mRandom(#goldenSteps)]

		-- rotates the wobble/error vector
		local rotAngle = goldenStep*goldenAngle
		local newposErrorVectorx = unitWobble[unitID].posErrorVectorx * mCos(rotAngle) - unitWobble[unitID].posErrorVectorz * mSin(rotAngle)
		local newposErrorVectorz = unitWobble[unitID].posErrorVectorx * mSin(rotAngle) + unitWobble[unitID].posErrorVectorz * mCos(rotAngle)

		-- set up drift vector
		local posErrorDeltax = (newposErrorVectorx - unitWobble[unitID].posErrorVectorx)/driftTime
		local posErrorDeltaz = (newposErrorVectorz - unitWobble[unitID].posErrorVectorz)/driftTime

		spSetUnitPosErrorParams(unitID,unitWobble[unitID].posErrorVectorx,0,unitWobble[unitID].posErrorVectorz,posErrorDeltax,0,posErrorDeltaz,1+driftTime/15)
		-- Please note, final parameter of SetUnitPosErrorParams is in number of slowUpdates, 15 frame intervals.
		-- and 1+ because engine checks as "if ((--nextPosErrorUpdate) > 0)"

		unitWobble[unitID].posErrorVectorx = newposErrorVectorx
		unitWobble[unitID].posErrorVectorz = newposErrorVectorz

	end
end

function gadget:UnitSeismicPing(x,y,z,strength,allyteam,unitID,unitDefID)

	if (allyteam ~= spGetUnitAllyTeam(unitID)) and (spIsUnitInRadar(unitID,allyteam) == false) then
		-- only run if the unit is being seen by a different allyTeam, and is not in radar.

		if (restoreUnitLOS[unitID]==nil) then -- no need to repeatedly set UnitLosState and UnitLosMask on every ping
			spSetUnitLosState(unitID,allyteam,2) -- makes unit unconditionally show up as a radar dot, bitmask
			spSetUnitLosMask(unitID,allyteam,2) -- stops engine from overwriting SetUnitLosState, bitmask
			restoreUnitLOS[unitID] = {}
		end
		restoreUnitLOS[unitID][allyteam] = spGetGameFrame() + seismicDotTime
		customWobble(unitID,0,1)
	end
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)

	-- save unit speed on a quick reference local table, when unit is created
	unitSpeeds[unitID] = UnitDefs[unitDefID].speed

	-- if the unit is an advanced radar, save it to the local table
	if unitDefWobbleReduction[unitDefID] then
		local allyTeam = spGetUnitAllyTeam(unitID)
		advancedRadars[allyTeam][unitID] = {}
		advancedRadars[allyTeam][unitID].radarEmitHeight = unitDefRadarEmitHeight[unitDefID]
		advancedRadars[allyTeam][unitID].radarRadius = unitDefRadarRadius[unitDefID]
		advancedRadars[allyTeam][unitID].wobblereduction = unitDefWobbleReduction[unitDefID]
	end

end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)

	-- remove dead/shared advanced radars from the local table
	advancedRadars[spGetUnitAllyTeam(unitID)][unitID] = nil

	-- remove dead units from the InRadar lists
	-- MetaUnitAdded is run AFTER MetaUnitRemoved, so if unit is just shared or captured, these values should be un-nilled soon
	for key, values in pairs(allyteamlist) do
		unitInAdvancedRadar[values][unitID] = nil
		unitInBasicRadar[values][unitID] = nil
	end

	unitSpeeds[unitID] = nil
	unitWobble[unitID] = nil

end

-- To make Amphibious units under water hidden from seismic sensors
function gadget:UnitEnteredUnderwater(unitID, unitDefID, unitTeam)
	spSetUnitSeismicSignature(unitID,0)
end

function gadget:UnitLeftUnderwater(unitID, unitDefID, unitTeam)
	spSetUnitSeismicSignature(unitID,unitDefSeismicSignature[unitDefID])
end

-- To make Hover units hidden from seismic sensors when on water
function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	if unitDefIsHover[unitDefID] then
		spSetUnitSeismicSignature(unitID,0)
	end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	if unitDefIsHover[unitDefID] then
		spSetUnitSeismicSignature(unitID,unitDefSeismicSignature[unitDefID])
	end
end

local function advancedRadarCheck(unitID,allyTeam)
	-- this function determines if a specific unit can be seen by the advanced radars of the allyTeam
	local basePointX, basePointY, basePointZ
	local unitPointX, unitPointY, unitPointZ
	local advancedRadarFreeLineOfFire = false
	local wobblereduction = 0

	for advancedRadar, tableValues in pairs(advancedRadars[allyTeam]) do -- loop over every aradar on the allyTeam
		local stunned_or_inbuild = spGetUnitIsStunned(advancedRadar) 
		if stunned_or_inbuild == false then
			advancedRadarFreeLineOfFire = false
			local radarEmitHeight = tableValues.radarEmitHeight
			local radarRadius = tableValues.radarRadius

			-- check if the unit is within cylinder distance of the radar
			local basePointX, basePointY, basePointZ, midPointX, midPointY, midPointZ  = spGetUnitPosition(advancedRadar,true)
			local unitPointX, unitPointY, unitPointZ = spGetUnitPosition(unitID) -- use basepoint as radar "paints" the ground
			local dist2Dsq = (basePointX-unitPointX)^2 + (basePointZ-unitPointZ)^2

			-- check if the radar can see the unit without being obstructed by terrain
			local raylength,_,_,_ = spTraceRayGroundBetweenPositions(basePointX, midPointY+radarEmitHeight, basePointZ, unitPointX, unitPointY + 1, unitPointZ, false)
			-- use midPointY to match engine, `const float losHeight  = std::max(unit->midPos.y + emitHeight, 0.0f);`
			-- +1 on unitPointY to prevent false ground collision positives at the terminal point.
			if raylength == nil then -- returns nil if no ground collision detected
				advancedRadarFreeLineOfFire = ((radarRadius+unitSpeeds[unitID])^2 >= dist2Dsq)
			end
			-- +unitspeed on radarRadius to help catch units just walking into radar range, it seems unitspeed is accounted for when determining when to trigger UnitEnteredRadar

			if advancedRadarFreeLineOfFire == true then 
				wobblereduction = mMax(wobblereduction,tableValues.wobblereduction) -- use best wobblereduction of all advanced radars in range
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

-- If I understand CGame::SimFrame() correctly,
-- First, UpdatePreFrame events happens
-- Then eventHandler.GameFrame [gadget:GameFrame] happens
-- Then rest of synced game logic happens [Which makes the abovecallins happen]
-- So, should be safe to assume gadget:GameFrame runs at start of sim frame
function gadget:GameFrame(nn)

	local advancedRadarUpdateFrame = (nn)%advancedRadarUpdateRate
	local basicRadarUpdateFrame = (nn)%basicRadarUpdateRate

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

	-- TODO (if performance is an issue): slice restoreUnitLOS like inBasicRadar, so restoretime <= nn is not checked every frame for every unit in seismic range
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

