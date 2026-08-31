
local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local TechTier = VFS.Include("modules/tech/tier.lua")
local Stages = VFS.Include("modules/tech/policy_stages.lua") ---@type TechPolicyStages

---@class TechUnlock
---@field unlockLevel integer
---@field unlockThreshold number
---@field unlockValue string|number|boolean

---@class TechBlockingContext
---@field level integer
---@field points number
---@field t2Threshold number
---@field t3Threshold number
---@field nextLevel integer
---@field nextThreshold number
---@field unitTransfer TechUnlock|nil
---@field metalTransfer TechUnlock|nil
---@field energyTransfer TechUnlock|nil

---@class TechCoreLadder
---@field modes string[]
---@field taxRate number|nil
---@field blocking TechBlockingContext

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

Policies.Pipeline(Stages.tech_core).Select(Stages.tech_core.TechCoreLadder, function(request)
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
