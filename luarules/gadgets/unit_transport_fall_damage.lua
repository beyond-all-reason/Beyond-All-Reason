function gadget:GetInfo()
	return {
		name = "Fall Damage from Transports",
		desc = "All units that fall from transports except Commandos receive height and mass proportional damage",
		author = "Beherith, SethDGamre",
		date = "2023.06.22",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end
--this gadget is enabled as a bandaid fix for commander effigies. Units cannot be moved when released from transports using Spring.SetUnitPosition until it lands, meaning effigy transposition cannot occur until commander lands. This gadget is pending approval from the GDT for mainline use.

--use customparams.fall_damage_multiplier = <number> to overwrite defaultDamageMultiplier
local defaultDamageMultiplier = 1.0 -- A multiplier representing the percentage of health lost from the velocity of a freefall. Also applies proportionally to velocities from explosion impulse.
local velocityStopThresholdMultiplier = 0.4 -- once the unit's velocity is equal to or below peakvelocity*velocityStopDivisor, take damage.
local velocityStopCountThreshold = 3 --number of frames below threshold before damage is applied
local velocityThreshold = 3.5 -- this is the velocity required for an explosion to trigger fall damage watch


local dropDamages = {}
local fallingUnits = {}
local transportedUnits = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	local damageReductionMultiplier = 0.2
	local baseDamageMultiplier = unitDef.customParams.fall_damage_multiplier or defaultDamageMultiplier
	dropDamages[unitDefID] = math.ceil(unitDef.health*baseDamageMultiplier * damageReductionMultiplier)
end

local function checkValidUnitVelocity(unitID) -- returns nil for invalid units
	if (Spring.GetUnitIsDead(unitID) ~= false) or (Spring.ValidUnitID(unitID) ~= true) then return nil end

		local velX, velY, velZ, velLength = Spring.GetUnitVelocity(unitID)
	if velLength then
		return velX, velY, velZ, velLength
	else
		return nil
	end
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	transportedUnits[unitID] = true
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	local velX, velY, velZ, velLength = Spring.GetUnitVelocity(unitID)
		fallingUnits[unitID] = {unitdefid = unitDefID, damagemultiplier = dropDamages[unitDefID], peakvelocity = 0, stopcount = 0, transportid = transportID}
		transportedUnits[unitID] = nil
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	local velX, velY, velZ, velLength = Spring.GetUnitVelocity(unitID)
	if not fallingUnits[unitID] and not transportedUnits[unitID] and velLength > velocityThreshold then
		fallingUnits[unitID] = {unitdefid = unitDefID, damagemultiplier = dropDamages[unitDefID], peakvelocity = 0, stopcount = 0}
	end
end

function gadget:GameFrame()
	for unitID, data in pairs(fallingUnits) do
		if data.transportid then
			local deadTransport = Spring.GetUnitIsDead(data.transportid)
			if deadTransport then
				data.transportid = nil -- if transport is dead, remove its ID from the falling unit
			end
		end
		local velX, velY, velZ, currentVelocity = checkValidUnitVelocity(unitID)
		if currentVelocity then
			if data.peakvelocity > currentVelocity then -- velocity slowing
				if currentVelocity <= (data.peakvelocity * velocityStopThresholdMultiplier) then -- landed
					if not data.vely then 
						data.vely = velY
						data.velocity = currentVelocity
					end
					data.stopcount = data.stopcount+1
					if data.stopcount > velocityStopCountThreshold then
						if not data.transportid and data.vely ~= 0 and data.velocity ~= 0 then -- if no transport, damage
							local yProportion = data.vely / data.velocity
							yProportion = -yProportion
							Spring.AddUnitDamage(unitID, damage, 0, Spring.GetGaiaTeamID(), 1)
						end
						fallingUnits[unitID] = nil -- remove after landing
					end
				end
			elseif not data.transportid then -- increase peak velocity if not protected by transport
				data.peakvelocity = currentVelocity
			end
		else -- dead
			fallingUnits[unitID] = nil
		end
	end
end