local base_startpos = {9263, 4100}
local radius = 256

local sin = math.sin
local cos = math.cos
local midX = Game.mapSizeX / 2
local midZ = Game.mapSizeZ / 2
local function Rotate(point, phi) return {
	midX + (point[1] - midX) * cos(phi) - (point[2] - midZ) * sin(phi),
	midZ + (point[2] - midZ) * cos(phi) + (point[1] - midX) * sin(phi),
} end

local ret = {}
for i = 0, 15 do
	local boxCenter = Rotate(base_startpos, i * math.pi / 8)
	local box = {}
	for j = 0, 15 do
		local phi = j * math.pi / 8
		box[j] = {
			boxCenter[1] + radius * math.sin(phi),
			boxCenter[2] + radius * math.cos(phi),
		}
	end
	ret[i] = {
		startpoints = { boxCenter },
		boxes = { box },
	}
end

return ret

