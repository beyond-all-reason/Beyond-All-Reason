function widget:GetInfo()
	return {
		name = "Blueprint API",
		desc = "Utilities for interacting with and drawing blueprints",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true
	}
end

-- types
-- =====

---@alias Point number[]

---@class BlueprintUnit
---@field blueprintUnitID number a globally unique ID for this unit
---@field unitDefID number
---@field position Point
---@field facing number

---@class Blueprint
---@field units BlueprintUnit[]
---@field name string
---@field spacing number
---@field facing number
---@field dimensions number[]
---@field floatOnWater boolean
---@field ordered boolean

-- optimization
-- ============

local SpringGetUnitDefID = Spring.GetUnitDefID
local SpringGetUnitBuildFacing = Spring.GetUnitBuildFacing
local SpringGetUnitPosition = Spring.GetUnitPosition
local SpringGetGroundHeight = Spring.GetGroundHeight
local SpringPos2BuildPos = Spring.Pos2BuildPos
local SpringTestBuildOrder = Spring.TestBuildOrder
local SpringGetMyTeamID = Spring.GetMyTeamID

-- util
-- ====

---Creates a simple enum-like table, where for each entry, the key and value are the same. This allows syntax like
---ENUM.OPTION_ONE, while also having the value "OPTION_ONE" for serialization or printing.
---@param ... table a list of entries for the enum
---@return table
local function enum(...)
	local args = { ... }
	local result = {}
	for _, v in ipairs(args) do
		result[v] = v
	end
	return result
end

