local widget = widget ---@type Widget

function widget:GetInfo()
	return {
	name	= "Cloaked Buildpower Default Move",
	desc	= "Prevents accidental reclaim, load, and attack commands on cloaked units\nMakes move the default command for commanders, decoys, and spies when cloaked",
	author	= "Catcow, BrainDamage",
	date	= "11/14/25",
	license	= "GNU GPL, v2 or later",
	layer	= -999999,
	enabled	= true,
	}
end

-- NOTE: This was initially only for spy bots and made only by BrainDamage,
--       but Catcow updated it to abstractly include commanders and decoys
--       and anything else that cloaks, builds, and moves. Also likely more efficient

-- Localized Spring API for performance
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetGameFrame = Spring.GetGameFrame

local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitStates = Spring.GetUnitStates

local idCanBuildCloakMove = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canCloak and unitDef.canReclaim and unitDef.canMove then
		idCanBuildCloakMove[unitDefID] = true
	end
end

local gameStarted

local CMD_MOVE = CMD.MOVE
local CMD_CLOAK = 37382

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
	if Spring.IsReplay() or spGetGameFrame() > 0 then
		maybeRemoveSelf()
	end
end

local cloakedBuilderMovableSelected = false

local function update()
	Spring.Echo('update')
	local selectedUnitsCount = spGetSelectedUnitsCount()

	cloakedBuilderMovableSelected = false
	-- above a little amount we likely aren't micro-ing cloaked things anymore...
	if selectedUnitsCount == 0 or selectedUnitsCount > 20 then return end

	local selectedUnitTypes = spGetSelectedUnitsSorted()
	for unitDefID, units in pairs(selectedUnitTypes) do
		if idCanBuildCloakMove[unitDefID] then
			for _, unitID in pairs(units) do
				-- 5=cloak https://recoilengine.org/docs/lua-api/#Spring.GetUnitStates
				if select(5, spGetUnitStates(unitID,false,true)) then
					cloakedBuilderMovableSelected = true
					return
				end
			end
		end
	end
end

function widget:SelectionChanged(sel)
	update()
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if (cmdID == CMD_CLOAK) and (idCanBuildCloakMove[unitDefID]) and (teamID == spGetMyTeamID()) then
		update()
	end
end

function widget:DefaultCommand()
	if cloakedBuilderMovableSelected then
		return CMD_MOVE
	end
end
