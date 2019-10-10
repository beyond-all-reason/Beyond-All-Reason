function widget:GetInfo()
  return {
    name    = "Metalspots",
	desc    = "",
	author  = "Floris",
	date    = "October 2019",
	license = "",
	layer   = 2,
	enabled = true,
  }
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local OPTIONS = {
	showValue			= true,
	metalViewOnly		= false,

	circleSpaceUsage	= 0.75,
	circleInnerOffset	= 0.35,
	rotationSpeed		= 4,
	opacity				= 0.5,

	-- size
	innersize			= 1.86,		-- outersize-innersize = circle width
	outersize			= 2.08,		-- outersize-innersize = circle width
}


local spIsGUIHidden = Spring.IsGUIHidden
local spIsSphereInView = Spring.IsSphereInView
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGroundHeight = Spring.GetGroundHeight

local metalSpots = {}
local valueList = {}
local circleList = {}
local previousOsClock = os.clock()
local currentRotation = 0

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 75
local fontfileOutlineSize = 15
local fontfileOutlineStrength = 1.4
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

local extractors = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.extractsMetal > 0 then
		extractors[uDefID] = true
	end
end

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()
	local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
	if (fontfileScale ~= newFontfileScale) then
		fontfileScale = newFontfileScale
		gl.DeleteFont(font)
		font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
	end
end


local function DrawCircleLine(innersize, outersize)
	gl.BeginEnd(GL.QUADS, function()
		local detailPartWidth, a1,a2,a3,a4
		local width = OPTIONS.circleSpaceUsage
		local pieces = 3 + math.ceil(innersize/11)
		local detail = math.ceil(innersize/pieces)
		local radstep = (2.0 * math.pi) / pieces
		for i = 1, pieces do
			for d = 1, detail do
				
				detailPartWidth = ((width / detail) * d)
				a1 = ((i+detailPartWidth - (width / detail)) * radstep)
				a2 = ((i+detailPartWidth) * radstep)
				a3 = ((i+OPTIONS.circleInnerOffset+detailPartWidth - (width / detail)) * radstep)
				a4 = ((i+OPTIONS.circleInnerOffset+detailPartWidth) * radstep)
				
				--outer (fadein)
				gl.Vertex(math.sin(a4)*innersize, 0, math.cos(a4)*innersize)
				gl.Vertex(math.sin(a3)*innersize, 0, math.cos(a3)*innersize)
				--outer (fadeout)
				gl.Vertex(math.sin(a1)*outersize, 0, math.cos(a1)*outersize)
				gl.Vertex(math.sin(a2)*outersize, 0, math.cos(a2)*outersize)
			end
		end
	end)
end


