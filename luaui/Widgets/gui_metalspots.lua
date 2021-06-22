function widget:GetInfo()
  return {
    name    = "Metalspots",
	desc    = "",
	author  = "Floris",
	date    = "October 2019",
	license = "",
	layer   = 2,
	enabled = false,
  }
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local showValue			= false
local metalViewOnly		= false

local circleSpaceUsage	= 0.75
local circleInnerOffset	= 0.35
local rotationSpeed		= 4
local opacity			= 0.5
local fadeTime			= 0.5

local innersize			= 1.86		-- outersize-innersize = circle width
local outersize			= 2.08		-- outersize-innersize = circle width


local spIsGUIHidden = Spring.IsGUIHidden
local spIsSphereInView = Spring.IsSphereInView
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGameSpeed = Spring.GetGameSpeed
local math_min = math.min

local metalSpots = {}
local valueList = {}
local circleList = {}
local previousOsClock = os.clock()
local currentRotation = 0
local checkspots = true
local sceduledCheckedSpotsFrame = Spring.GetGameFrame()

local isSpec, fullview = Spring.GetSpectatingState()
local myAllyTeamID = Spring.GetMyAllyTeamID()

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 80
local fontfileOutlineSize = 22
local fontfileOutlineStrength = 1.15
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

local dont, chobbyInterface

local extractors = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.extractsMetal > 0 then
		extractors[uDefID] = true
	end
end

function widget:ViewResize()
	local old_vsx, old_vsy = vsx, vsy
	vsx,vsy = Spring.GetViewGeometry()
	local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
	if (fontfileScale ~= newFontfileScale) then
		fontfileScale = newFontfileScale
		gl.DeleteFont(font)
		font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
	end
	if old_vsx ~= vsx or old_vsy ~= vsy then
		widget:Shutdown()
		widget:Initialize()
	end
end


