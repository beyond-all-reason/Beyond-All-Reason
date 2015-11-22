function widget:GetInfo()
   return {
      name      = "EnemySpotter",
      desc      = "Draws transparant smoothed donuts under enemy units (with teamcolors or predefined colors, depending on situation)",
      author    = "Floris (original enemyspotter by TradeMark, who edited 'TeamPlatter' by Dave Rodgers)",
      date      = "18 february 2015",
      license   = "GNU GPL, v2 or later",
      layer     = 5,
      enabled   = true
   }
end

--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

-- /enemyspotter_self
-- /enemyspotter_all

-- /enemyspotter_platter
-- /+enemyspotter_platter		-- opacity
-- /-enemyspotter_platter		-- opacity

-- /enemyspotter_highlight
-- /+enemyspotter_highlight		-- opacity
-- /-enemyspotter_highlight		-- opacity

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local updateFrame        				= 25		-- only update every X gameframes (... if camera has still the same position)

local drawPlatter						= true
local useXrayHighlight					= false

local drawWithHiddenGUI                 = true		-- keep widget enabled when graphical user interface is hidden (when pressing F5)
local renderAllTeamsAsSpec				= false		-- renders for all teams when spectator
local renderAllTeamsAsPlayer			= false		-- keep this 'false' if you dont want circles rendered under your own units as player

local spotterOpacity					= 0.16

                                        
local defaultColorsForAllyTeams			= 0 		-- (number of teams)   if number <= of total numebr of allyTeams then dont use teamcoloring but default colors
local keepTeamColorsForSmallAllyTeam	= 3			-- (number of teams)   use teamcolors if number or teams (inside allyTeam)  <=  this value
local spotterColor = {								-- default color values
	{0,0,1} , {1,0,1} , {0,1,1} , {0,1,0} , {1,0.5,0} , {0,1,1} , {1,1,0} , {1,1,1} , {0.5,0.5,0.5} , {0,0,0} , {0.5,0,0} , {0,0.5,0} , {0,0,0.5} , {0.5,0.5,0} , {0.5,0,0.5} , {0,0.5,0.5} , {1,0.5,0.5} , {0.5,0.5,0.1} , {0.5,0.1,0.5},
}

local spotterImg			= ":n:"..LUAUI_DIRNAME.."Images/enemyspotter.dds"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local glDrawListAtUnit        = gl.DrawListAtUnit
local glDrawFuncAtUnit        = gl.DrawFuncAtUnit

local spGetTeamColor          = Spring.GetTeamColor
local spGetUnitDefDimensions  = Spring.GetUnitDefDimensions
local spGetUnitDefID          = Spring.GetUnitDefID
local spIsUnitSelected        = Spring.IsUnitSelected
local spGetAllyTeamList       = Spring.GetAllyTeamList
local spGetTeamList           = Spring.GetTeamList
local spIsGUIHidden           = Spring.IsGUIHidden
local spGetUnitAllyTeam       = Spring.GetUnitAllyTeam
local spGetVisibleUnits       = Spring.GetVisibleUnits
local spGetCameraPosition	  = Spring.GetCameraPosition
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetGameFrame	      = Spring.GetGameFrame
          
local myTeamID                = Spring.GetLocalTeamID()
local myAllyID                = Spring.GetMyAllyTeamID()
local gaiaTeamID			  = Spring.GetGaiaTeamID()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local allyColors       		= {}
local allyToSpotterColor	= {}
local unitConf				= {}
local skipOwnAllyTeam		= true
local lastUpdatedFrame		= 0
local drawUnits				= {}

local prevCam = {}
prevCam[1],prevCam[2],prevCam[3] = spGetCameraPosition()

local edgeExponent			= 1.5
local highlightOpacity		= 2.3
local smoothPolys			= gl.Smoothing			-- looks a lot nicer, esp. without FSAA  (but eats into the FPS too much)

