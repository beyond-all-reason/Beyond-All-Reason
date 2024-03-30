function widget:GetInfo()
   return {
      name      = "API Unit Positions GL4",
      desc      = "Manages Unit Positions Texture",
      author    = "Beherith",
      date      = "2024.03.28",
      license   = "MINE",
      layer     = -900000,
			-- handler   = true,
      enabled   = true
   }
end


--------------------------------------------------------------------------------
-- Notes
-- An 8k x 256 texture (8k long)
-- 	RGBA0
--		RGB pos + Heading
--  RGBA1
--    RGB speed + Health?
--  RGBA32f texture
--	
-- Todo:
-- [ ] Alloc 8k texture
-- [ ] Figure out blend mode
-- [ ] Draw unit pos into texture	
-- [ ] Generate tristrip from texture
-- [ ] a way to track empty poisitions in table
-- [ ]
-- [ ]
-- [ ]
--
--------------------------------------------------------------------------------

local GL_RGBA32F_ARB = 0x8814


local autoreload = true
local texX, texY =  512, 256

local unitPosShader
local unitPosTexture
local unitPosIntanceVBO

local freeslots = {} -- an array of which slots are free
local numfreeslots = texX
for i=1, numfreeslots do freeslots[i] = texX - i end
local unitIDtoSlot = {}

local mobileUnitDefs = {}

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local shaderSourceCache = {
		vssrcpath = "LuaUI/Widgets/Shaders/unit_positions_texture.vert.glsl",
		fssrcpath = "LuaUI/Widgets/Shaders/unit_positions_texture.frag.glsl",
		uniformFloat = {
			time = 1.0,
		},
		uniformInt = {
			tex0 = 0,
		},
		shaderName = "unitPosShader GL4",
		shaderConfig = {
			TEXX = texX,
			TEXY = texY,
			},
	}

local function CreateUnitPosTexture()
	return gl.CreateTexture(texX, texY, {
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL_RGBA32F_ARB, -- more than enough
		})
end

local function initGL4()
	local quadVBO, numVertices = makeRectVBO(0,0,1,1,0,0,1,1) --(minX,minY, maxX, maxY, minU, minV, maxU, maxV)
  local unitPosIntanceVBOLayout = {
		  {id = 1, name = 'uvoffsets', size = 4}, -- widthlength
		  {id = 2, name = 'params', size = 4}, --  gf, 
		  {id = 3, name = 'instData', type = GL.UNSIGNED_INT, size= 4},
		}
  unitPosIntanceVBO = makeInstanceVBOTable(unitPosIntanceVBOLayout,256, "unitPosIntanceVBO", 3)
  unitPosIntanceVBO.numVertices = numVertices
  unitPosIntanceVBO.vertexVBO = quadVBO
  unitPosIntanceVBO.VAO = makeVAOandAttach(unitPosIntanceVBO.vertexVBO, unitPosIntanceVBO.instanceVBO)
  unitPosIntanceVBO.primitiveType = GL.TRIANGLES
  unitPosIntanceVBO.indexVBO = makeRectIndexVBO()
  unitPosIntanceVBO.VAO:AttachIndexBuffer(unitPosIntanceVBO.indexVBO)
  unitPosTexture = CreateUnitPosTexture()  
end

local function GetUnitPosTexture()
	return unitPosTexture
end

local function GetUnitIDtoSlot()
	return unitIDtoSlot
end
local function GetTexXY()
	return texX, texY
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end

	unitPosShader =  LuaShader.CheckShaderUpdates(shaderSourceCache)
	local shaderCompiled = unitPosShader:Initialize()
	if not shaderCompiled then Spring.Echo("Failed to compile unitPosShader GL4") end
	
	initGL4()
	
	for unitDefID, unitDef in pairs(UnitDefs) do
			if unitDef.maxAcc > 0 then
					mobileUnitDefs[unitDefID] = true
			end
	end
	
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
	
	WG['unitPosAPI'] = {}
	WG['unitPosAPI'].GetUnitPosTexture = GetUnitPosTexture
	WG['unitPosAPI'].GetUnitIDtoSlot = GetUnitIDtoSlot
	WG['unitPosAPI'].GetTexXY = GetTexXY
	widgetHandler:RegisterGlobal('GetUnitPosTexture', WG['unitPosAPI'].GetUnitPosTexture)
	widgetHandler:RegisterGlobal('GetUnitIDtoSlot', WG['unitPosAPI'].GetUnitIDtoSlot)
	widgetHandler:RegisterGlobal('GetTexXY', WG['unitPosAPI'].GetTexXY)
end

