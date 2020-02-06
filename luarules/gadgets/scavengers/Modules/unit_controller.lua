Spring.Echo("[Scavengers] Unit Controller initialized")

VFS.Include("luarules/gadgets/scavengers/Configs/"..GameShortName.."/UnitLists/staticunits.lua")

function SelfDestructionControls(n, scav, scavDef)
	UnitRange = {}
	local _,_,_,_,buildProgress = Spring.GetUnitHealth(scav)
	if buildProgress == 1 then
		if selfdx[scav] then
			oldselfdx[scav] = selfdx[scav]
		end
		if selfdy[scav] then
			oldselfdy[scav] = selfdy[scav]
		end
		if selfdz[scav] then
			oldselfdz[scav] = selfdz[scav]
		end
		selfdx[scav],selfdy[scav],selfdz[scav] = Spring.GetUnitPosition(scav)
		if UnitDefs[scavDef].maxWeaponRange + 200 < 800 then
			UnitRange[scav] = 2000
		else
			UnitRange[scav] = UnitDefs[scavDef].maxWeaponRange + 200
		end
		local nearestselfd = Spring.GetUnitNearestEnemy(scav, UnitDefs[scavDef].maxWeaponRange + 200, false)
		if not nearestselfd and (oldselfdx[scav] and oldselfdy[scav] and oldselfdz[scav]) and (oldselfdx[scav] > selfdx[scav]-10 and oldselfdx[scav] < selfdx[scav]+10) and (oldselfdy[scav] > selfdy[scav]-10 and oldselfdy[scav] < selfdy[scav]+10) and (oldselfdz[scav] > selfdz[scav]-10 and oldselfdz[scav] < selfdz[scav]+10) then
			Spring.DestroyUnit(scav, true, false)
		end
	end
	UnitRange[scav] = nil
end
				
function ArmyMoveOrders(n, scav, scavDef)
	UnitRange = {}
	if UnitDefs[scavDef].maxWeaponRange and UnitDefs[scavDef].maxWeaponRange > 10 then
		UnitRange[scav] = UnitDefs[scavDef].maxWeaponRange
	else
		UnitRange[scav] = 10
	end
	local nearest = Spring.GetUnitNearestEnemy(scav, 200000, false)
	local x,y,z = Spring.GetUnitPosition(nearest)
	local range = UnitRange[scav]
	local x = x + math.random(-range,range)
	local z = z + math.random(-range,range)
	if UnitDefs[scavDef].canFly or (UnitRange[scav] > unitControllerModuleConfig.minimumrangeforfight) then
		Spring.GiveOrderToUnit(scav, CMD.FIGHT,{x,y,z}, {"shift", "alt", "ctrl"})
	else
		Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift", "alt", "ctrl"})
	end		
end