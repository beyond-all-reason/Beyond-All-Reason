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

-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

local amountMultiplier = 1	-- will be set by mod option: critters_multiplier
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

local function makeUnitCritter(unitID)
	Spring.SetUnitNeutral(unitID, true)
	Spring.SetUnitNoSelect(unitID, true)
	Spring.SetUnitStealth(unitID, true)
	Spring.SetUnitNoMinimap(unitID, true)
	critterUnits[unitID] = true
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
	if critterUnits[unitID] ~= nil then
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
		else
			critterUnits[unitID] = true
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)

	if critterUnits[unitID] then critterUnits[unitID] = nil end
end

--http://springrts.com/phpbb/viewtopic.php?f=23&t=30109
function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)	
	--Spring.Echo (CMD[cmdID] or "nil")
	if cmdID and cmdID == CMD.ATTACK then 		
		if cmdParams and #cmdParams == 1 then			
			--Spring.Echo ("target is unit" .. cmdParams[1] .. " #cmdParams=" .. #cmdParams)
			if critterUnits[cmdParams[1]] then 
			--	Spring.Echo ("target is a critter and ignored!") 
				return false 
			end
		end
	end		
	return true
end
