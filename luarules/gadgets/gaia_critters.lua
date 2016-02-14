function gadget:GetInfo()
  return {
    name      = "gaia critter units",
    desc      = "units spawn and wander around the map",
    author    = "knorke",
    date      = "2013",
    license   = "horse",
    layer     = -100, --negative, otherwise critters spawned by gadget do not disappear on death (spawned with /give they always die)
    enabled   = true,
	}
end

-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

local GaiaTeamID  = Spring.GetGaiaTeamID()

local critterConfig = include("LuaRules/configs/gaia_critters_config.lua")
local critterUnits = {}	--critter units that are currently alive

local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitPosition = Spring.GetUnitPosition
local random = math.random
local sin, cos = math.sin, math.cos
local rad = math.rad

local function randomPatrolInBox(unitID, box)
	for i=1,5 do
		local x = random(box.x1, box.x2)
		local z = random(box.z1, box.z2)
		Spring.GiveOrderToUnit(unitID, CMD.PATROL , {x, spGetGroundHeight(x, z), z}, {"shift"})
	end
end

local function randomPatrolInCircle(unitID, circle)
	for i=1,5 do
		local a = rad(random(0, 360))
		local r = random(0, circle.r)
		local x = circle.x + r*sin(a)
		local z = circle.z + r*cos(a)
		Spring.GiveOrderToUnit(unitID, CMD.PATROL , {x, spGetGroundHeight(x, z), z}, {"shift"})
	end
end

local function makeUnitCritter(unitID)
	Spring.SetUnitNeutral(unitID, true)
	Spring.SetUnitNoSelect(unitID, true)
	Spring.SetUnitStealth(unitID, true)
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
		gadgetHandler:RemoveGadget(self)
	end	
end

-- spawning critters in game start prevents them from being spawned every time you do /luarules reload
function gadget:GameStart()
	for key, cC in pairs(critterConfig[Game.mapName]) do
		if cC.spawnBox then	
			for unitName, unitAmount in pairs(cC.unitNames) do
				for i=1, unitAmount do
					local unitID = nil
					local x = random(cC.spawnBox.x1, cC.spawnBox.x2)
					local z = random(cC.spawnBox.z1, cC.spawnBox.z2)
					unitID = Spring.CreateUnit(unitName, x, spGetGroundHeight(x, z), z, 0, GaiaTeamID)
					if unitID then
						randomPatrolInBox(unitID, cC.spawnBox)
						makeUnitCritter(unitID)
					else
						Spring.Echo("Failed to create " .. unitName)
					end
				end
			end
		elseif cC.spawnCircle then			
			for unitName, unitAmount in pairs(cC.unitNames) do
				for i=1, unitAmount do
					local unitID = nil
					local a = rad(random(0, 360))
					local r = random(0, cC.spawnCircle.r)
					local x = cC.spawnCircle.x + r*sin(a)
					local z = cC.spawnCircle.z + r*cos(a)
					unitID = Spring.CreateUnit(unitName, x, spGetGroundHeight(x, z), z, 0, GaiaTeamID)
					if unitID then
						randomPatrolInCircle(unitID, cC.spawnCircle)
						makeUnitCritter(unitID)
					else
						Spring.Echo("Failed to create " .. unitName)
					end
				end
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if Spring.GetGameFrame() > 0 and string.sub(UnitDefs[unitDefID].name, 0, 7) == "critter" then
		local x,y,z = spGetUnitPosition(unitID,true,true)
		local circle = {x=x, z=z, r=300}
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
