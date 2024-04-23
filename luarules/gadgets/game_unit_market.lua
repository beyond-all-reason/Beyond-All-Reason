function gadget:GetInfo()
    return {
        name    = "Unit Market - Backend",
        desc    = "Allows players to trade units with each other. Allies only. Fair price!",
        author  = "Tom Fyuri",
        date    = "2024",
        license = "GNU GPL v2",
        layer   = 0,
        enabled = true
    }
end
-- This handles fair transfer of resource for unit if the modoption is enabled, otherwise it just self removes.
local unitMarket   = Spring.GetModOptions().unit_market

-- We just have a state which holds unit price. (zero or nil - can't trade it)
-- We support only one price - the fair price - no tips - no discount - no markups.
-- We only allow you to trade finished units.

-- There is no GUI or any other fancy tricks here. This is just a backend. Other widget makers though should be able to use this no problem.

if gadgetHandler:IsSyncedCode() then
local unitsForSale = {}
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spGetTeamInfo         = Spring.GetTeamInfo
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitTeam			= Spring.GetUnitTeam
local ShareTeamResource     = Spring.ShareTeamResource
local GetTeamResources      = Spring.GetTeamResources
local TransferUnit          = Spring.TransferUnit
local spAreTeamsAllied      = Spring.AreTeamsAllied
local spSendLuaUIMsg        = Spring.SendLuaUIMsg
local spSendLuaRulesMsg     = Spring.SendLuaRulesMsg
local spValidUnitID         = Spring.ValidUnitID
local spGetUnitHealth       = Spring.GetUnitHealth
local spGetUnitRulesParam  	= Spring.GetUnitRulesParam
local spSetUnitRulesParam   = Spring.SetUnitRulesParam
local RPAccess = {allied = true}

function gadget:Initialize()
    -- if market is disabled globally, exit
    if not unitMarket or unitMarket ~= true then
        gadgetHandler:RemoveGadget(self) -- not enabled? shutdown
    end
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
end

function gadget:RecvLuaMsg(msg, playerID)
    local _, _, mySpec, msgFromTeamID = spGetPlayerInfo(playerID)

    if mySpec then return end -- ignore msgs from spectators

    local words = {}
    for word in msg:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if words[1] == "unitOfferToSell" then
        --Spring.Echo(words) -- debug
        local unitID = tonumber(words[2])
        if not spValidUnitID(unitID) then return end
        local unitDefID = spGetUnitDefID(unitID)
        if not unitDefID then return end -- whats wrong?
        local unitDef = UnitDefs[unitDefID]
        if not unitDef then return end -- whats wrong?
		local finished = (select(5,spGetUnitHealth(unitID))==1)
        if not finished then return end -- not finished, bad
        if unitDef.metalCost < 0 then return end -- should I even test it?
        if not unitsForSale[unitID] then
            unitsForSale[unitID] = unitDef.metalCost
            spSetUnitRulesParam(unitID, "unitPrice", unitDef.metalCost, RPAccess)
        else -- flip
            unitsForSale[unitID] = nil
            spSetUnitRulesParam(unitID, "unitPrice", 0, RPAccess)
        end
        spSendLuaUIMsg("unitForSale " .. unitID .. " " .. unitDef.metalCost .. " " .. " " .. msgFromTeamID) -- Announce offer
    elseif words[1] == "unitTryToBuy" then
        --Spring.Echo(words) -- debug
        local unitID = tonumber(words[2])
        if not unitID or unitsForSale[unitID] == nil or unitsForSale[unitID] == 0 then return end -- no unit/not for sale?
        local unitDefID = spGetUnitDefID(unitID)
        if not unitDefID then return end -- whats wrong?
        local unitDef = UnitDefs[unitDefID]
        if not unitDef then return end -- whats wrong?
        local current,storage = GetTeamResources(msgFromTeamID, "metal")
        if (current <= 0 or current < unitsForSale[unitID]) then return end -- can't afford
        local old_ownerID = spGetUnitTeam(unitID)
        if not spAreTeamsAllied(old_ownerID, msgFromTeamID) then return end -- ignore enemy units, won't be buying them anyway
        local price = unitsForSale[unitID]
        TransferUnit(unitID, msgFromTeamID)
        if msgFromTeamID ~= old_ownerID then -- don't send resources to yourself
            ShareTeamResource(msgFromTeamID, old_ownerID, "metal", price)
        end
        spSendLuaUIMsg("unitSold " .. unitID .. " " .. price .. " " .. old_ownerID .. " " .. msgFromTeamID) -- Announce sale
        spSetUnitRulesParam(unitID, "unitPrice", 0, RPAccess)
        unitsForSale[unitID] = nil
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
    unitsForSale[unitID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if unitDefID then
        spSetUnitRulesParam(unitID, "unitPrice", 0, RPAccess)
        unitsForSale[unitID] = nil
    end
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
    unitsForSale[unitID] = nil
end

-- debug/for testing: AI lists for sale ANY unit it finishes building, good enough for single player testing, comment out in production though
-- if you are using inactive AI, just use godmode 3 to control it to order to build something, then godmode 0 to stop control and then try alt+doubleclick to buy
--[[function gadget:UnitFinished(unitID, unitDefID, teamID, builderID)
    local _, _, _, isAiTeam = spGetTeamInfo(teamID)
    if isAiTeam then
        local unitDefID = spGetUnitDefID(unitID)
        if not unitDefID then return end
        local unitDef = UnitDefs[unitDefID]
        if not unitDef then return end

        if unitDef.metalCost < 0 then return end -- should I even test it?

        unitsForSale[unitID] = unitDef.metalCost
        spSetUnitRulesParam(unitID, "unitPrice", unitDef.metalCost, RPAccess)

	    local msgFromTeamID = spGetUnitTeam(unitID)
        spSendLuaUIMsg("unitForSale " .. unitID .. " " .. unitDef.metalCost .. " " .. " " .. msgFromTeamID) -- Announce offer
    end
end]]

end