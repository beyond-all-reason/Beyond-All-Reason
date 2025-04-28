local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Sensor Ranges Radar Preview",
		desc = "Raytraced Radar Range Coverage on building Radar (GL4)",
		author = "Beherith",
		date = "2021.07.12",
		license = "Lua: GPLv2, GLSL: (c) Beherith (mysterme@gmail.com)",
		layer = 0,
		enabled = true
	}
end

------- GL4 NOTES -----
-- There is regular radar and advanced radar, assumed to have identical ranges!

local SHADERRESOLUTION = 16 -- THIS SHOULD MATCH RADARMIPLEVEL!

local smallradarrange = 2100	-- updates to 'armrad' value
local largeradarrange = 3500	-- updates to 'armarad' value

local cmdidtoradarsize = {}
local radaremitheight = {}
local radarYOffset = 50			-- amount added to vertical height of overlay to more closely reflect engine radarLOS

-- Globals
local mousepos = { 0, 0, 0 }
local spGetActiveCommand = Spring.GetActiveCommand


local luaShaderDir = "LuaUI/Include/"
local LuaShader = VFS.Include(luaShaderDir .. "LuaShader.lua")
VFS.Include(luaShaderDir .. "instancevbotable.lua")

local radarTruthShader = nil

local smallradVAO = nil
local largeradVAO = nil
local selectedRadarUnitID = false

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.name == 'armarad' then
		largeradarrange = unitDef.radarDistance
	end
	if unitDef.name == 'armrad' then
		smallradarrange = unitDef.radarDistance
	end

	if unitDef.radarDistance > 2000 then
		radaremitheight[-1 * unitDefID] = unitDef.radarEmitHeight + radarYOffset

		if unitDef.radarDistance == smallradarrange then
			cmdidtoradarsize[-1 * unitDefID] = "small"
		end
		if unitDef.radarDistance == largeradarrange then
			cmdidtoradarsize[-1 * unitDefID] = "large"
		end
	end
end

local shaderConfig = {}
local vsSrcPath = "LuaUI/Shaders/sensor_ranges_radar_preview.vert.glsl"
local fsSrcPath = "LuaUI/Shaders/sensor_ranges_radar_preview.frag.glsl"

local shaderSourceCache = {
		vssrcpath = vsSrcPath,
		fssrcpath = fsSrcPath,
		shaderName = "radarTruthShader GL4",
		uniformInt = {
				heightmapTex = 0,
			},
		uniformFloat = {
			radarcenter_range = { 2000, 100, 2000, 2000 },
			resolution = { 128 },
		  },
		shaderConfig = shaderConfig,
	}

local function goodbye(reason)
	Spring.Echo("radarTruthShader GL4 widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
end

local function initgl4()
	radarTruthShader = LuaShader.CheckShaderUpdates(shaderSourceCache)

	if not radarTruthShader then
		goodbye("Failed to compile radarTruthShader  GL4 ")
	end

	local smol, smolsize = makePlaneVBO(1, 1, smallradarrange / SHADERRESOLUTION)
	local smoli, smolisize = makePlaneIndexVBO(smallradarrange / SHADERRESOLUTION, smallradarrange / SHADERRESOLUTION, true)
	smallradVAO = gl.GetVAO()
	smallradVAO:AttachVertexBuffer(smol)
	smallradVAO:AttachIndexBuffer(smoli)

	local larg, largsize = makePlaneVBO(1, 1, largeradarrange / SHADERRESOLUTION)
	local largi, largisize = makePlaneIndexVBO(largeradarrange / SHADERRESOLUTION, largeradarrange / SHADERRESOLUTION, true)
	largeradVAO = gl.GetVAO()
	largeradVAO:AttachVertexBuffer(larg)
	largeradVAO:AttachIndexBuffer(largi)
end


function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end

	if (smallradarrange > 2200) then
		Spring.Echo("Sensor Ranges Radar Preview does not support increased radar ranges modoptions, removing.")
		widgetHandler:RemoveWidget()
		return
	end

	initgl4()
end

function widget:SelectionChanged(sel)
	selectedRadarUnitID = false
	if #sel == 1 and Spring.GetUnitDefID(sel[1]) and cmdidtoradarsize[-Spring.GetUnitDefID(sel[1])] then
		selectedRadarUnitID = sel[1]
	end
end

function widget:DrawWorld()
	local cmdID
	if selectedRadarUnitID then
		cmdID = Spring.GetUnitDefID(selectedRadarUnitID)
		if cmdID then
			cmdID = -cmdID
		else
			selectedRadarUnitID = false
			return
		end
	else
		cmdID = select(2, spGetActiveCommand())
		if cmdID == nil or cmdID >= 0 then
			return
		end -- not build command
	end

	if Spring.IsGUIHidden() or (WG['topbar'] and WG['topbar'].showingQuit()) then
		return
	end

	local whichradarsize = cmdidtoradarsize[cmdID]
	if whichradarsize == nil then
		return
	end
	if selectedRadarUnitID then
		mousepos = { Spring.GetUnitPosition(selectedRadarUnitID) }
	else
		local mx, my, lp, mp, rp, offscreen = Spring.GetMouseState()
		local _, coords = Spring.TraceScreenRay(mx, my, true)
		if coords then
			mousepos = { coords[1], coords[2], coords[3] }
		end
	end

	gl.DepthTest(false)
	gl.Culling(GL.BACK)
	gl.Texture(0, "$heightmap")
	radarTruthShader:Activate()
	radarTruthShader:SetUniform("radarcenter_range",
		math.floor((mousepos[1] + 8) / (SHADERRESOLUTION * 2)) * (SHADERRESOLUTION * 2),
		mousepos[2] + radaremitheight[cmdID],
		math.floor((mousepos[3] + 8) / (SHADERRESOLUTION * 2)) * (SHADERRESOLUTION * 2),
		whichradarsize == "small" and smallradarrange or largeradarrange
	)
	if whichradarsize == "small" then
		smallradVAO:DrawElements(GL.TRIANGLES)
	elseif whichradarsize == "large" then
		largeradVAO:DrawElements(GL.TRIANGLES)
	end

	radarTruthShader:Deactivate()
	gl.Texture(0, false)
	gl.Culling(false)
	gl.DepthTest(true)
end