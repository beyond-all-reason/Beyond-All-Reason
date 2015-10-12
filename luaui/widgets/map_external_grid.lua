--related thread: http://springrts.com/phpbb/viewtopic.php?f=13&t=26732&start=22
function widget:GetInfo()
  return {
    name      = "External VR Grid",
    desc      = "VR grid around map",
    author    = "knorke, tweaked by KR",
    date      = "Sep 2011",
    license   = "PD",
    layer     = -3,
    enabled   = false,
    --detailsDefault = 3,
  }
end

if VFS.FileExists("nomapedgewidget.txt") then
	return
end

local DspLst = nil
--local updateFrequency = 120	-- unused
local gridTex = "LuaUI/Images/vr_grid.png"
--local height = 0	-- how far above ground to draw

---magical speedups---
local math = math
local random = math.random
local spGetGroundHeight = Spring.GetGroundHeight
local glVertex = gl.Vertex
local glTexCoord = gl.TexCoord
local glColor = gl.Color
local glCreateList = gl.CreateList
local glTexRect = gl.TexRect
local spTraceScreenRay = Spring.TraceScreenRay
----------------------

local heights = {}
local island = false
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

--[[
local maxHillSize = 800/res
local maxPlateauSize = math.floor(maxHillSize*0.6)
local maxHeight = 300
local featureChance = 0.01
local noFeatureRange = 0
]]--

options_path = 'Settings/Graphics/Map/VR Grid'
options_order = {"mirrorHeightMap","res","range","northSouthText"}
options = {
	mirrorHeightMap = {
		name = "Mirror heightmap",
		type = 'bool',
		value = true,
		desc = 'Mirrors heightmap on the grid',
		OnChange = function(self)
			if DspLst then
				gl.DeleteList(DspLst)
				widget:Initialize()
			end
		end, 		
	},
	res = {
		name = "Tile size (64-512)",
		advanced = true,
		type = 'number',
		min = 64, 
		max = 512, 
		step = 64,
		value = 512,
		desc = 'Sets tile size (lower = more detail)\nStepsize is 64; recommend powers of 2',
		OnChange = function(self)
			if DspLst then
				gl.DeleteList(DspLst)
				widget:Initialize()
			end
		end, 
	},
	range = {
		name = "Range (1024-8192)",
		advanced = true,
		type = 'number',
		min = 1024, 
		max = 8192, 
		step = 256,
		value = 3072,
		desc = 'How far outside the map to draw',
		OnChange = function(self)
			if DspLst then
				gl.DeleteList(DspLst)
				widget:Initialize()
			end
		end, 
	},	
	northSouthText = {
		name = "North, East, South, & West text",
		type = 'bool',
		value = false,
		desc = 'Help you identify map direction under rotation by placing a "North/South/East/West" text on the map edges',
		OnChange = function(self)
			if DspLst then
				gl.DeleteList(DspLst)
				widget:Initialize()
			end
		end, 		
	},	
}

-- for terrain randomization - kind of primitive
--[[
local terrainFuncs = {
	ridge = function(x, z, args)
			if args.height == 0 then return end
			for a=x-args.sizeX*res, x+args.sizeX*res,res do
				for b=z-args.sizeZ*res, z+args.sizeZ*res,res do
					local distFromCenterX = math.abs(a - x)/res
					local distFromCenterZ = math.abs(b - z)/res
					local heightMod = 0
					local excessDistX, excessDistZ = 0, 0
					if distFromCenterX > args.plateauSizeX then
						excessDistX = distFromCenterX - args.plateauSizeX
					end
					if distFromCenterZ > args.plateauSizeZ then
						excessDistZ = distFromCenterZ - args.plateauSizeZ
					end
					if excessDistX == 0 and excessDistZ == 0 then
						-- do nothing
					elseif excessDistX >= excessDistZ then
						heightMod = excessDistX/(args.sizeX - args.plateauSizeX)
					elseif excessDistX < excessDistZ then
						heightMod = excessDistZ/(args.sizeZ - args.plateauSizeZ)
					end
					
					if heights[a] and heights[a][b] then
						heights[a][b] = heights[a][b] + args.height * (1-heightMod)
					end
				end
			end
			--Spring.Echo(count)
		end,
	diamondHill = function(x, z, args) end,
	mesa = function(x, z, args) end,
}
]]--
local function GetGroundHeight(x, z)
	return heights[x] and heights[x][z] or spGetGroundHeight(x,z)