local function DrawCircleLine(innersize, outersize)
	gl.BeginEnd(GL.QUADS, function()
		local detailPartWidth, a1,a2,a3,a4
		local width = circleSpaceUsage
		local pieces = 3 + math.ceil(innersize/11)
		local detail = math.ceil(innersize/pieces)
		local radstep = (2.0 * math.pi) / pieces
		for i = 1, pieces do
			for d = 1, detail do

				detailPartWidth = ((width / detail) * d)
				a1 = ((i+detailPartWidth - (width / detail)) * radstep)
				a2 = ((i+detailPartWidth) * radstep)
				a3 = ((i+circleInnerOffset+detailPartWidth - (width / detail)) * radstep)
				a4 = ((i+circleInnerOffset+detailPartWidth) * radstep)

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
		widgetHandler:RemoveWidget()
	end

	WG.metalspots = {}
	WG.metalspots.setShowValue = function(value)
		showValue = value
	end
	WG.metalspots.getShowValue = function()
		return showValue
	end
	WG.metalspots.setOpacity = function(value)
		opacity = value
	end
	WG.metalspots.getOpacity = function()
		return opacity
	end
	WG.metalspots.setMetalViewOnly = function(value)
		metalViewOnly = value
	end
	WG.metalspots.getMetalViewOnly = function()
		return metalViewOnly
	end

	local currentClock = os.clock()
	local mSpots = WG.metalSpots
	local metalSpotsCount = #metalSpots
	for i = 1, #mSpots do
		local spot = mSpots[i]
		local value = string.format("%0.1f",math.round(spot.worth/1000,1))
		if tonumber(value) > 0.001 then
			local scale = 0.77 + ((math.max(spot.maxX,spot.minX)-(math.min(spot.maxX,spot.minX))) * (math.max(spot.maxZ,spot.minZ)-(math.min(spot.maxZ,spot.minZ)))) / 10000

			local units = spGetUnitsInSphere(spot.x, spot.y, spot.z, 115*scale)
			local occupied = false
			for j=1, #units do
				if extractors[spGetUnitDefID(units[j])]  then
					occupied = true
					break
				end
			end
			metalSpotsCount = metalSpotsCount + 1
			metalSpots[metalSpotsCount] = {spot.x, spGetGroundHeight(spot.x,spot.z), spot.z, value, scale, occupied, currentClock}
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
				circleList[scale] = gl.CreateList(DrawCircleLine, (innersize*21*scale)-((1-scale)*4), (outersize*21*scale))
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
	WG.metalspots = nil
	metalSpots = {}
	circleList = {}
	valueList = {}
	--gl.DeleteFont(font)
end


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:PlayerChanged(playerID)
	local prevFullview = fullview
	local prevMyAllyTeamID = myAllyTeamID
	isSpec, fullview = Spring.GetSpectatingState()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	if fullview ~= prevFullview or myAllyTeamID ~= prevMyAllyTeamID then
		checkMetalspots()
	end
end

function checkMetalspots()
	local now = os.clock()
	for i=1, #metalSpots do
		metalSpots[i][2] = spGetGroundHeight(metalSpots[i][1],metalSpots[i][3])
		local spot = metalSpots[i]
		local units = spGetUnitsInSphere(spot[1], spot[2], spot[3], 110*spot[5])
		local occupied = false
		local prevOccupied = metalSpots[i][6]
		for j=1, #units do
			if extractors[spGetUnitDefID(units[j])]  then
				occupied = true
				break
			end
		end
		if occupied ~= prevOccupied then
			metalSpots[i][7] = now
			metalSpots[i][6] = occupied
		end
	end
	sceduledCheckedSpotsFrame = Spring.GetGameFrame() + 89
	checkspots = false
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if extractors[unitDefID] then
		checkspots = true
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if extractors[unitDefID] then
		sceduledCheckedSpotsFrame = Spring.GetGameFrame() + 3	-- delay needed, i don't know why
	end
end

function widget:GameFrame(gf)
	if checkspots or gf >= sceduledCheckedSpotsFrame then
		checkMetalspots()
	end
end


function widget:DrawWorldPreUnit()
	if metalViewOnly and Spring.GetMapDrawMode() ~= 'metal' then return end
	if chobbyInterface then return end
	if spIsGUIHidden() then return end

	local clockDifference = (os.clock() - previousOsClock)
	previousOsClock = os.clock()

	gl.DepthTest(false)

	-- animate rotation
	local _, gameSpeed, isPaused = spGetGameSpeed()
	if rotationSpeed > 0 and not (isPaused or gameSpeed == 0) then
		local angleDifference = (rotationSpeed) * (clockDifference * 5)
		currentRotation = currentRotation + (angleDifference*0.66)
		if currentRotation > 360 then
		   currentRotation = currentRotation - 360
		end
	end
	local mult, scale, spot
	for i = 1, #metalSpots do
		spot = metalSpots[i]
		if spot[7] and spIsSphereInView(spot[1], spot[2], spot[3], 60) then
			if not spot[6] then
				mult = math_min(1, (previousOsClock-spot[7])/fadeTime)
			else
				mult = 1 - math_min(1, (previousOsClock-spot[7])/fadeTime)
			end
			if mult <= 0 then
				metalSpots[i][7] = nil
			else
				gl.PushMatrix()
				gl.Translate(spot[1], spot[2], spot[3])
				if mult ~= 1 then
					scale = 0.94 + (0.06 * (mult*mult))
					gl.Scale(scale,scale,scale)
				end

				gl.Rotate(currentRotation, 0,1,0)
				gl.Color(1, 1, 1, opacity*0.5*mult)
				gl.CallList(circleList[spot[5]])

				gl.Rotate(-currentRotation*2, 0,1,0)
				gl.Rotate(180, 1,0,0)
				scale = 1.33 - (spot[5]*0.075)
				gl.Scale(scale, scale, scale)
				gl.Color(1, 1, 1, opacity*mult)
				gl.CallList(circleList[spot[5]])

				if mult > 0.7 and (showValue or Spring.GetGameFrame() == 0 or Spring.GetMapDrawMode() == 'metal') then
					gl.Scale(21*spot[5],21*spot[5],21*spot[5])
					gl.Rotate(-180, 1,0,0)
					gl.Rotate(currentRotation, 0,1,0)
					gl.Billboard()
					gl.CallList(valueList[spot[4]])
				end
				gl.PopMatrix()
			end
		end
    end

    gl.DepthTest(true)
    gl.Color(1,1,1,1)
end

function widget:GetConfigData(data)
	return {
		showValue = showValue,
		opacity = opacity,
		metalViewOnly = metalViewOnly
	}
end

function widget:SetConfigData(data)
	if data.showValue ~= nil then
		showValue = data.showValue
	end
	if data.opacity ~= nil then
		opacity = data.opacity
	end
	if data.metalViewOnly ~= nil then
		metalViewOnly = data.metalViewOnly
	end
end
