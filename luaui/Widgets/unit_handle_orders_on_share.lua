function widget:GetInfo()
	return {
		name    = "Handle Orders on Share",
		desc    = "Handles command queue of shared units",
		author  = "lov",
		date    = "September 2023",
		license = "GNU GPL, v2 or later",
		layer   = 1,
		enabled = true
	}
end

local options = { shareCommands = 1 }
local shareCommandsList = { "movement", "all", "none" }
local myTeam

local CMD_MOVE = CMD.MOVE
local CMD_REMOVE = CMD.REMOVE
local CMD_STOP = CMD.STOP
local CMD_OPT_CTRL = CMD.OPT_CTRL
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
local spGetUnitCommands = Spring.GetUnitCommands

local isFactory = {}
for udid = 1, #UnitDefs do
	local ud = UnitDefs[udid]
	if ud.isFactory then
		isFactory[udid] = true
	end
end

local function getOption(param)
	return options[param]
end

local function setOption(params)
	if params[1] and params[2] then
		options[params[1]] = params[2]
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if newTeam ~= myTeam then return end
	if isFactory[unitDefID] then
		local commands = spGetFactoryCommands(unitID, -1) or {}
		for i = 1, #commands do
			spGiveOrderToUnit(unitID, CMD_REMOVE, commands[i].tag, CMD_OPT_CTRL)
		end
		return
	end
	local newCommands = { { CMD_STOP, {}, {} } }

	if options.shareCommands == 2 then return end
	if options.shareCommands == 3 then
		spGiveOrderArrayToUnit(unitID, newCommands)
		return
	end

	local commands = spGetUnitCommands(unitID, -1)
	if not commands then return end
	local i
	for i = 1, #commands do
		local c = commands[i]
		if c.id == CMD_MOVE then
			newCommands[#newCommands + 1] = { c.id, c.params, c.options }
		end
	end

	spGiveOrderArrayToUnit(unitID, newCommands)
end

function widget:GetConfigData(data)
	return options
end

function widget:SetConfigData(data)
	if data.shareCommands ~= nil then
		setOption({ "shareCommands", data.shareCommands })
	end
end

function widget:Initialize()
	myTeam = Spring.GetMyTeamID()
	local WG_name = 'shared_unit_orders'
	WG[WG_name] = {}
	WG[WG_name].getOption = getOption
	WG[WG_name].setOption = setOption
end
