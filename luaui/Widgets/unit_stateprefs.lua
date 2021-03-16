--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "State Prefs",
		desc = "Sets pre-defined units states.",
		author = "quantum + Doo",
		date = "2018",
		license = "GNU GPL, v2 or later",
		layer = math.huge,
		enabled = false  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local unitName = {}
for udid, ud in pairs(UnitDefs) do
	unitName[udid] = ud.name
end

local unitSet = {}
local chunk, err = loadfile("LuaUI/config/StatesPrefs.lua")
if chunk then
	local tmp = {}
	setfenv(chunk, tmp)
	unitArray = chunk()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() then
		widget:GameOver()
	end
end

function widget:Initialize()
	unitArray = unitArray or {}
	for i, v in pairs(unitArray) do
		unitSet[i] = v
	end
	if Spring.IsReplay() then
		widget:GameOver()
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	local selectedUnits = Spring.GetSelectedUnits()
	for i = 1, #selectedUnits do
		local unitID = selectedUnits[i]
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		local name = unitName[unitDefID]
		unitSet[name] = unitSet[name] or {}
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if ctrl and #cmdParams == 1 and not (unitSet[name][cmdID] == cmdParams[1]) then
			unitSet[name][cmdID] = cmdParams[1]
			Spring.Echo("State pref changed to: " .. (cmdParams[1]))
			table.save(unitSet, "LuaUI/config/StatesPrefs.lua", "--States prefs")
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	local name = unitName[unitDefID]
	unitSet[name] = unitSet[unitName[unitDefID]] or {}
	if unitTeam == Spring.GetMyTeamID() then
		for cmdID, cmdParam in pairs(unitSet[name]) do
			Spring.GiveOrderToUnit(unitID, cmdID, { cmdParam }, 0)
		end
	end
end

function widget:GameOver()
	Spring.Echo("Recorded States Prefs")
	table.save(unitSet, "LuaUI/config/StatesPrefs.lua", "--States prefs")
	widgetHandler:RemoveWidget(self)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

