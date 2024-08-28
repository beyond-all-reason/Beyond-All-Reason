function gadget:GetInfo()
	return {
		name = "Fall Damage from Transports",
		desc = "All units that fall from transports except Commandos receive height and mass proportional damage",
		author = "Beherith, SethDGamre",
		date = "2023.06.22",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end
--this gadget is enabled as a bandaid fix for commander effigies. Units cannot be moved when released from transports using Spring.SetUnitPosition until it lands, meaning effigy transposition cannot occur until commander lands. This gadget is pending approval from the GDT for mainline use.

--use customparams.fall_damage_multiplier = <number> to overwrite default damage multiplier as defined below.
local heightThreshold = 32 -- if unit is at least 32 elmos up consider it falling
local landedThreshold = 0 -- once the unit's height is equal or below ground height, take damage.
local defaultDamageMult = 0.03 -- damage is 3% of mass * dropHeight if not defined in customParam.fall_damage_multiplier
local velocityThreshold = 3.5 -- this is the velocity required for an explosion to trigger fall damage watch

local fallDamageMultipliers = {}
local masses = {}
local fallingUnits = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	masses[unitDefID] = unitDef.mass
	if unitDef.customParams.fall_damage_multiplier then
		fallDamageMultipliers[unitDefID] = unitDef.customParams.fall_damage_multiplier
	end
end

local function GetUnitHeightAboveGroundAndWater(unitID) -- returns nil for invalid units
	if (Spring.GetUnitIsDead(unitID) ~= false) or (Spring.ValidUnitID(unitID) ~= true) then return nil end

	local px, py, pz = Spring.GetUnitPosition(unitID)
	if px and py and pz  then
		local groundHeight = math.max(0, Spring.GetGroundHeight( px, pz ))
		return py - groundHeight
	else
		return nil
	end
end

local function CalculateDropDamage(unitDefID, dropHeight)
	local damageMult = fallDamageMultipliers[unitDefID] or defaultDamageMult
	local dropDamage = dropHeight * masses[unitDefID] * damageMult
	return dropDamage
end



function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	local unitHeight = GetUnitHeightAboveGroundAndWater(unitID)
	if unitHeight < heightThreshold then 
		return -- if dropped too low, ignore
	else
		fallingUnits[unitID] = {unitdefid = unitDefID, peakdropheight = 0, transportid = transportID}
	end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	local velX, velY, velZ, velLength = Spring.GetUnitVelocity(unitID)
	Spring.Echo("velocity stuff", velX, velY, velZ, velLength)
	if velLength > velocityThreshold and not fallingUnits[unitID] then
		fallingUnits[unitID] = {unitdefid = unitDefID, peakdropheight = 0}
	end
end

function gadget:GameFrame()
	if next(fallingUnits) then
		for unitID, data in pairs(fallingUnits) do
			if data.transportID then
			local deadTransport = Spring.GetUnitIsDead(data.transportid)
				if deadTransport then
					data.transportID = nil --if transport is dead, remove its ID from the falling unit
				end
			end
			if not data.transportID then --if no transport unloading unit, it should take fall damage
				local dropHeight = GetUnitHeightAboveGroundAndWater(unitID)
				if dropHeight then
					if data.peakdropheight and dropHeight < data.peakdropheight then -- going down!
						Spring.Echo("going down!", data.peakdropheight, dropHeight)
						if data.peakdropheight >= heightThreshold then
							if dropHeight <= landedThreshold then
								local dropDamage = CalculateDropDamage(data.unitdefid, data.peakdropheight)
								Spring.AddUnitDamage(unitID, dropDamage, 0, Spring.GetGaiaTeamID(), 1)
								fallingUnits[unitID] = nil
							end
						else --peakdropheight isn't high enough, remove
							fallingUnits[unitID] = nil
						end
					else --going up!
						data.peakdropheight = dropHeight
						Spring.Echo("going up!", data.peakdropheight)
					end
				else -- dead
					fallingUnits[unitID] = nil
				end
			end
		end
	end
end