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
        gadgetHandler:RemoveGadget(self)
    end
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
end

local function setUnitOnSale(unitID, price, toggle)
    if unitsForSale[unitID] == nil or unitsForSale[unitID] == 0 or toggle == false then
        unitsForSale[unitID] = price
        spSetUnitRulesParam(unitID, "unitPrice", price, RPAccess)
        return true
    else
        unitsForSale[unitID] = nil
        spSetUnitRulesParam(unitID, "unitPrice", 0, RPAccess)
        return false
    end
end
local function removeSale(unitID)
    unitsForSale[unitID] = nil
end
local function offerUnitForSale(unitID, msgFromTeamID)
    if not spValidUnitID(unitID) then return end
    local unitDefID = spGetUnitDefID(unitID)
    if not unitDefID then return end
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return end
	local unitTeamID = spGetUnitTeam(unitID)
	if msgFromTeamID ~= unitTeamID then return end -- comment this out in local testing
    local finished = (select(5,spGetUnitHealth(unitID))==1)
    if not finished then return end
    if unitDef.metalCost < 0 then return end
    local selling = setUnitOnSale(unitID, unitDef.metalCost, true)
    if selling then
        spSendLuaUIMsg("unitForSale " .. unitID .. " " .. unitDef.metalCost .. " " .. " " .. msgFromTeamID)
    else
        spSendLuaUIMsg("unitForSale " .. unitID .. " 0 " .. " " .. msgFromTeamID)
    end
end
local function tryToBuyUnit(unitID, msgFromTeamID)
    if not unitID or unitsForSale[unitID] == nil or unitsForSale[unitID] == 0 then return end
    local unitDefID = spGetUnitDefID(unitID)
    if not unitDefID then return end
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return end
    local current,storage = GetTeamResources(msgFromTeamID, "metal")
    if (current <= 0 or current < unitsForSale[unitID]) then return end
    local old_ownerID = spGetUnitTeam(unitID)
    if not spAreTeamsAllied(old_ownerID, msgFromTeamID) then return end
    local price = unitsForSale[unitID]
    TransferUnit(unitID, msgFromTeamID)
    if msgFromTeamID ~= old_ownerID then -- don't send resources to yourself
        ShareTeamResource(msgFromTeamID, old_ownerID, "metal", price)
    end
    spSendLuaUIMsg("unitSold " .. unitID .. " " .. price .. " " .. old_ownerID .. " " .. msgFromTeamID)
    spSetUnitRulesParam(unitID, "unitPrice", 0, RPAccess)
    removeSale(unitID)
end

function gadget:RecvLuaMsg(msg, playerID)
    local _, _, mySpec, msgFromTeamID = spGetPlayerInfo(playerID)

    if mySpec then return end

    local words = {}
    for word in msg:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if words[1] == "unitOfferToSell" then
        --Spring.Echo(words) -- debug
        local unitID = tonumber(words[2])
        offerUnitForSale(unitID, msgFromTeamID)
    elseif words[1] == "unitTryToBuy" then
        --Spring.Echo(words) -- debug
        local unitID = tonumber(words[2])
        tryToBuyUnit(unitID, msgFromTeamID)
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
    removeSale(unitID)
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if unitDefID then
        spSetUnitRulesParam(unitID, "unitPrice", 0, RPAccess)
        removeSale(unitID)
    end
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
    removeSale(unitID)
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

        setUnitOnSale(unitID, unitDef.metalCost, false)

	    local msgFromTeamID = spGetUnitTeam(unitID)
        spSendLuaUIMsg("unitForSale " .. unitID .. " " .. unitDef.metalCost .. " " .. " " .. msgFromTeamID) -- Announce offer
    end
end]]

end
