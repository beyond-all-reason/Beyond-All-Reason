
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Objectify",
        desc      = "Handle objects and decorations",
        author    = "Bluestone, Floris",
        date      = "Feb 2015",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

--[[
	Handle objects and decorations
	- Objects are things like walls, and they still need to receive damage
	- Decorations are things like hats and xmas baubles an should be invulnerable
]]--

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitArmored = Spring.GetUnitArmored
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetSelectedUnits = Spring.GetSelectedUnits

local CMD_ATTACK = CMD.ATTACK
local CMD_MOVE = CMD.MOVE
local CMD_RECLAIM = CMD.RECLAIM
local CMD_REPAIR = CMD.REPAIR

local isBuilder = {}
local isObject = {}
local isClosedObject = {}
local isDecoration = {}
local canAttack = {}
local canMove = {}
local canReclaim = {}
local canRepair = {}
local unitSize = {}

for udefID,def in ipairs(UnitDefs) do
    if def.customParams.objectify then
        isObject[udefID] = true
    end
    if def.customParams.decoration then
        isDecoration[udefID] = true
    end
	if def.isBuilder then
		isBuilder[udefID] = true
	end
	unitSize[udefID] = { ((def.xsize*8)+8)/2, ((def.zsize*8)+8)/2 }

	-- NB: This is `true` for e.g. constructors if `canattack = false` is not set. -- todo
	-- Spring.Echo("ATTACK", UnitDefs[selectedID].name, UnitDefs[selectedID].canAttack)
	-- So add an additional check that the unit has any actual, effective weapons.
	if def.canAttack and def.maxWeaponRange > 0 then
		canAttack[udefID] = true
	end
	if def.canMove then
		canMove[udefID] = true
	end
	if def.canReclaim then
		canReclaim[udefID] = true
	end
	if def.canRepair then
		canRepair[udefID] = true
	end
	if def.customParams.decoyfor and def.customParams.neutral_when_closed then
		local coy = UnitDefNames[def.customParams.decoyfor]
		if coy ~= nil and coy.customParams.objectify then
			isClosedObject[udefID] = true
		end
	end
end

