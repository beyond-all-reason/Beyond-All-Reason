
function widget:GetInfo()
  return {
    name      = "IdleBuildersNEW",
    desc      = "Adv Idle Indicator",
    author    = "Ray",
    date      = "Jul 23, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
include("colors.h.lua")

local vsx, vsy = widgetHandler:GetViewSizes()

function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
end

local MAX_ICONS = 10
local ICON_SIZE_X = 70
local ICON_SIZE_Y = 70
local CONDENSE = false -- show one icon for all builders of same type
local POSITION_X = 0.5 -- horizontal centre of screen
local POSITION_Y = 0.05 -- near bottom
local NEAR_IDLE = 8 -- this means that factories with only 8 build items left will be shown as idle
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


local X_MIN = 0
local X_MAX = 0
local Y_MIN = 0
local Y_MAX = 0
local drawTable = {}
local IdleList = {}
local activePress = false
local QCount = {}
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function IsIdleBuilder(unitID)
  local udef = Spring.GetUnitDefID(unitID)
  local ud = UnitDefs[udef] 
	local qCount = 0
  if ud.buildSpeed > 0 then  --- can build
    local bQueue = Spring.GetFullBuildQueue(unitID)
    if not bQueue[1] then  --- has no build queue
      local _, _, _, _, buildProg = Spring.GetUnitHealth(unitID)
      if buildProg == 1 then  --- isnt under construction
        if ud.isFactory then
          return true 
        else
          local cQueue = Spring.GetCommandQueue(unitID)
          if not cQueue[1] then
            return true
          end
        end
      end
		elseif ud.isFactory then
			for _, thing in ipairs(bQueue) do
				for _, count in pairs(thing) do
					qCount = qCount + count
				end 
			end
			if qCount <= NEAR_IDLE then
				QCount[unitID] = qCount
				return true
			end
    end
  end
  return false
end

local function DrawBoxes(number)
	gl.Color({ 0, 0, 0, 0.65 })
	X_MIN = POSITION_X*vsx-0.5*number*ICON_SIZE_X
	X_MAX = POSITION_X*vsx+0.5*number*ICON_SIZE_X
	Y_MIN = POSITION_Y*vsy-0.5*ICON_SIZE_Y
	Y_MAX = POSITION_Y*vsy+0.5*ICON_SIZE_Y
	local X1 = X_MIN
	local ct = 0
	while (ct < number) do
		ct = ct + 1
		local X2 = X1+ICON_SIZE_X
		
		gl.Shape(GL.LINE_LOOP, {
	    { v = { X1, Y_MIN } },
	    { v = { X2, Y_MIN } },
	    { v = { X2, Y_MAX } },
	    { v = { X1, Y_MAX } },
		})
		X1 = X2
		
	end
end--]]

local function SetupModelDrawing()
  gl.DepthTest(true) 
  gl.DepthMask(true)
  gl.Culling(GL.FRONT)
  gl.Lighting(true)
  gl.Blending(false)
  gl.Material({
    ambient  = { 1.0, 1.0, 1.0, 1.0 },
    diffuse  = { 1.0, 1.0, 1.0, 1.0 },
    emission = { 0.0, 0.0, 0.0, 1.0 },
    specular = { 0.3, 0.2, 0.2, 1.0 },
    shininess = 16.0
  })
end


local function RevertModelDrawing()
  gl.Blending(true)
  gl.Lighting(false)
  gl.Culling(false)
  gl.DepthMask(false)
  gl.DepthTest(false)
end

local function CenterUnitDef(unitDefID)
  local ud = UnitDefs[unitDefID] 
  if (not ud) then
    return
  end
  if (not ud.dimensions) then
    ud.dimensions = Spring.GetUnitDefDimensions(unitDefID)
  end
  if (not ud.dimensions) then
    return
  end

  local d = ud.dimensions
  local xSize = (d.maxx - d.minx)
  local ySize = (d.maxy - d.miny)
  local zSize = (d.maxz - d.minz)

  local hSize -- maximum horizontal dimension
  if (xSize > zSize) then hSize = xSize else hSize = zSize end

  -- aspect ratios
  local mAspect = hSize / ySize
  local vAspect = ICON_SIZE_X / ICON_SIZE_Y

  -- scale the unit to the box (maxspect)
  local scale
  if (mAspect > vAspect) then
    scale = (ICON_SIZE_X / hSize)
  else
    scale = (ICON_SIZE_Y / ySize)
  end
  scale = scale * 0.8
  gl.Scale(scale, scale, scale)

  -- translate to the unit's midpoint
  local xMid = 0.5 * (d.maxx + d.minx)
  local yMid = 0.5 * (d.maxy + d.miny)
  local zMid = 0.5 * (d.maxz + d.minz)
  gl.Translate(-xMid, -yMid, -zMid)
end