end

local function IsIsland()
	local sampleDist = 512
	for i=1,mapSizeX,sampleDist do
		-- top edge
		if GetGroundHeight(i, 0) > 0 then
			return false
		end
		-- bottom edge
		if GetGroundHeight(i, mapSizeZ) > 0 then
			return false
		end
	end
	for i=1,mapSizeZ,sampleDist do
		-- left edge
		if GetGroundHeight(0, i) > 0 then
			return false
		end
		-- right edge
		if GetGroundHeight(mapSizeX, i) > 0 then
			return false
		end	
	end
	return true
end

local function InitGroundHeights()
	local res = options.res.value or 128
	local range = (options.range.value or 8192)/res
	local TileMaxX = mapSizeX/res +1
	local TileMaxZ = mapSizeZ/res +1
	
	for x = (-range)*res,mapSizeX+range*res, res do
		heights[x] = {}
		for z = (-range)*res,mapSizeZ+range*res, res do
			local px, pz
			if options.mirrorHeightMap.value then
				if (x < 0 or x > mapSizeX) then	-- outside X map bounds; mirror true heightmap
					local xAbs = math.abs(x)
					local xFrac = (mapSizeX ~= xAbs) and x%(mapSizeX) or mapSizeX
					local xFlip = -1^math.floor(x/mapSizeX)
					if xFlip == -1 then
						px = mapSizeX - xFrac
					else
						px = xFrac
					end
				end
				if (z < 0 or z > mapSizeZ) then	-- outside Z map bounds; mirror true heightmap
					local zAbs = math.abs(z)
					local zFrac = (mapSizeZ ~= zAbs) and z%(mapSizeZ) or mapSizeZ
					local zFlip = -1^math.floor(z/mapSizeZ)
					if zFlip == -1 then
						pz = mapSizeZ - zFrac
					else
						pz = zFrac
					end				
				end
			end
			heights[x][z] = GetGroundHeight(px or x, pz or z)	-- 20, 0
		end
	end
	
	--apply noise
	--[[
	for x=-range*res, (TileMaxX+range)*res,res do
		for z=-range*res, (TileMaxZ+range)*res,res do
			if (x > 0 and z > 0) then Spring.Echo(x, z) end
			if not (x + noFeatureRange > 0 and z + noFeatureRange > 0 and x - noFeatureRange < TileMaxX and z - noFeatureRange < TileMaxZ) and featureChance>math.random() then
				local args = {
					sizeX = math.random(1, maxHillSize),
					sizeZ = math.random(1, maxHillSize),
					plateauSizeX = math.random(1, maxPlateauSize),
					plateauSizeZ = math.random(1, maxPlateauSize),
					height = math.random(-maxHeight, maxHeight),
				}
				terrainFuncs.ridge(x,z,args)
			end
		end
	end	
	
	-- for testing
	local args = {
		sizeX = maxHillSize,
		sizeZ = maxHillSize,
		plateauSizeX = maxPlateauSize,
		plateauSizeZ = maxPlateauSize,
		height = maxHeight,
	}
	terrainFuncs.ridge(-600,-600,args)	
	]]--
end

--[[
function widget:GameFrame(n)
	if n % updateFrequency == 0 then
		DspList = nil
	end
end
]]--