function widget:Initialize()
	if not WG.metalSpots then
		Spring.Echo("<metalspots> This widget requires the 'Metalspot Finder' widget to run.")
		widgetHandler:RemoveWidget(self)
	end

	WG.metalspots = {}
	WG.metalspots.setShowValue = function(value)
		OPTIONS.showValue = value
	end
	WG.metalspots.getShowValue = function()
		return OPTIONS.showValue
	end
	WG.metalspots.setOpacity = function(value)
		OPTIONS.opacity = value
	end
	WG.metalspots.getOpacity = function()
		return OPTIONS.opacity
	end
	WG.metalspots.setMetalViewOnly = function(value)
		OPTIONS.metalViewOnly = value
	end
	WG.metalspots.getMetalViewOnly = function()
		return OPTIONS.metalViewOnly
	end

	currentClock = os.clock()
	local mSpots = WG.metalSpots
	for i = 1, #mSpots do
		local spot = mSpots[i]
		local value = string.format("%0.1f",math.round(spot.worth/1000,1))
		if tonumber(value) > 0.001 then
			local scale = 0.77 + ((math.max(spot.maxX,spot.minX)-(math.min(spot.maxX,spot.minX))) * (math.max(spot.maxZ,spot.minZ)-(math.min(spot.maxZ,spot.minZ)))) / 10000
			metalSpots[#metalSpots+1] = {spot.x, Spring.GetGroundHeight(spot.x,spot.z), spot.z, value, scale}
			if not valueList[value] then
				valueList[value] = gl.CreateList(function()
					font:Begin()
					font:SetTextColor(1,1,1,1)
					font:SetOutlineColor(0,0,0,0.4)
					font:Print(value, 0, 0, 1.05, "con")
					font:End()
				end)
			end
			if not circleList[scale] then
				circleList[scale] = gl.CreateList(DrawCircleLine, (OPTIONS.innersize*21*scale)-((1-scale)*4), (OPTIONS.outersize*21*scale))
			end
		end
	end
end


function widget:Shutdown()
	for k,v in pairs(valueList) do
		gl.DeleteList(v)
	end
	for k,v in pairs(circleList) do
		gl.DeleteList(v)
	end
	gl.DeleteFont(font)
end


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end


-- periodically check if mex spot is occupied
function widget:GameFrame(gf)
	if gf % 39 == 1 then
		for i=1, #metalSpots do
			metalSpots[i][6] = false
			metalSpots[i][2] = spGetGroundHeight(metalSpots[i][1],metalSpots[i][3])
			local spot = metalSpots[i]
			local units = spGetUnitsInSphere(spot[1], spot[2], spot[3], 90*spot[5])
			for j=1, #units do
				if extractors[spGetUnitDefID(units[j])]  then
					metalSpots[i][6] = true
					break
				end
			end
		end
	end
end


function widget:DrawWorldPreUnit()
	if OPTIONS.metalViewOnly and Spring.GetMapDrawMode() ~= 'metal' then return end
	if chobbyInterface then return end
	if spIsGUIHidden() then return end
	
	local clockDifference = (os.clock() - previousOsClock)
	previousOsClock = os.clock()

	gl.DepthTest(false)

	-- animate rotation
	if OPTIONS.rotationSpeed > 0 then
		local angleDifference = (OPTIONS.rotationSpeed) * (clockDifference * 5)
		currentRotation = currentRotation + (angleDifference*0.66)
		if currentRotation > 360 then
		   currentRotation = currentRotation - 360
		end
	end

	for i = 1, #metalSpots do
		local spot = metalSpots[i]
		if not spot[6] and spIsSphereInView(spot[1], spot[2], spot[3], 60) then
			gl.PushMatrix()
			gl.Translate(spot[1], spot[2], spot[3])

			gl.Rotate(currentRotation, 0,1,0)
			gl.Color(1, 1, 1, OPTIONS.opacity*0.5)
			gl.CallList(circleList[spot[5]])

			gl.Rotate(-currentRotation*2, 0,1,0)
			gl.Rotate(180, 1,0,0)
			local scale = 1.3 - (spot[5]*0.11)
			gl.Scale(scale, scale, scale)
			gl.Color(1, 1, 1, OPTIONS.opacity)
			gl.CallList(circleList[spot[5]])

			if OPTIONS.showValue or Spring.GetGameFrame() == 0 then
				gl.Scale(21*spot[5],21*spot[5],21*spot[5])
				gl.Rotate(-180, 1,0,0)
				gl.Rotate(currentRotation, 0,1,0)
				gl.Billboard()
				gl.CallList(valueList[spot[4]])
			end
			gl.PopMatrix()
		end
    end

    gl.DepthTest(true)
    gl.Color(1,1,1,1)
end

function widget:GetConfigData(data)
	savedTable = {}
	savedTable.showValue = OPTIONS.showValue
	savedTable.opacity = OPTIONS.opacity
	savedTable.metalViewOnly = OPTIONS.metalViewOnly
	return savedTable
end

function widget:SetConfigData(data)
	if data.showValue ~= nil then
		OPTIONS.showValue = data.showValue
	end
	if data.opacity ~= nil then
		OPTIONS.opacity = data.opacity
	end
	if data.metalViewOnly ~= nil then
		OPTIONS.metalViewOnly = data.metalViewOnly
	end
end
