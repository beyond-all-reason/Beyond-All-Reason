function gadget:GetInfo()
	return {
        name = "Give Command",
        desc = "Provides the /give command to spawn units or give resources.",
        author = "GameLobby",
        date = "2024-07-26",
        license = "GNU GPL, v2 or later",
        layer = 1,
        enabled = true,
    }
end

if gadgetHandler:IsSyncedCode() then
    local spGetPlayerInfo = Spring.GetPlayerInfo
    local spGetTeamInfo = Spring.GetTeamInfo
    local spCreateUnit = Spring.CreateUnit
    local spAddTeamResource = Spring.AddTeamResource
    local spSetUnitExperience = Spring.SetUnitExperience
    local spSendMessageToPlayer = Spring.SendMessageToPlayer
    local ud_GetUnitDefID = UnitDefNames.GetUnitDefID

    local function GiveCmdFunc(_, args, playerID)
        local target, amount, teamID_str, xp_str = args:match("^(%S+)%s*(%d*)%s*(%d*)%s*(%d*)$")

        if not target then
            spSendMessageToPlayer(playerID, "Usage: /give <unitdef|metal|energy> [amount] [team] [experience]")
            return true
        end

        local amount_num = (amount and amount ~= "") and tonumber(amount) or 1
        local _, _, _, pTeamID = spGetPlayerInfo(playerID)
        local teamID = (teamID_str and teamID_str ~= "") and tonumber(teamID_str) or pTeamID
        local xp = (xp_str and xp_str ~= "") and tonumber(xp_str) or nil

        if not spGetTeamInfo(teamID) then
            spSendMessageToPlayer(playerID, "Invalid team ID: " .. teamID)
            return true
        end

        if (target == "metal" or target == "energy") then
            spAddTeamResource(teamID, target, amount_num)
            spSendMessageToPlayer(playerID, ("Gave %d %s to team %d"):format(amount_num, target, teamID))
            return true
        end

        local unitDefID = ud_GetUnitDefID(target)
        if not unitDefID then
            spSendMessageToPlayer(playerID, "Unknown unitdef: " .. target)
		return true
	end

        local x, _, z = spGetPlayerInfo(playerID, "mousepos")
        if not x then
             _, x, _, z = spGetTeamInfo(teamID, "startpos")
        end

        for i = 1, amount_num do
            local px = x + (math.random() * 100) - 50
            local pz = z + (math.random() * 100) - 50
            local py = Ground.GetHeight(px, pz)
            local unitID = spCreateUnit(unitDefID, {x=px, y=py, z=pz}, 0, teamID, false, false)
            if unitID and xp then
                spSetUnitExperience(unitID, xp)
            end
        end

        spSendMessageToPlayer(playerID, ("Spawned %d of %s for team %d"):format(amount_num, target, teamID))
        return true
	end

	function gadget:Initialize()
        gadgetHandler:AddChatAction('give', GiveCmdFunc, "Spawns units or gives resources: /give <unitdef|metal|energy> [amount] [team] [xp]")
	end

	function gadget:Shutdown()
        gadgetHandler:RemoveChatAction('give')
	end
end