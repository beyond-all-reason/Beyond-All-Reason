function widget:GetInfo()
	return {
		name = "Unit Group Number",
		desc = "Display which group all units belongs to",
		author = "Floris",
		date = "May 2022",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local cutoffDistance = 3500
local falloffDistance = 2500
local hideBelowGameframe = 100
local fontSize = 13

local GetGroupList = Spring.GetGroupList
local GetGroupUnits = Spring.GetGroupUnits
local GetGameFrame = Spring.GetGameFrame
local IsGuiHidden = Spring.IsGUIHidden
local spIsUnitInView = Spring.IsUnitInView
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetCameraPosition = Spring.GetCameraPosition
local diag = math.diag
local min = math.min

local vsx, vsy = Spring.GetViewGeometry()
local existingGroups = GetGroupList()
local existingGroupsFrame = 0
local gameStarted = (Spring.GetGameFrame() > 0)
local font, dlists

local crashing = {}

local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local unitCanFly = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canFly then
		unitCanFly[unitDefID] = true
	end
end

function widget:GameStart()
	gameStarted = true
	widget:PlayerChanged()
end

function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	font = WG['fonts'].getFont(nil, 1.4, 0.35, 1.4)

	if dlists then
		for i, _ in ipairs(dlists) do
			gl.DeleteList(dlists[i])
		end
	end
	dlists = {}
	for i = 0, 9 do
		dlists[i] = gl.CreateList(function()
			font:Begin()
			font:Print("\255\200\255\200" .. i, 20.0, -10.0, fontSize, "cno")
			font:End()
		end)
	end
end

function widget:Initialize()
	widget:ViewResize()
end

function widget:Shutdown()
	if dlists then
		for i, _ in ipairs(dlists) do
			gl.DeleteList(dlists[i])
		end
		dlists = {}
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	crashing[unitID] = nil
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if unitCanFly[unitDefID] and spGetUnitMoveTypeData(unitID).aircraftState == "crashing" then
		crashing[unitID] = true
	end
end

function widget:DrawWorld()
	if IsGuiHidden() or GetGameFrame() < hideBelowGameframe then
		return
	end
	existingGroupsFrame = existingGroupsFrame + 1
	if existingGroupsFrame % 10 == 0 then
		existingGroups = GetGroupList()
	end
	local camX, camY, camZ = spGetCameraPosition()
	local camDistance
	for inGroup, _ in pairs(existingGroups) do
		local units = GetGroupUnits(inGroup)
		for i = 1, #units do
			local unitID = units[i]
			if spIsUnitInView(unitID) and not crashing[unitID] then
				local ux, uy, uz = spGetUnitViewPosition(unitID)
				camDistance = diag(camX - ux, camY - uy, camZ - uz)
				if camDistance < cutoffDistance then
					local scale = min(1, 1 - (camDistance - falloffDistance) / cutoffDistance)
					gl.PushMatrix()
					gl.Translate(ux, uy, uz)
					if scale <=1 then
						gl.Scale(scale, scale, scale)
					end
					gl.Billboard()
					gl.CallList(dlists[inGroup])
					gl.PopMatrix()
				end
			end
		end
	end
end
