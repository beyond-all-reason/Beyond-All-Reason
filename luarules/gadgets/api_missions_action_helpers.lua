local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission API Actions Helper",
		desc = "Execute certain Mission API actions which cannot be completely done within the actions currently.",
		date = "2026",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spAddTeamResource = Spring.AddTeamResource
local spUseTeamResource = Spring.UseTeamResource

GG["MissionAPIActionHelper"] = {}

local resourcing = {
    active = false,
    metalPerSecond = {},
    energyPerSecond = {},
}

GG["MissionAPIActionHelper"].addMetalPerSecond = function(teamID, metalPerSecond)
    if not resourcing.metalPerSecond[teamID] then
        resourcing.metalPerSecond[teamID] = 0
    end
    resourcing.metalPerSecond[teamID] = resourcing.metalPerSecond[teamID] + metalPerSecond

    resourcing.active = true
end

GG["MissionAPIActionHelper"].addEnergyPerSecond = function(teamID, energyPerSecond)
    if not resourcing.energyPerSecond[teamID] then
        resourcing.energyPerSecond[teamID] = 0
    end
    resourcing.energyPerSecond[teamID] = resourcing.energyPerSecond[teamID] + energyPerSecond

    resourcing.active = true
end

function gadget:GameFrame(frame)
    ---------------
    -- Resourcing
    ---------------
    if resourcing.active and frame % Game.gameSpeed*0.5 == 0 then
        for teamID, amount in pairs(resourcing.metalPerSecond) do
            if amount > 0 then
                spAddTeamResource(teamID, "metal", amount)
            elseif amount < 0 then
                spUseTeamResource(teamID, "metal", -amount)
            end
        end
        for teamID, amount in pairs(resourcing.energyPerSecond) do
            if amount > 0 then
                spAddTeamResource(teamID, "energy", amount)
            elseif amount < 0 then
                spUseTeamResource(teamID, "energy", -amount)
            end
        end
    end
end