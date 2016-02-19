function gadget:GetInfo()
  return {
    name      = "gaia critter units",
    desc      = "units spawn and wander around the map",
    author    = "Floris (original: knorke, 2013)",
    date      = "2016",
    license   = "penguin",
    layer     = -100, --negative, otherwise critters spawned by gadget do not disappear on death (spawned with /give they always die)
    enabled   = true,
	}
end

-- NOTE: adding/removing will break at ´/luarules reload´ (needs to remember var ´critterUnits´)


-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end


local removeCritters		= true		-- gradually remove critters when unitcont gets higher
local addCrittersAgain		= true		-- re-add the removed critters again

local minTotalUnits			= 400		-- starting removing critters at this total unit count
local maxTotalunits			= 1700		-- finished removing critters at this total unit count
local minimumCritters		= 0.15		-- dont remove further than (0.1 == 10%) of critters
local minCritters			= 35		-- dont remove below this amount
local critterDiffChange		= 8			-- dont add/remove less than x critters



local amountMultiplier = 1		-- will be set by mod option: critters_multiplier
local minMulti = 0.2
local maxMulti = 2


local GaiaTeamID  = Spring.GetGaiaTeamID()

local critterConfig = include("LuaRules/configs/gaia_critters_config.lua")
local critterUnits = {}	--critter units that are currently alive

local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitPosition = Spring.GetUnitPosition
local random = math.random
local sin, cos = math.sin, math.cos
local rad = math.rad
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

local totalCritters = 0
local aliveCritters = 0

local function randomPatrolInBox(unitID, box, minWaterDepth)	-- only define minWaterDepth if unit is a submarine
	local ux,uy,uz = spGetUnitPosition(unitID,true,true)
	local waterRadius = 1000		-- max distance a submarine unit will travel
	local orders = 5
	local attempts = orders
	if minWaterDepth ~= nil then
		attempts = 150
	end
	local ordersGiven = 0
	
	local x,z
	for i=1,attempts do
		if minWaterDepth == nil then
			x = random(box.x1, box.x2)
			z = random(box.z1, box.z2)
		else
			local x1 = ux - waterRadius
			if x1 < box.x1 then x1 = box.x1 end
			local x2 = ux + waterRadius
			if x2 > box.x2 then x2 = box.x2 end
			local z1 = uz - waterRadius
			if z1 < box.z1 then z1 = box.z1 end
			local z2 = uz + waterRadius
			if z2 > box.z2 then z2 = box.z2 end
			x = random(x1, x2)
			z = random(z1, z2)
		end
		if x > 0 and z > 0 and x < mapSizeX and z < mapSizeZ then
			local y = spGetGroundHeight(x, z)
			if minWaterDepth == nil or y < minWaterDepth then
				Spring.GiveOrderToUnit(unitID, CMD.PATROL , {x, y, z}, {"shift"})
				ordersGiven = ordersGiven + 1
			end
		end
		if ordersGiven == orders then break end
	end
end

local function in_circle(center_x, center_y, radius, x, y)
	local square_dist = ((center_x - x) * (center_x - x)) + ((center_y - y) * (center_y - y))
	return square_dist <= radius * radius
end

local function randomPatrolInCircle(unitID, circle, minWaterDepth)	-- only define minWaterDepth if unit is a submarine
	local orders = 5
	local waterRadius = 1000		-- max distance a submarine unit will travel
	local attempts = orders
	if minWaterDepth ~= nil then
		attempts = 150
	end
	local ordersGiven = 0
	local ux, uz, ur = circle.x, circle.z, circle.r
	for i=1,attempts do
		if minWaterDepth ~= nil and waterRadius <= circle.r then
			ux,uy,uz = spGetUnitPosition(unitID,true,true)
			ur = waterRadius
		end
		local a = rad(random(0, 360))
		local r = random(0, ur)
		local x = ux + r*sin(a)
		local z = uz + r*cos(a)
		if x > 0 and z > 0 and x < mapSizeX and z < mapSizeZ and in_circle(circle.x, circle.z, circle.r, x, z) then
			local y = spGetGroundHeight(x, z)
			if minWaterDepth == nil or y < minWaterDepth then
				Spring.GiveOrderToUnit(unitID, CMD.PATROL , {x, y, z}, {"shift"})	-- this sometimes gives resursion errors, but am to lazy to spread spammign this command over multiple gameframes
				ordersGiven = ordersGiven + 1
			end
		end
		if ordersGiven == orders then break end
	end
end

local function setGaiaUnitSpecifics(unitID)
	Spring.SetUnitNeutral(unitID, true)
	Spring.SetUnitNoSelect(unitID, true)
	Spring.SetUnitStealth(unitID, true)
	Spring.SetUnitNoMinimap(unitID, true)
end

local function makeUnitCritter(unitID)
	setGaiaUnitSpecifics(unitID)
	critterUnits[unitID] = {alive=true}
	totalCritters = totalCritters + 1
	aliveCritters = aliveCritters + 1
