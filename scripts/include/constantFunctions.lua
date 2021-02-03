-- Constants
local SFXTYPE_SMOKEPUFF = 256
local SFXTYPE_WHITESMOKE = 257
local SFXTYPE_BLACKSMOKE = 258
local SFXTYPE_SUBBUBBLES = 259
local DEFAULT_SMOKE_AMOUNT = 8

-- Useful functions --

-- Smoke function
function SmokeUnit(unitID, smokePiece, multiplier)
	multiplier = multiplier or DEFAULT_SMOKE_AMOUNT
	local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
	local spGetUnitPiecePosDir = Spring.GetUnitPiecePosDir
	
	if not (smokePiece and smokePiece[1]) then
		return
	end
	while (GetUnitValue(COB.BUILD_PERCENT_LEFT) ~= 0) do
		Sleep(400)
	end
	while true do
		local healthPercent = GetUnitValue(COB.HEALTH)
		if (healthPercent < 66) and not spGetUnitIsCloaked(unitID) then
			local p = smokePiece[math.random(1, #smokePiece)]
			local x, y, z = spGetUnitPiecePosDir(unitID, p)
			if y >= -40 then
				EmitSfx(p, SFXTYPE_BLACKSMOKE)
			else
				return
			end
		end
		Sleep((multiplier * healthPercent + math.random(100, 200)))
	end
end