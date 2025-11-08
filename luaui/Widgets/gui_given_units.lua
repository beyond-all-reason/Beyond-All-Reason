local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name      = "Given Units",
      desc      = "Tags given units with 'new' icon",
      author    = "Floris",
      date      = "24.04.2014",
      license   = "GNU GPL, v2 or later",
      layer     = -50,
      enabled   = true
   }
end


-- Localized functions for performance

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame

-- config
local selectedFadeTime = 0.75
local timeoutFadeTime = 3
local timeoutTime = 6.5


--TODO
-- better icon because bloom makes the letters unreadable


local glDrawListAtUnit			= gl.DrawListAtUnit
local spIsGUIHidden				= Spring.IsGUIHidden
local spGetUnitDefID			= Spring.GetUnitDefID
local spIsUnitInView 			= Spring.IsUnitInView
local spGetCameraDirection		= Spring.GetCameraDirection

local drawList
local givenUnits = {}
local unitScale = {}
local unitHeight = {}
local sec = 0
local prevCam = {spGetCameraDirection()}
local myTeamID = Spring.GetLocalTeamID()

local gameStarted, selectionChanged

for udid, unitDef in pairs(UnitDefs) do
	local xsize, zsize = unitDef.xsize, unitDef.zsize
	local scale = 6*( xsize*xsize + zsize*zsize )^0.5
	unitScale[udid] = 7 + (scale/2.5)
	unitHeight[udid] = unitDef.height
end


function DrawIcon()
	local iconSize = 1
	gl.Translate(0,1,1.4)
	gl.Billboard()
	gl.TexRect(-(iconSize/2), 0, (iconSize/2), iconSize)
end


-- add unit-icon to unit
function AddGivenUnit(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	givenUnits[unitID] = {}
	givenUnits[unitID].osClock			= os.clock()
	givenUnits[unitID].lastInViewClock	= os.clock()
	givenUnits[unitID].unitHeight		= unitHeight[unitDefID]
	givenUnits[unitID].unitScale		= unitScale[unitDefID]
end

--------------------------------------------------------------------------------
-- Engine Calls
--------------------------------------------------------------------------------

function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
	end
end

function widget:GameStart()
	gameStarted = true
	maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	maybeRemoveSelf()
end

function widget:Initialize()
	if Spring.IsReplay() or spGetGameFrame() > 0 then
		maybeRemoveSelf()
	end
	drawList = gl.CreateList(DrawIcon)
end

function widget:Shutdown()
	gl.DeleteList(drawList)
end


function widget:Update(dt)
	sec = sec + dt
	if sec > 0.25 then
		sec = 0
		if selectionChanged then
			selectionChanged = nil
			local selectedUnitsCount = Spring.GetSelectedUnitsSorted()
			for uDID,unit in pairs(selectedUnitsCount) do
				for i=1,#unit do
					local unitID = unit[i]
					if givenUnits[unitID] then
						local currentAlpha = 1 - ((os.clock() - (givenUnits[unitID].osClock + (timeoutTime - timeoutFadeTime))) / timeoutFadeTime)
						if currentAlpha > 1 then
							currentAlpha = 1
						end
						givenUnits[unitID].selected = os.clock() -  (selectedFadeTime * (1 - currentAlpha))
						--givenUnits[unitID].selectedGameSecs = Spring.GetGameSeconds() + UnitDefs[spGetUnitDefID(unitID)].selfDCountdown
					else
						-- uncomment line below for testing
						-- AddGivenUnit(unitID)
					end
				end
			end
		end

		local camX, camY, camZ = spGetCameraDirection()
		if camX ~= prevCam[1] or  camY ~= prevCam[2] or  camZ ~= prevCam[3] then
			gl.DeleteList(drawList)
			drawList = gl.CreateList(DrawIcon)
		end
		prevCam = {camX,camY,camZ }
	end
end

function widget:DrawWorld()
	if spIsGUIHidden() then return end
	local osClock = os.clock()
	--local gameSecs = Spring.GetGameSeconds()

	gl.DepthMask(true)
	gl.DepthTest(true)
	gl.Texture('LuaUI/Images/new.dds')

	local alpha
	for unitID, unit in pairs(givenUnits) do
		if unit.selected then
			alpha = 1 - ((osClock - unit.selected) / selectedFadeTime)
		else
			alpha = 1 - ((osClock - (unit.osClock + (timeoutTime - timeoutFadeTime))) / timeoutFadeTime)
		end
		if spIsUnitInView(unitID) then

			if alpha <= 0 then
				givenUnits[unitID] = nil
			else
				gl.Color(1,1,1,alpha)
				glDrawListAtUnit(unitID, drawList, false, unit.unitScale, unit.unitScale, unit.unitScale)
			end
		else
			if unit.selected then
				givenUnits[unitID].selected = os.clock()
			else
				givenUnits[unitID].osClock = os.clock()
			end
		end
	end

	gl.Color(1,1,1,1)
	gl.Texture(false)
	gl.DepthTest(false)
	gl.DepthMask(false)
end

local lastreceiveframe = 0
-- add given units
function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if (newTeam == myTeamID) then
		AddGivenUnit(unitID)
		if lastreceiveframe < spGetGameFrame() then
			local x, y, z = Spring.GetUnitPosition(unitID)
			if x and y and z then
				Spring.SetLastMessagePosition(x, y, z)
			end
			lastreceiveframe = spGetGameFrame()
		end
	end
end


function widget:SelectionChanged(sel)
	selectionChanged = true
end