function widget:Shutdown()
	if infoTexture then gl.DeleteTexture(infoTexture) end
	WG['unitPosAPI'] = nil
	widgetHandler:DeregisterGlobal('GetUnitPosTexture')
	widgetHandler:DeregisterGlobal('GetUnitIDtoSlot')
	widgetHandler:DeregisterGlobal('GetTexXY')
end

local gameFrame = false
function widget:GameFrame(n)
	if (n % 1) == 0 then 
		gameFrame = true
	end
end

function widget:Update()
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	if not mobileUnitDefs[unitDefID] then return end
	local gf = Spring.GetGameFrame()
	local slot = freeslots[numfreeslots]
	freeslots[numfreeslots] = nil
	numfreeslots = numfreeslots - 1
	unitIDtoSlot[unitID] = slot
	
	--Spring.Echo("UnitPositions added unit ", UnitDefs[unitDefID].name, "at", slot, numfreeslots)
	pushElementInstance(
		unitPosIntanceVBO, -- push into this Instance VBO Table
		{
			slot, gf, 0, 0,
			0, 0, 0, 0, -- These are our default UV atlas tranformations
			0, 0, 0, 0 -- these are just padding zeros, that will get filled in
		},
		unitID, -- this is the key inside the VBO TAble,
		true, -- update existing element
		nil, -- noupload, dont use unless you know what you are doing
		unitID -- last one should be UNITID?
	)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	--Spring.Echo("widget:VisibleUnitsChanged",extVisibleUnits, extNumVisibleUnits)
	freeslots = {} -- an array of which slots are free
	numfreeslots = texY
	for i=1, numfreeslots do freeslots[i] = texY - i end
	for k,_ in pairs(unitIDtoSlot) do unitIDtoSlot[k] = nil end
	
	clearInstanceTable(unitPosIntanceVBO)
	for unitID, unitDefID in pairs(extVisibleUnits) do 
		widget:VisibleUnitAdded(unitID, unitDefID, Spring.GetUnitTeam(unitID))
	end
end

function widget:VisibleUnitRemoved(unitID, unitDefID)
	--unitDefID = unitDefID or Spring.GetUnitDefID(unitID)
	--if not mobileUnitDefs[unitDefID] then return end
	--Spring.Echo("widget:VisibleUnitRemoved",unitID)
	if unitPosIntanceVBO.instanceIDtoIndex[unitID] then 
		popElementInstance(unitPosIntanceVBO, unitID)
		
		--Spring.Echo("UnitPositions removed unit ", UnitDefs[unitDefID].name, "at", unitIDtoSlot[unitID], numfreeslots)
		numfreeslots = numfreeslots + 1
		freeslots[numfreeslots] = unitIDtoSlot[unitID]
		unitIDtoSlot[unitID] = nil
	end
end
local function renderToTextureFunc() 	
	gl.Blending(GL.ONE, GL.ZERO)
	unitPosIntanceVBO:draw()
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end

local function UpdateUnitPOSTexture()
	gl.DepthMask(false) -- dont write to depth buffer
	gl.Culling(false) -- cause our tris are reversed in plane vbo
	unitPosShader:Activate()
	gl.RenderToTexture(unitPosTexture, renderToTextureFunc)
	unitPosShader:Deactivate()
	gl.DepthMask(false) --"BK OpenGL state resets", reset to default state
end

function widget:DrawWorldPreUnit()
	if gameFrame then
		UpdateUnitPOSTexture(UpdateUnitPOSTexture)
		gameFrame = false
	end
end


function widget:DrawScreen() -- the debug display output
	if autoreload then
		--Spring.Echo(texY - numfreeslots, texX, texY, numfreeslots)
		unitPosShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or unitPosShader
		gl.Color(1,1,1,1) -- use this to show individual channels of the texture!
		gl.Blending(GL.ONE, GL.ZERO)
		gl.Texture(0, unitPosTexture)
		gl.TexRect(0, 0, texX * 2 , (texY - numfreeslots) * 2, 0, 0, 1, (texY - numfreeslots)/texY)
		--gl.TexRect(0, 0, texX * 2, texY *2 , 0, 0, 1, 1)
		gl.Texture(0, false)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
	
	if false then 
		gl.DepthMask(false) -- dont write to depth buffer
		gl.Culling(false) -- cause our tris are reversed in plane vbo
		unitPosShader:Activate()
		
		gl.Blending(GL.ONE, GL.ZERO)
		unitPosIntanceVBO:draw()
	
		unitPosShader:Deactivate()
		gl.DepthMask(false) --"BK OpenGL state resets", reset to default state
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
end






























