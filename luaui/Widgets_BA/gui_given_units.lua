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


--TODO
-- better icon because bloom makes the letters unreadable


--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

OPTIONS = {
	selectedFadeTime		= 0.75,
	timeoutTime				= 6.5,
	timeoutFadeTime			= 3,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local givenUnits = {}
local drawList
local unitConf = {}

local glDrawListAtUnit			= gl.DrawListAtUnit
local spIsGUIHidden				= Spring.IsGUIHidden
local spGetSelectedUnitsCount	= Spring.GetSelectedUnitsCount
local spGetUnitDefID			= Spring.GetUnitDefID
local spIsUnitInView 			= Spring.IsUnitInView
local spGetCameraDirection		= Spring.GetCameraDirection

local myTeamID                = Spring.GetLocalTeamID()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function SetUnitConf()
	for udid, unitDef in pairs(UnitDefs) do
		local xsize, zsize = unitDef.xsize, unitDef.zsize
		local scale = 6*( xsize^2 + zsize^2 )^0.5
		unitConf[udid] = 7 + (scale/2.5)
	end
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
	givenUnits[unitID].unitHeight		= UnitDefs[unitDefID].height
	givenUnits[unitID].unitScale		= unitConf[unitDefID]
	--givenUnits[unitID].lastInViewClock	= Spring.GetGameSeconds() + OPTIONS.timeoutTime
	--givenUnits[unitID].endSecs			= Spring.GetGameSeconds() + OPTIONS.timeoutTime
end

--------------------------------------------------------------------------------
-- Engine Calls
--------------------------------------------------------------------------------

function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget(self)
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
	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		maybeRemoveSelf()
	end
	SetUnitConf()
	drawList = gl.CreateList(DrawIcon)
end

function widget:Shutdown()
	gl.DeleteList(drawList)
end


local sec = 0
local prevCam = {spGetCameraDirection()}
function widget:Update(dt)
	sec = sec + dt
	if sec > 0.15 then
		sec = 0

		if commandsChangedCheck then
			commandsChangedCheck = nil
			for uDID,unit in pairs(Spring.GetSelectedUnitsSorted()) do
				if uDID ~= 'n' then --'n' returns table size
					for i=1,#unit do
						local unitID = unit[i]
						if givenUnits[unitID] then
							local currentAlpha = 1 - ((os.clock() - (givenUnits[unitID].osClock + (OPTIONS.timeoutTime - OPTIONS.timeoutFadeTime))) / OPTIONS.timeoutFadeTime)
							if currentAlpha > 1 then
								currentAlpha = 1
							end
							givenUnits[unitID].selected = os.clock() -  (OPTIONS.selectedFadeTime * (1 - currentAlpha))
							--givenUnits[unitID].selectedGameSecs = Spring.GetGameSeconds() + UnitDefs[spGetUnitDefID(unitID)].selfDCountdown
						else
							-- uncomment line below for testing
							-- AddGivenUnit(unitID)
						end
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


-- draw icons
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
			alpha = 1 - ((osClock - unit.selected) / OPTIONS.selectedFadeTime)
		else
			alpha = 1 - ((osClock - (unit.osClock + (OPTIONS.timeoutTime - OPTIONS.timeoutFadeTime))) / OPTIONS.timeoutFadeTime)
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


-- add given units
function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if (newTeam == myTeamID) then
		AddGivenUnit(unitID)
	end
end


-- remove icons when the given units are selected
function widget:CommandsChanged()
	
	if spGetSelectedUnitsCount() > 0 then
		commandsChangedCheck = true
	end
end

