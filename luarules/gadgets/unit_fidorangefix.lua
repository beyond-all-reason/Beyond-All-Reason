
function gadget:GetInfo()
	return {
		name 	= "Ranges Fix",
		desc	= "Makes sure the unit's maxRange fits its weapons",
		author	= "Doo",
		date	= "01/09/2018",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled = false,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local CMD_ONOFF = CMD.ONOFF
local CMD_WAIT = CMD.WAIT

local isFido = {}
local Ranges = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if string.sub(unitDef.name, 1,7) == 'armfido' then
		local hplasmarange = ((WeaponDefs[unitDef.weapons[1].weaponDef].projectilespeed*30) ^2 ) / Game.gravity
		if hplasmarange >= WeaponDefs[unitDef.weapons[1].weaponDef].range then
			hplasmarange = WeaponDefs[unitDef.weapons[1].weaponDef].range
		end
		isFido[unitDefID] = {WeaponDefs[unitDef.weapons[1].weaponDef].range, hplasmarange}
	end
	local maxRange = 0
	local maxAARange = 0
	local weapons = unitDef.weapons
	for i=1, #weapons do
		local wDef = WeaponDefs[weapons[i].weaponDef]
		if wDef.range >= maxRange and wDef.canAttackGround == true then
			maxRange = wDef.range
		elseif wDef.range >= maxAARange and not wDef.canAttackGround == true then
			maxAARange = wDef.range
		end
	end
	if maxRange ~= 0 then
		Ranges[unitDefID] = maxRange
	else
		Ranges[unitDefID] = maxAARange
	end
	if unitDef.customParams.customrange then
		Ranges[unitDefID] = tonumber(unitDef.customParams.customrange)
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if isFido[unitDefID] then
		Spring.SetUnitWeaponState(unitID, 1, "range", isFido[unitDefID][2])
		Spring.SetUnitMaxRange(unitID, isFido[unitDefID][1])
		return
	end
	if Ranges[unitDefID] then
		Spring.SetUnitMaxRange(unitID, Ranges[unitDefID])
		return
	end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdOpts, cmdParams, cmdTag, playerID, fromSynced, fromLua)
	if isFido[unitDefID] then
		if cmdID == CMD_ONOFF then
			if cmdParams and cmdOpts[1] == 0 then -- DESACTIVATE (GAUSS)
				Spring.SetUnitWeaponState(unitID, 2, "range", 0)
				Spring.SetUnitWeaponState(unitID, 1, "range", isFido[unitDefID][1])
				Spring.SetUnitMaxRange(unitID, isFido[unitDefID][1])
			elseif cmdParams and cmdOpts[1] == 1 then -- ACTIVATE (HEAVY PLASMA)
				Spring.SetUnitWeaponState(unitID, 2, "range", isFido[unitDefID][2])
				Spring.SetUnitWeaponState(unitID, 1, "range", isFido[unitDefID][2])
				Spring.SetUnitMaxRange(unitID, isFido[unitDefID][2])
			end
			Spring.GiveOrderToUnit(unitID, CMD_WAIT, {}, 0)
			Spring.GiveOrderToUnit(unitID, CMD_WAIT, {}, 0)
		end
	end
end
