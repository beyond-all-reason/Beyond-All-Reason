local SMOKE = 258
local random = math.random


function dmgsmoke(dmgPieces)
	local n = #dmgPieces
	while (GetUnitValue(COB.BUILD_PERCENT_LEFT) ~= 0) do
		Sleep(1000)
	end
	while true do
		local health = GetUnitValue(COB.HEALTH)
		if (health <= 50) then
			EmitSfx(dmgPieces[random(1,n)], SMOKE)
		end
		Sleep(9*health + random(100,200))
	end
end