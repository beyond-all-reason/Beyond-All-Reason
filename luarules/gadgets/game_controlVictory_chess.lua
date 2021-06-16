

local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamList = Spring.GetTeamList
local spGetAllyTeamList= Spring.GetAllyTeamList
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spGetGaiaTeamID = Spring.GetGaiaTeamID

HiddenCommander = {}

function gadget:GetInfo()
    return {
      name      = "Control Victory Chess Mode",
      desc      = "123",
      author    = "Damgam",
      date      = "2020",
      layer     = -100,
      enabled   = true,
    }
end

-- Functions to hide commanders

local function DisableUnit(unitID)
	Spring.MoveCtrl.Enable(unitID)
	Spring.MoveCtrl.SetNoBlocking(unitID, true)
	local x,y,z = Spring.GetUnitPosition(unitID)
    Spring.MoveCtrl.SetPosition(unitID, x, y-1000, z)
	Spring.SetUnitNeutral(unitID, true)
	Spring.SetUnitCloak(unitID, true)
	--Spring.SetUnitHealth(unitID, {paralyze=99999999})
	Spring.SetUnitMaxHealth(unitID, 10000000)
	Spring.SetUnitHealth(unitID, 10000000)
	Spring.SetUnitNoDraw(unitID, true)
	Spring.SetUnitStealth(unitID, true)
	Spring.SetUnitNoSelect(unitID, true)
	Spring.SetUnitNoMinimap(unitID, true)
	Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0)
end

local function DisableCommander()
    local teams = spGetTeamList()
    for i = 1,#teams do
        local teamUnits = Spring.GetTeamUnits(i-1)
        for _, unitID in ipairs(teamUnits) do
            HiddenCommander[i-1] = unitID
            DisableUnit(unitID)
        end
    end
end

