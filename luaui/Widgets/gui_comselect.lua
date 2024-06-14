function widget:GetInfo()
	return {
		name = "Commander Selector",
		desc = "Allows for proper keybind selection of any flavour of commanders",
		author = "Hornet, with some ZK raiding",
		date = "03 June 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local myTeamID

local commanderList = {}
local commanderIds = {}
for udid, ud in pairs(UnitDefs) do
	if ud.customParams.iscommander then
		commanderIds[udid] = udid
	end
end

function widget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	if unitTeam ~= myTeamID then
		return
	end
	if commanderIds[unitDefID] then
		table.insert(commanderList, unitID)
	end
end


function widget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	if not commanderIds[unitDefID] then
		return
	end

	local found = table.removeFirst(commanderList, unitID)

	-- if not found then
	-- 	error("unit is a commander but was not on the list!", unitID)
	-- end
end


-- comm selection functionality
local commIndex = 1
local function SelectComm()
	local commCount = #commanderList

	if commCount <= 0 then
		return
	end

	-- This check deals with the case of spectators selecting
	-- teams with different numbers of commanders.
	if commCount < commIndex then
		commIndex = commCount
	end

	local unitID
	-- Loop long enough to check every commander.
	-- The most recently Ctrl+C selected commander is checked last.
	-- Select the first non-selected commander encountered.
	for i = 1, commCount do
		unitID = commanderList[commIndex]
		commIndex = commIndex + 1
		if commIndex > commCount then
			commIndex = 1
		end
		if not Spring.IsUnitSelected(unitID) then
			break
		end
	end

	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	Spring.SelectUnit(unitID, shift)

	if not shift then
		local x, y, z = Spring.GetUnitPosition(unitID)
		Spring.SetCameraTarget(x, y, z)
	end
end


local function RefreshList()
	local spGetUnitDefID = Spring.GetUnitDefID

	commanderList = {}
	local count = 0
	local units = Spring.GetTeamUnits(myTeamID)
	for i = 1, #units do
		local unitID = units[i]
		if commanderIds[spGetUnitDefID(unitID)] then
			count = count + 1
			commanderList[count] = unitID
		end
	end
end

function widget:PlayerChanged()
	local teamID = Spring.GetMyTeamID()

	if teamID ~= myTeamID then
		myTeamID = teamID
		RefreshList()
	end
end

function widget:Shutdown()
	widgetHandler:RemoveAction("selectcomm")
end


function widget:Initialize()
	myTeamID = Spring.GetMyTeamID()
	RefreshList()

	widgetHandler:AddAction("selectcomm", SelectComm, nil, 'p')
end