-- preferred to keep these values the same as fancy unit selections widget
local rectangleFactor		= 3.3
local scalefaktor			= 2.9

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function CreateHighlightShader()
	if shader ~= nil then
		gl.DeleteShader(shader)
	end
	shader = gl.CreateShader({

	uniform = {
	  edgeExponent = edgeExponent * highlightOpacity,
	},

	vertex = [[
	  // Application to vertex shader
	  varying vec3 normal;
	  varying vec3 eyeVec;
	  varying vec3 color;
	  uniform mat4 camera;
	  uniform mat4 caminv;

	  void main()
	  {
		vec4 P = gl_ModelViewMatrix * gl_Vertex;
			  
		eyeVec = P.xyz;
			  
		normal  = gl_NormalMatrix * gl_Normal;
			  
		color = gl_Color.rgb;
			  
		gl_Position = gl_ProjectionMatrix * P;
	  }
	]],  

	fragment = [[
	  varying vec3 normal;
	  varying vec3 eyeVec;
	  varying vec3 color;

	  uniform float edgeExponent;

	  void main()
	  {
		float opac = dot(normalize(normal), normalize(eyeVec));
		opac = 1.0 - abs(opac);
		opac = pow(opac, edgeExponent);
		  
		gl_FragColor.rgb = color;
		gl_FragColor.a = opac;
	  }
	]],
	})
end


function setColors()
	
    if Spring.GetSpectatingState()  and  renderAllTeamsAsSpec then
        skipOwnAllyTeam = false
    elseif not Spring.GetSpectatingState() and renderAllTeamsAsPlayer then
        skipOwnAllyTeam = false
    end
    
	local allyToSpotterColorCount = 0
	local allyTeamList = spGetAllyTeamList()
	local numberOfAllyTeams = #allyTeamList
	for allyTeamListIndex = 1, numberOfAllyTeams do
		local allyID = allyTeamList[allyTeamListIndex]
		
		if not skipOwnAllyTeam  or  (skipOwnAllyTeam  and  not (allyID == myAllyID))  then
		
			allyToSpotterColorCount     = allyToSpotterColorCount+1
			allyToSpotterColor[allyID]  = allyToSpotterColorCount
			local usedSpotterColor      = spotterColor[allyToSpotterColorCount]
			if defaultColorsForAllyTeams < numberOfAllyTeams-1 then
				local teamList = Spring.GetTeamList(allyID)
				for teamListIndex = 1, #teamList do
					local teamID = teamList[teamListIndex]
					if teamID ~= gaiaTeamID then
						local pickTeamColor = false
						if (teamListIndex == 1  and  #teamList <= keepTeamColorsForSmallAllyTeam) then     -- only check for the first allyTeam, (to be consistent with picking a teamcolor or default color, inconsistency could happen with different teamsizes)
							pickTeamColor = true
						end
						if pickTeamColor then
						-- pick the first team in the allyTeam and take the color from that one
							if (teamListIndex == 1) then
								usedSpotterColor[1],usedSpotterColor[2],usedSpotterColor[3],_       = Spring.GetTeamColor(teamID)
							end
						end
					end
				end
			end
			teamList = Spring.GetTeamList(allyID)
			for teamListIndex = 1, #teamList do
				teamID = teamList[teamListIndex]
				if teamID ~= gaiaTeamID then
					allyColors[allyID] = usedSpotterColor
				end
			end
		end
	end
	
end

function SetUnitConf()
	for udid, unitDef in pairs(UnitDefs) do
		local xsize, zsize = unitDef.xsize, unitDef.zsize
		local scale = scalefaktor*( xsize^2 + zsize^2 )^0.5
		local shape, xscale, zscale
		
		if (unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0) then
			shape = 'square'
			xscale, zscale = rectangleFactor * xsize, rectangleFactor * zsize
		elseif (unitDef.isAirUnit) then
			shape = 'triangle'
			xscale, zscale = scale, scale
		else
			shape = 'circle'
			xscale, zscale = scale, scale
		end
		unitConf[udid] = {shape=shape, xscale=xscale, zscale=zscale}
	end
end

local function DrawGroundquad(x,y,z,size)
	gl.TexCoord(0,0)
	gl.Vertex(x-size,y,z-size)
	gl.TexCoord(0,1)
	gl.Vertex(x-size,y,z+size)
	gl.TexCoord(1,1)
	gl.Vertex(x+size,y,z+size)
	gl.TexCoord(1,0)
	gl.Vertex(x+size,y,z-size)
end


local visibleUnits = {}
local visibleUnitsCount = 0
function checkAllUnits()
	drawUnits = {}
	visibleUnits = spGetVisibleUnits(skipOwnAllyTeam and Spring.ENEMY_UNITS or Spring.ALL_UNITS, nil, false)
	visibleUnitsCount = #visibleUnits
	for i=1, visibleUnitsCount do
		checkUnit(visibleUnits[i])
	end
end

function checkUnit(unitID)
	local allyID = spGetUnitAllyTeam(unitID)
	if not skipOwnAllyTeam  or  (skipOwnAllyTeam  and  not (allyID == myAllyID))  then
		local unitDefIDValue = spGetUnitDefID(unitID)
		if (unitDefIDValue) then
			if drawUnits[allyID] == nil then
				drawUnits[allyID] = {}
			end
			drawUnits[allyID][unitID] = unitConf[unitDefIDValue].xscale*3
		end
	end
end
--------------------------------------------------------------------------------
-- Engine Calls
--------------------------------------------------------------------------------

function widget:Initialize()
	SetUnitConf()
	setColors()
	checkAllUnits()
	if gl.CreateShader ~= nil then
		CreateHighlightShader()
	end
end


function widget:Shutdown()
	
	if shader ~= nil then
		gl.DeleteShader(shader)
	end
end


function widget:DrawWorldPreUnit()
	if not drawWithHiddenGUI then
		if spIsGUIHidden() then return end
	end
	
	if drawPlatter then
		local unitZ = false
		
		gl.DepthTest(true)
		gl.PolygonOffset(-100, -2)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)      -- disable layer blending
		gl.Texture(spotterImg)
		
		local allyTeamList = spGetAllyTeamList()
		local numberOfAllyTeams = #allyTeamList
		for allyTeamListIndex = 1, numberOfAllyTeams do
			local allyID = allyTeamList[allyTeamListIndex]
			if allyColors[allyID] ~= nil and allyColors[allyID][1] ~= nil then
				gl.Color(allyColors[allyID][1],allyColors[allyID][2],allyColors[allyID][3],spotterOpacity)
				if drawUnits[allyID] ~= nil then
					for unitID, unitScale in pairs(drawUnits[allyID]) do
						glDrawFuncAtUnit(unitID, false, DrawSpotter, unitScale)
					end
				end
			end
		end
		gl.Texture(false)
		gl.Color(1,1,1,1)
		gl.PolygonOffset(false)
	end
