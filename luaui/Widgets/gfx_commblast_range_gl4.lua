function widget:GetInfo()
	return {
		name = "Commblast Range GL4",
		desc = "Draws the spherical commblast range onto the ground",
		author = "Beherith",
		date = "2022.08.27",
		license = "Lua code: GNU GPL, v2 or later, Shader GLSL code: (c) Beherith (mysterme@gmail.com)",
		layer = -1,
		enabled = true,
	}
end

local commblastSphereShader = nil

local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest


local spGetUnitPosition     = Spring.GetUnitPosition
local spGetGroundHeight		= Spring.GetGroundHeight
local spGetUnitNearestEnemy	= Spring.GetUnitNearestEnemy
local spIsGUIHidden			= Spring.IsGUIHidden
local spIsSphereInView		= Spring.IsSphereInView
local diag 					= math.diag

---- Config stuff ------------------
local commanders = {} -- keyed as {unitID : {draw = bool, oldopacity = 0.0, newopacity = 1.0}}
local commDefIds = { [UnitDefNames['corcom'].id] = true, [UnitDefNames['armcom'].id] = true}
local dgunRange	= WeaponDefNames["armcom_disintegrator"].range + WeaponDefNames["armcom_disintegrator"].damageAreaOfEffect

local blastRadius			= 370		-- com explosion
local showOnEnemyDistance	= 370
local fadeInDistance		= 160

---- GL4 Config stuff ----------------


local shaderConfig = {
	FULLRADIUS = 400,
	SPHERESEGMENTS = 8,
	BLASTRADIUS = blastRadius,
	DGUNRANGE = dgunRange,
	OPACITYMULTIPLIER = 0.75,
	TEAMCOLORED = 0
}

---- Object intersection test http://www.realtimerendering.com/intersections.html

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local commblastSphereVBO

local shaderSourceCache = {
		vssrcpath = "LuaUI/Widgets/Shaders/commblast_range.vert.glsl",
		fssrcpath = "LuaUI/Widgets/Shaders/commblast_range.frag.glsl",
		--gssrcpath = gsSrcPath,
		uniformInt = {
			mapDepths = 0,
		},
		uniformFloat = {
			fadeDistance = 300000,
		},
		shaderName = "Commblast Range GL4",
		shaderConfig = shaderConfig
	}

function widget:Update()
	--commblastSphereShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or commblastSphereShader
end

local function initFogGL4(shaderConfig, DPATname)
	commblastSphereShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or commblastSphereShader

	if not commblastSphereShader then
		Spring.Echo("Error: Commblast Range GL4 shader not initialized")
		widgetHandler:RemoveWidget()
		return
	end

	local sphereVBO, numVertices, sphereIndexVBO, numIndices = makeSphereVBO(shaderConfig.SPHERESEGMENTS, shaderConfig.SPHERESEGMENTS/2, 1)

	DrawPrimitiveAtUnitVBO = makeInstanceVBOTable(
		{
			{id = 3, name = 'params_alphastart_alphaend_gameframe', size = 4},
			{id = 4, name = 'instData', type = GL.UNSIGNED_INT, size = 4},
		},
		64, -- maxelements
		DPATname .. "VBO", -- name,
		4 --unitIDattribID
	)

	DrawPrimitiveAtUnitVBO:makeVAOandAttach(sphereVBO,DrawPrimitiveAtUnitVBO.instanceVBO, sphereIndexVBO)
	return DrawPrimitiveAtUnitVBO, commblastSphereShader
end
local cacheTable = {0,0,0,0,0,0,0,0}
local function AddBlastSphere(unitID, noUpload, oldopacity, newopacity, gameframe)
	--Spring.Echo("Added a unit")
	cacheTable[1] = oldopacity
	cacheTable[2] = newopacity
	cacheTable[3] = gameframe

	return pushElementInstance(commblastSphereVBO,
			cacheTable,
			unitID, true, noUpload, unitID)
