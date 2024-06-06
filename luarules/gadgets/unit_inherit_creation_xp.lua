function gadget:GetInfo()
	return {
		name = "Inherit Creation Units XP",
		desc = "Allows units with added UnitDefs to gain a defined fraction of the XP earned by their creations.",
		author = "SethDGamre and Xehrath",
		date = "May 2024",
		license = "Public domain",
		layer = 0,
		enabled = false
	}
end

-- synced only
if not gadgetHandler:IsSyncedCode() then return false end

--**********unit customparams to add to unitdef***********
-- inheritxpratemultiplier = 1, 	-- defined in unitdef customparams of the parent unit. It's a number by which XP gained by children is multiplied and passed to the parent after power difference calculations
-- childreninheritxp = "MOBILEBUILT DRONE BOTCANNON", --  determines what kinds of units linked to parent inherit XP
-- parentsinheritxp = "MOBILEBUILT DRONE BOTCANNON", -- determines what kinds of units linked to the parent will give the parent XP

local inheritChildrenXP = {} -- stores the value of XP rate to be derived from unitdef
local childrenInheritXP = {} -- stores the string that represents the types of units that will inherit the parent's XP when created
local parentsInheritXP = {} -- stores the string that represents the types of units the parent will gain xp from
local childrenWithParents = {} --stores the parent/child relationships format. Each entry stores key of unitID with an array of {unitID, builderID, xpInheritance}
local mobileUnits = {}
local unitPowerDefs = {}
local unitsList = {}

for id, def in pairs(UnitDefs) do
	if def.customParams.inheritxpratemultiplier then
		inheritChildrenXP[id] = def.customParams.inheritxpratemultiplier or 1
	end
	if def.customParams.parentsinheritxp then
		parentsInheritXP[id] = def.customParams.parentsinheritxp or " "
	else parentsInheritXP[id] = " "
	end
	if def.customParams.childreninheritxp then
		childrenInheritXP[id] = def.customParams.childreninheritxp or " "
	else childrenInheritXP[id] = " "
	end
	if def.speed and def.speed ~= 0 then
		mobileUnits[id] = true
	end
	if def.power then
	unitPowerDefs[id] = def.power
	end
end

if table.count(inheritChildrenXP) <= 0 then -- this enables or disables the gadget
	return false
end

local function calculatePowerDiffXP(childID, parentID) -- this function calculates the right proportion of XP to inherit from child as though they were attacking the target themself.
	local childDefID = Spring.GetUnitDefID(childID)
	local parentDefID = Spring.GetUnitDefID(parentID)
	local childPower =  unitPowerDefs[childDefID]
	local parentPower = unitPowerDefs[parentDefID]
	return (childPower/parentPower)*inheritChildrenXP[parentDefID]
end

local initializeList = {}
local ignoreList = {}
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if  builderID and mobileUnits[Spring.GetUnitDefID(unitID)] and string.find(parentsInheritXP[Spring.GetUnitDefID(builderID)], "MOBILEBUILT") then -- only mobile combat units will pass xp
			childrenWithParents[unitID] = {
				unitid=unitID,
				parentunitid=builderID,
				parentxpmultiplier=calculatePowerDiffXP(unitID, builderID),
				childinheritsXP = childrenInheritXP[Spring.GetUnitDefID(unitID)],
				childtype = "MOBILEBUILT",
			}
	end
	unitsList[unitID] = true
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	initializeList[unitID] = true --must initialize after finishing building otherwise child XP inheritance won't happen
end

local xpGainParents = {} --stores the unitID's of parents that inherit xp
local lastRunFrame = 0
local oldChildXPValues = {}
function gadget:GameFrame(frame)
	if frame > (lastRunFrame + 30) then
		for unitID, value in pairs(unitsList) do
			local parentID
			if not ignoreList[unitID] then
				if initializeList[unitID] == true then -- check for parenthood
					local unitDefID = Spring.GetUnitDefID(unitID)
					local parentDefID
					if Spring.GetUnitRulesParam(unitID, "carrier_host_unit_id") then --estabalishes unit_carrier_spawner parenthood
						parentID = Spring.GetUnitRulesParam(unitID, "carrier_host_unit_id")
						parentDefID = Spring.GetUnitDefID(parentID)
						if parentsInheritXP[parentDefID] ~= nil and string.find(parentsInheritXP[parentDefID], "DRONE") then
							childrenWithParents[unitID] = {
								unitid = unitID,
								parentunitid = parentID,
								parentxpmultiplier = calculatePowerDiffXP(unitID, parentID),
								childinheritsXP = childrenInheritXP[unitDefID],
								childtype = "DRONE",
							}
						end
					end
					if Spring.GetUnitRulesParam(unitID, "parent_unit_id") then --estabalishes unit_explosion_spawner parenthood
						parentID = Spring.GetUnitRulesParam(unitID, "parent_unit_id")
						parentDefID = Spring.GetUnitDefID(parentID)
						if parentsInheritXP[parentDefID] ~= nil and string.find(parentsInheritXP[parentDefID], "BOTCANNON") then
							childrenWithParents[unitID] = {
								unitid = unitID,
								parentunitid = parentID,
								parentxpmultiplier = calculatePowerDiffXP(unitID, parentID),
								childinheritsXP = childrenInheritXP[unitDefID],
								childtype = "BOTCANNON",
							}
						end
					end
					if childrenWithParents[unitID] then
						parentID = childrenWithParents[unitID].parentunitid --sets parentID if it's not already set
						parentDefID = Spring.GetUnitDefID(parentID) -- gets the parentDefID
					end
					if parentID ~= nil and childrenInheritXP[parentDefID] and childrenWithParents[unitID] then --if the parent has the unitdef, set childxp to parent xp.
						local parentTypes = childrenInheritXP[parentDefID]
						if string.find(parentTypes, childrenWithParents[unitID].childtype) then -- if child is correcty type, set xp
							local parentXP = Spring.GetUnitExperience(parentID)
							Spring.SetUnitExperience(unitID, parentXP)
							oldChildXPValues[unitID] = parentXP	--add parent xp to the oldxp value to exclude it from inheritance
						end
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
					local gainedXP = (parentXP*10000000 + ((newXP-oldXP)*10000000*multiplier))/10000000 --10000000 is to prevent very small numbers being lost during calculation
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