local function DrawUnitIcons(number)
	if not drawTable then
		return -1 
	end
	
	local ct = 0
	local X1, X2
	gl.Texture(false)
	SetupModelDrawing()
	
	gl.Scissor(true)
	while (ct < number) do
		ct = ct + 1
		
		gl.PushMatrix()
		X1 = X_MIN+(ICON_SIZE_X*(ct-1))
		X2 = X1+ICON_SIZE_X
		
		gl.Scissor(X1, Y_MIN, X2 - X1, Y_MAX - Y_MIN)
	
		gl.Translate(0.5*(X2+X1), 0.5*(Y_MAX+Y_MIN), 0)
		gl.Rotate(15.0, 1, 0, 0)
		
		CenterUnitDef(drawTable[ct].unitDefID)
		
		gl.UnitShape(drawTable[ct].unitDefID, Spring.GetMyTeamID())
		
		gl.Scissor(false)
		gl.PopMatrix()
		
		if CONDENSE then
			local NumberCondensed = table.getn(drawTable[ct].units)
			if NumberCondensed > 1 then
				gl.Text(NumberCondensed, X1, Y_MIN, 10, "o")
			end
			
		end
		
		local unitID = drawTable[ct].units
		if type(unitID) == 'table' then 
			unitID = unitID[1]
		end
		if QCount[unitID] then
			gl.Text(QCount[unitID], X1+(0.5*ICON_SIZE_X),Y_MIN,15,"ocn")
		end
			
	end
	RevertModelDrawing()
end--]]

local function MouseOverIcon(x, y)
	if not drawTable then return -1 end
	
	local NumOfIcons = table.getn(drawTable)
  if (x < X_MIN)   then return -1 end
  if (x > X_MAX)   then return -1 end
  if (y < Y_MIN)   then return -1 end
  if (y > Y_MAX)   then return -1 end
  
  local icon = math.floor((x-X_MIN)/ICON_SIZE_X)
  if (icon < 0) then
    icon = 0
  end
  if (icon >= NumOfIcons) then
    icon = (NumOfIcons - 1)
  end
  return icon
end--]]


function DrawIconQuad(iconPos, color)
  local X1 = X_MIN + (ICON_SIZE_X * iconPos)
  local X2 = X1 + ICON_SIZE_X
  
  gl.Color(color)
  gl.Blending(GL.SRC_ALPHA, GL.ONE)
  gl.Shape(GL.QUADS, {
    { v = { X1, Y_MIN } },
    { v = { X2, Y_MIN } },
    { v = { X2, Y_MAX } },
    { v = { X1, Y_MAX } },
  })
  
  gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end--]]


------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
local Clicks = {}
local mouseOnUnitID = nil


function widget:Initialize()
  local _, _, spec = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
  if spec then
   -- widgetHandler:RemoveWidget()
   -- return false
  end
	
	
end

function widget:GetConfigData(data)
  return {
    position_x = POSITION_X,
    position_y = POSITION_Y,
    max_icons = MAX_ICONS
  }
end

function widget:SetConfigData(data)
  POSITION_X = data.position_x or POSITION_X
	POSITION_Y = data.position_y or POSITION_Y
	MAX_ICONS = data.max_icons or MAX_ICONS
end


function widget:Update()
	IdleList = {}
	QCount = {}
	local myUnits = Spring.GetTeamUnitsSorted(Spring.GetMyTeamID())
	local unitCount = 0
	for unitDefID, unitTable in pairs(myUnits) do
		if type(unitTable) == 'table' then
			for count, unitID in pairs(unitTable) do
				if count ~= 'n' and IsIdleBuilder(unitID) then
					unitCount = unitCount + 1
					if IdleList[unitDefID] then
						table.insert(IdleList[unitDefID], unitID)
					else
						IdleList[unitDefID] = {unitID}
					end
				end
			end
		else
		
		end
	end

	if unitCount >= MAX_ICONS then
		CONDENSE = true
	else
		CONDENSE = false
	end
		
end



function widget:TweakMouseMove(x, y, dx, dy, button)
	local right = (x + (0.5*MAX_ICONS*ICON_SIZE_X))/vsx
	local left = (x - (0.5*MAX_ICONS*ICON_SIZE_X))/vsx
	local top = (y + (0.5*ICON_SIZE_Y))/vsy
	local bottom = (y - (0.5*ICON_SIZE_Y))/vsy
	if right > 1 then
		right = 1
		left = 1 - (MAX_ICONS*ICON_SIZE_X)/vsx
	end
	if left < 0 then
		left = 0
		right = (MAX_ICONS*ICON_SIZE_X)/vsx
	end
	if top > 1 then 
		top = 1
		bottom = 1 - ICON_SIZE_Y/vsy
	end
	if bottom < 0 then
		bottom = 0
		top = ICON_SIZE_Y/vsy
	end
	
	POSITION_X = 0.5*(right+left)
	POSITION_Y = 0.5*(top+bottom)
end

function widget:TweakMousePress(x, y, button)
	local iconNum = MouseOverIcon(x, y)
  if iconNum >= 0 then return true end
end

function widget:MouseWheel(up, value)
	if not widgetHandler:InTweakMode() then return false end
	
	local x,y,_,_,_ = Spring.GetMouseState()
	local iconNum = MouseOverIcon(x, y)
  if iconNum < 0 then return false end
	
	if up then
		MAX_ICONS = MAX_ICONS + 1
	else
		MAX_ICONS = MAX_ICONS - 1
		if MAX_ICONS < 1 then MAX_ICONS = 1 end
	end
	return true
