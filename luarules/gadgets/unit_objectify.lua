
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

local isBuilder = {}
local unitSize = {}
local isObject = {}
local isDecoration = {}
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
end


if gadgetHandler:IsSyncedCode() then

	local numDecorations = 0
	local numObjects = 0

	local CMD_ATTACK = CMD.ATTACK
	local spGetUnitDefID = Spring.GetUnitDefID

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
				if cmdParams[3] and isBuilder[spGetUnitDefID(unitID)] then
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


    local CMD_MOVE = CMD.MOVE
    local spGetUnitDefID = Spring.GetUnitDefID

    function gadget:DefaultCommand(type, id, cmd)
		if type == "unit" and cmd ~= CMD_MOVE then
			local uDefID = spGetUnitDefID(id)
			if isObject[uDefID] or isDecoration[uDefID] then
				-- make sure a command given on top of a objectified/decoration unit is a move command
				if select(4, Spring.GetUnitHealth(id)) == 1 then
					return CMD_MOVE
				end
			end
		end
    end

end

