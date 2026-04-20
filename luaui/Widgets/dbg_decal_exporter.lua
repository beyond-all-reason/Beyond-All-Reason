local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Decal Exporter & Analytics",
		desc = "Export decal snapshots, generate combat heatmaps, and produce mapper-friendly data files",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Engine API locals
local spEcho = Spring.Echo
local spGetGameFrame = Spring.GetGameFrame
local spGetGroundHeight = Spring.GetGroundHeight
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers

local glSaveImage = gl.SaveImage
local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture
local glRenderToTexture = gl.RenderToTexture
local glTexRect = gl.TexRect
local glColor = gl.Color
local glBlending = gl.Blending
local glTexture = gl.Texture

local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local sqrt = math.sqrt
local pi = math.pi
local format = string.format

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local mapName = Game.mapName
local DECALS_DIR = "Terraform Brush/Decals/"

-- ========== HEATMAP ACCUMULATOR ==========
-- Tracks every explosion decal that spawns during the game for density analysis.
-- Grid resolution in elmos per cell.
local HEAT_CELL_SIZE = 64
local heatGridW = ceil(mapSizeX / HEAT_CELL_SIZE)
local heatGridH = ceil(mapSizeZ / HEAT_CELL_SIZE)
local heatGrid = {}
local heatMax = 0
local totalExplosions = 0

local function initHeatGrid()
	for i = 1, heatGridW * heatGridH do
		heatGrid[i] = 0
	end
	heatMax = 0
	totalExplosions = 0
end

-- Add a weighted hit to the heatmap at world position (wx, wz) with given radius
local function addHeat(wx, wz, radius)
	local cx = floor(wx / HEAT_CELL_SIZE) + 1
	local cz = floor(wz / HEAT_CELL_SIZE) + 1
	local spread = max(1, floor(radius / HEAT_CELL_SIZE))
	local weight = radius / 100 -- bigger explosions = more heat

	for dx = -spread, spread do
		for dz = -spread, spread do
			local gx = cx + dx
			local gz = cz + dz
			if gx >= 1 and gx <= heatGridW and gz >= 1 and gz <= heatGridH then
				local dist = sqrt(dx * dx + dz * dz)
				local falloff = max(0, 1 - dist / (spread + 1))
				local idx = (gz - 1) * heatGridW + gx
				heatGrid[idx] = heatGrid[idx] + weight * falloff
				if heatGrid[idx] > heatMax then
					heatMax = heatGrid[idx]
				end
			end
		end
	end
	totalExplosions = totalExplosions + 1
end

-- ========== EXPLOSION TRACKING ==========
-- Hook into visible explosions to accumulate heatmap data
function widget:Explosion(weaponDefID, px, py, pz, ownerID, projectileID)
	local wd = WeaponDefs[weaponDefID]
	if wd then
		local radius = wd.damageAreaOfEffect or 32
		addHeat(px, pz, radius)
	end
end

-- ========== SNAPSHOT: GL4 WIDGET DECALS ==========
-- Captures all active decals from the Decals GL4 widget
local function snapshotGL4Decals()
	local decalsApi = WG['decalsgl4']
	if not decalsApi then
		spEcho("[Decal Exporter] Decals GL4 widget not loaded")
		return nil
	end

	-- Ensure data is fresh
	if decalsApi.RebuildActiveDecalData then
		decalsApi.RebuildActiveDecalData()
	end

	local activeDecals = decalsApi.GetActiveDecals()
	if not activeDecals then
		spEcho("[Decal Exporter] No active decal data")
		return nil
	end

	local snapshot = {}
	local count = 0
	local curFrame = spGetGameFrame()

	for instanceID, d in pairs(activeDecals) do
		-- d = {posx, posz, size, alphastart, alphadecay, spawnframe, isFootprint, width, length, rotation, p, q, s, t}
		local age = curFrame - d[6]
		local currentAlpha = d[4] - d[5] * age
		if currentAlpha > 0.01 then
			count = count + 1
			snapshot[count] = {
				source = "gl4",
				posx = d[1],
				posz = d[2],
				posy = spGetGroundHeight(d[1], d[2]) or 0,
				width = d[8],
				length = d[9],
				rotation = d[10],
				alpha = min(1, currentAlpha),
				isFootprint = d[7] or false,
				uv = { p = d[11], q = d[12], s = d[13], t = d[14] },
			}
		end
	end

	spEcho(format("[Decal Exporter] Captured %d GL4 decals", count))
	return snapshot