end

function widget:DrawScreen()

	if widgetHandler:InTweakMode() then	
		DrawBoxes(MAX_ICONS)
		local line1 = "Idle cons tweak mode"
		local line2 = "Click and drag here to move icons around, hover over icons and move mouse wheel to change max number of icons"
		gl.Text(line1, POSITION_X*vsx, POSITION_Y*vsy, 15, "c")
		gl.Text(line2, POSITION_X*vsx, (POSITION_Y*vsy)-10, 10, "c")
		return
	end

	local noOfIcons = 0
	drawTable = {}
	
	for unitDefID, units in pairs(IdleList) do
		if CONDENSE then
			table.insert(drawTable, {unitDefID = unitDefID, units = units})
			noOfIcons = noOfIcons + 1
		else
			for _, unitID in pairs(units) do
				table.insert(drawTable, {unitDefID = unitDefID, units = unitID})
			end
			noOfIcons = noOfIcons + table.getn(units)
		end

	
	end
	if noOfIcons > MAX_ICONS then
		noOfIcons = MAX_ICONS
	elseif noOfIcons == 0 then
		return
	end
	gl.Clear(GL.DEPTH_BUFFER_BIT)
	
	DrawBoxes(noOfIcons)
	DrawUnitIcons(noOfIcons)
	

	local x, y, lb, mb, rb = Spring.GetMouseState()
	local icon = MouseOverIcon(x, y)
	if (icon >= 0) then
		if (lb or mb or rb) then
			DrawIconQuad(icon, { 1, 0, 0, 0.333 })
		else
			DrawIconQuad(icon, { 0, 0.1, 0.8, 0.433 })
		end
	end
  
end

--]]

function widget:DrawWorld()
	if widgetHandler:InTweakMode() then return -1 end
	
	local x,y,_,_,_ = Spring.GetMouseState()
	local iconNum = MouseOverIcon(x, y)
  if iconNum < 0 then
		mouseOnUnitID = nil
		return -1
	end
	
	local unitID = drawTable[iconNum+1].units
	local unitDefID = drawTable[iconNum+1].unitDefID
	if Clicks[unitDefID] == nil then
		Clicks[unitDefID] = 1
	end
	if type(unitID) == 'table' then
		unitID = unitID[math.fmod(Clicks[unitDefID]+1, table.getn(unitID))+1]
	end
	
	mouseOnUnitID = unitID
	-- hilight the unit we are about to click on
	gl.Unit(unitID, true)
end


function widget:DrawInMiniMap(sx, sz)
	if not mouseOnUnitID then return -1 end
	
	local ux, uy, uz = Spring.GetUnitPosition(mouseOnUnitID)
  if (not ux or not uy or not uz) then
    return
  end
	local xr = ux/(Game.mapX*512)
	local yr = 1 - uz/(Game.mapY*512)
	gl.Color(1,0,0)
	gl.Rect(xr*sx, yr*sz, (xr*sx)+5, (yr*sz)+5)
end


function widget:MousePress(x, y, button)
  local icon = MouseOverIcon(x, y)
  activePress = (icon >= 0)
  return activePress
end


function widget:MouseRelease(x, y, button)
  if not activePress then return -1 end
  activePress = false
	
  local iconNum = MouseOverIcon(x, y)
	if iconNum < 0 then return -1 end
	
  local unitID = drawTable[iconNum+1].units	
	local unitDefID = drawTable[iconNum+1].unitDefID
	
	if type(unitID) == 'table' then
		if Clicks[unitDefID] then
			Clicks[unitDefID] = Clicks[unitDefID] + 1
		else
			Clicks[unitDefID] = 1
		end
		unitID = unitID[math.fmod(Clicks[unitDefID], table.getn(unitID))+1]
	end
	
  local alt, ctrl, meta, shift = Spring.GetModKeyState()
  
  if (button == 1) then -- left mouse
    Spring.SelectUnitArray({unitID})
  elseif (button == 2) then -- middle mouse
    Spring.SelectUnitArray({unitID})
    Spring.SendCommands({"viewselection"})   
  end
	
  return -1
end

function widget:GetTooltip(x, y)
  local iconNum = MouseOverIcon(x, y)
  local units = drawTable[iconNum+1].units
	if type(units) == 'table' then
		units = units[1]
	end
  local unitDefID = Spring.GetUnitDefID(units)
  local ud = UnitDefs[unitDefID]
  return ud.humanName .. "\nLeft mouse: select unit\nMiddle mouse: move to unit\n"
end

function widget:IsAbove(x, y)
  if MouseOverIcon(x, y) == -1 then
    return false
  else
   return true
  end
end

function echo(msg)
	if type(msg) == 'string' or type(msg) == 'number' then
		Spring.SendCommands({"echo " .. msg})
	elseif type(msg) == 'table' then
		Spring.SendCommands({"echo echo failed on table"})
	else
		Spring.SendCommands({"echo broke :-"})
	end
end
