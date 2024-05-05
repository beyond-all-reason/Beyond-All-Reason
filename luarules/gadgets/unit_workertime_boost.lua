function gadget:GetInfo()
	return {
		name = "Workertime Multiplier Boost",
		desc = "Allows units with added UnitDefs to build gadget-defined types of units faster.",
		author = "SethDGamre",
		date = "April 2024",
		license = "Public domain",
		layer = 0,
		enabled = true
	}
end



-- synced only
if not gadgetHandler:IsSyncedCode() then return false end


local boosttriggers = {} -- stores what words parsed from the wtboostunittype "trigger" boost
local mobileunits = {} -- stores the names of units that can move
local boostedworkertimes = {}-- stores the values of builders who have defined workertimeboost definitions.
local originalworkertimes = {} 
-- workertimeboost = number -- in the unitdefs of the builder. This is the mulitplier by which workertime is boosted.
-- wtboostunittype = defined in unitdef of builder, it's a table of strings such as "MOBILE" which defines what units boost buildpower for the builder.
	
for id, def in pairs(UnitDefs) do
	if def.buildSpeed then
		if def.customParams.workertimeboost then
			originalworkertimes[id] = def.buildSpeed
			boostedworkertimes[id] = def.buildSpeed * def.customParams.workertimeboost--adds the key "id" unitname to the list. Boostable builders represented the boosted workertime.
		end
	end
	if def.speed and def.speed ~= 0 then
		mobileunits[id] = true
	end
	if def.customParams.wtboostunittype then
		boosttriggers[id] = def.customParams.wtboostunittype --stores the string of the builder that defines unit categories
	end
end

if table.count(originalworkertimes) <= 0 then -- this enables or disables the gadget
	return false
end

local boostedtofinish = {}-- going to store the key of unitID equal to the builderID

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if  builderID ~= nil then
		local boost = boostedworkertimes[Spring.GetUnitDefID(builderID) or -1]
		local trigger = boosttriggers[Spring.GetUnitDefID(builderID) or -1]
		if boost and trigger and builderID then
			if string.find(trigger, "MOBILE") and mobileunits[unitDefID] then
				Spring.SetUnitBuildSpeed(builderID, boost)
				boostedtofinish[builderID] = builderID
			elseif boostedtofinish[builderID] then
				Spring.SetUnitBuildSpeed(builderID, originalworkertimes[Spring.GetUnitDefID(builderID)]) -- if another unit is created by a boosted builder that isn't a trigger, revert to normal workertime
				boostedtofinish[builderID] = nil
			end
		end
	end
end

function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if boostedtofinish[unitID] then
		Spring.SetUnitBuildSpeed(unitID, originalworkertimes[unitDefID])
		boostedtofinish[unitID] = nil
	end
end