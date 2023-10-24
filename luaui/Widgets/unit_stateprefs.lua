--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "State Prefs V2",
		desc = "Sets pre-defined units states. CTRL-click on a unit's state commands to define states for newly produced units of its type. V2 fixes bug, improves console output to show unit and state change details.",
		author = "Errrrrrr, quantum + Doo",
		date = "April 21, 2023",
		license = "GNU GPL, v2 or later",
		layer = 999999,
		enabled = false, --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local unitArray = {}
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
local function GetCmdOpts(alt, ctrl, meta, shift, right)
	local opts = { alt = alt, ctrl = ctrl, meta = meta, shift = shift, right = right }
	local coded = 0

	if alt then
		coded = coded + CMD.OPT_ALT
	end
	if ctrl then
		coded = coded + CMD.OPT_CTRL
	end
	if meta then
		coded = coded + CMD.OPT_META
	end
	if shift then
		coded = coded + CMD.OPT_SHIFT
	end
	if right then
		coded = coded + CMD.OPT_RIGHT
	end

	opts.coded = coded
	return opts
end

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
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	if not ctrl then
		return false
	end
	-- need to filter only state commands!
	if cmdID > 1000 or cmdID < 0 then
		--Spring.Echo("Not a state change command!")
		return false
	end
	local cmdName = CMD[cmdID].name
	if cmdName and not cmdName.find("STATE") then
		--Spring.Echo("Not a state change command!")
		return false
	end

	local selectedUnits = Spring.GetSelectedUnits()
	for i = 1, #selectedUnits do
		local unitID = selectedUnits[i]
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		local name = unitName[unitDefID]
		unitSet[name] = unitSet[name] or {}
		if #cmdParams == 1 and not (unitSet[name][cmdID] == cmdParams[1]) then
			unitSet[name][cmdID] = cmdParams[1]
			Spring.Echo("State pref changed:  " .. name .. ",  " .. CMD[cmdID] .. " " .. cmdParams[1])
			table.save(unitSet, "LuaUI/config/StatesPrefs.lua", "--States prefs")

			-- Spring.PlaySoundFile('LuaUI/sounds/volume_osd/pop.wav', 1.0, 'ui')
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	local cmdOpts = GetCmdOpts(false, false, false, true, false)
	--local altOpts = GetCmdOpts(true, false, false, false, false)

	local name = unitName[unitDefID]
	--local unitDef = UnitDefs[unitDefID]

	unitSet[name] = unitSet[unitName[unitDefID]] or {}
	if unitTeam == Spring.GetMyTeamID() then
		for cmdID, cmdParam in pairs(unitSet[name]) do
			if cmdID == 115 then
				return
			end -- we're skipping "repeat" command here for now
			local success = Spring.GiveOrderToUnit(unitID, cmdID, { cmdParam }, cmdOpts)
			--Spring.Echo("".. name .. ", " .. tostring(cmdID) .. ", " .. tostring(cmdParam) .. " success: ".. tostring(success))
		end
	end
end

function widget:GameOver()
	Spring.Echo("Recorded States Prefs")
	table.save(unitSet, "LuaUI/config/StatesPrefs.lua", "--States prefs")
	widgetHandler:RemoveWidget()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
