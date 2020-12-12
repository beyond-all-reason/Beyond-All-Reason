
-- phase control
function ScavBossPhaseControl(bosshealthpercentage)
	if bosshealthpercentage >= 90 then
		BossFightCurrentPhase = 1
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesEarlyList
	elseif bosshealthpercentage >= 80 then
		BossFightCurrentPhase = 2
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesMidgameList
	elseif bosshealthpercentage >= 70 then
		BossFightCurrentPhase = 3
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesMidgameList
	elseif bosshealthpercentage >= 60 then
		BossFightCurrentPhase = 4
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesMidgameList
	elseif bosshealthpercentage >= 50 then
		BossFightCurrentPhase = 5
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesMidgameList
	elseif bosshealthpercentage >= 40 then
		BossFightCurrentPhase = 6
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesMidgameList
	elseif bosshealthpercentage >= 30 then
		BossFightCurrentPhase = 7
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesMidgameList
	elseif bosshealthpercentage >= 20 then
		BossFightCurrentPhase = 8
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesEndgameList
	elseif bosshealthpercentage >= 10 then
		BossFightCurrentPhase = 9
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesEndgameList
	else
		BossFightCurrentPhase = 10
		BossSpecialAbilitiesUsedList = BossSpecialAbilitiesEndgameList
	end
end

BossSpecialAbilitiesEarlyList = {}
BossSpecialAbilitiesMidgameList = {}
BossSpecialAbilitiesEndgameList = {}

VFS.Include("luarules/gadgets/scavengers/BossFight/"..GameShortName.."/abilities.lua")