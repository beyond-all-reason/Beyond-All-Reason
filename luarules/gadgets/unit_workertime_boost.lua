function gadget:GetInfo()
	return {
		name = "Workertime Multiplier Boost",
		desc = "Allows units with added UnitDefs to build gadget-defined types of units faster.",
		author = "SethDGamre",
		date = "April 2024",
		license = "Public domain",
		layer = 1,
		enabled = true
	}
end

-- synced only
if not gadgetHandler:IsSyncedCode() then return false end

-- is unba com on
if not Spring.GetModOptions().evocom then return false end

local boosttriggers = {} -- stores what words parsed from the wtboostunittype "trigger" boost
local mobileunits = {} -- stores the names of units that can move
local boostedworkertimes = {}-- stores the values of builders who have defined workertimeboost definitions.
local originalworkertimes = {}  -- does what it's named
local inheritchildrenxp = {} -- stores the value of XP rate to be derived from unitdef
-- workertimeboost = number -- in the unitdefs of the builder. This is the mulitplier by which workertime is boosted.
-- wtboostunittype = defined in unitdef customparams of builder, it's a table of strings such as "MOBILE" which defines what units boost buildpower for the builder.
-- wtinheritxprate = defined in unitdef customparams of the builder. It's a number by which XP gained by children is multiplied and passed to the parent
	
--step 1, FOR make a table containing the  names of the units that can boost
local childrenwithparents = {} --stores the parent/child relationships format. Each entry stores key of unitID with an array of {unitID, builderID, xpInheritance}
local botCannonUnits = {} -- stores the unitDefID of parents that spawn things with bot-cannon
for id, def in pairs(UnitDefs) do
	if def.buildSpeed then
		if def.customParams.workertimeboost then
			originalworkertimes[id] = def.buildSpeed
			boostedworkertimes[id] = def.buildSpeed * def.customParams.workertimeboost--adds the key "id" unitname to the list. Boostable builders represented the boosted workertime.
			inheritchildrenxp[id] = def.customParams.wtinheritxprate or -1

			for twd, vwd in pairs(WeaponDefs) do
				if vwd.customParams and vwd.customParams.spawns_name then
					botCannonUnits[vwd] = vwd.customParams.spawns_name
				end
			end
		end
		if botCannonUnits[def.name] then -- check if name of current for-loop is a botcannon unit
			botCannonUnits[def.id] = def.id --convert string to unitdef number
			botCannonUnits[def.name] = nil --remove string version of name
		end
	end

	if def.speed and def.speed ~= 0 then
		mobileunits[id] = true
	end

	if def.customParams.wtboostunittype then
		boosttriggers[id] = def.customParams.wtboostunittype --stores the string of the builder that defines unit categories
	end
end

local boostedtofinish = {}-- going to store the key of unitID equal to the builderID

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local parentID
	local childparent = builderID or parentID	
	Spring.Echo("unitcreated 1")
	Spring.Echo(parentID)
	Spring.Echo(childparent)
	if  childparent ~= nil then
		local parentDefID = Spring.GetUnitDefID(childparent)
		local boost = boostedworkertimes[parentDefID or -1]
		local trigger = boosttriggers[parentDefID or -1]
		Spring.Echo("unitcreated 2")
		Spring.Echo(childparent)
		if boost and trigger and childparent then
			if string.find(trigger, "MOBILE") and mobileunits[unitDefID] then
				Spring.SetUnitBuildSpeed(childparent, boost)
				boostedtofinish[childparent] = childparent
				childrenwithparents[unitID] = {unitid=unitID, parentunitid=childparent, parentxpmultiplier=inheritchildrenxp[parentDefID]}
			elseif boostedtofinish[childparent] then
				Spring.SetUnitBuildSpeed(childparent, originalworkertimes[Spring.GetUnitDefID(childparent)]) -- if another unit is created by a boosted builder that isn't a trigger, revert to normal workertime
				boostedtofinish[childparent] = nil
			end
		end
	end
end

function gadget:RenderUnitDestroyed(unitID, unitDefID, unitTeam)
	Spring.Echo("getunitrulesparam")
	Spring.Echo(unitID)
	Spring.Echo(Spring.GetUnitRulesParam(unitID, "parent_unit_id"))
	Spring.Echo("getunitrulesparam 2")
	if Spring.GetUnitRulesParam(unitID, "parent_unit_id") then
		Spring.Echo("UnitDestroyed getunitrulesparam")
		local xpToGive
		local parentID
		parentID = Spring.GetUnitRulesParam(unitID, "parent_unit_id")
		Spring.Echo(parentID)
		xpToGive = Spring.GetUnitExperience(unitID) * inheritchildrenxp(parentID)
		Spring.Echo(xpToGive)
		local currentXP = Spring.GetUnitExperience(parentID) * inheritchildrenxp(parentID)
		Spring.Echo(currentXP)
		local newXPvalue = currentXP + xpToGive
		Spring.SetUnitExperience(parentID, newXPvalue, buildPercent)
	end
end

function gadget:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	Spring.Echo("UWB 1")
	if childrenwithparents[unitID] then
		Spring.Echo("UWB 2")
		local parentUnitID = childrenwithparents[unitID].parentunitid
		local parentOldXP = Spring.GetUnitExperience(parentUnitID)
		local parentMultiplier = childrenwithparents[unitID].parentxpmultiplier
		local xp

		Spring.Echo("UWB 3")
		if parentMultiplier then
			xp = parentOldXP + ((experience - oldExperience) * parentMultiplier)
			Spring.SetUnitExperience(parentUnitID, xp)
		end
	end
end

function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if boostedtofinish[unitID] then
		Spring.SetUnitBuildSpeed(unitID, originalworkertimes[unitDefID])
		boostedtofinish[unitID] = nil
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if childrenwithparents[unitID] then
		childrenwithparents[unitID] = nil --removes children from list when destroyed
	end
end