end

function gadget:Initialize()
	local mo = Spring.GetModOptions()
	if mo and tonumber(mo.critters)==0 then
		Spring.Echo("gaia_critters.lua: turned off via modoptions")
		gadgetHandler:RemoveGadget(self)
	end
	
	Spring.Echo("gaia_critters.lua: gadget:Initialize() Game.mapName=" .. Game.mapName)
	if not critterConfig[Game.mapName] then
		Spring.Echo("no critter config for this map")
		--gadgetHandler:RemoveGadget(self)		-- disabled so if you /give critters they still will be auto patrolled
	end
	if mo.critters_multiplier ~= nil then
		amountMultiplier = tonumber(mo.critters_multiplier)
	end
	if amountMultiplier < minMulti then amountMultiplier = minMulti end
	if amountMultiplier > maxMulti then amountMultiplier = maxMulti end
end

function getUnitDefIdbyName(unitName)
	for udid, unitDef in pairs(UnitDefs) do
		if unitDef.name == unitName then return udid end
	end
end

-- excluding gaia units
local function getTotalUnits()
	local totalUnits = 0
	local allyTeamList = Spring.GetAllyTeamList()
	local numberOfAllyTeams = #allyTeamList
	for allyTeamListIndex = 1, numberOfAllyTeams do
		local allyID = allyTeamList[allyTeamListIndex]
		local teamList = Spring.GetTeamList(allyID)
		for _,teamID in pairs(teamList) do
			if teamID ~= GaiaTeamID then
				totalUnits = totalUnits + Spring.GetTeamUnitCount(teamID)
			end
		end
	end
	return totalUnits
end

local function adjustCritters(newAliveCritters)

	if newAliveCritters == aliveCritters then return end
	
	local critterDifference = newAliveCritters - aliveCritters 
	if critterDifference == 0 then return end
	local add = false
	if critterDifference > 0 then 
		add = true 
		if addCrittersAgain == false then return end
	end
	
	local removeKeys = {}
	for unitID, critter in pairs(critterUnits) do
		if add and not critter.alive  or  not add and critter.alive then
			if add then 
				table.insert(removeKeys, unitID)
				local newUnitID = Spring.CreateUnit(critter.unitName, critter.x, critter.y, critter.z, 0, GaiaTeamID)
				setGaiaUnitSpecifics(newUnitID)
				critterDifference = critterDifference - 1
				--Spring.Echo("added: "..critter.unitName.."  x:"..critter.x.."  z:"..critter.z)
			else
				local x,y,z = spGetUnitPosition(unitID,true,true)
				aliveCritters = aliveCritters - 1
				critterDifference = critterDifference + 1
				critterUnits[unitID].alive = false
				critterUnits[unitID].x = x
				critterUnits[unitID].y = y
				critterUnits[unitID].z = z
				Spring.DestroyUnit(unitID, false, true)	-- reclaimed
				--Spring.Echo("removed: "..critter.unitName.."  x:"..x.."  z:"..z)
				if aliveCritters <= minCritters then break end
			end
			if critterDifference > -1 and critterDifference < 1  then break end
		end
	end
	if add then
		for i, unitID in ipairs(removeKeys) do
			critterUnits[unitID] = nil		-- this however leaves these keys still being iterated 
		end
		--if totalCritters > 800 then		-- occasional cleanup (leaving this in will make ´critterDifference´ useless)
			newCritterUnits = {}
			for unitID, critter in pairs(critterUnits) do
				if critter ~= nil then
					newCritterUnits[unitID] = critter
				end
			end
			critterUnits = newCritterUnits
		--end
	end
end

-- increase/decrease critters according to unitcount
function gadget:GameFrame(gameFrame)
	if removeCritters == false then return end
	
	if gameFrame%200==0 then 
		local totalUnits = getTotalUnits() -- is without critters
		local multiplier = 1 - ((totalUnits-minTotalUnits) / (maxTotalunits-minTotalUnits))
		if multiplier < 0 then multiplier = 0 end
		multiplier = multiplier + minimumCritters
		if multiplier > 1 then multiplier = 1 end
		local newAliveCritters = math.ceil(totalCritters * multiplier)
		
		--Spring.Echo("multiplier: "..multiplier.."  total: "..totalCritters.."  alive: "..aliveCritters.."  newalive: "..newAliveCritters)
		local critterDifference = newAliveCritters - aliveCritters 
		if critterDifference > 0 or (critterDifference < 0 and aliveCritters > minCritters)  then
			if math.abs(critterDifference) >= critterDiffChange or (critterDifference < 0 and aliveCritters+critterDifference <= minCritters) then
				adjustCritters(newAliveCritters)
			end
		end
	end
end


function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

