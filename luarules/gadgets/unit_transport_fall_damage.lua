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

--use customparams.fall_damage = <number> to define 
local landedThreshold = 0 -- once the unit's height is equal or below ground height, take damage.
local defaultDamageMult = 0.03 -- damage to be applied per frame of freefall
local velocityThreshold = 3.5 -- this is the velocity required for an explosion to trigger fall damage watch

local dropDamages = {}
local fallingUnits = {}
local transportedUnits = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	dropDamages[unitDefID] = unitDef.customParams.fall_damage or math.ceil(unitDef.health*defaultDamageMult)
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

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	transportedUnits[unitID] = true
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
		fallingUnits[unitID] = {unitdefid = unitDefID, dropdamage = dropDamages[unitDefID], totaldamage = 0, peakheight = 0, transportid = transportID}
		transportedUnits[unitID] = nil
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	local velX, velY, velZ, velLength = Spring.GetUnitVelocity(unitID)
	Spring.Echo("velocity stuff", velX, velY, velZ, velLength)
	if velLength > velocityThreshold and not fallingUnits[unitID] and not transportedUnits[unitID] then
		fallingUnits[unitID] = {unitdefid = unitDefID, dropdamage = dropDamages[unitDefID], totaldamage = 0, peakheight = 0}
	end
end

function gadget:GameFrame()
	if next(fallingUnits) then
		for unitID, data in pairs(fallingUnits) do
			if data.transportid then
			local deadTransport = Spring.GetUnitIsDead(data.transportid)
				if deadTransport then
					data.transportid = nil --if transport is dead, remove its ID from the falling unit
				end
			end
			local unitHeight = GetUnitHeightAboveGroundAndWater(unitID)
			if unitHeight then
				if data.peakheight > unitHeight then
					if unitHeight <= landedThreshold then --landed
						Spring.AddUnitDamage(unitID, data.totaldamage, 0, Spring.GetGaiaTeamID(), 1)
						fallingUnits[unitID] = nil
						Spring.Echo("Ouch!", data.totaldamage)
					elseif not data.transportid then
						data.totaldamage = data.totaldamage + data.dropdamage
						Spring.Echo("cumulative Damage", data.totaldamage)
					end
				else
					data.peakheight = unitHeight
				end
			else -- dead
				fallingUnits[unitID] = nil
			end
		end
	end
end