--- The tech_core tier scheme: what a team's tier unlocks under it, and what
--- it would unlock next.
---
--- This is ONE scheme, not the definition of tech. What is general lives in
--- tier.lua — resolve an _at_t2/_at_t3 variant for a level — and what is
--- tech_core's is here: that the ladder is three tiers, that it gates unit
--- sharing and the resource tax, and that a tier is reached by points. A
--- different scheme (flat tiers, per-unit unlocks, no tax coupling) is
--- another file beside this one, and the mode preset picks which applies.
---
--- Tech does not decide what a transfer costs — transfer does. Tech decides
--- which tier a team is at, and therefore which variant of a setting applies,
--- plus the progression a UI can promise ("share opens at T2"). Both answers
--- come out of one record, computed once per team per cache update rather
--- than per lookup.
---
--- Pure: everything it needs arrives in the request, so it specs without
--- Spring and a mode preset can be asked what it would unlock without a game
--- running.

local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local TechTier = VFS.Include("modules/tech/tier.lua")

local NONE = ModeEnums.UnitFilterCategory.None

---@param request TechTierRequest
---@param baseKey string
---@param currentValue any
---@param normalize fun(v: any): any
---@return TechUnlock|nil
local function nextProgression(request, baseKey, currentValue, normalize)
	for scanLevel = request.level + 1, 3 do
		local futureValue = TechTier.resolveByTechLevel(request.opts, baseKey, scanLevel)
		if futureValue ~= nil and futureValue ~= "" and normalize(futureValue) ~= currentValue then
			local threshold = scanLevel == 2 and request.t2Threshold or request.t3Threshold
			return { unlockLevel = scanLevel, unlockThreshold = threshold, unlockValue = futureValue }
		end
	end
	return nil
end

---The unit-sharing modes active at this tier: the base mode plus every tier
---variant the team has reached. None of them set means sharing is off.
---@param request TechTierRequest
---@return string[]
local function activeModes(request)
	local opts, modes = request.opts, {}
	local base = opts.unit_sharing_mode
	if base and base ~= "" and base ~= NONE then
		modes[#modes + 1] = base
	end
	for _, tier in ipairs({ 2, 3 }) do
		local mode = opts["unit_sharing_mode_at_t" .. tier]
		if request.level >= tier and mode and mode ~= "" then
			modes[#modes + 1] = mode
		end
	end
	if #modes == 0 then
		modes = { NONE }
	end
	return modes
end

Policies.Pipeline()
	:Compute("TechCoreLadder", function(request)
		local currentTax = tonumber(TechTier.resolveByTechLevel(request.opts, "tax_resource_sharing_amount", request.level))
		local taxUnlock = nextProgression(request, "tax_resource_sharing_amount", currentTax, tonumber)
		local unitUnlock = nil
		for scanLevel = request.level + 1, 3 do
			local nextMode = request.opts["unit_sharing_mode_at_t" .. scanLevel]
			if nextMode and nextMode ~= "" then
				local threshold = scanLevel == 2 and request.t2Threshold or request.t3Threshold
				unitUnlock = { unlockLevel = scanLevel, unlockThreshold = threshold, unlockValue = nextMode }
				break
			end
		end
		local nextLevel = request.level < 2 and 2 or 3
		return {
			modes = activeModes(request),
			taxRate = currentTax,
			blocking = {
				level = request.level,
				points = request.points,
				t2Threshold = request.t2Threshold,
				t3Threshold = request.t3Threshold,
				nextLevel = nextLevel,
				nextThreshold = nextLevel == 2 and request.t2Threshold or request.t3Threshold,
				unitTransfer = unitUnlock,
				-- One tax modoption feeds both, so both promise the same unlock.
				metalTransfer = taxUnlock,
				energyTransfer = taxUnlock,
			},
		}
	end)
	:Register()
