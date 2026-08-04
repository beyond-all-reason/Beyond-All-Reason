--- Synced contract of the placement module: where a thing can legally stand.
---
--- No gadget and no state. Placement is a question about the map as it is right
--- now, so this file wires the pure search order to the engine-facing tests and
--- answers; there is nothing to own between calls, and nothing to get out of
--- sync.
---
---     local Placement = ModuleHandler.Get("placement")
---     local x, y, z, why = Placement.NearestValid(wantX, wantZ, {
---         radius = 400,          -- how far to look, NOT how far to scatter
---         footprint = 64,        -- what the thing actually occupies
---         surface = "land",
---     })
---     if x == nil then
---         Spring.Log(..., "nowhere to put it: " .. why)
---     end

local Search = VFS.Include("modules/placement/lib/search.lua")
local Ground = VFS.Include("modules/placement/spring/ground.lua")

--- position_checks reads the world the moment it loads (gaia's team, map size),
--- so it is pulled in on first USE rather than on include. A module that
--- explodes at require time takes every consumer's spec down with it, and
--- nothing here needs the map until somebody asks a question about it.
local ground
local function checks()
	if ground == nil then
		ground = Ground.New({
			positionChecks = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua"),
		})
	end
	return ground
end

--- Default lattice spacing. Half a small structure: fine enough that "nearest"
--- means something, coarse enough that a 512-elmo search is tens of samples
--- rather than thousands.
local DEFAULT_STEP = 64

return {
	---The nearest spot to (x, z) that the thing described by `opts` can stand
	---on, or nil and a sentence saying what refused it.
	---
	---Deterministic: the walk is a fixed integer lattice, so the same request
	---on the same map gives the same answer on every client, in a replay, and
	---in a spec. Nothing here draws a random number.
	---
	---@param x number
	---@param z number
	---@param opts { radius: number|nil, step: number|nil, footprint: number|nil, surface: string|nil, flatness: number|nil, clearance: number|nil, limit: integer|nil }|nil
	---@return number|nil x, number|nil y, number|nil z, string|nil why
	NearestValid = function(x, z, opts)
		opts = opts or {}
		local want = {
			footprint = opts.footprint or 64,
			surface = opts.surface or "land",
			flatness = opts.flatness,
			clearance = opts.clearance,
		}
		local ground = checks()
		local tally = ground.NewTally()
		local found
		local fx, fz = Search.Outward(x, z, {
			radius = opts.radius or 0,
			step = opts.step or DEFAULT_STEP,
			limit = opts.limit,
		}, function(cx, cz)
			local ok, y = ground.Usable(cx, cz, want, tally)
			if ok then
				found = y
			end
			return ok
		end)

		if fx == nil then
			return nil, nil, nil, ground.Explain(tally)
		end
		return fx, found, fz, nil
	end,

	---Is this exact spot usable? The question without the search, for a caller
	---that wants to know rather than to be moved.
	---@param x number
	---@param z number
	---@param opts table|nil
	---@return boolean ok, number|nil y
	IsValid = function(x, z, opts)
		opts = opts or {}
		return checks().Usable(x, z, {
			footprint = opts.footprint or 64,
			surface = opts.surface or "land",
			flatness = opts.flatness,
			clearance = opts.clearance,
		}, nil)
	end,

	---Spread several things around a point without stacking them, in a fixed
	---order. Each takes the nearest spot the ones before it have not taken,
	---which is what makes a group land as a deliberate cluster rather than a
	---scatter — and makes the result reproducible.
	---@param x number
	---@param z number
	---@param count integer
	---@param opts table|nil
	---@return { x: number, y: number, z: number }[] spots may be shorter than count
	Cluster = function(x, z, count, opts)
		opts = opts or {}
		local footprint = opts.footprint or 64
		local ground = checks()
		local taken = {}
		local out = {}
		local want = {
			footprint = footprint,
			surface = opts.surface or "land",
			flatness = opts.flatness,
			clearance = opts.clearance,
		}
		for _ = 1, count do
			local placed
			local px, pz = Search.Outward(x, z, {
				radius = opts.radius or 0,
				step = opts.step or DEFAULT_STEP,
				limit = opts.limit,
			}, function(cx, cz)
				if taken[cx .. "," .. cz] then
					return false
				end
				local ok, y = ground.Usable(cx, cz, want, nil)
				if ok then
					placed = y
				end
				return ok
			end)
			if px == nil then
				break
			end
			taken[px .. "," .. pz] = true
			out[#out + 1] = { x = px, y = placed, z = pz }
		end
		return out
	end,
}