if gadgetHandler:IsSyncedCode() then

	local numDecorations = 0
	local numObjects = 0

	function gadget:Initialize()
		gadgetHandler:RegisterAllowCommand(CMD.ATTACK)
		gadgetHandler:RegisterAllowCommand(CMD.BUILD)
		for _, unitID in pairs(Spring.GetAllUnits()) do
			gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
		end
	end

	local function objectifyUnit(unitID)
		Spring.SetUnitNeutral(unitID, true)
		Spring.SetUnitStealth(unitID, true)
		Spring.SetUnitSonarStealth(unitID, true)
		Spring.SetUnitBlocking(unitID, true, true, true, true, true, true, false) -- set as crushable
		--for weaponID, _ in pairs(UnitDefs[spGetUnitDefID(unitID)].weapons) do
		--	Spring.UnitWeaponHoldFire(unitID, weaponID)
		--end
	end

	local function decorationUnit(unitID)
		Spring.SetUnitNeutral(unitID, true)
		Spring.SetUnitStealth(unitID, true)
		Spring.SetUnitSonarStealth(unitID, true)
		Spring.SetUnitBlocking(unitID, true, true, false, false, true, false, false)
		for weaponID, _ in pairs(UnitDefs[spGetUnitDefID(unitID)].weapons) do
			Spring.UnitWeaponHoldFire(unitID, weaponID)
		end
		Spring.SetUnitNoSelect(unitID, true)
		Spring.SetUnitNoMinimap(unitID, true)
		Spring.SetUnitIconDraw(unitID, false)
		Spring.SetUnitSensorRadius(unitID, 'los', 0)
		Spring.SetUnitSensorRadius(unitID, 'airLos', 0)
		Spring.SetUnitSensorRadius(unitID, 'radar', 0)
		Spring.SetUnitSensorRadius(unitID, 'sonar', 0)
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		if isDecoration[unitDefID] then
			numDecorations = numDecorations - 1
		end
		if isObject[unitDefID] then
			numObjects = numObjects - 1
		end
	end

    function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
		if isDecoration[unitDefID] then
			numDecorations = numDecorations + 1
			decorationUnit(unitID)
		end
		if isObject[unitDefID] then
			numObjects = numObjects + 1
			objectifyUnit(unitID)
		end
    end

    function gadget:UnitGiven(unitID, unitDefID, oldTeam, newTeam)
        if isObject[unitDefID] then
            objectifyUnit(unitID)
        end
    end

    function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if isDecoration[unitDefID] then
			return 0, 0
		elseif isObject[unitDefID] and not paralyzer then
            local _,maxHealth,_,_,buildProgress = Spring.GetUnitHealth(unitID)
            if buildProgress and maxHealth and buildProgress < 1 then
                return (damage/100)*maxHealth, nil
            end
        end
        return damage, nil
    end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		if cmdID and (numObjects > 0 or numDecorations > 0) then
			-- prevents area targetting
			if cmdID == CMD_ATTACK then
				if cmdParams and #cmdParams == 1 then
					local uDefID = spGetUnitDefID(cmdParams[1])
					if isDecoration[uDefID] then
						return false
					end
				end

			-- remove any decoration that is blocking a queued build order
			elseif cmdID < 0 and numDecorations > 0 then
				if cmdParams[3] and isBuilder[unitDefID] then
					local udefid = math.abs(cmdID)
					local units = Spring.GetUnitsInBox(cmdParams[1]-unitSize[udefid][1],cmdParams[2]-200,cmdParams[3]-unitSize[udefid][2],cmdParams[1]+unitSize[udefid][1],cmdParams[2]+50,cmdParams[3]+unitSize[udefid][2])
					for i=1, #units do
						if isDecoration[spGetUnitDefID(units[i])] then
							if Spring.GetUnitIsDead(units[i]) == false then
								Spring.DestroyUnit(units[i], false, true)
							end
						end
					end
				end
			end
		end
		return true
	end


else -- UNSYNCED


	local myAllyTeam = Spring.GetMyAllyTeamID()
	local spectating = Spring.GetSpectatingState()
	function gadget:PlayerChanged(playerID)
		myAllyTeam = Spring.GetMyAllyTeamID()
		spectating = Spring.GetSpectatingState()
	end

	-- Don't auto-guard units like walls and don't reveal enemy decoys:
	local function getUnitHoverCommand(unitID, unitDefID, fromCommand)
		local objectUnit = isObject[unitDefID]
		local decoyState = isClosedObject[unitDefID] and spGetUnitArmored(unitID) ~= false
		local decorative = isDecoration[unitDefID]
		local beingBuilt = not decorative and spGetUnitIsBeingBuilt(unitID)
		local inAlliance = decorative or spAreTeamsAllied(spGetUnitAllyTeam(unitID), myAllyTeam)

		if not beingBuilt then
			if inAlliance then
				if objectUnit and fromCommand == CMD_GUARD then
					return CMD_MOVE
				end
			elseif not decorative and not objectUnit and not decoyState then
				local selected = spGetSelectedUnits()
				local canAttackInSelect = false
				-- Limit the search somewhat. Gadgets don't have g:UpdateSelection.
				-- This could be more efficient but is not especially costly as-is.
				for i = 1, math.min(64, #selected) do
					local selectedID = spGetUnitDefID(selected[i])
					if canMove[selectedID] then
						return CMD_MOVE
					elseif not canAttackInSelect and canAttack[selectedID] then
						canAttackInSelect = true
					end
				end
				if canAttackInSelect then
					return CMD_ATTACK
				end
			end
		end
	end

    function gadget:DefaultCommand(type, id, cmd)
		if type == "unit" and not spectating then
			return getUnitHoverCommand(id, spGetUnitDefID(id), cmd)
		end
    end

end
