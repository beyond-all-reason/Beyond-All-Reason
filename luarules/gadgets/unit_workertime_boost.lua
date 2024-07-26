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
local boostableUnits = {}
local builderWatchDefs = {}
local builderWatch = {}
	
for id, def in pairs(UnitDefs) do
	if def.buildSpeed then
		if def.customParams.workertimeboost and def.customParams.wtboostunittype then
			builderWatchDefs[id] = {buildspeed = def.buildSpeed, boost = def.customParams.workertimeboost*def.buildSpeed, trigger = def.customParams.wtboostunittype}
		end
	end
	if def.speed and def.speed ~= 0 then
		boostableUnits[id] = "MOBILE"
	end
	if def.speed == 0 and def.weapons and def.weapons[1] then
		boostableUnits[id] = "TURRET"
	end
	if def.speed == 0 and not def.weapons then
		boostableUnits[id] = "PASSIVE"
	end
	if def.buildSpeed then
		boostableUnits[id] = "BUILDER"
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

function gadget:UnitDestroyed(unitID)
	builderWatch[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % 19 == 0 then
		for id, data in pairs(builderWatch) do
			local project = spGetUnitIsBuilding(id) or nil
			if project then
				local projectTypeString = boostableUnits[spGetUnitDefID(project)]
				if projectTypeString and string.find(data.trigger, projectTypeString) then
					Spring.SetUnitBuildSpeed(id, data.boost)
					Spring.Echo("YEAH, BABY")
				end
			else
				Spring.SetUnitBuildSpeed(id, data.buildspeed)
				Spring.Echo("LAME, BABY")
			end
		end
	end
end