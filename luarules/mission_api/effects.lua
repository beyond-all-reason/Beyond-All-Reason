---
--- Status effects, which deal damage, modify unit attributes, and apply other state changes.
---
--- Each effect in luarules/mission_api/effects/ implements Create(area, strength):id and Remove(id).
--- A nil area resolves to the whole map. Each effect determines what its "strength" value does.
---

local function secondsToFrames(seconds)
	return math.floor(seconds * Game.gameSpeed + 0.5)
end

local function clearAppliedEffect(effectName, appliedEffect)
	GG["MissionAPI"].effectNames[effectName] = nil
	GG["MissionAPI"].EffectDefinitions.Effects[appliedEffect.effectType].Remove(appliedEffect.instanceID)
end

local function applyEffect(effectType, effectName, area, duration, strength)
	local effectNames = GG["MissionAPI"].effectNames
	local previous = effectNames[effectName]
	if previous then
		clearAppliedEffect(effectName, previous)
	end

	local effect = GG["MissionAPI"].EffectDefinitions.Effects[effectType]
	effectNames[effectName] = {
		effectType = effectType,
		instanceID = effect.Create(area, strength),
		endFrame = duration and Spring.GetGameFrame() + secondsToFrames(duration) or nil,
	}
end

local function clearEffect(effectName)
	local appliedEffect = GG["MissionAPI"].effectNames[effectName]
	if appliedEffect then
		clearAppliedEffect(effectName, appliedEffect)
	end
end

local function clearExpiredEffects(frameNumber)
	for effectName, appliedEffect in pairs(GG["MissionAPI"].effectNames) do
		if appliedEffect.endFrame and frameNumber >= appliedEffect.endFrame then
			clearAppliedEffect(effectName, appliedEffect)
		end
	end
end

return {
	ApplyEffect = applyEffect,
	ClearEffect = clearEffect,
	ClearExpiredEffects = clearExpiredEffects,
}
