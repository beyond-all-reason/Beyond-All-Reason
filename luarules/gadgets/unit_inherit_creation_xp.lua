local gadget = gadget ---@type Gadget

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

--**********unit customparams to add to unitdef***********
-- inheritxpratemultiplier = 1, 	-- defined in unitdef customparams of the parent unit. It's a number by which XP gained by children is multiplied and passed to the parent after power difference calculations
-- childreninheritxp = "TURRET MOBILEBUILT DRONE BOTCANNON", --  determines what kinds of units linked to parent inherit XP
-- parentsinheritxp = "TURRET MOBILEBUILT DRONE BOTCANNON", -- determines what kinds of units linked to the parent will give the parent XP

local spGetUnitExperience = Spring.GetUnitExperience
local spSetUnitExperience = Spring.SetUnitExperience
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitDefID = Spring.GetUnitDefID

local inheritChildrenXP = {} -- stores the value of XP rate to be derived from unitdef
local inheritCreationXP = {} -- multiplier of XP to inherit to newly created units, indexed by unitID
local childrenInheritXP = {} -- stores the string that represents the types of units that will inherit the parent's XP when created
local parentsInheritXP = {} -- stores the string that represents the types of units the parent will gain xp from
local childrenWithParents = {} --stores the parent/child relationships format. Each entry stores key of unitID with an array of {unitID, builderID, xpInheritance}
local mobileUnits = {}
local turretUnits = {}
local unitPowerDefs = {}

for id, def in pairs(UnitDefs) do
	if def.customParams.inheritxpratemultiplier then
		inheritChildrenXP[id] = def.customParams.inheritxpratemultiplier or 1
	end
	if def.customParams.inheritcreationxpmultiplier then
		inheritCreationXP[id] = def.customParams.inheritcreationxpmultiplier or 1
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
	if def.speed == 0 and def.weapons and def.weapons[1] then
		for i = 1, #def.weapons do
			local wDef = WeaponDefs[def.weapons[i].weaponDef]
			if wDef.type ~= "Shield" then
				turretUnits[id] = true
				break
			end
		end
	end
	if def.power then
		unitPowerDefs[id] = def.power
	end
end

if table.count(inheritChildrenXP) <= 0 then -- this enables or disables the gadget
	return false
end

local function calculatePowerDiffXP(childID, parentID) -- this function calculates the right proportion of XP to inherit from child as though they were attacking the target themself.
	local childDefID = spGetUnitDefID(childID)
	local parentDefID = spGetUnitDefID(parentID)
	local childPower =  unitPowerDefs[childDefID]
	local parentPower = unitPowerDefs[parentDefID]
	return (childPower/parentPower)*inheritChildrenXP[parentDefID]
end

local initializeList = {}
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if  builderID and mobileUnits[spGetUnitDefID(unitID)] and string.find(parentsInheritXP[spGetUnitDefID(builderID)], "MOBILEBUILT") then -- only mobile combat units will pass xp
		childrenWithParents[unitID] = {
			unitid = unitID,
			parentunitid = builderID,
			parentxpmultiplier = calculatePowerDiffXP(unitID, builderID),
			childinheritsXP = childrenInheritXP[spGetUnitDefID(unitID)],
			childtype = "MOBILEBUILT",
		}
	end
	if  builderID and turretUnits[spGetUnitDefID(unitID)] and string.find(parentsInheritXP[spGetUnitDefID(builderID)], "TURRET") then -- only immobile combat units will pass xp
		childrenWithParents[unitID] = {
			unitid = unitID,
			parentunitid = builderID,
			parentxpmultiplier = calculatePowerDiffXP(unitID, builderID),
			childinheritsXP = childrenInheritXP[spGetUnitDefID(unitID)],
			childtype = "TURRET",
		}
end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	initializeList[unitID] = true --must initialize after finishing building otherwise child XP inheritance won't happen
end

local oldChildXPValues = {}
function gadget:GameFrame(frame)
	if frame%30 == 0 then
		local parentID
		for unitID, value in pairs(initializeList) do
			local unitDefID = spGetUnitDefID(unitID)
			local parentDefID
			if spGetUnitRulesParam(unitID, "carrier_host_unit_id") then --estabalishes unit_carrier_spawner parenthood
				parentID = spGetUnitRulesParam(unitID, "carrier_host_unit_id")
				parentDefID = spGetUnitDefID(parentID)
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
			if spGetUnitRulesParam(unitID, "parent_unit_id") then --estabalishes unit_explosion_spawner parenthood
				parentID = spGetUnitRulesParam(unitID, "parent_unit_id")
				parentDefID = spGetUnitDefID(parentID)
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
				parentDefID = spGetUnitDefID(parentID) -- gets the parentDefID
			end
			if parentID ~= nil and childrenInheritXP[parentDefID] and childrenWithParents[unitID] then --if the parent has the unitdef, set childxp to parent xp.
				local parentTypes = childrenInheritXP[parentDefID]
				if string.find(parentTypes, childrenWithParents[unitID].childtype) then -- if child is correct type, set xp
					local parentXP = spGetUnitExperience(parentID)
					spSetUnitExperience(unitID, parentXP)
					oldChildXPValues[unitID] = parentXP --add parent xp to the oldxp value to exclude it from inheritance
					local initMult = inheritCreationXP[parentDefID] or 1
					local childInitXP = parentXP * initMult
					spSetUnitExperience(unitID, childInitXP)
					oldChildXPValues[unitID] = childInitXP  --add parent xp to the oldxp value to exclude it from inheritance
				end
			end

			initializeList[unitID] = nil -- this concludes innitialization
		end


		for unitID, value in pairs(childrenWithParents) do
			local oldXP = oldChildXPValues[unitID] or 0
			local newXP = spGetUnitExperience(unitID) or 0
			if newXP > oldXP then
				parentID = childrenWithParents[unitID].parentunitid
				local parentXP = spGetUnitExperience(parentID) or 0
				local multiplier = childrenWithParents[unitID].parentxpmultiplier
				local gainedXP = parentXP+((newXP-oldXP)*multiplier)
				oldChildXPValues[unitID] = newXP
				spSetUnitExperience(parentID, gainedXP)
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)

	local evoID = Spring.GetUnitRulesParam(unitID, "unit_evolved")
	if evoID then
		for id, data in pairs(childrenWithParents) do
			if data.parentunitid == unitID then
				data.parentunitid = evoID
				data.parentxpmultiplier = calculatePowerDiffXP(id, evoID)
			end
		end
	end
	childrenWithParents[unitID] = nil --removes units from lists when destroyed
	initializeList[unitID] = nil
end