-- spawning critters in game start prevents them from being spawned every time you do /luarules reload
function gadget:GameStart()
	if critterConfig[Game.mapName] == nil then
		return 
	end 
	for key, cC in pairs(critterConfig[Game.mapName]) do
		if cC.spawnBox then	
			for unitName, unitAmount in pairs(cC.unitNames) do
				local unitDefID = getUnitDefIdbyName(unitName)
				local minWaterDepth = 0 - UnitDefs[unitDefID].minWaterDepth
				local waterunit = false
				if minWaterDepth < 0 then waterunit = true end
				
				-- to make sure at least 1 critter is placed  (to prevent when the multiplier is small, that a small critter-amount always gets diminished to zero)
				local amount = unitAmount * amountMultiplier
				if amount > 0 and amount < 1 then amount = 1 end	
				amount = round(amount)
				
				for i=1, amount do
					local unitID = nil
					local x = random(cC.spawnBox.x1, cC.spawnBox.x2)
					local z = random(cC.spawnBox.z1, cC.spawnBox.z2)
					local y = spGetGroundHeight(x, z)
					if not waterunit or cC.nowatercheck ~= nil or y < minWaterDepth then
						local supplyMinWaterDepth = nil
						if waterunit and not cC.nowatercheck then
							supplyMinWaterDepth = minWaterDepth
						end
						unitID = Spring.CreateUnit(unitName, x, y, z, 0, GaiaTeamID)
						if unitID then
							randomPatrolInBox(unitID, cC.spawnBox, supplyMinWaterDepth)
							makeUnitCritter(unitID)
							critterUnits[unitID].unitName = unitName
						else
							Spring.Echo("Failed to create " .. unitName)
						end
					end
				end
			end
		elseif cC.spawnCircle then			
			for unitName, unitAmount in pairs(cC.unitNames) do
				local unitDefID = getUnitDefIdbyName(unitName)
				local minWaterDepth = 0 - UnitDefs[unitDefID].minWaterDepth
				local waterunit = false
				if minWaterDepth < 0 then waterunit = true end
				
				-- to make sure at least 1 critter is placed  (to prevent when the multiplier is small, that a small critter-amount always gets diminished to zero)
				local amount = unitAmount * amountMultiplier
				if amount > 0 and amount < 1 then amount = 1 end	
				amount = round(amount)
				
				for i=1, amount do
					local unitID = nil
					local a = rad(random(0, 360))
					local r = random(0, cC.spawnCircle.r)
					local x = cC.spawnCircle.x + r*sin(a)
					local z = cC.spawnCircle.z + r*cos(a)
					local y = spGetGroundHeight(x, z)
					if not waterunit or cC.nowatercheck ~= nil or y < minWaterDepth then
						local supplyMinWaterDepth = nil
						if waterunit and not cC.nowatercheck then
							supplyMinWaterDepth = minWaterDepth
						end
						unitID = Spring.CreateUnit(unitName, x, y, z, 0, GaiaTeamID)
						if unitID then
							randomPatrolInCircle(unitID, cC.spawnCircle, supplyMinWaterDepth)
							makeUnitCritter(unitID)
							critterUnits[unitID].unitName = unitName
						else
							Spring.Echo("Failed to create " .. unitName)
						end
					end
				end
			end
		end
	end
end

function gadget:UnitIdle(unitID, unitDefID, unitTeam)
	if Spring.GetGameFrame() > 0 and string.sub(UnitDefs[unitDefID].name, 0, 7) == "critter" then
		local x,y,z = spGetUnitPosition(unitID,true,true)
		local radius = 220
		if UnitDefs[unitDefID].name == "critter_gull" then
			radius = 750
		end
		local circle = {x=x, z=z, r=radius}
		randomPatrolInCircle(unitID, circle)
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if Spring.GetGameFrame() > 0 and string.sub(UnitDefs[unitDefID].name, 0, 7) == "critter" then
		local x,y,z = spGetUnitPosition(unitID,true,true)
		local radius = 300
		if UnitDefs[unitDefID].name == "critter_gull" then
			radius = 1500
		end
		local circle = {x=x, z=z, r=radius}
		randomPatrolInCircle(unitID, circle)
		if unitTeam == GaiaTeamID then
			makeUnitCritter(unitID)
			critterUnits[unitID].unitName = UnitDefs[unitDefID].name
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)

	if critterUnits[unitID] ~= nil and attackerID ~= nil then 
		critterUnits[unitID] = nil
		totalCritters = totalCritters - 1
	end
end

--http://springrts.com/phpbb/viewtopic.php?f=23&t=30109
function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)	
	--Spring.Echo (CMD[cmdID] or "nil")
	if cmdID and cmdID == CMD.ATTACK then 		
		if cmdParams and #cmdParams == 1 then			
			--Spring.Echo ("target is unit" .. cmdParams[1] .. " #cmdParams=" .. #cmdParams)
			if critterUnits[cmdParams[1]] ~= nil then 
			--	Spring.Echo ("target is a critter and ignored!") 
				return false 
			end
		end
	end		
	return true
end
