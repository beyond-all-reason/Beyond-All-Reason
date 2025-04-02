local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Area unload",
		desc = "Makes area unloads deterministic with equal distanced drops (not random) ",
		author = "Doo",
		date = "April 2018",
		license = "GNU GPL, v2 or later",
		handler = true,
		layer = 0,
		enabled = true
	}
end

local math_sqrt = math.sqrt
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS

local function CanUnitExecute(uID, cmdID)
	if cmdID == CMD_UNLOAD_UNITS then
		local transporting = Spring.GetUnitIsTransporting(uID)
		return (transporting and #transporting > 0)
	end
	return (Spring.FindUnitCmdDesc(uID, cmdID) ~= nil)
end

local function GetExecutingUnits(cmdID)
	local units = {}
	local selUnits = Spring.GetSelectedUnits()
	for i = 1, #selUnits do
		local uID = selUnits[i]
		if CanUnitExecute(uID, cmdID) then
			units[#units + 1] = uID
		end
	end
	return units
end

function radius(k, n, b)
	local r
	if k > n - b then
		r = 1
	else
		r = math_sqrt(k - 1 / 2) / math_sqrt(n - (b + 1) / 2)
	end
	return r
end

function widget:CommandNotify(id, params, options)
	if id == CMD.UNLOAD_UNITS then
		if params[4] and params[4] >= 64 then
			local alt, ctrl, meta, shift = Spring.GetModKeyState()
			local ray = params[4]
			local units = GetExecutingUnits(id)
			--if (2 * math.pi * ray*ray)/(#units) >= 128*128 then -- Surface check to prevent clumping (needs GUI before enabling check)
			local alpha = 1
			local b = math.floor(alpha * math_sqrt(#units))
			local phi = (math_sqrt(5) + 1) / 2
			local theta, r, x, y, z
			for k = 1, #units do
				if not shift then
					Spring.GiveOrderToUnit(units[k], CMD.STOP, {}, 0)
				end
				r = radius(k, #units, b)
				theta = 2 * math.pi * k / phi * phi
				x = params[1] + r * math.cos(theta) * ray
				z = params[3] + r * math.sin(theta) * ray
				y = Spring.GetGroundHeight(x, z)
				Spring.GiveOrderToUnit(units[k], CMD.UNLOAD_UNIT, { x, y, z }, { "shift" })
			end
			--end
			return true
		else
			return false
		end
	end
end
