local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Terraform Brush",
		desc = "Raises, lowers, or levels terrain with configurable shape, radius, and rotation. Requires /cheat.",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	function gadget:RecvFromSynced(name, undoCount, redoCount)
		if name == "TerraformBrushStacks" then
			if Script.LuaUI("TerraformBrushStackUpdate") then
				Script.LuaUI.TerraformBrushStackUpdate(undoCount, redoCount)
			end
		end
	end
	return
end

local PACKET_HEADER = "$terraform_brush$"
local PACKET_HEADER_LENGTH = #PACKET_HEADER
local RAMP_HEADER = "$terraform_ramp$"
local RAMP_HEADER_LENGTH = #RAMP_HEADER
local SPLINE_RAMP_HEADER = "$terraform_ramp_spline$"
local SPLINE_RAMP_HEADER_LENGTH = #SPLINE_RAMP_HEADER
local RESTORE_HEADER = "$terraform_restore$"
local RESTORE_HEADER_LENGTH = #RESTORE_HEADER
local IMPORT_HEADER = "$terraform_import$"
local IMPORT_HEADER_LENGTH = #IMPORT_HEADER
local UNDO_HEADER = "$terraform_undo$"
local REDO_HEADER = "$terraform_redo$"
local HEIGHT_STEP = 8
local MAX_UNDO = 100

local undoStack = {}
local redoStack = {}
local MAX_RADIUS = 2000
local MIN_RADIUS = 8
local RING_INNER_RATIO = 0.6

local floor = math.floor
local max = math.max
local min = math.min
local cos = math.cos
local sin = math.sin
local abs = math.abs
local pi = math.pi
local atan2 = math.atan2

local function rotatePoint(px, pz, angleDeg)
	local rad = angleDeg * pi / 180
	local cosA = cos(rad)
	local sinA = sin(rad)
	return px * cosA - pz * sinA, px * sinA + pz * cosA
end

local function isInsideCircle(dx, dz, radius)
	return dx * dx + dz * dz <= radius * radius
end

local function isInsideSquare(dx, dz, radius, angleDeg)
	local lx, lz = rotatePoint(dx, dz, -angleDeg)
	return abs(lx) <= radius and abs(lz) <= radius
end

local function isInsideRing(dx, dz, radius)
	local distSquared = dx * dx + dz * dz
	local innerRadius = radius * RING_INNER_RATIO
	return distSquared <= radius * radius and distSquared >= innerRadius * innerRadius
end

local function regularPolygonFalloff(dx, dz, radius, angleDeg, numSides)
	local lx, lz = rotatePoint(dx, dz, -angleDeg)
	local dist = (lx * lx + lz * lz) ^ 0.5
	if dist < 0.001 then return 1 end
	local angle = atan2(lz, lx)
	if angle < 0 then angle = angle + 2 * pi end
	local sectorAngle = 2 * pi / numSides
	local angleInSector = (angle % sectorAngle) - sectorAngle / 2
	local apothem = radius * cos(pi / numSides)
	local edgeDist = apothem / cos(angleInSector)
	if dist > edgeDist then return nil end
	return 1 - dist / edgeDist
end

local function computeFalloff(dx, dz, radius, shape, angleDeg, curve, lengthScale)
	lengthScale = lengthScale or 1.0
	local distSquared = dx * dx + dz * dz
	local radiusSquared = radius * radius
	local rawFalloff = nil

	if shape == "circle" then
		local lx, lz = rotatePoint(dx, dz, -angleDeg)
		lz = lz / lengthScale
		local d2 = lx * lx + lz * lz
		if d2 > radiusSquared then
			return nil
		end

		rawFalloff = 1 - (d2 / radiusSquared)
	elseif shape == "square" then
		local lx, lz = rotatePoint(dx, dz, -angleDeg)
		lz = lz / lengthScale
		if abs(lx) > radius or abs(lz) > radius then
			return nil
		end

		rawFalloff = 1 - max(abs(lx), abs(lz)) / radius
	elseif shape == "hexagon" then
		local lx, lz = rotatePoint(dx, dz, -angleDeg)
		lz = lz / lengthScale
		local f = regularPolygonFalloff(lx, lz, radius, 0, 6)
		if not f then return nil end
		rawFalloff = f
	elseif shape == "octagon" then
		local lx, lz = rotatePoint(dx, dz, -angleDeg)
		lz = lz / lengthScale
		local f = regularPolygonFalloff(lx, lz, radius, 0, 8)
		if not f then return nil end
		rawFalloff = f
	elseif shape == "ring" then
		local lx, lz = rotatePoint(dx, dz, -angleDeg)
		lz = lz / lengthScale
		local d2 = lx * lx + lz * lz
		local innerRadius = radius * RING_INNER_RATIO
		if d2 > radiusSquared or d2 < innerRadius * innerRadius then
			return nil
		end

		local dist = d2 ^ 0.5
		local ringWidth = radius - innerRadius
		local midRadius = (radius + innerRadius) * 0.5
		local distFromMid = abs(dist - midRadius)
		rawFalloff = 1 - (distFromMid / (ringWidth * 0.5))
	end

	if not rawFalloff then
		return nil
	end

	return rawFalloff ^ curve