end

function DrawSpotter(iconSize)
	gl.Rotate(90,1,0,0)
	gl.TexRect(-iconSize, iconSize, iconSize, -iconSize)
end


local sec = 0
local sceduledCheck = false
local updateTime = 1
function widget:Update(dt)
	sec=sec+dt
	local camX, camY, camZ = spGetCameraPosition()
	if camX ~= prevCam[1] or  camY ~= prevCam[2] or  camZ ~= prevCam[3] then
		sceduledCheck = true
	end
	if (sec>1/updateTime and lastUpdatedFrame ~= spGetGameFrame() or (sec>1/(updateTime*5) and sceduledCheck)) then
		sec = 0
		checkAllUnits()
		lastUpdatedFrame = spGetGameFrame()
		sceduledCheck = false
		updateTime = Spring.GetFPS() / 15
		if updateTime < 0.66 then 
			updateTime = 0.66
		end
	end
	prevCam[1],prevCam[2],prevCam[3] = camX,camY,camZ
end


function widget:DrawWorld()
	if useXrayHighlight then
		if not drawWithHiddenGUI then
			if spIsGUIHidden() then return end
		end
		
		local unitZ = false
		
		if visibleUnitsCount > 0 then
			if (smoothPolys) then
				gl.Smoothing(nil, nil, true)
			end

			gl.Color(1, 1, 1, 0.7)
			gl.UseShader(shader)
			gl.DepthTest(true)
			gl.Blending(GL.SRC_ALPHA, GL.ONE)
			gl.PolygonOffset(-2, -2)
			
			local allyTeamList = spGetAllyTeamList()
			local numberOfAllyTeams = #allyTeamList
			for allyTeamListIndex = 1, numberOfAllyTeams do
				local allyID = allyTeamList[allyTeamListIndex]
				if drawUnits[allyID] ~= nil and allyColors[allyID] ~= nil and allyColors[allyID][1] ~= nil then
					gl.Color(allyColors[allyID][1],allyColors[allyID][2],allyColors[allyID][3],highlightOpacity)
					for unitID, unitScale in pairs(drawUnits[allyID]) do
						gl.Unit(unitID, true)
					end
				end
			end
			
			gl.PolygonOffset(false)
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			gl.DepthTest(false)
			gl.UseShader(0)
			gl.Color(1, 1, 1, 0.7)
			
			if (smoothPolys) then
				gl.Smoothing(nil, nil, false)
			end
		end
	end