end

-- ========== SNAPSHOT: ENGINE GROUND DECALS ==========
-- Captures all engine-side ground decals (building plates, explosion scars, tracks, lua decals)
local function snapshotEngineDecals()
	if not Spring.GetAllGroundDecals then
		spEcho("[Decal Exporter] Engine decal API not available (need engine 105+)")
		return nil
	end

	local allIDs = Spring.GetAllGroundDecals()
	if not allIDs or #allIDs == 0 then
		spEcho("[Decal Exporter] No engine ground decals found")
		return nil
	end

	local snapshot = {}
	local count = 0

	for _, decalID in ipairs(allIDs) do
		local posX, posZ = Spring.GetGroundDecalMiddlePos(decalID)
		if posX then
			local sizeX, sizeZ, projHeight = Spring.GetGroundDecalSizeAndHeight(decalID)
			local rotation = Spring.GetGroundDecalRotation(decalID)
			local texture = Spring.GetGroundDecalTexture(decalID, true)
			local normalTex = Spring.GetGroundDecalTexture(decalID, false)
			local alpha, alphaFalloff = Spring.GetGroundDecalAlpha(decalID)
			local decalType = Spring.GetGroundDecalType(decalID)
			local tintR, tintG, tintB, tintA
			if Spring.GetGroundDecalTint then
				tintR, tintG, tintB, tintA = Spring.GetGroundDecalTint(decalID)
			end
			local glow, glowFalloff
			if Spring.GetGroundDecalGlowParams then
				glow, glowFalloff = Spring.GetGroundDecalGlowParams(decalID)
			end

			count = count + 1
			snapshot[count] = {
				source = "engine",
				decalType = decalType or "unknown",
				decalID = decalID,
				posX = posX,
				posZ = posZ,
				posY = spGetGroundHeight(posX, posZ) or 0,
				sizeX = sizeX,
				sizeZ = sizeZ,
				projHeight = projHeight,
				rotation = rotation or 0,
				texture = texture,
				normalTexture = normalTex,
				alpha = alpha or 1,
				alphaFalloff = alphaFalloff or 0,
				tint = (tintR and { tintR, tintG, tintB, tintA }) or nil,
				glow = glow,
				glowFalloff = glowFalloff,
			}
		end
	end

	spEcho(format("[Decal Exporter] Captured %d engine decals", count))
	return snapshot
end

