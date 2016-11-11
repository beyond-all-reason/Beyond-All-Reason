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

local font = gl.LoadFont(LUAUI_DIRNAME.."Fonts/FreeSansBold.otf", 55, 10, 10)
local shadowFont = gl.LoadFont(LUAUI_DIRNAME.."Fonts/FreeSansBold.otf", 55, 38, 1.6)


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GetUnitTeam        		= Spring.GetUnitTeam
local GetTeamInfo        		= Spring.GetTeamInfo
local GetPlayerInfo      		= Spring.GetPlayerInfo
local GetPlayerList    		    = Spring.GetPlayerList
local GetTeamColor       		= Spring.GetTeamColor
local GetVisibleUnits    		= Spring.GetVisibleUnits
local GetUnitDefID       		= Spring.GetUnitDefID
local GetAllUnits        		= Spring.GetAllUnits
local IsUnitInView	 	 		= Spring.IsUnitInView
local GetCameraPosition  		= Spring.GetCameraPosition
local GetUnitPosition    		= Spring.GetUnitPosition
local GetFPS					= Spring.GetFPS
local GetSpectatingState		= Spring.GetSpectatingState

local glDepthTest        		= gl.DepthTest
local glAlphaTest        		= gl.AlphaTest
local glColor            		= gl.Color
local glText             		= gl.Text
local glTranslate        		= gl.Translate
local glBillboard        		= gl.Billboard
local glDrawFuncAtUnit   		= gl.DrawFuncAtUnit
local glDrawListAtUnit   		= gl.DrawListAtUnit
local GL_GREATER     	 		= GL.GREATER
local GL_SRC_ALPHA				= GL.SRC_ALPHA	
local GL_ONE_MINUS_SRC_ALPHA	= GL.ONE_MINUS_SRC_ALPHA
local glBlending          		= gl.Blending
local glScale          			= gl.Scale

local glCreateList				= gl.CreateList
local glBeginEnd				= gl.BeginEnd
local glDeleteList				= gl.DeleteList
local glCallList				= gl.CallList

local diag						= math.diag

--------------------------------------------------------------------------------

local comms = {}
local drawShadow = fontShadow
local comnameList = {}
local CheckedForSpec = false

--------------------------------------------------------------------------------

--gets the name, color, and height of the commander
local function GetCommAttributes(unitID, unitDefID)
  local team = GetUnitTeam(unitID)
  if team == nil then
    return nil
  end
  local players = GetPlayerList(team)
  local name = (#players>0) and GetPlayerInfo(players[1]) or 'Robert Paulson'
  for _,pID in ipairs(players) do
    local pname,active,spec = GetPlayerInfo(pID)
    if active and not spec then
      name = pname
      break
    end
  end
  local r, g, b, a = GetTeamColor(team)
  local bgColor = {0,0,0,1}
  if (r + g*1.35 + b*0.5) < 0.75 then  -- not acurate (enough) with playerlist   but...   font:SetAutoOutlineColor(true)   doesnt seem to work
	bgColor = {1,1,1,1}
  end
  
  local height = UnitDefs[unitDefID].height + heightOffset
  return {name, {r, g, b, a}, height, bgColor}
end

local function createComnameList(attributes)
	comnameList[attributes[1]] = gl.CreateList( function()
		local outlineColor = {0,0,0,1}
		if (attributes[2][1] + attributes[2][2]*1.35 + attributes[2][3]*0.5) < 0.8 then
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

local function DrawName(unitID, attributes, shadow)
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

local vsx, vsy = Spring.GetViewGeometry()
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
	    
		glDrawFuncAtUnit(unitID, false, DrawName, unitID, attributes, fontShadow)
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
