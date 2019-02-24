function widget:GetInfo()
  return {
    name      = "gui_transport_weight_limit",
    desc      = "When pressing Load command, it highlights units the transport can lift",
    author    = "nixtux ( + made fancy by Floris)",
    date      = "Apr 24, 2015",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local OPTIONS = {}
table.insert(OPTIONS, {
	circlePieces					= 3,
	circlePieceDetail				= 14,
	circleSpaceUsage				= 0.8,
	circleInnerOffset				= 0,
	rotationSpeed					= 8,
	
	-- size
	innersize						= 1.85,		-- outersize-innersize = circle width
	outersize						= 2.02,		-- outersize-innersize = circle width
	
	alphaFalloffdistance			= 750,
	maxAlpha						= 0.55,
})
local currentOption					= 1		-- just a remnant of other widget i used for the gfx type options

local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local unitstodraw = {}
local transID = nil

local validTrans = {}


local function DrawCircleLine(innersize, outersize)
	gl.BeginEnd(GL.QUADS, function()
		local detailPartWidth, a1,a2,a3,a4
		local width = OPTIONS[currentOption].circleSpaceUsage
		local detail = OPTIONS[currentOption].circlePieceDetail

		local radstep = (2.0 * math.pi) / OPTIONS[currentOption].circlePieces
		for i = 1, OPTIONS[currentOption].circlePieces do
			for d = 1, detail do
				
				detailPartWidth = ((width / detail) * d)
				a1 = ((i+detailPartWidth - (width / detail)) * radstep)
				a2 = ((i+detailPartWidth) * radstep)
				a3 = ((i+OPTIONS[currentOption].circleInnerOffset+detailPartWidth - (width / detail)) * radstep)
				a4 = ((i+OPTIONS[currentOption].circleInnerOffset+detailPartWidth) * radstep)
				
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
	
	circleList = gl.CreateList(DrawCircleLine, OPTIONS[currentOption].innersize, OPTIONS[currentOption].outersize)
	currentClock = os.clock()
	
	for i=1,#UnitDefs do
		local unitDefID = UnitDefs[i]
		if unitDefID.transportSize and unitDefID.transportSize > 0 then
			validTrans[i] = true
		end
	end
end

function widget:Shutdown()
	gl.DeleteList(circleList)
end

function widget:GameFrame(n)
    local unitcount = 0
	if (n % 2 == 1) then
    unitstodraw = {}
	local _,cmdID,_ = Spring.GetActiveCommand()
	local selectedUnits = Spring.GetSelectedUnits()
	if #selectedUnits == 1 then
		if validTrans[Spring.GetUnitDefID(selectedUnits[1])] then
        	transID = selectedUnits[1]
		end
        elseif #selectedUnits > 1 then
			for _,unitID in pairs(selectedUnits) do
				
				local unitdefID = Spring.GetUnitDefID(unitID)
				if validTrans[unitdefID] then
				   transID = unitID
				   unitcount = unitcount + 1
				   if unitcount > 1 then 
					   transID = nil
					   return end
				end
			end
        else
		transID = nil
		return
	end
	
	
	if transID then
		local TransDefID = Spring.GetUnitDefID(transID)
		local udTrans = UnitDefs[TransDefID]
		if udTrans ~= nil then
			local transMassLimit = udTrans.transportMass
			local transCapacity = udTrans.transportCapacity
			local transportSize = udTrans.transportSize
			if cmdID == CMD_LOAD_UNITS then
				local visibleUnits = Spring.GetVisibleUnits()
				if #visibleUnits then
					for i=1, #visibleUnits do
					local unitID = visibleUnits[i]
					local visableID = Spring.GetUnitDefID(unitID)
						local isinTrans = Spring.GetUnitIsTransporting(transID)
						if #isinTrans >= transCapacity then
							return
						end
						if transID and transID ~= visableID then
							local ud = UnitDefs[visableID]
							local passengerMass = ud.mass
								local passengerX = ud.xsize/2
								if (passengerMass <= transMassLimit) and (passengerX <= transportSize) and not ud.cantBeTransported and not Spring.IsUnitIcon(unitID) then 
									local x, y, z = Spring.GetUnitBasePosition(unitID)
									if (x) then
										 unitstodraw[unitID] = {pos = {x,y,z},size = (passengerX*6)}
									end
								end
							end
						end
					end
				end
			end
		end
    end
end


local cursorGround = {0,0,0}
function widget:Update()
	local mx, my = Spring.GetMouseState()
	local  _, coords = Spring.TraceScreenRay(mx, my, true)

	if type(coords) == "table" then
		cursorGround = coords
	end
end

local previousOsClock = os.clock()
local currentRotationAngle = 0
local currentRotationAngleOpposite = 0
function widget:DrawWorldPreUnit()
	
	local clockDifference = (os.clock() - previousOsClock)
	previousOsClock = os.clock()
	
	-- animate rotation
	if OPTIONS[currentOption].rotationSpeed > 0 then
		local angleDifference = (OPTIONS[currentOption].rotationSpeed) * (clockDifference * 5)
		currentRotationAngle = currentRotationAngle + (angleDifference*0.66)
		if currentRotationAngle > 360 then
		   currentRotationAngle = currentRotationAngle - 360
		end
	
		currentRotationAngleOpposite = currentRotationAngleOpposite - angleDifference
		if currentRotationAngleOpposite < -360 then
		   currentRotationAngleOpposite = currentRotationAngleOpposite + 360
		end
	end
	
	local alpha = 1
    for unitID,_ in pairs(unitstodraw) do
        local pos = unitstodraw[unitID].pos
        local xDiff = cursorGround[1] - pos[1]
        local zDiff = cursorGround[3] - pos[3]
        alpha = 1 - math.sqrt(xDiff*xDiff + zDiff*zDiff) / OPTIONS[currentOption].alphaFalloffdistance
        if alpha > OPTIONS[currentOption].maxAlpha then alpha = OPTIONS[currentOption].maxAlpha end
        if alpha > 0.04 then
			local size = unitstodraw[unitID].size
			gl.Color(0, 0.8, 0, alpha*0.55)
			gl.DrawListAtUnit(unitID, circleList, false, size, 1.0, size, currentRotationAngle, 0, 1, 0)
			gl.Color(0, 0.8, 0, alpha)
			gl.DrawListAtUnit(unitID, circleList, false, size*1.18, 1.0, size*1.18, -currentRotationAngle, 0, 1, 0)
		end
    end
    
    gl.Color(1,1,1,1)
    gl.LineWidth(1)
end