end

function widget:PlayerChanged()
    if Spring.GetSpectatingState()  and  renderAllTeamsAsSpec then
        skipOwnAllyTeam = false
        setColors()
    elseif not Spring.GetSpectatingState() and renderAllTeamsAsPlayer then
        skipOwnAllyTeam = false
        setColors()
    end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetConfigData(data)
    savedTable = {}
    savedTable.drawPlatter				= drawPlatter
    savedTable.useXrayHighlight			= useXrayHighlight
    savedTable.renderAllTeamsAsSpec		= renderAllTeamsAsSpec
    savedTable.renderAllTeamsAsPlayer	= renderAllTeamsAsPlayer
    savedTable.spotterOpacity			= spotterOpacity
    savedTable.highlightOpacity			= highlightOpacity
    return savedTable
end

function widget:SetConfigData(data)
    if data.drawPlatter ~= nil				then  drawPlatter				= data.drawPlatter end
    if data.useXrayHighlight ~= nil			then  useXrayHighlight			= data.useXrayHighlight end
    if data.renderAllTeamsAsSpec ~= nil		then  renderAllTeamsAsSpec		= data.renderAllTeamsAsSpec end
    if data.renderAllTeamsAsPlayer ~= nil	then  renderAllTeamsAsPlayer	= data.renderAllTeamsAsPlayer end
    spotterOpacity        = data.spotterOpacity       or spotterOpacity
    highlightOpacity        = data.highlightOpacity       or highlightOpacity
end

function widget:TextCommand(command)
	
    if (string.find(command, "enemyspotter_platter") == 1  and  string.len(command) == 20) then 
		drawPlatter = not drawPlatter
		if drawPlatter then
			Spring.Echo("EnemySpotter: drawing platters on")
		else
			Spring.Echo("EnemySpotter: drawing platters off")
		end
	end
    if (string.find(command, "enemyspotter_highlight") == 1  and  string.len(command) == 22) then 
    
		if (shader == nil) then
			Spring.Echo("EnemySpotter: This shader is not supported on your hardware, or you have disabled shaders in Spring settings.")
		else
			useXrayHighlight = not useXrayHighlight
			if useXrayHighlight then
				Spring.Echo("EnemySpotter: drawing unit highlight on")
			else
				Spring.Echo("EnemySpotter: drawing unit highlight off")
			end
		end
	end
    if (string.find(command, "enemyspotter_self") == 1  and  string.len(command) == 17) then 
		renderAllTeamsAsPlayer = not renderAllTeamsAsPlayer
		if not Spring.GetSpectatingState() then 
			skipOwnAllyTeam = not renderAllTeamsAsPlayer
			setColors()
		end
	end
    if (string.find(command, "enemyspotter_all") == 1  and  string.len(command) == 16) then 
		renderAllTeamsAsSpec = not renderAllTeamsAsSpec
		if Spring.GetSpectatingState() then 
			skipOwnAllyTeam = not renderAllTeamsAsSpec
			setColors()
		end
	end
    if (string.find(command, "+enemyspotter_platter") == 1) then spotterOpacity = spotterOpacity + 0.02; Spring.Echo("EnemySpotter: platter opacity: "..spotterOpacity) end
    if (string.find(command, "-enemyspotter_platter") == 1) then spotterOpacity = spotterOpacity - 0.02; Spring.Echo("EnemySpotter: platter opacity: "..spotterOpacity) end
    
    
    if (string.find(command, "+enemyspotter_highlight") == 1) then 
		highlightOpacity = highlightOpacity - (0.02 + highlightOpacity / 6) if highlightOpacity < 0.7 then highlightOpacity = 0.7 end
		Spring.Echo("EnemySpotter: highlight opacity: "..highlightOpacity) 
		CreateHighlightShader() 
	end
    if (string.find(command, "-enemyspotter_highlight") == 1) then 
		highlightOpacity = highlightOpacity + (0.02 + highlightOpacity / 6) if highlightOpacity > 10 then highlightOpacity = 10 end
		Spring.Echo("EnemySpotter: highlight opacity: "..highlightOpacity) 
		CreateHighlightShader() end
end
