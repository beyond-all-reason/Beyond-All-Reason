function widget:GetInfo()
return {
	name      = "91 Hotness fix",
	version   = "0.1",
	desc      = "Fixes nuke not firing when aimed before missile is ready",
	author    = "Pako",
	date      = "2012.09.04", --YYYY.MM.DD, created - updated
	license   = "GPL",
	layer     = 0,	--higher layer is loaded last 
	enabled   = true
}
end


function widget:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	Spring.GiveOrderToUnit(unitID, CMD.WAIT, {},{})
	Spring.GiveOrderToUnit(unitID, CMD.WAIT, {},{})
end