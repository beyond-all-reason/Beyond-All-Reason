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
-- Config
--------------------------------------------------------------------------------

OPTIONS = {
	haloSize				= 0.8,
	haloDistance			= 4.5,
	skipBuildings			= true,
	fadeOnCameraDistance	= true,
	sizeVariation			= 0.09,
	sizeSpeed				= 0.65,		-- lower is faster
	opacityVariation		= 0.09,
}

local haloImg = ':n:'..LUAUI_DIRNAME..'Images/halo.dds'

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local myTeamID                = Spring.GetLocalTeamID()

-- preferred to keep these values the same as fancy unit selections widget
local scalefaktor			= 2.9
local unitConf				= {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local haloUnits = {}
local haloUnitsCount = 0
local glDrawListAtUnit			= gl.DrawListAtUnit
local glDrawFuncAtUnit			= gl.DrawFuncAtUnit

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
		unitConf[udid] = {scale=scale}
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
		local ud = UnitDefs[spGetUnitDefID(unitID)]
		
		haloUnits[unitID] = {}
		haloUnits[unitID].unitHeight		= ud.height
		haloUnits[unitID].sizeAddition		= 0
		haloUnits[unitID].sizeUp			= true
		haloUnits[unitID].opacityAddition	= 0
		haloUnits[unitID].opacityUp			= true
		haloUnits[unitID].name				= unitUnitDefs.name
		
		haloUnitsCount = haloUnitsCount + 1
	end
end

--------------------------------------------------------------------------------
-- Engine Calls
--------------------------------------------------------------------------------

function widget:Initialize()
	
	SetUnitConf()
	updateUnitlist()
end

function updateUnitlist()
	local units = Spring.GetAllUnits()
	local unitCount = #units
	for i=1, unitCount do
		local unitID = units[i]
		if haloUnits[unitID] == nil then
			if Spring.GetUnitRulesParam(unitID, "resurrected") ~= nil then
				AddHaloUnit(unitID)
			end
		end
	end
end


function widget:UnitCreated(unitID, unitDefID, teamID, builderID)
	if Spring.GetUnitRulesParam(unitID, "resurrected") ~= nil then
		AddHaloUnit(unitID)
	end
end

function widget:UnitEnteredLos(unitID)
	if Spring.GetUnitRulesParam(unitID, "resurrected") ~= nil then
		AddHaloUnit(unitID)
	end
end



function widget:DrawWorld()
	
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
					opacityMultiplier = 2.2 - (camDistance/2000)
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
					if OPTIONS.opacityVariation > 0 then 
						alpha = alpha - (OPTIONS.opacityVariation/2)
					end
					local alpha1 = alpha
					alpha = alpha + (alpha * (unit.sizeAddition))
					if alpha1 <= 0 then 
						haloUnits[unitID] = nil
						haloUnitsCount = haloUnitsCount - 1
					else
						gl.Color(1,1,1,alpha*opacityMultiplier)
						local unitDefs = unitConf[spGetUnitDefID(unitID)]
						if unitDefs ~= nil then
							local unitScale = unitDefs.scale
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