end

local function applyTerraform(centerX, centerZ, radius, direction, shape, angleDeg, curve, heightMin, heightMax, intensity, lengthScale)
	local squareSize = Game.squareSize
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	lengthScale = lengthScale or 1.0

	local extent = radius * max(1, lengthScale) * 1.42

	local minX = max(0, floor((centerX - extent) / squareSize) * squareSize)
	local maxX = min(mapSizeX, floor((centerX + extent) / squareSize) * squareSize)
	local minZ = max(0, floor((centerZ - extent) / squareSize) * squareSize)
	local maxZ = min(mapSizeZ, floor((centerZ + extent) / squareSize) * squareSize)

	local snapshot = {}
	Spring.SetHeightMapFunc(function()
		for z = minZ, maxZ, squareSize do
			for x = minX, maxX, squareSize do
				local dx = x - centerX
				local dz = z - centerZ
				local falloff = computeFalloff(dx, dz, radius, shape, angleDeg, curve, lengthScale)

				if falloff then
					local current = Spring.GetGroundHeight(x, z)
					snapshot[#snapshot + 1] = {x, z, current}
					local newHeight

					if direction == 0 then
						local targetHeight = Spring.GetGroundHeight(centerX, centerZ)
						local diff = targetHeight - current
						newHeight = current + diff * falloff * 0.3 * intensity
					else
						local delta = direction * HEIGHT_STEP * falloff * intensity
						newHeight = current + delta
					end

					if heightMin then
						newHeight = max(heightMin, newHeight)
					end

					if heightMax then
						newHeight = min(heightMax, newHeight)
					end

					Spring.SetHeightMap(x, z, newHeight)
				end
			end
		end
	end)
	if #snapshot > 0 then
		undoStack[#undoStack + 1] = snapshot
		if #undoStack > MAX_UNDO then
			table.remove(undoStack, 1)
		end
		redoStack = {}
		SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
	end
end

local function applyRamp(startX, startZ, startY, endX, endZ, endY, width)
	local squareSize = Game.squareSize
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ

	local dx = endX - startX
	local dz = endZ - startZ
	local length = (dx * dx + dz * dz) ^ 0.5
	if length < 1 then
		return
	end

	local dirX = dx / length
	local dirZ = dz / length

	local minX = max(0, floor((min(startX, endX) - width) / squareSize) * squareSize)
	local maxX = min(mapSizeX, floor((max(startX, endX) + width) / squareSize) * squareSize)
	local minZ = max(0, floor((min(startZ, endZ) - width) / squareSize) * squareSize)
	local maxZ = min(mapSizeZ, floor((max(startZ, endZ) + width) / squareSize) * squareSize)

	local heightData = {}
	for z = minZ, maxZ, squareSize do
		for x = minX, maxX, squareSize do
			local px = x - startX
			local pz = z - startZ

			local along = px * dirX + pz * dirZ
			if along >= 0 and along <= length then
				local perpX = px - along * dirX
				local perpZ = pz - along * dirZ
				local perpDist = (perpX * perpX + perpZ * perpZ) ^ 0.5

				if perpDist <= width then
					local t = along / length
					local targetHeight = startY + (endY - startY) * t
					local current = Spring.GetGroundHeight(x, z)
					local blend = current + (targetHeight - current) * 0.3
					heightData[#heightData + 1] = { x, z, blend }
				end
			end
		end
	end

	if #heightData > 0 then
		local snapshot = {}
		Spring.SetHeightMapFunc(function()
			for i = 1, #heightData do
				snapshot[#snapshot + 1] = {heightData[i][1], heightData[i][2], Spring.GetGroundHeight(heightData[i][1], heightData[i][2])}
				Spring.SetHeightMap(heightData[i][1], heightData[i][2], heightData[i][3])
			end
		end)
		undoStack[#undoStack + 1] = snapshot
		if #undoStack > MAX_UNDO then
			table.remove(undoStack, 1)
		end
		redoStack = {}
		SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
	end
end

local function applySplineRamp(waypoints, width)
	local squareSize = Game.squareSize
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	local numPts = #waypoints

	if numPts < 2 then return end

	-- Compute cumulative arc lengths
	local arcLengths = { 0 }
	for i = 2, numPts do
		local dx = waypoints[i][1] - waypoints[i - 1][1]
		local dz = waypoints[i][2] - waypoints[i - 1][2]
		arcLengths[i] = arcLengths[i - 1] + (dx * dx + dz * dz) ^ 0.5
	end
	local totalLength = arcLengths[numPts]
	if totalLength < 1 then return end

	-- Get start and end ground heights
	local startY = Spring.GetGroundHeight(waypoints[1][1], waypoints[1][2])
	local endY = Spring.GetGroundHeight(waypoints[numPts][1], waypoints[numPts][2])

	-- Compute bounding box
	local bbMinX, bbMaxX = waypoints[1][1], waypoints[1][1]
	local bbMinZ, bbMaxZ = waypoints[1][2], waypoints[1][2]
	for i = 2, numPts do
		if waypoints[i][1] < bbMinX then bbMinX = waypoints[i][1] end
		if waypoints[i][1] > bbMaxX then bbMaxX = waypoints[i][1] end
		if waypoints[i][2] < bbMinZ then bbMinZ = waypoints[i][2] end
		if waypoints[i][2] > bbMaxZ then bbMaxZ = waypoints[i][2] end
	end

	local minX = max(0, floor((bbMinX - width) / squareSize) * squareSize)
	local maxX = min(mapSizeX, floor((bbMaxX + width) / squareSize) * squareSize)
	local minZ = max(0, floor((bbMinZ - width) / squareSize) * squareSize)
	local maxZ = min(mapSizeZ, floor((bbMaxZ + width) / squareSize) * squareSize)

	local heightData = {}
	for z = minZ, maxZ, squareSize do
		for x = minX, maxX, squareSize do
			-- Find closest point on the polyline
			local bestDist = math.huge
			local bestArc = 0

			for i = 1, numPts - 1 do
				local ax, az = waypoints[i][1], waypoints[i][2]
				local bx, bz = waypoints[i + 1][1], waypoints[i + 1][2]
				local segDx = bx - ax
				local segDz = bz - az
				local segLen = (segDx * segDx + segDz * segDz) ^ 0.5
				if segLen > 0 then
					local px = x - ax
					local pz = z - az
					local t = (px * segDx + pz * segDz) / (segLen * segLen)
					t = max(0, min(1, t))
					local projX = ax + t * segDx
					local projZ = az + t * segDz
					local dist = ((x - projX) * (x - projX) + (z - projZ) * (z - projZ)) ^ 0.5
					if dist < bestDist then
						bestDist = dist
						bestArc = arcLengths[i] + t * segLen
					end
				end
			end

			if bestDist <= width then
				local t = bestArc / totalLength
				local targetHeight = startY + (endY - startY) * t
				local current = Spring.GetGroundHeight(x, z)
				local blend = current + (targetHeight - current) * 0.3
				heightData[#heightData + 1] = { x, z, blend }
			end
		end
	end

	if #heightData > 0 then
		local snapshot = {}
		Spring.SetHeightMapFunc(function()
			for i = 1, #heightData do
				snapshot[#snapshot + 1] = { heightData[i][1], heightData[i][2], Spring.GetGroundHeight(heightData[i][1], heightData[i][2]) }
				Spring.SetHeightMap(heightData[i][1], heightData[i][2], heightData[i][3])
			end
		end)
		undoStack[#undoStack + 1] = snapshot
		if #undoStack > MAX_UNDO then
			table.remove(undoStack, 1)
		end
		redoStack = {}
		SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
	end
end

local function applyRestore(centerX, centerZ, radius, shape, angleDeg, curve, intensity, lengthScale)
	local squareSize = Game.squareSize
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	lengthScale = lengthScale or 1.0

	local extent = radius * max(1, lengthScale) * 1.42

	local minX = max(0, floor((centerX - extent) / squareSize) * squareSize)
	local maxX = min(mapSizeX, floor((centerX + extent) / squareSize) * squareSize)
	local minZ = max(0, floor((centerZ - extent) / squareSize) * squareSize)
	local maxZ = min(mapSizeZ, floor((centerZ + extent) / squareSize) * squareSize)

	local heightData = {}
	for z = minZ, maxZ, squareSize do
		for x = minX, maxX, squareSize do
			local dx = x - centerX
			local dz = z - centerZ
			local falloff = computeFalloff(dx, dz, radius, shape, angleDeg, curve, lengthScale)

			if falloff then
				local current = Spring.GetGroundHeight(x, z)
				local original = Spring.GetGroundOrigHeight(x, z)
				local newHeight = current + (original - current) * falloff * 0.3 * intensity
				heightData[#heightData + 1] = { x, z, newHeight }
			end
		end
	end

	if #heightData > 0 then
		local snapshot = {}
		Spring.SetHeightMapFunc(function()
			for i = 1, #heightData do
				snapshot[#snapshot + 1] = {heightData[i][1], heightData[i][2], Spring.GetGroundHeight(heightData[i][1], heightData[i][2])}
				Spring.SetHeightMap(heightData[i][1], heightData[i][2], heightData[i][3])
			end
		end)
		undoStack[#undoStack + 1] = snapshot
		if #undoStack > MAX_UNDO then
			table.remove(undoStack, 1)
		end
		redoStack = {}
		SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg == UNDO_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end

		if #undoStack == 0 then
			Spring.Echo("[Terraform Brush] Nothing to undo")
			return true
		end

		local snapshot = undoStack[#undoStack]
		undoStack[#undoStack] = nil

       -- Capture current state for redo before restoring
       local redoSnapshot = {}
       Spring.SetHeightMapFunc(function()
          for i = 1, #snapshot do
             redoSnapshot[#redoSnapshot + 1] = {snapshot[i][1], snapshot[i][2], Spring.GetGroundHeight(snapshot[i][1], snapshot[i][2])}
             Spring.SetHeightMap(snapshot[i][1], snapshot[i][2], snapshot[i][3])
          end
       end)
       if #redoSnapshot > 0 then
          redoStack[#redoStack + 1] = redoSnapshot
          if #redoStack > MAX_UNDO then
             table.remove(redoStack, 1)
          end
       end
       SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
       return true
    end

    if msg == REDO_HEADER then
       if not Spring.IsCheatingEnabled() then
          Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
          return true
       end

       if #redoStack == 0 then
          Spring.Echo("[Terraform Brush] Nothing to redo")
          return true
       end

       local snapshot = redoStack[#redoStack]
       redoStack[#redoStack] = nil

       -- Capture current state for undo before restoring
       local undoSnapshot = {}
       Spring.SetHeightMapFunc(function()
          for i = 1, #snapshot do
             undoSnapshot[#undoSnapshot + 1] = {snapshot[i][1], snapshot[i][2], Spring.GetGroundHeight(snapshot[i][1], snapshot[i][2])}
             Spring.SetHeightMap(snapshot[i][1], snapshot[i][2], snapshot[i][3])
          end
       end)
       if #undoSnapshot > 0 then
          undoStack[#undoStack + 1] = undoSnapshot
       end
       SendToUnsynced("TerraformBrushStacks", #undoStack, #redoStack)
       return true
    end

	if msg:sub(1, IMPORT_HEADER_LENGTH) == IMPORT_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end

		local payload = msg:sub(IMPORT_HEADER_LENGTH + 1)
		local parts = {}
		for word in payload:gmatch("[%-%.%w]+") do
			parts[#parts + 1] = word
		end

		local x = tonumber(parts[1])
		if not x then
			return true
		end

		local squareSize = Game.squareSize
		local mapSizeZ = Game.mapSizeZ

		local heightData = {}
		for j = 2, #parts do
			local h = tonumber(parts[j])
			if h then
				local z = (j - 2) * squareSize
				if z <= mapSizeZ then
					heightData[#heightData + 1] = { x, z, h }
				end
			end
		end

		if #heightData > 0 then
			Spring.SetHeightMapFunc(function()
				for i = 1, #heightData do
					Spring.SetHeightMap(heightData[i][1], heightData[i][2], heightData[i][3])
				end
			end)
		end
		return true
	end

	if msg:sub(1, RESTORE_HEADER_LENGTH) == RESTORE_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end

		local payload = msg:sub(RESTORE_HEADER_LENGTH + 1)
		local parts = {}
		for word in payload:gmatch("[%-%.%w]+") do
			parts[#parts + 1] = word
		end

		local centerX = tonumber(parts[1])
		local centerZ = tonumber(parts[2])
		local radius = tonumber(parts[3])
		local shape = parts[4] or "circle"
		local angleDeg = tonumber(parts[5]) or 0
		local curve = tonumber(parts[6]) or 1.0
		local intensity = tonumber(parts[7]) or 1.0
		local lengthScale = tonumber(parts[8]) or 2.0

		if not centerX or not centerZ or not radius then
			return true
		end

		radius = max(MIN_RADIUS, min(MAX_RADIUS, radius))
		curve = max(0.1, min(5.0, curve))
		intensity = max(0.1, min(100.0, intensity))
		lengthScale = max(0.2, min(5.0, lengthScale))

		applyRestore(centerX, centerZ, radius, shape, angleDeg, curve, intensity, lengthScale)
		return true
	end

	if msg:sub(1, SPLINE_RAMP_HEADER_LENGTH) == SPLINE_RAMP_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end

		local payload = msg:sub(SPLINE_RAMP_HEADER_LENGTH + 1)
		local parts = {}
		for word in payload:gmatch("[%-%.%w]+") do
			parts[#parts + 1] = word
		end

		local width = tonumber(parts[1])
		local numPts = tonumber(parts[2])
		if not width or not numPts or numPts < 2 then
			return true
		end

		width = max(MIN_RADIUS, min(MAX_RADIUS, width))
		local waypoints = {}
		for i = 1, numPts do
			local px = tonumber(parts[2 + (i - 1) * 2 + 1])
			local pz = tonumber(parts[2 + (i - 1) * 2 + 2])
			if not px or not pz then
				return true
			end
			waypoints[i] = { px, pz }
		end

		applySplineRamp(waypoints, width)
		return true
	end

	if msg:sub(1, RAMP_HEADER_LENGTH) == RAMP_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
			return true
		end

		local payload = msg:sub(RAMP_HEADER_LENGTH + 1)
		local parts = {}
		for word in payload:gmatch("[%-%.%w]+") do
			parts[#parts + 1] = word
		end

		local sX = tonumber(parts[1])
		local sZ = tonumber(parts[2])
		local sY = tonumber(parts[3])
		local eX = tonumber(parts[4])
		local eZ = tonumber(parts[5])
		local eY = tonumber(parts[6])
		local width = tonumber(parts[7])

		if not sX or not sZ or not sY or not eX or not eZ or not eY or not width then
			return true
		end

		width = max(MIN_RADIUS, min(MAX_RADIUS, width))
		applyRamp(sX, sZ, sY, eX, eZ, eY, width)
		return true
	end

	if msg:sub(1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
		return
	end

	if not Spring.IsCheatingEnabled() then
		Spring.Echo("[Terraform Brush] Requires /cheat to be enabled")
		return true
	end

	local payload = msg:sub(PACKET_HEADER_LENGTH + 1)
	local parts = {}
	for word in payload:gmatch("[%-%.%w]+") do
		parts[#parts + 1] = word
	end

	local direction = tonumber(parts[1])
	local centerX = tonumber(parts[2])
	local centerZ = tonumber(parts[3])
	local radius = tonumber(parts[4])
	local shape = parts[5] or "circle"
	local angleDeg = tonumber(parts[6]) or 0
	local curve = tonumber(parts[7]) or 1.0
	local heightMin = tonumber(parts[8])
	local heightMax = tonumber(parts[9])
	local intensity = tonumber(parts[10]) or 1.0
	local lengthScale = tonumber(parts[11]) or 2.0

	if not direction or not centerX or not centerZ or not radius then
		return true
	end

	radius = max(MIN_RADIUS, min(MAX_RADIUS, radius))
	curve = max(0.1, min(5.0, curve))
	intensity = max(0.1, min(100.0, intensity))
	lengthScale = max(0.2, min(5.0, lengthScale))

	applyTerraform(centerX, centerZ, radius, direction, shape, angleDeg, curve, heightMin, heightMax, intensity, lengthScale)
	return true
end
