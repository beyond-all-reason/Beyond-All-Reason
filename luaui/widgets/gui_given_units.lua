function widget:GetInfo()
   return {
      name      = "Given Units",
      desc      = "Tags given units with 'new' icon",
      author    = "Floris",
      date      = "24.04.2014",
      license   = "GNU GPL, v2 or later",
      layer     = 5,
      enabled   = true
   }
end


--TODO
-- better icon because bloom makes the letters unreadable


--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

OPTIONS = {
	iconSize				= 32,
	selectedFadeTime		= 0.75,
	timeoutTime				= 7,
	timeoutFadeTime			= 3,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local myTeamID                = Spring.GetLocalTeamID()

-- preferred to keep these values the same as fancy unit selections widget
local rectangleFactor		= 3.3
local scalefaktor			= 2.9
local unitConf				= {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local givenUnits = {}
local glDrawListAtUnit			= gl.DrawListAtUnit
local glDrawFuncAtUnit			= gl.DrawFuncAtUnit

local spIsGUIHidden				= Spring.IsGUIHidden
local spGetSelectedUnitsCount	= Spring.GetSelectedUnitsCount
local spGetSelectedUnits		= Spring.GetSelectedUnits
local spGetUnitDefID			= Spring.GetUnitDefID
local spIsUnitInView 			= Spring.IsUnitInView
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

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


function DrawIcon(posY, posX, iconSize)
	gl.Translate(posX*0.9,posY,posX*1.5)
	gl.Billboard()
	gl.TexRect(-(iconSize/2), 0, (iconSize/2), iconSize)
end


-- add unit-icon to unit
function AddGivenUnit(unitID)
	local ud = UnitDefs[spGetUnitDefID(unitID)]
	
	givenUnits[unitID] = {}
	givenUnits[unitID].osClock			= os.clock()
	givenUnits[unitID].lastInViewClock	= os.clock()
	givenUnits[unitID].unitHeight		= ud.height
	--givenUnits[unitID].lastInViewClock	= Spring.GetGameSeconds() + OPTIONS.timeoutTime
	--givenUnits[unitID].endSecs			= Spring.GetGameSeconds() + OPTIONS.timeoutTime
end

--------------------------------------------------------------------------------
-- Engine Calls
--------------------------------------------------------------------------------

function widget:Initialize()
	
	SetUnitConf()
end


-- draw icons
function widget:DrawWorld()
	if spIsGUIHidden() then return end
	local osClock = os.clock()
	--local gameSecs = Spring.GetGameSeconds()
	
	gl.DepthMask(true)
	gl.DepthTest(true)
	gl.Texture('LuaUI/Images/new.dds')
	
	for unitID, unit in pairs(givenUnits) do
		local alpha = 1
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
				local unitDefs = unitConf[spGetUnitDefID(unitID)]
				local unitScale = unitDefs.xscale*1.22 - (unitDefs.xscale/6.6)
				glDrawFuncAtUnit(unitID, false, DrawIcon, 10, unitScale, OPTIONS.iconSize)
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
		local units = Spring.GetSelectedUnitsSorted()
		for uDID,_ in pairs(units) do
			if uDID ~= 'n' then --'n' returns table size
				for i=1,#units[uDID] do
					local unitID = units[uDID][i]
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
end