local function TextOutside()
	if (options.northSouthText.value) then
		local mapSizeX = mapSizeX
		local mapSizeZ = mapSizeZ
		local average = (GetGroundHeight(mapSizeX/2,0) + GetGroundHeight(0,mapSizeZ/2) + GetGroundHeight(mapSizeX/2,mapSizeZ) +GetGroundHeight(mapSizeX,mapSizeZ/2))/4

		gl.Rotate(-90,1,0,0)
		gl.Translate (0,0,average)		
		gl.Text("North", mapSizeX/2, 200, 200, "co")
		
		gl.Rotate(-90,0,0,1)
		gl.Text("East", mapSizeZ/2, mapSizeX+200, 200, "co")
		
		gl.Rotate(-90,0,0,1)	
		gl.Text("South", -mapSizeX/2, mapSizeZ +200, 200, "co")
		
		gl.Rotate(-90,0,0,1)
		gl.Text("West", -mapSizeZ/2,200, 200, "co")
		
		-- gl.Text("North", mapSizeX/2, 100, 200, "on")
		-- gl.Text("South", mapSizeX/2,-mapSizeZ, 200, "on")
		-- gl.Text("East", mapSizeX,-(mapSizeZ/2), 200, "on")
		-- gl.Text("West", 0,-(mapSizeZ/2), 200, "on")
	end
end

local function TilesVerticesOutside()
	local res = options.res.value or 128
	local range = (options.range.value or 8192)/res
	local TileMaxX = mapSizeX/res +1
	local TileMaxZ = mapSizeZ/res +1	
	for x=-range,TileMaxX+range,1 do
		for z=-range,TileMaxZ+range,1 do
			if (x > 0 and z > 0 and x < TileMaxX and z < TileMaxZ) then 
			else
				glTexCoord(0,0)
				glVertex(res*(x-1), GetGroundHeight(res*(x-1),res*z), res*z)
				glTexCoord(0,1)
				glVertex(res*x, GetGroundHeight(res*x,res*z), res*z)
				glTexCoord(1,1)				
				glVertex(res*x, GetGroundHeight(res*x,res*(z-1)), res*(z-1))
				glTexCoord(1,0)
				glVertex(res*(x-1), GetGroundHeight(res*(x-1),res*(z-1)), res*(z-1))
			end
		end
	end
end

local function DrawTiles()
	gl.PushAttrib(GL.ALL_ATTRIB_BITS)
	gl.DepthTest(true)
	gl.DepthMask(true)
	gl.Texture(gridTex)
	gl.BeginEnd(GL.QUADS,TilesVerticesOutside)
	gl.Texture(false)
	gl.DepthMask(false)
	gl.DepthTest(false)
	TextOutside()
	glColor(1,1,1,1)
	gl.PopAttrib()
end

function widget:DrawWorldPreUnit()
	if DspLst then
		gl.CallList(DspLst)-- Or maybe you want to keep it cached but not draw it everytime.
		-- Maybe you want Spring.SetDrawGround(false) somewhere
	end	
end

function widget:DrawWorldRefraction()
	if DspLst then
		gl.CallList(DspLst)-- Or maybe you want to keep it cached but not draw it everytime.
		-- Maybe you want Spring.SetDrawGround(false) somewhere
	end	
end

function widget:MousePress(x, y, button)
	local _, mpos = spTraceScreenRay(x, y, true) --//convert UI coordinate into ground coordinate.
	if mpos==nil then --//activate epic menu if mouse position is outside the map
		local _, _, meta, _ = Spring.GetModKeyState()
		if meta then  --//show epicMenu when user also press the Spacebar
			WG.crude.OpenPath(options_path) --click + space will shortcut to option-menu
			WG.crude.ShowMenu() --make epic Chili menu appear.
			return false
		end
	end
end

function widget:Initialize()
	Spring.SendCommands("luaui disablewidget Map Edge Extension")
	island = IsIsland()
	InitGroundHeights()
	DspLst = glCreateList(DrawTiles)
end

function widget:Shutdown()
	gl.DeleteList(DspList)
end