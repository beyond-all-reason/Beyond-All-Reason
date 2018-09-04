function widget:GetInfo()
  return {
    name      = "Commander Name Tags",
    desc      = "Displays a name tags above commanders.",
    author    = "Bluestone, Floris",
    date      = "20 february 2015",
    license   = "GNU GPL, v2 or later",
    layer     = 2,
    enabled   = true,  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local nameScaling			= true
local useThickLeterring		= true
local heightOffset			= 50
local fontSize				= 15		-- not real fontsize, it will be scaled
local scaleFontAmount		= 120
local fontShadow			= true		-- only shows if font has a white outline
local shadowOpacity			= 0.35

local font = gl.LoadFont("LuaUI/Fonts/FreeSansBold.otf", 55, 10, 10)
local shadowFont = gl.LoadFont("LuaUI/Fonts/FreeSansBold.otf", 55, 38, 1.6)

local vsx, vsy = Spring.GetViewGeometry()

local singleTeams = false
if #Spring.GetTeamList()-1  ==  #Spring.GetAllyTeamList()-1 then
    singleTeams = true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GetUnitTeam        		= Spring.GetUnitTeam
local GetPlayerInfo      		= Spring.GetPlayerInfo
local GetPlayerList    		    = Spring.GetPlayerList
local GetTeamColor       		= Spring.GetTeamColor
local GetUnitDefID       		= Spring.GetUnitDefID
local GetAllUnits        		= Spring.GetAllUnits
local IsUnitInView	 	 		= Spring.IsUnitInView
local GetCameraPosition  		= Spring.GetCameraPosition
local GetUnitPosition    		= Spring.GetUnitPosition
local GetSpectatingState		= Spring.GetSpectatingState

local glDepthTest        		= gl.DepthTest
local glAlphaTest        		= gl.AlphaTest
local glColor            		= gl.Color
local glTranslate        		= gl.Translate
local glBillboard        		= gl.Billboard
local glDrawFuncAtUnit   		= gl.DrawFuncAtUnit
local GL_GREATER     	 		= GL.GREATER
local GL_SRC_ALPHA				= GL.SRC_ALPHA	
local GL_ONE_MINUS_SRC_ALPHA	= GL.ONE_MINUS_SRC_ALPHA
local glBlending          		= gl.Blending
local glScale          			= gl.Scale

local glCallList				= gl.CallList

local diag						= math.diag

--------------------------------------------------------------------------------

local comms = {}
local comnameList = {}
local CheckedForSpec = false
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()

local sameTeamColors = false
if WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors ~= nil then
    sameTeamColors = WG['playercolorpalette'].getSameTeamColors()
end

--------------------------------------------------------------------------------

--gets the name, color, and height of the commander
local function GetCommAttributes(unitID, unitDefID)
  local team = GetUnitTeam(unitID)
  if team == nil then
    return nil
  end

  local name = ''
  if Spring.GetGameRulesParam('ainame_'..team) then
      name = Spring.GetGameRulesParam('ainame_'..team)..' (AI)'
  else
    local players = GetPlayerList(team)
    name = (#players>0) and GetPlayerInfo(players[1]) or '------'
    for _,pID in ipairs(players) do
      local pname,active,spec = GetPlayerInfo(pID)
      if active and not spec then
        name = pname
        break
      end
    end
  end

  local r, g, b, a = GetTeamColor(team)
  local bgColor = {0,0,0,1}
  if (r + g*1.2 + b*0.4) < 0.8 then  -- try to keep these values the same as the playerlist
	bgColor = {1,1,1,1}
  end
  
  local height = UnitDefs[unitDefID].height + heightOffset
  return {name, {r, g, b, a}, height, bgColor}
end

local function RemoveLists()
    for name, list in pairs(comnameList) do
        gl.DeleteList(comnameList[name])
    end
    comnameList = {}
end

local function createComnameList(attributes)
    if comnameList[attributes[1]] ~= nil then
        gl.DeleteList(comnameList[attributes[1]])
    end
	comnameList[attributes[1]] = gl.CreateList( function()
		local outlineColor = {0,0,0,1}
		if (attributes[2][1] + attributes[2][2]*1.2 + attributes[2][3]*0.4) < 0.8 then  -- try to keep these values the same as the playerlist
			outlineColor = {1,1,1,1}
		end
		if useThickLeterring then
			if outlineColor[1] == 1 and fontShadow then
			  glTranslate(0, -(fontSize/44), 0)
			  shadowFont:Begin()
			  shadowFont:SetTextColor({0,0,0,shadowOpacity})
			  shadowFont:SetOutlineColor({0,0,0,shadowOpacity})
			  shadowFont:Print(attributes[1], 0, 0, fontSize, "con")
			  shadowFont:End()
			  glTranslate(0, (fontSize/44), 0)
			end
			font:SetTextColor(outlineColor)
			font:SetOutlineColor(outlineColor)
			
			font:Print(attributes[1], -(fontSize/38), -(fontSize/33), fontSize, "con")
			font:Print(attributes[1], (fontSize/38), -(fontSize/33), fontSize, "con")
		end
		font:Begin()
		font:SetTextColor(attributes[2])
		font:SetOutlineColor(outlineColor)
		font:Print(attributes[1], 0, 0, fontSize, "con")
		font:End()
	end)
end

function widget:Update(dt)
    if WG['playercolorpalette'] ~= nil then
        if WG['playercolorpalette'].getSameTeamColors and sameTeamColors ~= WG['playercolorpalette'].getSameTeamColors() then
            sameTeamColors = WG['playercolorpalette'].getSameTeamColors()
            RemoveLists()
            CheckAllComs()
        end
    elseif sameTeamColors == true then
        sameTeamColors = false
        RemoveLists()
        CheckAllComs()
    end
    if not singleTeams and WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors() then
        if myTeamID ~= Spring.GetMyTeamID() then
            -- old
            local name = GetPlayerInfo(select(2,Spring.GetTeamInfo(myTeamID)))
            if comnameList[name] ~= nil then
                gl.DeleteList(comnameList[name])
                comnameList[name] = nil
            end
            -- new
            myTeamID = Spring.GetMyTeamID()
            myPlayerID = Spring.GetMyPlayerID()
            name = GetPlayerInfo(select(2,Spring.GetTeamInfo(myTeamID)))
            if comnameList[name] ~= nil then
                gl.DeleteList(comnameList[name])
                comnameList[name] = nil
            end
            CheckAllComs()
        end
    end
end

local function DrawName(attributes)
	if comnameList[attributes[1]] == nil then
		createComnameList(attributes)
	end
	glTranslate(0, attributes[3], 0)
	glBillboard()
	if nameScaling then
		glScale(usedFontSize/fontSize,usedFontSize/fontSize,usedFontSize/fontSize)
	end
	glCallList(comnameList[attributes[1]])

	if nameScaling then
		glScale(1,1,1)
	end
end

function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()
end

function widget:DrawWorld()
  if Spring.IsGUIHidden() then return end
  -- untested fix: when you resign, to also show enemy com playernames  (because widget:PlayerChanged() isnt called anymore)
  if not CheckedForSpec and Spring.GetGameFrame() > 1 then
	  if GetSpectatingState() then
		CheckedForSpec = true
		CheckAllComs()
	  end
  end
  
  glDepthTest(true)
  glAlphaTest(GL_GREATER, 0)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
   
  local camX, camY, camZ = GetCameraPosition()
  
  for unitID, attributes in pairs(comms) do
    
    -- calc opacity
	if IsUnitInView(unitID) then
		local x,y,z = GetUnitPosition(unitID)
		camDistance = diag(camX-x, camY-y, camZ-z) 
		
	    usedFontSize = (fontSize*0.5) + (camDistance/scaleFontAmount)
	    
		glDrawFuncAtUnit(unitID, false, DrawName, attributes)
	end
  end
  
  glAlphaTest(false)
  glColor(1,1,1,1)
  glDepthTest(false)
end

--------------------------------------------------------------------------------

function CheckCom(unitID, unitDefID, unitTeam)
  if (unitDefID and UnitDefs[unitDefID] and UnitDefs[unitDefID].customParams.iscommander) then
      comms[unitID] = GetCommAttributes(unitID, unitDefID)
  end
end

function CheckAllComs()
  local allUnits = GetAllUnits()
  for _, unitID in pairs(allUnits) do
    local unitDefID = GetUnitDefID(unitID)
    if (unitDefID and UnitDefs[unitDefID].customParams.iscommander) then
      comms[unitID] = GetCommAttributes(unitID, unitDefID)
    end
  end
end

function widget:Initialize()
    CheckAllComs()
end

function widget:Shutdown()
    RemoveLists()
end

function widget:PlayerChanged(playerID)
  local name,_ = GetPlayerInfo(playerID)
  comnameList[name] = nil
  CheckAllComs() -- handle substitutions, etc
end
    
function widget:UnitCreated(unitID, unitDefID, unitTeam)
  CheckCom(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  comms[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
  CheckCom(unitID, unitDefID, unitTeam)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
  CheckCom(unitID, unitDefID, unitTeam)
end

function widget:UnitEnteredLos(unitID, unitDefID, unitTeam)
  CheckCom(unitID, unitDefID, unitTeam)
end


function toggleNameScaling()
	nameScaling = not nameScaling
end

function widget:GetConfigData()
    return {
        nameScaling = nameScaling
    }
end

function widget:SetConfigData(data) --load config
	widgetHandler:AddAction("comnamescale", toggleNameScaling)
	if data.nameScaling ~= nil then
		nameScaling = data.nameScaling
	end
end
