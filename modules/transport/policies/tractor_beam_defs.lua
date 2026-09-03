local Defs = VFS.Include("modules/defs/contract.lua") ---@type DefsContract
local Contract = VFS.Include("modules/transport/contract.lua") ---@type TransportContract

-- Fx-Doo's tractor beam transports: a ruleset per beta_tractorbeam value
-- rewrites the carriers (script, model, seats) and stamps every passenger's
-- seat cost. It runs before the base game's post, as it did inside it.

local rulesets = {} ---@type table<string, table>

---@param modOptions table
---@return table|nil the ruleset for the option, nil while tractor beams are off
local function rulesetFor(modOptions)
	local mode = modOptions.beta_tractorbeam
	if mode == nil or mode == "disabled" then
		return nil
	end
	local ruleset = rulesets[mode]
	if ruleset == nil then
		local defs = VFS.Include("modules/transport/tractor_beams/transporter_defs_" .. mode .. ".lua")
		ruleset = {
			transporters = defs.transporters or {},
			transporterDefaults = defs.transporterDefaults or {},
			passengerSizes = defs.passengerSizes or {},
			labBuildoptions = defs.labBuildoptions or {},
			known = {}, -- every transporter the ruleset manages, scrubbed from lab buildoptions
		}
		for name in pairs(ruleset.transporters) do
			ruleset.known[name] = true
		end
		rulesets[mode] = ruleset
	end
	return ruleset
end

-- Convert a raw passengersize float to (nseats, oversized) where nseats is the nearest
-- lower power-of-2 and oversized is "1" (1.5× weight) or "-1" (0.5× weight) when needed.
local function passengerSizeToParams(size)
	if size == 0.5 then
		return 1, "-1"
	end -- 1 * 0.5
	if size == 1 then
		return 1, nil
	end
	if size == 1.5 then
		return 1, "1"
	end -- 1 * 1.5
	if size == 2 then
		return 2, nil
	end
	if size == 3 then
		return 2, "1"
	end -- 2 * 1.5
	if size == 4 then
		return 4, nil
	end
	if size == 6 then
		return 4, "1"
	end -- 4 * 1.5
	if size == 8 then
		return 8, nil
	end
	if size == 16 then
		return 16, nil
	end
	-- generic fallback: floor to nearest power-of-2
	local p = 1
	while p * 2 <= size do
		p = p * 2
	end
	if size == p * 1.5 then
		return p, "1"
	elseif size == p * 0.5 then
		return p / 2, "1" -- shouldn't happen with known values
	else
		return p, nil
	end
end

Policies.Pipeline(Defs.UnitDef)
	.Select(Contract.UnitDef.TractorBeams, function(ctx)
		local ruleset = rulesetFor(ctx.modOptions)
		if ruleset == nil then
			return
		end
		-- apply transporter overrides
		local tentry = ruleset.transporters[ctx.name]
		if tentry then
			-- apply shared defaults
			for k, v in pairs(ruleset.transporterDefaults) do
				ctx.def[k] = v
			end
			ctx.def.objectname = "units/" .. ctx.name .. "_tractorbeam.s3o"
			-- apply per-unit top-level overrides (e.g. script for weaponized transports)
			for k, v in pairs(tentry) do
				if k ~= "customparams" then
					ctx.def[k] = v
				end
			end
			-- apply per-unit customparams
			if tentry.customparams then
				if not ctx.def.customparams then
					ctx.def.customparams = {}
				end
				for k, v in pairs(tentry.customparams) do
					ctx.def.customparams[k] = v
				end
			end
		end
		-- apply passenger sizes (nseats + oversized tag) from passengerSizes table
		local pentry = ruleset.passengerSizes[ctx.name]
		if pentry then
			local nseats, oversized = passengerSizeToParams(pentry.passengercategory)
			if not ctx.def.customparams then
				ctx.def.customparams = {}
			end
			-- skip if already set by tweakUnits/tweakDefs
			if ctx.def.customparams.nseats == nil then
				ctx.def.customparams.nseats = nseats
			end
			if oversized and ctx.def.customparams.oversized == nil then
				ctx.def.customparams.oversized = oversized
			end
		end
		-- apply lab buildoptions: strip known transporters then re-add only the listed ones
		local labOpts = ruleset.labBuildoptions[ctx.name]
		if labOpts ~= nil then
			local filtered = {}
			for _, unitName in pairs(ctx.def.buildoptions) do
				if not ruleset.known[unitName] then
					filtered[#filtered + 1] = unitName
				end
			end
			for _, transportName in ipairs(labOpts) do
				filtered[#filtered + 1] = transportName
			end
			ctx.def.buildoptions = filtered
		end
	end)
	.Before(Defs.UnitDef.Base)
