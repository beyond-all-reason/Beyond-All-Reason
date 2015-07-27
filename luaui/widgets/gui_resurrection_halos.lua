function widget:GetInfo()
   return {
      name      = "Resurrection Halos",
      desc      = "Gives units have have been resurrected a little halo above it.",
      author    = "Floris",
      date      = "18 february 2015",
      license   = "GNU GPL, v2 or later",
      layer     = 5,
      enabled   = true
   }
end

--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

-- /halos_buildings			-- toggles halos for buildings (and non-movable units/factories)
-- /halos_comsonly			-- toggles halos for coms only
-- /halos_dontfade			-- toggles halos to stay visible forever, or to slowly fade away eventually (coms will stay visible forever if defined in config)

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

OPTIONS = {
	haloSize				= 0.8,
	haloDistance			= 4.5,
	skipBuildings			= true,
	timeoutTime				= 90,
	timeoutFadeTime			= 40,
	dontTimeout				= true,
	dontTimeoutComs			= true,
	onlyForComs				= false,
	fadeOnCameraDistance	= true,
	sizeVariation			= 0.09,
	sizeSpeed				= 0.65,		-- lower is faster
	opacityVariation		= 0.09,
	--opacitySpeed			= 0.35,
}

local haloImg = ':n:'..LUAUI_DIRNAME..'Images/halo.dds'

local debug = false		-- set to true to make all selected units display a halo

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local myTeamID                = Spring.GetLocalTeamID()

