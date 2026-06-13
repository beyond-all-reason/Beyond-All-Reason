local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name = "Unit Killed Population Count Transfer",
        desc = "Allows modifying population count to or from killed units allyteam or to Gaia",
        author = "Chemdude8",
        date = "2026-05-06",
        license = "None",
        layer = 49,
        enabled = true
    }
end

if gadgetHandler:IsSyncedCode() then

    -- Local copies of spring/recoil functions
    local spTransferTeamMaxUnits = Spring.TransferTeamMaxUnits
    local math = math
    local string = string

    -- One-off spring calls
    local modOptions = Spring.GetModOptions()
    local GaiaTeamID = Spring.GetGaiaTeamID()

    -- Local long running variables
    local killedTeamToCountTable = {} -- either the teamID of the killed player in gaia-mode, or killedTeam..attackerTeam to count in transfer mode

    function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)

        if modOptions.populationtransfer == "disabled" or modOptions.populationtransfer == nil or modOptions.populationtransferratio == 0 then
            return
        end

        -- In gaia mode you might not need an attackerTeam but lava cases could punish you unnecessarily then
        if unitTeam == nil or attackerTeam == nil then
            return
        end

        local transferIncrement = nil
        if modOptions.populationtransfer == "reduce" then
            killedTeamToCountTable[unitTeam] = (killedTeamToCountTable[unitTeam] == nil and modOptions.populationtransferratio) or
                killedTeamToCountTable[unitTeam] + modOptions.populationtransferratio;
            if math.abs(killedTeamToCountTable[unitTeam]) >= 1 then
                transferIncrement = 1
                killedTeamToCountTable[unitTeam] = 0
            end
        elseif modOptions.populationtransfer == "transfer" then
            killedTeamToCountTable[unitTeam .. attackerTeam] = (killedTeamToCountTable[unitTeam .. attackerTeam] == nil and modOptions.populationtransferratio) or
                killedTeamToCountTable[unitTeam .. attackerTeam] + modOptions.populationtransferratio;
            if math.abs(killedTeamToCountTable[unitTeam .. attackerTeam]) >= 1 then
                transferIncrement = 1
                killedTeamToCountTable[unitTeam .. attackerTeam] = 0
            end
        end

        if (transferIncrement == nil or math.abs(transferIncrement) < 1) then
            return
        end

        if modOptions.populationtransferratio > 0 then
            if modOptions.populationtransfer == "reduce" then
                spTransferTeamMaxUnits(unitTeam, GaiaTeamID, 1);
            elseif modOptions.populationtransfer == "transfer" then
                spTransferTeamMaxUnits(unitTeam, attackerTeam, 1);
            end
        else
            -- Intentionally not allowing taking population from gaia currently
            --[[ if modOptions.populationtransfer == "reduce" then
                   spTransferTeamMaxUnits(GaiaTeamID, unitTeam, 1);
            else ]]
            if modOptions.populationtransfer == "transfer" then
                spTransferTeamMaxUnits(attackerTeam, unitTeam, 1);
            end
        end
    end

    function gadget:RecvLuaMsg(msg, playerID)
        Spring.Echo("LuaRules message received by Gadget from Playerv1 " .. msg .. " from player: " .. playerID)
        -- Incoming message expected to look like Spring.SendLuaRulesMsg('pct|d|'..myTeamID..'|'..populationPlayer.team..'|'..shareAmount)
        if string.find(msg, 'pct') == 1 then
            Spring.Echo("PopCapTransfer message received " .. msg .. " from player: " .. playerID)
            
            local splitIterator = string.split(msg, "|")
            local arguments = {}
            for i, v in pairs(splitIterator) do
                arguments[i] = v
            end
            arguments[3] = tonumber(arguments[3])
            arguments[4] = tonumber(arguments[4])
            arguments[5] = tonumber(arguments[5])

            -- Ensure the 'from' player matches the message producer
            if #arguments == 5 and arguments[2] == 'd' and playerID == arguments[3] then
                Spring.Echo("PopCapTransfer message parsed " .. msg .. " from player: " .. playerID)
                -- Direct transfer from one player giving to another
                spTransferTeamMaxUnits(arguments[3], arguments[4], arguments[5]);
            end

        end
    end

end -- end of syncd
