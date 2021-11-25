local bossAbilities = VFS.Include("luarules/gadgets/scavengers/BossFight/" .. Game.gameShortName .. "/abilities.lua")
local currentPhaseBossAbilities = {}

local function bossPhaseControl(bossHealthPercent)
	if bossHealthPercent >= 90 then
		BossFightCurrentPhase = 1
		currentPhaseBossAbilities = bossAbilities.Early
	elseif bossHealthPercent >= 80 then
		BossFightCurrentPhase = 2
		currentPhaseBossAbilities = bossAbilities.Midgame
	elseif bossHealthPercent >= 70 then
		BossFightCurrentPhase = 3
		currentPhaseBossAbilities = bossAbilities.Midgame
	elseif bossHealthPercent >= 60 then
		BossFightCurrentPhase = 4
		currentPhaseBossAbilities = bossAbilities.Midgame
	elseif bossHealthPercent >= 50 then
		BossFightCurrentPhase = 5
		currentPhaseBossAbilities = bossAbilities.Midgame
	elseif bossHealthPercent >= 40 then
		BossFightCurrentPhase = 6
		currentPhaseBossAbilities = bossAbilities.Midgame
	elseif bossHealthPercent >= 30 then
		BossFightCurrentPhase = 7
		currentPhaseBossAbilities = bossAbilities.Midgame
	elseif bossHealthPercent >= 20 then
		BossFightCurrentPhase = 8
		currentPhaseBossAbilities = bossAbilities.Endgame
	elseif bossHealthPercent >= 10 then
		BossFightCurrentPhase = 9
		currentPhaseBossAbilities = bossAbilities.Endgame
	else
		BossFightCurrentPhase = 10
		currentPhaseBossAbilities = bossAbilities.Endgame
	end
end

local function activatePassiveAbilities(currentFrame)
	return bossAbilities.Passive(currentFrame)
end

local specialAbilityCountdown = 10

local function activateAbility(currentFrame)
	local bossFightPreviousPhase = BossFightCurrentPhase
	bossFightPreviousPhase = bossFightPreviousPhase
	specialAbilityCountdown = specialAbilityCountdown - 1
	if specialAbilityCountdown <= 0 or bossFightPreviousPhase ~= BossFightCurrentPhase then
		local ability = currentPhaseBossAbilities[math_random(1,#currentPhaseBossAbilities)]
		if ability then
			specialAbilityCountdown = (20 - (BossFightCurrentPhase*2))
			ability(currentFrame)
		end
	end
end

return {
	UpdateFightPhase = bossPhaseControl,
	ActivatePassiveAbilities = activatePassiveAbilities,
	ActivateAbility = activateAbility,
}