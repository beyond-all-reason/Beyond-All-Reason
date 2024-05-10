function gadget:GetInfo()
	return {
		name = "Inherit Creation Units XP",
		desc = "Allows units with added UnitDefs to gain a defined fraction of the XP earned by their creations.",
		author = "SethDGamre and Xehrath",
		date = "May 2024",
		license = "Public domain",
		layer = 0,
		enabled = true
	}
end

-- synced only
if not gadgetHandler:IsSyncedCode() then return false end

local inheritChildrenXP = {} -- stores the value of XP rate to be derived from unitdef
-- inheritxratemultiplier = 1 -- defined in unitdef customparams of the parent unit. It's a number by which XP gained by children is multiplied and passed to the parent after power difference calculations
local childrenInheritXP = {} -- stores the true/false of child xp inheritance from parents
-- childreninheritxp = true --  determines whether or not children inherit current xp from their parents when created.

local childrenWithParents = {} --stores the parent/child relationships format. Each entry stores key of unitID with an array of {unitID, builderID, xpInheritance}

local unitPowerDefs = {}
local unitsList = {}


for id, def in pairs(UnitDefs) do
	if def.customParams.inheritxratemultiplier then
		inheritChildrenXP[id] = def.customParams.inheritxratemultiplier or 0
	end
	if def.customParams.childreninheritxp then
		childrenInheritXP[id] = true
	else
		childrenInheritXP[id] = false
	end
	if def.power then
	unitPowerDefs[id] = def.power
	end
end

if table.count(inheritChildrenXP) <= 0 then -- this enables or disables the gadget
	return false
end

local function calculatePowerDiffXP(childID, parentID)
	local childDefID = Spring.GetUnitDefID(childID)
	local parentDefID = Spring.GetUnitDefID(parentID)
	local childPower =  unitPowerDefs[childDefID]
	local parentPower = unitPowerDefs[parentDefID]
	return (childPower/parentPower)*inheritChildrenXP[parentDefID]
end

local initializeList = {}
local ignoreList = {}
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if  inheritChildrenXP[builderID] then
			childrenWithParents[unitID] = {
				unitid=unitID,
				parentunitid=builderID,
				parentxpmultiplier=calculatePowerDiffXP(unitID, builderID),
				childinheritsXP = childrenInheritXP[Spring.GetUnitDefID(unitID)]
			}
	end
	initializeList[unitID] = true
	unitsList[unitID] = true
end

local xpGainParents = {} --stores the unitID's of parents that inherit xp
local lastRunFrame = 0
local oldChildXPValues = {}
function gadget:GameFrame(frame)
	if frame > (lastRunFrame + 30) then
		for unitID, value in pairs(unitsList) do
			local parentID
			if not ignoreList[unitID] then
				if initializeList[unitID] then -- check for parenthood
					local unitDefID = Spring.GetUnitDefID(unitID)
					local parentXP = 0
					local parentDefID
					if Spring.GetUnitRulesParam(unitID, "carrier_host_unit_id") then --estabalishes unit_carrier_spawner parenthood
						parentID = Spring.GetUnitRulesParam(unitID, "carrier_host_unit_id")
					end
					if Spring.GetUnitRulesParam(unitID, "parent_unit_id") then --estabalishes unit_explosion_spawner parenthood
						parentID = Spring.GetUnitRulesParam(unitID, "parent_unit_id")
						local xp = Spring.GetUnitExperience(parentID)
						Spring.SetUnitExperience(unitID, xp)
					end
					if parentID ~= nil then -- if either of the above rulesparams return a value, then add to childrenwithparents
						childrenWithParents[unitID] = {
							unitid = unitID,
							parentunitid = parentID,
							parentxpmultiplier = calculatePowerDiffXP(unitID, parentID),
							childinheritsXP = childrenInheritXP[unitDefID]
						}
					end
					if parentID then
						parentDefID = Spring.GetUnitDefID(parentID) or 0 -- gets the parentDefID
					end
					if childrenInheritXP[parentDefID] == true and childrenWithParents[unitID] then --if the parent has the unitdef, set childxp to parent xp.
						parentXP = Spring.GetUnitExperience(childrenWithParents[parentDefID])
						Spring.SetUnitExperience(unitID, parentXP)
						oldChildXPValues[unitID] = parentXP	--add parent xp to the oldxp value to exclude it from inheritance
					end
					if inheritChildrenXP[unitDefID] then -- if parent inherits xp, then add to list of units to inherit xp
						xpGainParents[unitID] = true
					end
					if not xpGainParents[unitID] and not childrenWithParents[unitID] then --if not a parent or a child of a parent who inherits xp, add to ignore list
						ignoreList[unitID] = true
					end
					initializeList[unitID] = nil -- this concludes innitialization
				end
				if childrenWithParents[unitID] then
					parentID = childrenWithParents[unitID].parentunitid
					local oldXP = oldChildXPValues[unitID] or 0
					local newXP = Spring.GetUnitExperience(unitID) or 0
					local parentXP = Spring.GetUnitExperience(parentID) or 0
					local multiplier = childrenWithParents[unitID].parentxpmultiplier
					local gainedXP = parentXP + ((newXP-oldXP)*multiplier)
					oldChildXPValues[unitID] = newXP
					Spring.SetUnitExperience(parentID, gainedXP)
				end
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	
	childrenWithParents[unitID] = nil --removes units from lists when destroyed
	ignoreList[unitID] = nil
	initializeList[unitID] = nil
end