-- ========== EXPORT: LUA TABLE (for map widgets / mapinfo) ==========
-- Writes a self-contained Lua file that a map can dofile() to get decal placements.
-- Mapper drops this into their map folder and loads it from a widget/gadget.
local function exportLuaTable(snapshot, filename)
	if not snapshot or #snapshot == 0 then
		spEcho("[Decal Exporter] Nothing to export")
		return
	end

	local lines = {}
	lines[#lines + 1] = "-- Decal snapshot exported from Beyond All Reason"
	lines[#lines + 1] = format("-- Map: %s | Date: frame %d | Count: %d", mapName, spGetGameFrame(), #snapshot)
	lines[#lines + 1] = format("-- Map size: %d x %d elmos", mapSizeX, mapSizeZ)
	lines[#lines + 1] = ""
	lines[#lines + 1] = "local decals = {"

	for i, d in ipairs(snapshot) do
		if d.source == "engine" then
			lines[#lines + 1] = format("\t{ -- #%d [%s]", i, d.decalType)
			lines[#lines + 1] = format("\t\tposX = %.1f, posZ = %.1f, posY = %.1f,", d.posX, d.posZ, d.posY)
			lines[#lines + 1] = format("\t\tsizeX = %.1f, sizeZ = %.1f,", d.sizeX or 0, d.sizeZ or 0)
			lines[#lines + 1] = format("\t\trotation = %.4f,", d.rotation)
			lines[#lines + 1] = format("\t\talpha = %.3f, alphaFalloff = %.6f,", d.alpha, d.alphaFalloff or 0)
			if d.texture then
				lines[#lines + 1] = format("\t\ttexture = %q,", d.texture)
			end
			if d.normalTexture then
				lines[#lines + 1] = format("\t\tnormalTexture = %q,", d.normalTexture)
			end
			if d.tint then
				lines[#lines + 1] = format("\t\ttint = { %.3f, %.3f, %.3f, %.3f },", d.tint[1], d.tint[2], d.tint[3], d.tint[4])
			end
			if d.glow and d.glow > 0 then
				lines[#lines + 1] = format("\t\tglow = %.3f, glowFalloff = %.6f,", d.glow, d.glowFalloff or 0)
			end
			lines[#lines + 1] = format("\t\tdecalType = %q,", d.decalType)
			lines[#lines + 1] = "\t},"
		else
			-- GL4 decal
			lines[#lines + 1] = format("\t{ -- #%d [gl4%s]", i, d.isFootprint and " footprint" or "")
			lines[#lines + 1] = format("\t\tposX = %.1f, posZ = %.1f, posY = %.1f,", d.posx, d.posz, d.posy)
			lines[#lines + 1] = format("\t\twidth = %.1f, length = %.1f,", d.width, d.length)
			lines[#lines + 1] = format("\t\trotation = %.4f,", d.rotation)
			lines[#lines + 1] = format("\t\talpha = %.3f,", d.alpha)
			lines[#lines + 1] = format("\t\tisFootprint = %s,", tostring(d.isFootprint))
			lines[#lines + 1] = "\t},"
		end
	end

	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "return decals"

	local path = filename or format(DECALS_DIR .. "decal_snapshot_%s_%d.lua", mapName, spGetGameFrame())
	Spring.CreateDir(DECALS_DIR)
	local file = io.open(path, "w")
	if file then
		file:write(table.concat(lines, "\n"))
		file:close()
		spEcho(format("[Decal Exporter] Lua table saved: %s (%d entries)", path, #snapshot))
	else
		spEcho(format("[Decal Exporter] Failed to write: %s", path))
	end
end

-- ========== EXPORT: CSV (for GIS tools, spreadsheets, Python scripts) ==========
local function exportCSV(snapshot, filename)
	if not snapshot or #snapshot == 0 then
		spEcho("[Decal Exporter] Nothing to export")
		return
	end

	local lines = {}
	lines[1] = "source,decalType,posX,posZ,posY,sizeX,sizeZ,rotation,alpha,texture,isFootprint"

	for _, d in ipairs(snapshot) do
		if d.source == "engine" then
			lines[#lines + 1] = format("engine,%s,%.1f,%.1f,%.1f,%.1f,%.1f,%.4f,%.3f,%s,false",
				d.decalType, d.posX, d.posZ, d.posY,
				d.sizeX or 0, d.sizeZ or 0, d.rotation, d.alpha,
				d.texture or "")
		else
			lines[#lines + 1] = format("gl4,scar,%.1f,%.1f,%.1f,%.1f,%.1f,%.4f,%.3f,,%s",
				d.posx, d.posz, d.posy,
				d.width, d.length, d.rotation, d.alpha,
				tostring(d.isFootprint))
		end
	end

	local path = filename or format(DECALS_DIR .. "decal_snapshot_%s_%d.csv", mapName, spGetGameFrame())
	Spring.CreateDir(DECALS_DIR)
	local file = io.open(path, "w")
	if file then
		file:write(table.concat(lines, "\n"))
		file:close()
		spEcho(format("[Decal Exporter] CSV saved: %s (%d rows)", path, #snapshot))
	else
		spEcho(format("[Decal Exporter] Failed to write: %s", path))
	end
end

-- ========== EXPORT: STAMP FILE (re-importable via engine API) ==========
-- Produces a Lua script that can be run as a widget to recreate all decals on any map.
local function exportStampFile(snapshot, filename)
	if not snapshot or #snapshot == 0 then
		spEcho("[Decal Exporter] Nothing to export")
		return
	end

	-- Filter to only engine decals that can be recreated
	local engineDecals = {}
	for _, d in ipairs(snapshot) do
		if d.source == "engine" and d.texture then
			engineDecals[#engineDecals + 1] = d
		end
	end

	if #engineDecals == 0 then
		spEcho("[Decal Exporter] No engine decals with textures to stamp")
		return
	end

	local lines = {}
	lines[#lines + 1] = "-- Decal stamp file: recreates decals via Spring.CreateGroundDecal"
	lines[#lines + 1] = format("-- Source map: %s | Decals: %d", mapName, #engineDecals)
	lines[#lines + 1] = format("-- Map size: %d x %d elmos", mapSizeX, mapSizeZ)
	lines[#lines + 1] = ""
	lines[#lines + 1] = "local stamps = {"

	for i, d in ipairs(engineDecals) do
		lines[#lines + 1] = "\t{"
		lines[#lines + 1] = format("\t\tposX = %.1f, posZ = %.1f,", d.posX, d.posZ)
		lines[#lines + 1] = format("\t\tsizeX = %.1f, sizeZ = %.1f,", d.sizeX, d.sizeZ)
		lines[#lines + 1] = format("\t\trotation = %.4f,", d.rotation)
		lines[#lines + 1] = format("\t\ttexture = %q,", d.texture)
		if d.normalTexture then
			lines[#lines + 1] = format("\t\tnormalTexture = %q,", d.normalTexture)
		end
		lines[#lines + 1] = format("\t\talpha = %.3f,", d.alpha)
		if d.tint then
			lines[#lines + 1] = format("\t\ttint = { %.3f, %.3f, %.3f, %.3f },", d.tint[1], d.tint[2], d.tint[3], d.tint[4])
		end
		if d.glow and d.glow > 0 then
			lines[#lines + 1] = format("\t\tglow = %.3f,", d.glow)
		end
		lines[#lines + 1] = "\t},"
	end

	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- Apply stamps: call this function to recreate all decals"
	lines[#lines + 1] = "local function applyStamps()"
	lines[#lines + 1] = "\tlocal created = 0"
	lines[#lines + 1] = "\tfor _, s in ipairs(stamps) do"
	lines[#lines + 1] = "\t\tlocal id = Spring.CreateGroundDecal()"
	lines[#lines + 1] = "\t\tif id then"
	lines[#lines + 1] = "\t\t\tSpring.SetGroundDecalPosAndDims(id, s.posX, s.posZ, s.sizeX, s.sizeZ)"
	lines[#lines + 1] = "\t\t\tSpring.SetGroundDecalRotation(id, s.rotation)"
	lines[#lines + 1] = "\t\t\tSpring.SetGroundDecalTexture(id, s.texture, true)"
	lines[#lines + 1] = "\t\t\tif s.normalTexture then"
	lines[#lines + 1] = "\t\t\t\tSpring.SetGroundDecalTexture(id, s.normalTexture, false)"
	lines[#lines + 1] = "\t\t\tend"
	lines[#lines + 1] = "\t\t\tSpring.SetGroundDecalAlpha(id, s.alpha, 0)"
	lines[#lines + 1] = "\t\t\tif s.tint then"
	lines[#lines + 1] = "\t\t\t\tSpring.SetGroundDecalTint(id, s.tint[1], s.tint[2], s.tint[3], s.tint[4])"
	lines[#lines + 1] = "\t\t\tend"
	lines[#lines + 1] = "\t\t\tif s.glow then"
	lines[#lines + 1] = "\t\t\t\tSpring.SetGroundDecalGlowParams(id, s.glow, 0)"
	lines[#lines + 1] = "\t\t\tend"
	lines[#lines + 1] = "\t\t\tcreated = created + 1"
	lines[#lines + 1] = "\t\tend"
	lines[#lines + 1] = "\tend"
	lines[#lines + 1] = "\tSpring.Echo('[Decal Stamp] Applied ' .. created .. ' decals')"
	lines[#lines + 1] = "\treturn created"
	lines[#lines + 1] = "end"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "return { stamps = stamps, apply = applyStamps }"

	local path = filename or format(DECALS_DIR .. "decal_stamps_%s_%d.lua", mapName, spGetGameFrame())
	Spring.CreateDir(DECALS_DIR)
	local file = io.open(path, "w")
	if file then
		file:write(table.concat(lines, "\n"))
		file:close()
		spEcho(format("[Decal Exporter] Stamp file saved: %s (%d decals)", path, #engineDecals))
	else
		spEcho(format("[Decal Exporter] Failed to write: %s", path))
	end
end

-- ========== EXPORT: HEATMAP AS CSV GRID ==========
-- Exports the accumulated combat heatmap as a CSV grid that can be
-- opened in any image editor or imported into Python/numpy for visualization.
local function exportHeatmapCSV(filename)
	if totalExplosions == 0 then
		spEcho("[Decal Exporter] No explosions recorded yet — play some game first")
		return
	end

	local path = filename or format(DECALS_DIR .. "heatmap_%s_%d.csv", mapName, spGetGameFrame())
	Spring.CreateDir(DECALS_DIR)
	local file = io.open(path, "w")
	if not file then
		spEcho(format("[Decal Exporter] Failed to write: %s", path))
		return
	end

	-- Header with metadata
	file:write(format("# Combat heatmap | Map: %s | Cell size: %d elmos | Grid: %dx%d | Explosions: %d | Max heat: %.2f\n",
		mapName, HEAT_CELL_SIZE, heatGridW, heatGridH, totalExplosions, heatMax))

	for row = 1, heatGridH do
		local rowData = {}
		for col = 1, heatGridW do
			local idx = (row - 1) * heatGridW + col
			rowData[col] = format("%.2f", heatGrid[idx])
		end
		file:write(table.concat(rowData, ",") .. "\n")
	end

	file:close()
	spEcho(format("[Decal Exporter] Heatmap CSV saved: %s (%dx%d grid, %d explosions, peak=%.1f)",
		path, heatGridW, heatGridH, totalExplosions, heatMax))
end

-- ========== EXPORT: HEATMAP AS PGM IMAGE (Portable Gray Map) ==========
-- Mappers can open this directly in GIMP/Photoshop as an overlay reference.
local function exportHeatmapPGM(filename)
	if totalExplosions == 0 then
		spEcho("[Decal Exporter] No explosions recorded yet")
		return
	end

	local path = filename or format(DECALS_DIR .. "heatmap_%s_%d.pgm", mapName, spGetGameFrame())
	Spring.CreateDir(DECALS_DIR)
	local file = io.open(path, "wb")
	if not file then
		spEcho(format("[Decal Exporter] Failed to write: %s", path))
		return
	end

	-- PGM header (P5 = binary grayscale)
	file:write(format("P5\n# Combat heatmap %s\n%d %d\n255\n", mapName, heatGridW, heatGridH))

	local safeMax = max(heatMax, 0.001)
	local chars = {}
	for row = 1, heatGridH do
		for col = 1, heatGridW do
			local idx = (row - 1) * heatGridW + col
			local normalized = min(1, heatGrid[idx] / safeMax)
			-- Apply sqrt for perceptual brightness
			local byte = floor(sqrt(normalized) * 255 + 0.5)
			chars[#chars + 1] = string.char(byte)
		end
	end
	file:write(table.concat(chars))
	file:close()

	spEcho(format("[Decal Exporter] Heatmap PGM saved: %s (%dx%d, %d explosions)",
		path, heatGridW, heatGridH, totalExplosions))
end

-- ========== EXPORT: FEATURES.LUA (convert decal scars to map features) ==========
-- Translates explosion decal positions into feature definitions that can be
-- pasted into a map's features.lua to permanently scatter debris/craters.
local function exportFeaturesLua(snapshot, filename)
	if not snapshot or #snapshot == 0 then
		spEcho("[Decal Exporter] Nothing to export")
		return
	end

	-- Map decal sizes to appropriate feature types
	local function sizeToFeature(size)
		if size > 200 then return "heap" end
		if size > 80 then return "metal" end
		return "rock"
	end

	local lines = {}
	lines[#lines + 1] = "-- Map features generated from decal positions"
	lines[#lines + 1] = format("-- Source: %s at frame %d", mapName, spGetGameFrame())
	lines[#lines + 1] = "-- Drop into your map's features.lua or merge manually"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "local features = {"

	local count = 0
	for _, d in ipairs(snapshot) do
		local px = d.posX or d.posx
		local pz = d.posZ or d.posz
		local size = max(d.sizeX or d.width or 32, d.sizeZ or d.length or 32)
		local rot = d.rotation or 0

		if px and pz then
			count = count + 1
			local feat = sizeToFeature(size)
			lines[#lines + 1] = format("\t{ name = %q, x = %.0f, z = %.0f, rot = %.0f },",
				feat, px, pz, rot * 180 / pi)
		end
	end

	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "return features"

	local path = filename or format(DECALS_DIR .. "decal_features_%s_%d.lua", mapName, spGetGameFrame())
	Spring.CreateDir(DECALS_DIR)
	local file = io.open(path, "w")
	if file then
		file:write(table.concat(lines, "\n"))
		file:close()
		spEcho(format("[Decal Exporter] Features file saved: %s (%d entries)", path, count))
	else
		spEcho(format("[Decal Exporter] Failed to write: %s", path))
	end
end

-- ========== SUMMARY STATS ==========
local function printStats()
	local gl4Count = 0
	local decalsApi = WG['decalsgl4']
	if decalsApi and decalsApi.GetActiveDecals then
		local active = decalsApi.GetActiveDecals()
		if active then
			for _ in pairs(active) do gl4Count = gl4Count + 1 end
		end
	end

	local engineCount = 0
	if Spring.GetAllGroundDecals then
		local ids = Spring.GetAllGroundDecals()
		if ids then engineCount = #ids end
	end

	spEcho("===== DECAL EXPORTER STATS =====")
	spEcho(format("  GL4 widget decals: %d", gl4Count))
	spEcho(format("  Engine ground decals: %d", engineCount))
	spEcho(format("  Heatmap explosions tracked: %d (peak intensity: %.1f)", totalExplosions, heatMax))
	spEcho(format("  Heatmap grid: %dx%d cells (%d elmos/cell)", heatGridW, heatGridH, HEAT_CELL_SIZE))
	spEcho(format("  Map: %s (%dx%d)", mapName, mapSizeX, mapSizeZ))
	spEcho("================================")
end

-- ========== TEXT COMMANDS ==========
function widget:TextCommand(command)
	if command == "decalexport" or command == "decal_export" then
		-- Full export: both GL4 + engine decals to all formats
		local gl4 = snapshotGL4Decals() or {}
		local eng = snapshotEngineDecals() or {}
		local combined = {}
		for _, d in ipairs(gl4) do combined[#combined + 1] = d end
		for _, d in ipairs(eng) do combined[#combined + 1] = d end

		if #combined > 0 then
			exportLuaTable(combined)
			exportCSV(combined)
			exportStampFile(combined)
			exportFeaturesLua(combined)
		else
			spEcho("[Decal Exporter] No decals found to export")
		end
		return true
	end

	if command == "decalexport_gl4" then
		local snap = snapshotGL4Decals()
		if snap then
			exportLuaTable(snap, format("decals_gl4_%s_%d.lua", mapName, spGetGameFrame()))
		end
		return true
	end

	if command == "decalexport_engine" then
		local snap = snapshotEngineDecals()
		if snap then
			exportLuaTable(snap, format(DECALS_DIR .. "decals_engine_%s_%d.lua", mapName, spGetGameFrame()))
			exportStampFile(snap, format(DECALS_DIR .. "decal_stamps_%s_%d.lua", mapName, spGetGameFrame()))
		end
		return true
	end

	if command == "decalexport_features" then
		local gl4 = snapshotGL4Decals() or {}
		local eng = snapshotEngineDecals() or {}
		local combined = {}
		for _, d in ipairs(gl4) do combined[#combined + 1] = d end
		for _, d in ipairs(eng) do combined[#combined + 1] = d end
		if #combined > 0 then
			exportFeaturesLua(combined)
		end
		return true
	end

	if command == "decalheatmap" or command == "decal_heatmap" then
		exportHeatmapCSV()
		exportHeatmapPGM()
		return true
	end

	if command == "decalheatmap_reset" then
		initHeatGrid()
		spEcho("[Decal Exporter] Heatmap reset")
		return true
	end

	if command == "decalstats" or command == "decal_stats" then
		printStats()
		return true
	end

	return false
end

-- ========== PUBLIC API ==========
function widget:Initialize()
	initHeatGrid()

	WG.DecalExporter = {
		snapshotGL4 = snapshotGL4Decals,
		snapshotEngine = snapshotEngineDecals,
		exportLua = exportLuaTable,
		exportCSV = exportCSV,
		exportStamp = exportStampFile,
		exportFeatures = exportFeaturesLua,
		exportHeatmapCSV = exportHeatmapCSV,
		exportHeatmapPGM = exportHeatmapPGM,
		getHeatGrid = function() return heatGrid, heatGridW, heatGridH, heatMax end,
		getTotalExplosions = function() return totalExplosions end,
		resetHeatmap = initHeatGrid,
		stats = printStats,
	}

	spEcho("[Decal Exporter] Loaded. Commands: /decalexport, /decalexport_gl4, /decalexport_engine, /decalexport_features, /decalheatmap, /decalheatmap_reset, /decalstats")
end

function widget:Shutdown()
	WG.DecalExporter = nil
end
