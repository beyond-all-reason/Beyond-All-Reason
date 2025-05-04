local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Workertime Multiplier Boost",
		desc = "Allows units with added UnitDefs to build and repair gadget-defined types of units faster.",
		author = "SethDGamre",
		date = "April 2024",
		license = "Public domain",
		layer = 0,
		enabled = true
	}
end



-- synced only
if not gadgetHandler:IsSyncedCode() then return false end

-- workertimeboost = number -- in the unitdefs of the builder. This is the mulitplier by which workertime is boosted.
-- wtboostunittype = "MOBILE TURRET" defined in unitdef of builder which defines what units trigger workertime boost for that builder.

local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetUnitDefID = Spring.GetUnitDefID
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local boostableUnits = {}
local builderWatchDefs = {}
local builderWatch = {}
	
for id, def in pairs(UnitDefs) do
	if def.buildSpeed then
		if def.customParams.workertimeboost and def.customParams.wtboostunittype then
			builderWatchDefs[id] = {buildspeed = def.buildSpeed, boost = def.customParams.workertimeboost*def.buildSpeed, trigger = def.customParams.wtboostunittype, timestamp = 0}
		end
	end
	boostableUnits[id] = {}
	if def.speed and def.speed ~= 0 then
		table.insert(boostableUnits[id], "MOBILE")
	end
	if def.speed == 0 and def.weapons[1] then
		table.insert(boostableUnits[id], "TURRET")
	end
	if def.speed == 0 and not def.weapons[1] and def.buildSpeed < 1 then
		table.insert(boostableUnits[id], "PASSIVE")
	end
	if def.buildSpeed and def.buildSpeed > 0 then
		table.insert(boostableUnits[id], "BUILDER")
	end
end

if table.count(builderWatchDefs) <= 0 then -- this enables or disables the gadget
	return false
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderWatchDefs[unitDefID] then
		builderWatch[unitID] = builderWatchDefs[unitDefID]
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	builderWatch[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % 16 == 0 then
		for id, data in pairs(builderWatch) do
			if data.timestamp < frame then
				local project = spGetUnitIsBuilding(id) or nil
				if project then
					local projectStrings = boostableUnits[spGetUnitDefID(project)] or {" "}
					local enableBoost = false
					for _, string in pairs(projectStrings) do
						if projectStrings and string.find(data.trigger, string) then
							enableBoost = true
							break
						end
					end
					if enableBoost == true then
						Spring.SetUnitBuildSpeed(id, data.boost)
						spSetUnitRulesParam(id, "workertimeBoosted", data.boost)
					else
						Spring.SetUnitBuildSpeed(id, data.buildspeed)
						data.timestamp = frame+60
						spSetUnitRulesParam(id, "workertimeBoosted", 0)
					end
				else
					Spring.SetUnitBuildSpeed(id, data.buildspeed)
				end
			end
		end
	end
end