---@param a Point
---@param b Point
---@return Point
local function subtractPoints(a, b)
	local result = {}
	for i = 1, math.max(#a, #b) do
		result[i] = (a[i] or 0) - (b[i] or 0)
	end
	return result
end

---@param point Point
---@param center Point
---@param angle number
---@return Point
local function rotatePointXZ(point, center, angle)
	local rotatedPoint = {}

	-- Translate the point to the origin
	local translatedPoint = {
		point[1] - center[1],
		point[2],
		point[3] - center[3],
	}

	-- Perform the rotation
	rotatedPoint[1] = translatedPoint[1] * math.cos(angle) - translatedPoint[3] * math.sin(angle)
	rotatedPoint[3] = translatedPoint[1] * math.sin(angle) + translatedPoint[3] * math.cos(angle)

	-- Translate the point back to its original position
	rotatedPoint[1] = rotatedPoint[1] + center[1]
	rotatedPoint[3] = rotatedPoint[3] + center[3]

	return rotatedPoint
end

---@param bp Blueprint
---@param facing number
---@return Blueprint
local function rotateBlueprint(bp, facing)
	return table.merge(
		bp,
		{
			units = table.map(bp.units, function(bpu)
				return {
					blueprintUnitID = bpu.blueprintUnitID,
					unitDefID = bpu.unitDefID,
					position = rotatePointXZ(
						bpu.position,
						{ 0, 0, 0 },
						-facing * (math.pi / 2)
					),
					facing = (bpu.facing + facing) % 4
				}
			end),
			facing = (bp.facing + facing) % 4
		}
	)
end

-- GL4
-- ===

local includeDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(includeDir .. "LuaShader.lua")
VFS.Include(includeDir .. "instancevbotable.lua")

---@language Glsl
local vsSrc = [[
#version 420
#line 20000

//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec2 local_pos;

layout (location = 1) in vec3 world_pos;
layout (location = 2) in vec2 dimensions;
layout (location = 3) in vec4 color;

out DataVS {
	vec4 color;
} outputVars;

uniform sampler2D heightmapTex;

#line 25000
void main() {
	vec2 uvhm = heightmapUVatWorldPos(world_pos.xz);

	vec3 result_pos = vec3(
		world_pos.x + local_pos.x * dimensions.x,
		textureLod(heightmapTex, uvhm, 0.0).x,
		world_pos.z + local_pos.y * dimensions.y
	);

	gl_Position = cameraViewProj * vec4(result_pos, 1.0);

	outputVars.color = color;
}
]]

---@language Glsl
local fsSrc = [[
#version 420
#line 30000

in DataVS {
	vec4 color;
} inputVars;

out vec4 color;

#line 35000
void main() {
	color = inputVars.color;
}
]]

local outlineShader = nil

local outlineVertexVBOLayout = {
	{ id = 0, name = "position", size = 2 },
}

local outlineInstanceVBO = nil
local outlineInstanceVBOLayout = {
	{ id = 1, name = 'position', size = 3 },
	{ id = 2, name = 'dimensions', size = 2 },
	{ id = 3, name = 'color', size = 4 },
}

local function makeOutlineVBO()
	local vbo = gl.GetVBO(GL.ARRAY_BUFFER, true)

	local vboData = {}

	vboData[#vboData + 1] = -1 / 2
	vboData[#vboData + 1] = -1 / 2

	vboData[#vboData + 1] = -1 / 2
	vboData[#vboData + 1] = 1 / 2

	vboData[#vboData + 1] = 1 / 2
	vboData[#vboData + 1] = 1 / 2

	vboData[#vboData + 1] = 1 / 2
	vboData[#vboData + 1] = -1 / 2

	vboData[#vboData + 1] = -1 / 2
	vboData[#vboData + 1] = -1 / 2

	local numVertices = #vboData / 2

	vbo:Define(
		numVertices,
		outlineVertexVBOLayout
	)
	vbo:Upload(vboData)

	return vbo, numVertices
end

local function makeInstanceVBO(layout, vertexVBO, numVertices)
	local vbo = makeInstanceVBOTable(layout, nil, widget:GetInfo().name)
	vbo.vertexVBO = vertexVBO
	vbo.numVertices = numVertices
	vbo.VAO = makeVAOandAttach(vbo.vertexVBO, vbo.instanceVBO)
	return vbo
end

local function initGL4()
	local outlineVBO, outlineVertices = makeOutlineVBO()
	outlineInstanceVBO = makeInstanceVBO(outlineInstanceVBOLayout, outlineVBO, outlineVertices)

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	outlineShader = LuaShader(
		{
			vertex = vsSrc,
			fragment = fsSrc,
			uniformInt = {
				heightmapTex = 0
			},
		},
		widget:GetInfo().name
	)
	local shaderCompiled = outlineShader:Initialize()
	return shaderCompiled
end

-- draw
-- ====

local SQUARE_SIZE = 8
local BUILD_SQUARE_SIZE = SQUARE_SIZE * 2;

local UNIT_ALPHA = 0.6

local BUILD_MODES = enum(
	"SINGLE",
	"LINE",
	"SNAPLINE",
	"GRID",
	"BOX",
	"AROUND"
)

local activeBlueprint = nil
local activeBuildPositions = {}
local activeBuilderBuildOptions = {}

local function getBuildingDimensions(unitDefID, facing)
	local unitDef = UnitDefs[unitDefID]
	if (facing % 2 == 1) then
		return SQUARE_SIZE * unitDef.zsize, SQUARE_SIZE * unitDef.xsize
	else
		return SQUARE_SIZE * unitDef.xsize, SQUARE_SIZE * unitDef.zsize
	end
end

local function getUnitsBounds(units)
	if #units == 0 then
		return nil, nil, nil, nil
	end

	local r = table.reduce(
		units,
		function(acc, unit)
			local bw, bh = getBuildingDimensions(unit.unitDefID, unit.facing)
			local bxMin = unit.position[1] - bw / 2
			local bxMax = unit.position[1] + bw / 2
			local bzMin = unit.position[3] - bh / 2
			local bzMax = unit.position[3] + bh / 2

			acc.xMin = acc.xMin and math.min(acc.xMin, bxMin) or bxMin
			acc.xMax = acc.xMax and math.max(acc.xMax, bxMax) or bxMax
			acc.zMin = acc.zMin and math.min(acc.zMin, bzMin) or bzMin
			acc.zMax = acc.zMax and math.max(acc.zMax, bzMax) or bzMax

			return acc
		end,
		{}
	)

	return r.xMin, r.xMax, r.zMin, r.zMax
end

local function getBlueprintDimensions(blueprint, facing)
	local xMin, xMax, zMin, zMax = getUnitsBounds(blueprint.units)

	if not facing or facing % 2 == 0 then
		return xMax - xMin, zMax - zMin
	else
		return zMax - zMin, xMax - xMin
	end
end

---Find the closest position for a blueprint that is aligned with the map grid.
---
---Analogous to Pos2BuildPos (which positions individual units), but for whole blueprints.
---@param blueprint Blueprint
---@param pos Point
---@param facing number
local function snapBlueprint(blueprint, pos, facing)
	local result = { 0, pos[2], 0 }

	local xSize, zSize = getBlueprintDimensions(blueprint, facing or 0)

	-- snap build-positions to 16-elmo grid
	if math.floor(xSize / 16) % 2 > 0 then
		result[1] = math.floor((pos[1]) / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE + SQUARE_SIZE;
	else
		result[1] = math.floor((pos[1] + SQUARE_SIZE) / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE;
	end

	if math.floor(zSize / 16) % 2 > 0 then
		result[3] = math.floor((pos[3]) / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE + SQUARE_SIZE;
	else
		result[3] = math.floor((pos[3] + SQUARE_SIZE) / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE;
	end

	return result;
end

---See FillRowOfBuildPos
local function fillRow(x, z, xStep, zStep, n, facing)
	local result = {}
	for _ = 1, n do
		result[#result + 1] = { x, 0, z, facing }
		x = x + xStep
		z = z + zStep
	end

	return result
end

---See CGuiHandler::GetBuildPositions
local function getBuildPositionsSingle(blueprint, startPos)
	if not startPos then
		return {}
	end

	startPos = snapBlueprint(blueprint, startPos, blueprint.facing)

	return fillRow(startPos[1], startPos[3], 0, 0, 1)
end

---See CGuiHandler::GetBuildPositions
local function calculateSteps(blueprint, startPos, endPos, spacing)
	local bxSize, bzSize = getBlueprintDimensions(blueprint, blueprint.facing)

	local delta = subtractPoints(endPos, startPos)

	local xSize = bxSize + SQUARE_SIZE * spacing * 2
	local zSize = bzSize + SQUARE_SIZE * spacing * 2

	local xNum = math.floor((math.abs(delta[1]) + xSize * 1.4) / xSize)
	local zNum = math.floor((math.abs(delta[3]) + zSize * 1.4) / zSize)

	local xStep = math.floor((delta[1] > 0) and xSize or -xSize)
	local zStep = math.floor((delta[3] > 0) and zSize or -zSize)

	return xStep, zStep, xNum, zNum, delta
end

---See CGuiHandler::GetBuildPositions
local function getBuildPositionsLine(blueprint, startPos, endPos, spacing)
	if not startPos or not endPos or not spacing then
		return {}
	end

	startPos = snapBlueprint(blueprint, startPos, blueprint.facing)
	endPos = snapBlueprint(blueprint, endPos, blueprint.facing)

	local xStep, zStep, xNum, zNum, delta = calculateSteps(blueprint, startPos, endPos, spacing)

	local xDominatesZ = math.abs(delta[1]) > math.abs(delta[3])

	if xDominatesZ then
		zStep = xStep * delta[3] / (delta[1] ~= 0 and delta[1] or 1)
	else
		xStep = zStep * delta[1] / (delta[3] ~= 0 and delta[3] or 1)
	end

	return fillRow(startPos[1], startPos[3], xStep, zStep, xDominatesZ and xNum or zNum)
end

---See CGuiHandler::GetBuildPositions
local function getBuildPositionsSnapLine(blueprint, startPos, endPos, spacing)
	if not startPos or not endPos or not spacing then
		return {}
	end

	startPos = snapBlueprint(blueprint, startPos, blueprint.facing)
	endPos = snapBlueprint(blueprint, endPos, blueprint.facing)

	local xStep, zStep, xNum, zNum, delta = calculateSteps(blueprint, startPos, endPos, spacing)

	local xDominatesZ = math.abs(delta[1]) > math.abs(delta[3])

	if xDominatesZ then
		zStep = 0
	else
		xStep = 0
	end

	return fillRow(startPos[1], startPos[3], xStep, zStep, xDominatesZ and xNum or zNum)
end

---See CGuiHandler::GetBuildPositions
local function getBuildPositionsGrid(blueprint, startPos, endPos, spacing)
	if not startPos or not endPos or not spacing then
		return {}
	end

	startPos = snapBlueprint(blueprint, startPos, blueprint.facing)
	endPos = snapBlueprint(blueprint, endPos, blueprint.facing)

	local xStep, zStep, xNum, zNum, delta = calculateSteps(blueprint, startPos, endPos, spacing)

	local result = {}
	local z = startPos[3]
	for zn = 1, zNum do
		if zn % 2 == 0 then
			--fill row right to left
			table.append(result, fillRow(startPos[1] + (xNum - 1) * xStep, z, -xStep, 0, xNum))
		else
			--fill row left to right
			table.append(result, fillRow(startPos[1], z, xStep, 0, xNum))
		end
		z = z + zStep
	end

	return result
end

---See CGuiHandler::GetBuildPositions
local function getBuildPositionsBox(blueprint, startPos, endPos, spacing)
	if not startPos or not endPos or not spacing then
		return {}
	end

	startPos = snapBlueprint(blueprint, startPos, blueprint.facing)
	endPos = snapBlueprint(blueprint, endPos, blueprint.facing)

	local xStep, zStep, xNum, zNum, delta = calculateSteps(blueprint, startPos, endPos, spacing)

	local result = {}

	if xNum > 1 and zNum > 1 then
		-- go down left side
		table.append(result, fillRow(startPos[1], startPos[3] + zStep, 0, zStep, zNum - 1))
		-- go right bottom side
		table.append(result, fillRow(startPos[1] + xStep, startPos[3] + (zNum - 1) * zStep, xStep, 0, xNum - 1))
		-- go up right side
		table.append(result, fillRow(startPos[1] + (xNum - 1) * xStep, startPos[3] + (zNum - 2) * zStep, 0, -zStep, zNum - 1))
		-- go left top side
		table.append(result, fillRow(startPos[1] + (xNum - 2) * xStep, startPos[3], -xStep, 0, xNum - 1))
	elseif xNum == 1 then
		table.append(result, fillRow(startPos[1], startPos[3], 0, zStep, zNum))
	elseif zNum == 1 then
		table.append(result, fillRow(startPos[1], startPos[3], xStep, 0, xNum))
	end

	return result
end

---See CGuiHandler::GetBuildPositions
local function getBuildPositionsAround(blueprint, unitID)
	if not unitID then
		return {}
	end

	local unitDefID = SpringGetUnitDefID(unitID)
	local facing = SpringGetUnitBuildFacing(unitID)

	local oxSize, ozSize = getBuildingDimensions(unitDefID, facing)
	local xSize, zSize = getBlueprintDimensions(blueprint)

	local ox, oy, oz = SpringGetUnitPosition(unitID)

	local startPos = { ox - oxSize / 2, 0, oz - ozSize / 2 }
	local endPos = { ox + oxSize / 2, 0, oz + ozSize / 2 }

	local xNum = 0.99 + (ozSize / xSize)
	local zNum = 0.99 + (oxSize / xSize)

	local result = {}

	table.append(result, fillRow(endPos[1] + zSize / 2, startPos[3] + xSize / 2, 0, xSize, xNum, 3))
	table.append(result, fillRow(endPos[1] - xSize / 2, endPos[3] + zSize / 2, -xSize, 0, zNum, 2))
	table.append(result, fillRow(startPos[1] - zSize / 2, endPos[3] - xSize / 2, 0, -xSize, xNum, 1))
	table.append(result, fillRow(startPos[1] + xSize / 2, startPos[3] - zSize / 2, xSize, 0, zNum, 0))

	return result
end

local BUILD_MODES_HANDLERS = {
	SINGLE = getBuildPositionsSingle,
	LINE = getBuildPositionsLine,
	SNAPLINE = getBuildPositionsSnapLine,
	GRID = getBuildPositionsGrid,
	BOX = getBuildPositionsBox,
	AROUND = getBuildPositionsAround,
}

-- instanceIDs[buildPositionKey] = { outline = { instanceID1, ...}, unit = { instanceID1, ...}, }
local instanceIDs = {}

local function clearInstances()
	if outlineInstanceVBO then
		clearInstanceTable(outlineInstanceVBO)
	end

	if WG.StopDrawUnitShapeGL4 then
		WG.StopDrawAll(widget:GetInfo().name)
	end

	instanceIDs = {}
end

local blockingColor = { 1.0, 0.0, 0.0, 1.0 }
local buildableColor = { 0.0, 1.0, 0.0, 1.0 }
local unbuildableColor = { 1.0, 1.0, 0.0, 1.0 }

---Create building and outline instances for a blueprint at a given location
---@param blueprint Blueprint
---@param teamID Blueprint
---@param copyPosition Blueprint
---@param positionKey Blueprint
local function createInstancesForPosition(blueprint, teamID, copyPosition, positionKey)
	instanceIDs[positionKey] = { outline = {}, unit = {} }

	local effectiveBlueprint = blueprint
	if copyPosition[4] ~= nil then
		effectiveBlueprint = rotateBlueprint(blueprint, copyPosition[4])
	end

	for _, unit in ipairs(effectiveBlueprint.units) do
		local x = copyPosition[1] + unit.position[1]
		local z = copyPosition[3] + unit.position[3]

		local y = SpringGetGroundHeight(x, z)

		local sx, sy, sz = SpringPos2BuildPos(unit.unitDefID, x, y, z, unit.facing)

		local bw, bh = getBuildingDimensions(unit.unitDefID, unit.facing)

		local blocking = SpringTestBuildOrder(
			unit.unitDefID,
			sx, sy, sz,
			unit.facing
		)

		local color
		if blocking == 0 then
			color = blockingColor
		elseif activeBuilderBuildOptions[unit.unitDefID] then
			color = buildableColor
		else
			color = unbuildableColor
		end

		-- outline
		table.insert(instanceIDs[positionKey].outline, pushElementInstance(
			outlineInstanceVBO,
			{
				sx, sy, sz,
				bw, bh,
				unpack(color),
			},
			nil,
			true,
			true
		))

		-- building
		table.insert(instanceIDs[positionKey].unit, WG.DrawUnitShapeGL4(
			unit.unitDefID,
			sx, sy, sz,
			unit.facing * (math.pi / 2),
			UNIT_ALPHA,
			teamID,
			nil,
			nil,
			nil,
			widget:GetInfo().name
		))
	end
end

---Synchronize the building and outline instances with the given list of build positions.
---@param blueprint Blueprint
---@param buildPositions StartPoints
---@param teamID number
local function updateInstances(blueprint, buildPositions, teamID)
	if not blueprint or not buildPositions then
		clearInstances()
		return
	end

	local usedCacheKeys = {}

	-- add missing instances
	for _, copyPosition in ipairs(buildPositions) do
		--{ x, 0, z, facing }
		local positionKey = table.toString(copyPosition)
		usedCacheKeys[positionKey] = true

		if not instanceIDs[positionKey] then
			createInstancesForPosition(blueprint, teamID, copyPosition, positionKey)
		end
	end

	-- remove unused instances
	for positionKey, positionInstanceIDs in pairs(instanceIDs) do
		if not usedCacheKeys[positionKey] then
			for _, instanceID in ipairs(positionInstanceIDs.unit) do
				WG.StopDrawUnitShapeGL4(instanceID)
			end
			for _, instanceID in ipairs(positionInstanceIDs.outline) do
				popElementInstance(outlineInstanceVBO, instanceID, true)
			end
			instanceIDs[positionKey] = nil
		end
	end

	uploadAllElements(outlineInstanceVBO)
end

local function drawOutlines()
	if outlineInstanceVBO.usedElements == 0 then
		return
	end

	gl.LineWidth(2)
	gl.DepthTest(GL.ALWAYS) -- so that it wont be drawn behind terrain
	gl.DepthMask(false) -- so that we dont write the depth of the drawn pixels
	gl.Texture(0, "$heightmap")
	outlineShader:Activate()
	outlineInstanceVBO.VAO:DrawArrays(
		GL.LINE_STRIP,
		outlineInstanceVBO.numVertices,
		0,
		outlineInstanceVBO.usedElements,
		0
	)
	outlineShader:Deactivate()
	gl.Texture(0, false)
	gl.DepthTest(false)
end

function widget:DrawWorldPreUnit()
	if not activeBlueprint then
		return
	end

	-- units are drawn in gfx_DrawUnitShapeGL4:DrawWorldPreUnit()
	drawOutlines()
end

-- api
-- ===

local function setActiveBlueprint(bp)
	if bp then
		bp = rotateBlueprint(bp, bp.facing)
	end

	activeBlueprint = bp

	clearInstances()
	updateInstances(activeBlueprint, activeBuildPositions, SpringGetMyTeamID())
end

local function setBlueprintPositions(buildPositions)
	activeBuildPositions = buildPositions

	updateInstances(activeBlueprint, activeBuildPositions, SpringGetMyTeamID())
end

local function calculateBuildPositions(blueprint, mode, ...)
	return BUILD_MODES_HANDLERS[mode](blueprint, ...)
end

local function setActiveBuilders(unitIDs)
	activeBuilderBuildOptions = table.reduce(
		unitIDs,
		function(acc, cur)
			local unitDefID = SpringGetUnitDefID(cur)
			if unitDefID == nil then
				return acc
			end

			local unitDef = UnitDefs[unitDefID]
			if unitDef == nil then
				return acc
			end

			for _, buildOption in ipairs(unitDef.buildOptions) do
				acc[buildOption] = true
			end

			return acc
		end,
		{}
	)
end

function widget:Initialize()
	if not gl.CreateShader then
		-- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end

	if not initGL4() then
		-- shader compile failed
		widgetHandler:RemoveWidget()
		return
	end

	WG["api_blueprint"] = {
		setActiveBlueprint = setActiveBlueprint,
		setActiveBuilders = setActiveBuilders,
		setBlueprintPositions = setBlueprintPositions,

		rotateBlueprint = rotateBlueprint,
		calculateBuildPositions = calculateBuildPositions,
		getBuildingDimensions = getBuildingDimensions,
		getBlueprintDimensions = getBlueprintDimensions,
		getUnitsBounds = getUnitsBounds,
		snapBlueprint = snapBlueprint,
		BUILD_MODES = BUILD_MODES,
		SQUARE_SIZE = SQUARE_SIZE,
		BUILD_SQUARE_SIZE = BUILD_SQUARE_SIZE,
	}
end

function widget:Shutdown()
	WG["api_blueprint"] = nil

	clearInstances()

	if outlineInstanceVBO and outlineInstanceVBO.VAO then
		outlineInstanceVBO.VAO:Delete()
	end

	if outlineShader then
		outlineShader:Finalize()
	end
end
