local versionNumber = "1.71"

function widget:GetInfo()
  return {
    name      = "Commander Name Tags ",
    desc      = versionNumber .." Displays a name tag above each commander.",
    author    = "Evil4Zerggin and CarRepairer",
    date      = "18 April 2008",
    license   = "GNU GPL, v2 or later",
    layer     = -10,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local showStickyTags = false --comms literally wear name tags
local heightOffset = 22
local xOffset = 0
local yOffset = 0
local fontSize = 6

--------------------------------------------------------------------------------
-- speed-ups
--------------------------------------------------------------------------------

local GetUnitTeam         = Spring.GetUnitTeam
local GetTeamInfo         = Spring.GetTeamInfo
local GetPlayerInfo       = Spring.GetPlayerInfo
local GetTeamColor        = Spring.GetTeamColor
local GetUnitViewPosition = Spring.GetUnitViewPosition
local GetVisibleUnits     = Spring.GetVisibleUnits
local GetUnitDefID        = Spring.GetUnitDefID
local GetAllUnits         = Spring.GetAllUnits
local GetUnitHeading      = Spring.GetUnitHeading

local iconsize   = 10
local iconhsize  = iconsize * 0.5


local glColor             = gl.Color
--local glText              = gl.Text
local glPushMatrix        = gl.PushMatrix
local glPopMatrix         = gl.PopMatrix
local glTranslate         = gl.Translate
local glBillboard         = gl.Billboard
local glDrawFuncAtUnit    = gl.DrawFuncAtUnit

local glDepthTest      = gl.DepthTest
local glAlphaTest      = gl.AlphaTest
local glTexture        = gl.Texture
local glTexRect        = gl.TexRect
local glRotate         = gl.Rotate
local GL_GREATER       = GL.GREATER
local glUnitMultMatrix = gl.UnitMultMatrix
local glUnitPieceMultMatrix = gl.UnitPieceMultMatrix
local glScale          = gl.Scale


local overheadFont	= "LuaUI/Fonts/FreeSansBold_14"
local stickyFont	= "LuaUI/Fonts/FreeSansBold_14"
local fhDraw		= fontHandler.Draw
--------------------------------------------------------------------------------
-- local variables
--------------------------------------------------------------------------------

--key: unitID
--value: attributes = {name, color, height, currentAttributes, torsoPieceID}
--currentAttributes = {name, color, height}
local comms = {}

--------------------------------------------------------------------------------
-- helper functions
--------------------------------------------------------------------------------

--gets the name, color, and height of the commander
local function GetCommAttributes(unitID, unitDefID)
  local team = GetUnitTeam(unitID)
  if team == nil then
    return nil
  end
  local _, player = GetTeamInfo(team)
  local name = GetPlayerInfo(player) or 'Robert Paulson'
  local r, g, b, a = GetTeamColor(team)
  local height = UnitDefs[unitDefID].height + heightOffset
  local pm = spGetUnitPieceMap(unitID)
  local pmt = pm["torso"]
  if (pmt == nil) then 
    pmt = pm["chest"]
  end    
  return {name, {r, g, b, a}, height, pmt }
end

local function DrawCommName(unitID, attributes)
  glTranslate(0, attributes[3], 0 )
  glBillboard()
  
  glColor(attributes[2])
  --glText(attributes[1], xOffset, yOffset, fontSize, "cn")
  fontHandler.UseFont(overheadFont)
  fontHandler.DrawCentered(attributes[1], xOffset,yOffset)
  glColor(1,1,1,1)
end

local function DrawNameTag(rotation)
  glRotate(rotation,0,1,0)
  glTranslate(8, 35, 7)
  
  glColor(1,1,1,1)
  glTexRect(-iconhsize, 0, iconhsize, iconsize)
end

local function DrawCommName2(unitID, attributes, rotation)
  glRotate(rotation,0,1,0)
  glTranslate(8, 40, 7)

  glColor(attributes[2])
  --glText(attributes[1], xOffset, yOffset, 1, "cn")

  glColor(1,1,1,1)
end

--------------------------------------------------------------------------------
-- callins
--------------------------------------------------------------------------------

function widget:Initialize()
  local allUnits = GetAllUnits()
  for _, unitID in pairs(allUnits) do
    local unitDefID = GetUnitDefID(unitID)
    if (unitDefID and UnitDefs[unitDefID].customParams.iscommander) then
      comms[unitID] = GetCommAttributes(unitID, unitDefID)
    end
  end
end


function spGetUnitPieceMap(unitID,piecename)
  local pieceMap = {}
  local pl = Spring.GetUnitPieceList(unitID)
  if pl == nil then
    return pieceMap
  end
  for piecenum,piecename in pairs(pl) do
    pieceMap[piecename] = piecenum
  end
  return pieceMap
end


function widget:DrawWorld()
  glDepthTest(true)
  glAlphaTest(GL_GREATER, 0)

  if (showStickyTags) then
    glTexture('LuaUI/Images/hellomynameis.png')
    for unitID, attributes in pairs(comms) do
	  if (attributes[4]) then
	      glPushMatrix()
	      glUnitMultMatrix(unitID)
	      glUnitPieceMultMatrix(unitID, attributes[4])
	      glRotate(0,0,1,0)
	      glTranslate(8, 0, 7)
	      glColor(1,1,1,1)
	      glTexRect(-iconhsize, 0, iconhsize, iconsize)
	      glPopMatrix()
		end
    end
    for unitID, attributes in pairs(comms) do
	  if (attributes[4]) then
	      glPushMatrix()
	      glUnitMultMatrix(unitID)
	      glUnitPieceMultMatrix(unitID, attributes[4])
	      glRotate(0,0,1,0)
	      glTranslate(8, 0, 7)
	      glColor(attributes[2])
	 
	      glPushMatrix()
	      glScale(0.03, 0.03, 0.03)
	      glTranslate (0,120,5)
	      fontHandler.UseFont(stickyFont)
	      fontHandler.DrawCentered(attributes[1], 0,0)
	      glPopMatrix()
	 
	      glPopMatrix()
	  end
    end

  end
      
  for unitID, attributes in pairs(comms) do
    local heading = GetUnitHeading(unitID)
    if (not heading) then
      return
    end
    local rot = (heading / 32768) * 180
    glDrawFuncAtUnit(unitID, false, DrawCommName, unitID, attributes)
    if (showStickyTags) then
      glDrawFuncAtUnit(unitID, false, DrawCommName2, unitID, attributes, rot)
    end
  end

  glAlphaTest(false)
  glColor(1,1,1,1)
  glTexture(false)
  glDepthTest(false)
end

function widget:UnitCreated( unitID,  unitDefID,  unitTeam)
  if (unitDefID and UnitDefs[unitDefID] and UnitDefs[unitDefID].customParams.iscommander) then
    comms[unitID] = GetCommAttributes(unitID, unitDefID)
  end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  comms[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
  widget:UnitCreated( unitID,  unitDefID,  unitTeam)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
  widget:UnitCreated( unitID,  unitDefID,  unitTeam)
end

function widget:UnitEnteredLos(unitID, unitDefID, unitTeam)
  widget:UnitCreated( unitID,  unitDefID,  unitTeam)
end
