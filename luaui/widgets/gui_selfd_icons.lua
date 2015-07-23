function widget:GetInfo()
   return {
      name      = "Self-Destruct icons",
      desc      = "",
      author    = "Floris",
      date      = "06.05.2014",
      license   = "GNU GPL, v2 or later",
      layer     = 5,
      enabled   = true
   }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local myTeamID                = Spring.GetLocalTeamID()

-- preferred to keep these values the same as fancy unit selections widget
local rectangleFactor		= 3.3
local scalefaktor			= 2.9
local unitConf				= {}


local font = gl.LoadFont(LUAUI_DIRNAME..'Fonts/FreeSansBold.otf', 50, 4, 3)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local selfdUnits = {}
local glDrawFuncAtUnit			= gl.DrawFuncAtUnit

local spIsGUIHidden				= Spring.IsGUIHidden
local spGetUnitDefID			= Spring.GetUnitDefID
local spIsUnitInView 			= Spring.IsUnitInView
local spGetUnitSelfDTime		= Spring.GetUnitSelfDTime
local spGetAllUnits				= Spring.GetAllUnits
local spGetUnitCommands			= Spring.GetUnitCommands

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function DrawIcon(posY, posX, iconSize, text)
	gl.Texture(':n:'..LUAUI_DIRNAME..'Images/skull.dds')
	gl.Color(0.9,0.9,0.9,1)
	gl.Translate(posX*0.9,posY,posX*1.5)
	gl.Billboard()
	gl.TexRect(-(iconSize/2), 0, (iconSize/2), iconSize)
	if string.len(text) > 0  and  text ~= 0 then
		font:Begin()
		font:SetTextColor({0.88,0.88,0.88,1})
		font:SetOutlineColor({0,0,0,0.6})
		font:Print(text, -(iconSize*0.92), 1, iconSize*0.84, "con")
		font:End()
	end
end


-- add unit-icon to unit
function AddSelfDUnit(unitID)
	local ud = UnitDefs[spGetUnitDefID(unitID)]
	
	givenUnits[unitID] = {}
	givenUnits[unitID].osClock			= os.clock()
	givenUnits[unitID].lastInViewClock	= os.clock()
	givenUnits[unitID].unitHeight		= ud.height
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

--------------------------------------------------------------------------------
-- Engine Calls
--------------------------------------------------------------------------------

function widget:Initialize()
	SetUnitConf()
	
	-- check all units for selfd cmd
	local units = spGetAllUnits()
	for _, unitID in ipairs(units) do
		if spGetUnitSelfDTime(unitID) ~= nil then 
			if spGetUnitSelfDTime(unitID) > 0 then
				selfdUnits[unitID] = true
			end
			-- check for queued selfd
			local unitQueue = spGetUnitCommands(unitID,20) or {}
			if (#unitQueue > 0) then
				for _,cmd in ipairs(unitQueue) do
					if cmd.id == CMD.SELFD then
						selfdUnits[unitID] = true
					end
				end
			end
		end
	end
end


-- draw icons
function widget:DrawWorld()
	--if spIsGUIHidden() then return end
	
	local gameSecs = Spring.GetGameSeconds()
	
	gl.DepthMask(true)
	gl.DepthTest(true)
	
	local unitDefs, unitScale, countdown
	for unitID, unitEndSecs in pairs(selfdUnits) do
		if spIsUnitInView(unitID) then
			unitDefs = unitConf[spGetUnitDefID(unitID)]
			unitScale = unitDefs.xscale*1.22 - (unitDefs.xscale/6.6)
			countdown = math.ceil(spGetUnitSelfDTime(unitID) / 2)
			glDrawFuncAtUnit(unitID, false, DrawIcon, 10.1, unitScale, 22, countdown)
		end
	end
	
	gl.Color(1,1,1,1)
	gl.Texture(false)
	gl.DepthTest(false)
	gl.DepthMask(false)
end


function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)

	-- check for queued selfd (to check if queue gets cancelled)
	if selfdUnits[unitID] then
		local foundSelfdCmd = false
		local unitQueue = spGetUnitCommands(unitID,20) or {}
		if (#unitQueue > 0) then
			for _,cmd in ipairs(unitQueue) do
				if cmd.id == CMD.SELFD then
					foundSelfdCmd = true
					break
				end
			end
		end
		if foundSelfdCmd then
			selfdUnits[unitID] = nil
		end
	end
	
	if cmdID == CMD.SELFD then
		if spGetUnitSelfDTime(unitID) > 0 then  	-- since cmd hasnt been cancelled yet
			selfdUnits[unitID] = nil
		else
			selfdUnits[unitID] = true
		end
	end
end


function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	
	if selfdUnits[unitID] then  
		selfdUnits[unitID] = nil
	end
end
