
if not gadgetHandler:IsSyncedCode() then return end

function gadget:GetInfo()
	return {
		name      = "Map Lua Metal Spot Placer",
		desc      = "Places metal spots according to lua metal map",
		author    = "raaar",
		version   = "v1",
		date      = "2017",
		license   = "PD",
		layer     = -10,
		enabled   = true
	}
end

------------------------------------------------------------
-- Config
------------------------------------------------------------
local MAPSIDE_METALMAP = "mapconfig/map_metal_layout.lua"

local METAL_MAP_SQUARE_SIZE = 16
local MAP_SIZE_X = Game.mapSizeX
local MAP_SIZE_X_SCALED = MAP_SIZE_X / METAL_MAP_SQUARE_SIZE
local MAP_SIZE_Z = Game.mapSizeZ
local MAP_SIZE_Z_SCALED = MAP_SIZE_Z / METAL_MAP_SQUARE_SIZE

local mapConfig = VFS.FileExists(MAPSIDE_METALMAP) and VFS.Include(MAPSIDE_METALMAP) or false

-- assigns metal to the defined metal spots when the gadget loads
function gadget:Initialize()
	if mapConfig and Spring.GetGameFrame() == 0 then
	
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "Loading map-side lua metal spot configuration...")
		local spots = mapConfig.spots
		local metalFactor = 0.43 * 9 / 21

		local metalIdx = 1
		local xIndex, zIndex, xi, zi
		if (spots and #spots > 0) then
			for i = 1, #spots do
				local spot = spots[i]

				px = spot.x
				pz = spot.z
				metal = spot.metal

				-- place metal for spot
				if (px and pz and metal) then
					
					--Spring.Echo("metal set for x="..px.." z="..pz.." metal="..metal)
					xIndex = math.floor(px / METAL_MAP_SQUARE_SIZE)
					zIndex = math.floor(pz / METAL_MAP_SQUARE_SIZE)

					-- set the metal values
					if xIndex >=0 and zIndex >=0 then
						for dxi = -2, 2 do
							for dzi = -2, 2 do
								if (math.abs(dxi) == 2 and math.abs(dzi) == 2) then 
									-- skip corners
								else
									xi = xIndex + dxi
									zi = zIndex + dzi
		
									if (xi > 0 and xi < MAP_SIZE_X_SCALED and zi > 0 and zi < MAP_SIZE_Z_SCALED ) then							
										Spring.SetMetalAmount(xi,zi,metal * metalFactor *255)
									end
								end
							end
						end
					end
				end
			end
		end
	end
end