end

function widget:RecvLuaMsg(msg, playerID)
	--Spring.Echo("widget:RecvLuaMsg",msg)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorldPreUnit()

	if chobbyInterface then return end
    if spIsGUIHidden() then return end

	if commblastSphereShader.shaderObj ~= nil and commblastSphereVBO.usedElements > 0 then
		--Spring.Echo(commblastSphereVBO.usedElements)
		glCulling(GL.FRONT)
		glDepthTest(GL.LEQUAL)
		glDepthTest(false)
		gl.DepthMask(false)
		gl.Texture(0, "$map_gbuffer_zvaltex")

		commblastSphereShader:Activate()
		commblastSphereVBO:Draw()
		commblastSphereShader:Deactivate()
		glTexture(0, false)
		glCulling(false)
		glDepthTest(false)
	end
end

--- Look how easy api_unit_tracker is to use!
function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	--Spring.Echo("VisibleUnitAdded",	unitID, unitDefID, unitTeam)
	if commDefIds[unitDefID] then
		commanders[unitID] = {draw = false, oldopacity = 0.0, newopacity = 0.0}
	end
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	clearInstanceTable(commblastSphereVBO) -- clear all instances
	for unitID, unitDefID in pairs(extVisibleUnits) do
		widget:VisibleUnitAdded(unitID, unitDefID)
	end
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	commanders[unitID] = nil
	if commblastSphereVBO.instanceIDtoIndex[unitID] then
		popElementInstance(commblastSphereVBO, unitID)
	end
end

function widget:GameFrame(n)
	-- This is where we update the alphas of the spheres
	-- also based on health!
	-- we gotta do this every 15 frames, and do interpolation in-shader for optimum efficiency
	-- check com movement, also try to draw as little as possible!
	-- api_unit_tracker will take care of removing invisible commanders for us
	-- but we have to add/update them here manually!
	if n%15 ~= 0 then return end

	-- in the first pass, identify which ones we want to draw, and set their new opacities accordingly

	-- do not draw if any:
		-- comm above ground
		-- not in view
		-- no enemies in range
	for unitID, params in pairs(commanders) do
		local x,y,z = spGetUnitPosition(unitID)
		local draw = false
		local newopacity = 0
		if x then
			local groundHeight = spGetGroundHeight(x,z)
			draw = true
			if y - groundHeight > 10 then
				draw = false
			elseif not spIsSphereInView(x,y,z,blastRadius) then
				draw = false
			end
			--	Spring.Echo(draw, groundHeight)
			if draw then
				draw = false
				local nearestEnemyUnitID = spGetUnitNearestEnemy(unitID,showOnEnemyDistance+fadeInDistance)
				if nearestEnemyUnitID then
					local ex,ey,ez = spGetUnitPosition(nearestEnemyUnitID)
					if ex then
						local distance = diag(x-ex, y-ey, z-ez)
						if distance <  (showOnEnemyDistance + fadeInDistance) then
							draw = true
							newopacity = 1.0 - math.min(1.0, math.max(0.0, (distance - showOnEnemyDistance) / fadeInDistance))
						end
					end
				end
			end
		end
		params.draw = draw
		params.oldopacity = params.newopacity
		params.newopacity = newopacity
	end
	clearInstanceTable(commblastSphereVBO)
	local gameframe = Spring.GetGameFrame()
	for unitID, params in pairs(commanders) do
		if params.draw then
			--Spring.Echo("Drawing blastsphere for", unitID, params.draw,params.newopacity, params.oldopacity)
			AddBlastSphere(unitID, true, params.oldopacity, params.newopacity, gameframe)
		end
	end
	uploadAllElements(commblastSphereVBO)
end

function widget:Initialize()
	commblastSphereVBO, commblastSphereShader = initFogGL4(shaderConfig, "commblastSpheres")
	--Spring.Echo(Spring.HaveShadows(),"advshad",Spring.HaveAdvShading())
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
end
