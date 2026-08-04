
local Search = VFS.Include("modules/placement/lib/search.lua")
local Ground = VFS.Include("modules/placement/spring/ground.lua")

local ground
local function checks()
	if ground == nil then
		ground = Ground.New({
			positionChecks = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua"),
		})
	end
	return ground
end

--- Half a small structure: fine enough that "nearest" means something, coarse enough that a
--- 512-elmo search is tens of samples rather than thousands.
local DEFAULT_STEP = 64

return {
	---A fixed integer lattice and no random numbers, so every client and a replay agree.
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
