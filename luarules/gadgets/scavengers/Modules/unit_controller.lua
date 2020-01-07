Spring.Echo("[Scavengers] Unit Controller initialized")

VFS.Include("luarules/gadgets/scavengers/Configs/"..GameShortName.."/UnitLists/staticunits.lua")	

function SelfDestructionControls(n, scav)
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
	if (oldselfdx[scav] and oldselfdy[scav] and oldselfdz[scav]) and (oldselfdx[scav] > selfdx[scav]-10 and oldselfdx[scav] < selfdx[scav]+10) and (oldselfdy[scav] > selfdy[scav]-10 and oldselfdy[scav] < selfdy[scav]+10) and (oldselfdz[scav] > selfdz[scav]-10 and oldselfdz[scav] < selfdz[scav]+10) then
		Spring.DestroyUnit(scav, true, false)
	end
end
				
function ArmyMoveOrders(n, scav)
	local nearest = Spring.GetUnitNearestEnemy(scav, 200000, false)
	local x,y,z = Spring.GetUnitPosition(nearest)
	local x = x + math.random(-50,50)
	local z = z + math.random(-50,50)
	Spring.GiveOrderToUnit(scav, CMD.FIGHT,{x,y,z}, {"shift", "alt", "ctrl"})
end