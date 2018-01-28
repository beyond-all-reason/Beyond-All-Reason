function widget:GetInfo()
   return {
      name      = "Resurrection Halos",
      desc      = "Gives units have have been resurrected a little halo above it.",
      author    = "Floris",
      date      = "18 february 2015",
      license   = "GNU GPL, v2 or later",
      layer     = -50,
      enabled   = true
   }
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

OPTIONS = {
	haloSize				= 0.8,
	haloDistance			= 4.2,
	skipBuildings			= true,
	fadeOnCameraDistance	= true,
	sizeVariation			= 0.09,
	sizeSpeed				= 0.65,		-- lower is faster
	opacityVariation		= 0.1,
}

local haloImg = ':n:LuaUI/Images/halo.dds'

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local unitConf = {}
local drawLists = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local haloUnits = {}
local haloUnitsCount = 0
local glDrawListAtUnit			= gl.DrawListAtUnit

local spGetUnitDefID			= Spring.GetUnitDefID
local spIsUnitInView 			= Spring.IsUnitInView
local spGetCameraPosition 		= Spring.GetCameraPosition
local spGetUnitPosition			= Spring.GetUnitPosition

local prevOsClock				= os.clock();

local diag						= math.diag

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function SetUnitConf()
	for udid, unitDef in pairs(UnitDefs) do
		local xsize, zsize = unitDef.xsize, unitDef.zsize
		local scale = 3*( xsize^2 + zsize^2 )^0.5

		unitConf[udid] = {scale=scale, iconSize=scale*OPTIONS.haloSize, height=math.ceil((unitDef.height+(OPTIONS.haloDistance * (scale/7)))/3)}
	end
end


function DrawIcon(unitHeight)
	gl.Translate(0,unitHeight,0)
	gl.Rotate(90, 1,0,0)
	gl.TexRect(-0.5, -0.5, 0.5, 0.5)
end


-- add unit-icon to unit
function AddHaloUnit(unitID)
	local unitUnitDefs = UnitDefs[spGetUnitDefID(unitID)]
	if not OPTIONS.skipBuildings or (OPTIONS.skipBuildings and not (unitUnitDefs.isBuilding or unitUnitDefs.isFactory or unitUnitDefs.speed==0)) then
		local ud = UnitDefs[spGetUnitDefID(unitID)]
		
		haloUnits[unitID] = {}
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

function widget:Shutdown()
	for k,_ in pairs(drawLists) do
		gl.DeleteList(drawLists[k])
	end
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

	if haloUnitsCount > 0 then
		osClock = os.clock()
		clockDiff = osClock - prevOsClock
		prevOsClock = osClock

		local camX, camY, camZ = spGetCameraPosition()

		gl.DepthMask(true)
		gl.DepthTest(true)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		gl.Texture(haloImg)
		for unitID, unit in pairs(haloUnits) do

			if spIsUnitInView(unitID) then
				local opacityMultiplier = 1
				if OPTIONS.fadeOnCameraDistance then
					local x,y,z = spGetUnitPosition(unitID)
					local camDistance = diag(camX-x, camY-y, camZ-z)
					opacityMultiplier = 2.2 - (camDistance/2000)
					if opacityMultiplier > 1 then
						opacityMultiplier = 1
					end
				end
				if opacityMultiplier > 0.22 then
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
					elseif unitConf[spGetUnitDefID(unitID)] then
						gl.Color(1,1,1,alpha*opacityMultiplier)
						local iconsize = unitConf[spGetUnitDefID(unitID)].iconSize * (1+unit.sizeAddition)
						local unitHeight = unitConf[spGetUnitDefID(unitID)].height
						if not drawLists[unitHeight] then
							drawLists[unitHeight] = gl.CreateList(DrawIcon, unitHeight*3)
						end
						glDrawListAtUnit(unitID, drawLists[unitHeight], false, iconsize, 1, iconsize)
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