-- preferred to keep these values the same as fancy unit selections widget
local rectangleFactor		= 3.3
local scalefaktor			= 2.9
local unitConf				= {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local haloUnits = {}
local haloUnitsCount = 0
local glDrawListAtUnit			= gl.DrawListAtUnit
local glDrawFuncAtUnit			= gl.DrawFuncAtUnit

local spIsGUIHidden				= Spring.IsGUIHidden
local spGetSelectedUnitsCount	= Spring.GetSelectedUnitsCount
local spGetSelectedUnits		= Spring.GetSelectedUnits
local spGetUnitDefID			= Spring.GetUnitDefID
local spIsUnitInView 			= Spring.IsUnitInView
local spGetCameraPosition 		= Spring.GetCameraPosition
local spGetUnitPosition			= Spring.GetUnitPosition

local prevOsClock				= os.clock();
	
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


function DrawIcon(posY, posX, haloSize)
	gl.Translate(0,posY,-(haloSize/2))
	gl.Rotate(90,1,0,0)
	gl.TexRect(-(haloSize/2), 0, (haloSize/2), haloSize)
end


-- add unit-icon to unit
function AddHaloUnit(unitID)
	local unitUnitDefs = UnitDefs[spGetUnitDefID(unitID)]
	if not OPTIONS.skipBuildings or (OPTIONS.skipBuildings and not (unitUnitDefs.isBuilding or unitUnitDefs.isFactory or unitUnitDefs.speed==0)) then
		if not OPTIONS.onlyForComs or (OPTIONS.onlyForComs and (unitUnitDefs.name == 'corcom' or unitUnitDefs.name == 'armcom')) then
			local ud = UnitDefs[spGetUnitDefID(unitID)]
			
			haloUnits[unitID] = {}
			haloUnits[unitID].unitHeight		= ud.height
			haloUnits[unitID].endSecs			= Spring.GetGameSeconds() + OPTIONS.timeoutTime
			haloUnits[unitID].sizeAddition		= 0
			haloUnits[unitID].sizeUp			= true
			haloUnits[unitID].opacityAddition	= 0
			haloUnits[unitID].opacityUp			= true
			haloUnits[unitID].name				= unitUnitDefs.name
			
			haloUnitsCount = haloUnitsCount + 1
		end
	end
end

--------------------------------------------------------------------------------
-- Engine Calls
--------------------------------------------------------------------------------

function widget:Initialize()
	
	SetUnitConf()
end

local gameStarted = false			
function widget:GameStart()
	gameStarted = true
end 

-- draw halos
function widget:DrawWorld()
	--if spIsGUIHidden() then return end
	
    osClock = os.clock()
    clockDiff = osClock - prevOsClock
	prevOsClock = osClock
	
	local camX, camY, camZ = spGetCameraPosition()
	
	if haloUnitsCount > 0 then
		gl.DepthMask(true)
		gl.DepthTest(true)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		gl.Texture(haloImg)
		for unitID, unit in pairs(haloUnits) do
			
			if spIsUnitInView(unitID) then
				local x,y,z = spGetUnitPosition(unitID)
				local xDifference = camX - x
				local yDifference = camY - y
				local zDifference = camZ - z
				local camDistance = math.sqrt(xDifference*xDifference + yDifference*yDifference + zDifference*zDifference)
				
				local opacityMultiplier = 1
				if OPTIONS.fadeOnCameraDistance then
					opacityMultiplier = 2.2 - (camDistance/1700)
					if opacityMultiplier > 1 then
						opacityMultiplier = 1
					end
				end
				if opacityMultiplier > 0.25 then
					-- calc addition size
					if OPTIONS.sizeVariation > 0 then
						if unit.sizeUp and unit.sizeAddition >= OPTIONS.sizeVariation / 2 then
							unit.sizeUp = false
						end
						if not unit.sizeUp and unit.sizeAddition <= -(OPTIONS.sizeVariation / 2) then
							unit.sizeUp = true
						end
						if unit.sizeUp then
							unit.sizeAddition = unit.sizeAddition + ((OPTIONS.sizeVariation / 2) * (clockDiff / OPTIONS.sizeSpeed))
							if unit.sizeAddition > (OPTIONS.sizeVariation / 2) then
								unit.sizeAddition = (OPTIONS.sizeVariation / 2)
							end
						else
							unit.sizeAddition = unit.sizeAddition - ((OPTIONS.sizeVariation / 2) * (clockDiff / OPTIONS.sizeSpeed))
							if unit.sizeAddition < -(OPTIONS.sizeVariation / 2) then
								unit.sizeAddition = -(OPTIONS.sizeVariation / 2)
							end
						end
					end
					local alpha = 1
					if not OPTIONS.dontTimeout and (not OPTIONS.dontTimeoutComs or (OPTIONS.dontTimeoutComs and unit.name ~= 'corcom' and unit.name ~= 'armcom')) then
						alpha = ((((unit.endSecs+OPTIONS.timeoutFadeTime) - gameSecs) / OPTIONS.timeoutTime))
					end
					if alpha > 1 then alpha = 1 end
					if OPTIONS.opacityVariation > 0 then alpha = alpha - (OPTIONS.opacityVariation/2) end
					local alpha1 = alpha
					alpha = alpha + (alpha * (unit.sizeAddition))
					if alpha1 <= 0 then 
						haloUnits[unitID] = nil
						haloUnitsCount = haloUnitsCount - 1
					else
						gl.Color(1,1,1,alpha*opacityMultiplier)
						local unitDefs = unitConf[spGetUnitDefID(unitID)]
						if unitDefs ~= nil then
							local unitScale = unitDefs.xscale
							if alpha < 1 then 
								alpha = 1
							end
							local iconsize = (unitScale * OPTIONS.haloSize) + ((unitScale * OPTIONS.haloSize) * unit.sizeAddition)
							glDrawFuncAtUnit(unitID, false, DrawIcon, unit.unitHeight+(OPTIONS.haloDistance * (unitScale/7)), 0, iconsize)
						end
					end
				end
			end
		end
		gl.Color(1,1,1,1)
		gl.Texture(false)
		gl.DepthTest(false)
		gl.DepthMask(false)
	end
end
	

-- detect resurrected units here
function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID  and  UnitDefs[spGetUnitDefID(builderID)].canResurrect then
		AddHaloUnit(unitID)
	end
end


-- for testing: draw halos on selected units
if debug then
	function widget:CommandsChanged()
		
		if spGetSelectedUnitsCount() > 0 then
			local units = Spring.GetSelectedUnitsSorted()
			for uDID,_ in pairs(units) do
				if uDID ~= 'n' then --'n' returns table size
					for i=1,#units[uDID] do
						local unitID = units[uDID][i]
						if not haloUnits[unitID] then
							AddHaloUnit(unitID)
						end
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetConfigData(data)
    savedTable = {}
    savedTable.skipBuildings	= OPTIONS.skipBuildings
    savedTable.onlyForComs		= OPTIONS.onlyForComs
    savedTable.dontTimeout		= OPTIONS.dontTimeout
    savedTable.lastOsClock		= os.clock()			-- save current time so we can restore haloUnits if a ´/luaui reload´ has been done
    savedTable.haloUnits		= haloUnits
    savedTable.haloUnitsCount	= haloUnitsCount
    return savedTable
end

function widget:SetConfigData(data)
    if data.skipBuildings ~= nil 	then  OPTIONS.skipBuildings	= data.skipBuildings end
    if data.onlyForComs ~= nil	 	then  OPTIONS.onlyForComs	= data.onlyForComs end
    if data.dontTimeout ~= nil	 	then  OPTIONS.dontTimeout	= data.dontTimeout end
		
    if	data.haloUnitsCount ~= nil and data.haloUnitsCount > 0 and data.haloUnits ~= nil and data.lastOsClock ~= nil  and  os.clock() - data.lastOsClock < 2 and gameStarted then
		haloUnits		= data.haloUnits
		haloUnitsCount	= data.haloUnitsCount
    end
end

function widget:TextCommand(command)
    if (string.find(command, "halos_buildings") == 1  and  string.len(command) == 27) then 
		OPTIONS.skipBuildings = not OPTIONS.skipBuildings
	end
    if (string.find(command, "halos_comsonly") == 1  and  string.len(command) == 26) then 
		OPTIONS.onlyForComs = not OPTIONS.onlyForComs
	end
    if (string.find(command, "halos_dontfade") == 1  and  string.len(command) == 26) then 
		OPTIONS.dontTimeout = not OPTIONS.dontTimeout
	end
end
