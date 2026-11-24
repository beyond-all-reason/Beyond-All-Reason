local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Given Units",
		desc = "Tags given units with 'new' icon",
		author = "Floris",
		date = "24.04.2014",
		license = "GNU GPL, v2 or later",
		layer = -50,
		enabled = true,
	}
end

-- config
local selectedFadeTime = 0.75
local timeoutFadeTime = 3
local timeoutTime = 6.5

--TODO
-- better icon because bloom makes the letters unreadable

local fadeStartTime = timeoutTime - timeoutFadeTime
local iconTexture = "LuaUI/Images/new.dds"

local glColor = gl.Color
local glDrawListAtUnit = gl.DrawListAtUnit
local spGetGameFrame = Spring.GetGameFrame
local spIsGUIHidden = Spring.IsGUIHidden
local spIsUnitInView = Spring.IsUnitInView
local spGetCameraDirection = Spring.GetCameraDirection
local osClock = os.clock

local drawList ---@type integer
local camDirX, camDirY, camDirZ ---@type number, number, number
local myTeamID = Spring.GetLocalTeamID()
local gameStarted
local lastReceiveFrame = 0

-- given units as parallel arrays, unitIndex maps unitID to its slot
local givenCount = 0
local givenIDs = {} ---@type table<integer, UnitID>
local givenScale = {} ---@type table<integer, number>
local givenStart = {} ---@type table<integer, number> os.clock the timeout counts from, reset while out of view
local givenSelected = {} ---@type table<integer, number|false> os.clock the selected fade counts from
local unitIndex = {} ---@type table<UnitID, integer?>

local unitScale = {}
for udid, unitDef in pairs(UnitDefs) do
	local xsize, zsize = unitDef.xsize, unitDef.zsize
	local scale = 6 * (xsize * xsize + zsize * zsize) ^ 0.5
	unitScale[udid] = 7 + (scale / 2.5)
end

local function drawIcon()
	local iconSize = 1
	gl.Translate(0, 1, 1.4)
	gl.Billboard()
	gl.TexRect(-(iconSize / 2), 0, (iconSize / 2), iconSize)
end

local function addGivenUnit(unitID, unitDefID)
	local i = unitIndex[unitID]
	if not i then
		i = givenCount + 1
		givenCount = i
		givenIDs[i] = unitID
		unitIndex[unitID] = i
	end
	givenScale[i] = unitScale[unitDefID]
	givenStart[i] = osClock()
	givenSelected[i] = false
end

local function removeGivenUnit(i)
	local last = givenCount
	unitIndex[givenIDs[i]] = nil
	if i ~= last then
		local unitID = givenIDs[last]
		givenIDs[i] = unitID
		givenScale[i] = givenScale[last]
		givenStart[i] = givenStart[last]
		givenSelected[i] = givenSelected[last]
		unitIndex[unitID] = i
	end
	givenIDs[last] = nil
	givenScale[last] = nil
	givenStart[last] = nil
	givenSelected[last] = nil
	givenCount = last - 1
end

--------------------------------------------------------------------------------
-- Engine Calls
--------------------------------------------------------------------------------

local function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
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
	camDirX, camDirY, camDirZ = spGetCameraDirection()
	drawList = gl.CreateList(drawIcon)
	if Spring.IsReplay() or spGetGameFrame() > 0 then
		maybeRemoveSelf()
	end
end

function widget:Shutdown()
	gl.DeleteList(drawList)
end

function widget:DrawWorld()
	if givenCount == 0 or spIsGUIHidden() then
		return
	end

	-- the billboard matrix is baked into the list
	local dirX, dirY, dirZ = spGetCameraDirection()
	if dirX ~= camDirX or dirY ~= camDirY or dirZ ~= camDirZ then
		camDirX, camDirY, camDirZ = dirX, dirY, dirZ
		gl.DeleteList(drawList)
		drawList = gl.CreateList(drawIcon)
	end

	local now = osClock()
	gl.DepthMask(true)
	gl.DepthTest(true)
	gl.Texture(iconTexture)
	local color ---@type number?

	for i = givenCount, 1, -1 do
		local unitID = givenIDs[i]
		local inView = spIsUnitInView(unitID)
		if inView then
			local selected = givenSelected[i]
			local alpha
			if selected then
				alpha = 1 - ((now - selected) / selectedFadeTime)
			else
				alpha = 1 - ((now - (givenStart[i] + fadeStartTime)) / timeoutFadeTime)
			end
			if alpha <= 0 then
				removeGivenUnit(i)
			else
				if alpha > 1 then
					alpha = 1
				end
				if alpha ~= color then
					color = alpha
					glColor(1, 1, 1, alpha)
				end
				local scale = givenScale[i]
				glDrawListAtUnit(unitID, drawList, false, scale, scale, scale)
			end
		elseif inView == nil then
			-- dead or no longer readable
			removeGivenUnit(i)
		elseif givenSelected[i] then
			givenSelected[i] = now
		else
			givenStart[i] = now
		end
	end

	glColor(1, 1, 1, 1)
	gl.Texture(false)
	gl.DepthTest(false)
	gl.DepthMask(false)
end

-- add given units
function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if newTeam == myTeamID then
		addGivenUnit(unitID, unitDefID)
		local frame = spGetGameFrame()
		if lastReceiveFrame < frame then
			local x, y, z = Spring.GetUnitPosition(unitID)
			if x then
				Spring.SetLastMessagePosition(x, y, z)
			end
			lastReceiveFrame = frame
		end
	elseif oldTeam == myTeamID and unitIndex[unitID] then
		removeGivenUnit(unitIndex[unitID])
	end
end

function widget:SelectionChanged(sel)
	if givenCount == 0 then
		return
	end
	local now = osClock()
	for j = 1, #sel do
		local i = unitIndex[sel[j]]
		if i then
			if not givenSelected[i] then
				local currentAlpha = 1 - ((now - (givenStart[i] + fadeStartTime)) / timeoutFadeTime)
				if currentAlpha > 1 then
					currentAlpha = 1
				end
				givenSelected[i] = now - (selectedFadeTime * (1 - currentAlpha))
			end
		else
			-- uncomment line below for testing
			-- addGivenUnit(sel[j], Spring.GetUnitDefID(sel[j]))
		end
	end
end
