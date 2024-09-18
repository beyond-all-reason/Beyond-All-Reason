function gadget:GetInfo()
	return {
		name = "Collision Damage Behavior",
		desc = "Magnifies the default engine ground and object collision damage and handles max impulse limits",
		author = "SethDGamre",
		date = "2024.8.29",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local moveDefsData = VFS.Include('gamedata/movedefs.lua')

--anything equal to or above this number will be ignored.
local ignoredMaxWaterDepthThreshold = 5000

local spGetUnitHealth = Spring.GetUnitHealth
local mathMin = math.min
local mathMax = math.max

local fallDamageMultipliers = {}
local transportedUnits = {}
local unitCheckFlags = {}
local unitDepthDamageFlags = {}
local weaponDefWatch = {}
local gameFrame = 0
local velocityWatchDuration = 8
local movedefsTable = {}
local unitDefData = {}

for _, entry in pairs(moveDefsData) do
  if entry.name and not entry.minwaterdepth and entry.maxwaterdepth and entry.maxwaterdepth < ignoredMaxWaterDepthThreshold then
    movedefsTable[entry.name] = entry.maxwaterdepth
  end
end

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.name == "corak" then
	Spring.Echo("corak shit", unitDef.maxwaterdepth)
	end
	if unitDef.movementClass then --and movedefsTable[unitDef.movementClass] then
		unitDefData[unitDefID] = {}
		unitDefData[unitDefID].fallDamageMultiplier = unitDef.customParams.fall_damage_multiplier or 1.0
		Spring.Echo("Shit found!", unitDef.name, unitDef.movementClass)
	end
end

local function GetUnitHeightAboveGroundAndWater(unitID) -- returns nil for invalid units
	if (Spring.GetUnitIsDead(unitID) ~= false) or (Spring.ValidUnitID(unitID) ~= true) then return nil end

	local positionX, positionY, positionZ = Spring.GetUnitBasePosition(unitID)
	if positionX and positionY and positionZ  then
		local groundHeight = Spring.GetWaterLevel( positionX, positionZ )
		return positionY - groundHeight
	else
		return nil
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam,  transportID, transportTeam)
	transportedUnits[unitID] = nil
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	transportedUnits[unitID] = nil
	unitInertiaCheckFlags[unitID] = nil
end

function gadget:GameFrame(frame)
	for unitID, expirationFrame in pairs(unitCheckFlags) do

	end
	gameFrame = frame
end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)

	--Spring.Echo(unitID)
	--Spring.Echo(moveDefsData.COMMANDERBOT)

end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	local movedata = Spring.GetUnitMoveTypeData(unitID)

	Spring.Echo(movedata)

end