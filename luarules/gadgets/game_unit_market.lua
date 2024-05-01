if not Spring.GetModOptions().unit_market then
    return
end

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

VFS.Include("luarules/configs/customcmds.h.lua")

if gadgetHandler:IsSyncedCode() then

-- We just have a state which holds unit price. (zero or nil - can't trade it)
-- We support only one price - the fair price - no tips - no discount - no markups.
-- We only allow you to trade finished units.

-- There is no GUI or any other fancy tricks here. This is just a backend. Other widget makers though should be able to use this no problem.

-- Update: AI will remember your gifts and give you discount in kind for your purchases. In practise, this means you can swap units with AI for free, as long as you've given the AI more than you bought from AI.

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
local AllyAIsalesEverything = true -- does this needs to be a modoption? This seems useful for coop.
local AllyAItab = {} -- [teamAI_ID][teamID] -- array of teams that this AI team owes metal to

local function setUnitOnSale(unitID, price, toggle)
    if unitsForSale[unitID] == nil or unitsForSale[unitID] == 0 or toggle == false then
        unitsForSale[unitID] = price
        spSetUnitRulesParam(unitID, "unitPrice", price, RPAccess)
        return true
    else
        unitsForSale[unitID] = nil
        spSetUnitRulesParam(unitID, "unitPrice", 0, RPAccess) -- we cannot set price lower or equal to zero, zero is going to be "unit is NOT for sale"
        return false
    end
end

local function removeSale(unitID)
    unitsForSale[unitID] = nil
end

local function getAIdiscount(newTeamID, oldTeamID, price)
    if not AllyAIsalesEverything then return 0 end

    local myDiscount = AllyAItab[oldTeamID] and AllyAItab[oldTeamID][newTeamID] or 0
    local finalDiscount = math.min(price, myDiscount) -- Ensure finalDiscount doesn't exceed price

    if finalDiscount > 0 then
        if myDiscount > 0 then
            AllyAItab[oldTeamID][newTeamID] = myDiscount - finalDiscount
        end
        return finalDiscount
    else
        return 0
    end
end


local function UnitSale(unitID, price, msgFromTeamID)
    SendToUnsynced("UnitSale",  unitID, price, msgFromTeamID)
end

local function UnitSold(unitID, price, old_ownerTeamID, msgFromTeamID)
    SendToUnsynced("UnitSold", unitID, price, old_ownerTeamID, msgFromTeamID)
end

local function offerUnitForSale(unitID, sale_price, msgFromTeamID)
    if not spValidUnitID(unitID) then return end
    local unitDefID = spGetUnitDefID(unitID)
    if not unitDefID then return end
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return end
	local unitTeamID = spGetUnitTeam(unitID)
	if msgFromTeamID ~= unitTeamID then return end -- comment this out in local testing, only owner can set units for sale
    local finished = (select(5,spGetUnitHealth(unitID))==1)
    if not finished then return end
    local price
    if sale_price > 0 then price = sale_price -- for now we only support fair price, but for future - 0 = set price automatically
    else price = unitDef.metalCost
    end
    if price <= 0 then return end
    local selling = setUnitOnSale(unitID, price, true)
    if not selling then
        price = 0
    end
    UnitSale(unitID, price, msgFromTeamID)
end

local function tryToBuyUnit(unitID, msgFromTeamID)
    if not unitID or unitsForSale[unitID] == nil or unitsForSale[unitID] == 0 then return end
    local unitDefID = spGetUnitDefID(unitID)
    if not unitDefID then return end
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return end

    local old_ownerTeamID = spGetUnitTeam(unitID)
    local _, _, _, isAiTeam = spGetTeamInfo(old_ownerTeamID)
    if not spAreTeamsAllied(old_ownerTeamID, msgFromTeamID) then return end

    local current,storage = GetTeamResources(msgFromTeamID, "metal")
    local price = unitsForSale[unitID]

    if isAiTeam then
        local discount = getAIdiscount(msgFromTeamID, old_ownerTeamID, price) -- if AI ally owes you metal, you can discount
        price = price - discount
        --Spring.Echo("debug discount: "..discount) -- debug: if AI owes you money...
    end

    if (current < price) then return end

    TransferUnit(unitID, msgFromTeamID)
    if msgFromTeamID ~= old_ownerTeamID and price > 0 then -- don't send resources to yourself
        ShareTeamResource(msgFromTeamID, old_ownerTeamID, "metal", price)
    end
    spSetUnitRulesParam(unitID, "unitPrice", 0, RPAccess)
    removeSale(unitID)
    UnitSold(unitID, price, old_ownerTeamID, msgFromTeamID)
end

function gadget:RecvLuaMsg(msg, playerID)
    local _, _, mySpec, msgFromTeamID = spGetPlayerInfo(playerID)

    if mySpec then return end

    local words = {}
    for word in msg:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if words[1] == "unitOfferToSell" then
        local unitID = tonumber(words[2])
        --local sale_price = tonumber(words[3])
        -- at the moment we only support "fair" price, but it is possible here to set unit price by client, for now we send 0 - set price automatically
        offerUnitForSale(unitID, 0, msgFromTeamID)
    elseif words[1] == "unitTryToBuy" then
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
    if (AllyAIsalesEverything) and spAreTeamsAllied(newTeamID, oldTeamID) then
        local unitDef = UnitDefs[unitDefID]
        local _, _, _, isAiTeamOld = spGetTeamInfo(oldTeamID) -- player
        local _, _, _, isAiTeamNew = spGetTeamInfo(newTeamID) -- gives unit to AI
        if not isAiTeamOld and isAiTeamNew and unitDef.metalCost>0 then
            local finished = (select(5,spGetUnitHealth(unitID))==1) -- AI tab only accepts finished units
            if finished then
                local price = unitDef.metalCost
                -- This "ugly" calculation won't be called too much since you are not often giving units to the AI
                -- But it might be a good idea to pre init arrays if we expand this optional functionality for between players
                if AllyAItab[newTeamID] == nil then
                    AllyAItab[newTeamID] = {}
                end
                if AllyAItab[newTeamID][oldTeamID] == nil then
                    AllyAItab[newTeamID][oldTeamID] = 0
                end
                AllyAItab[newTeamID][oldTeamID] = AllyAItab[newTeamID][oldTeamID] + price
                --Spring.Echo("old team "..oldTeamID.." owes "..newTeamID.." this much: "..AllyAItab[newTeamID][oldTeamID]..".") -- debug
                -- TODO this is kinda useful but I don't know how to not spam you constantly with this information...
                -- so need to figure out how to show you how much AI owes you metal for your donations
                -- possible TODO, maybe forbid AI from selling you its metal extractors?
                setUnitOnSale(unitID, price, false)
                UnitSale(unitID, price, newTeamID)
                return
            end
        end
    end
    removeSale(unitID)
    UnitSale(unitID, 0, newTeamID)
end

function gadget:UnitFinished(unitID, unitDefID, teamID, builderID)
    if (AllyAIsalesEverything) then
        local _, _, _, isAiTeam = spGetTeamInfo(teamID)
        if isAiTeam then
            local unitDefID = spGetUnitDefID(unitID)
            if not unitDefID then return end
            local unitDef = UnitDefs[unitDefID]
            if not unitDef then return end
            if unitDef.metalCost <= 0 then return end

            local price = unitDef.metalCost
            setUnitOnSale(unitID, price, false)
            UnitSale(unitID, price, teamID)
        end
    end
end

function gadget:Initialize()
    -- if market is disabled globally, exit
    if not unitMarket or unitMarket ~= true then
        gadgetHandler:RemoveGadget(self)
    end
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
    --
    if (AllyAIsalesEverything) then -- set all AI units for sale
        for _, unitID in ipairs(Spring.GetAllUnits()) do
            local teamID = spGetUnitTeam(unitID)
            local _, _, _, isAiTeam = spGetTeamInfo(teamID)
            if isAiTeam then
                local unitDefID = spGetUnitDefID(unitID)
                if unitDefID then
                    local unitDef = UnitDefs[unitDefID]
                    if unitDef and unitDef.metalCost >= 0 then
                        local price = unitDef.metalCost
                        setUnitOnSale(unitID, price, false)
                        UnitSale(unitID, price, teamID)
                    end
                end
            end
        end
    end
end

else -- unsynced

    -- lets only broadcast these trades to allies and spectators
	local spGetSpectatingState = Spring.GetSpectatingState
	local spec, _ = spGetSpectatingState()
    local spGetPlayerInfo = Spring.GetPlayerInfo
	local myPlayerID = Spring.GetMyPlayerID()
    local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
    local spAreTeamsAllied = Spring.AreTeamsAllied
    local myTeamID = Spring.GetMyTeamID()
    local myAllyTeamID = Spring.GetMyAllyTeamID()

	function gadget:PlayerChanged(playerID)
        myPlayerID = Spring.GetMyPlayerID()
        myTeamID = Spring.GetMyTeamID()
        myAllyTeamID = Spring.GetMyAllyTeamID()
	end

	function gadget:Initialize()
        -- if market is disabled globally, exit
        if not unitMarket or unitMarket ~= true then
            gadgetHandler:RemoveGadget(self)
        end
		gadgetHandler:AddSyncAction("UnitSale", handleSaleEvent)
		gadgetHandler:AddSyncAction("UnitSold", handleSoldEvent)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("UnitSale")
		gadgetHandler:RemoveSyncAction("UnitSold")
	end

	function handleSaleEvent(_, unitID, price, msgFromTeamID)
		local spec, fullView = spGetSpectatingState()
		if not spec or not fullView then
            if not spAreTeamsAllied(msgFromTeamID, myTeamID) then return end
		end
		if Script.LuaUI("UnitSale") then
			Script.LuaUI.UnitSale(unitID, price, msgFromTeamID)
		end
	end

	function handleSoldEvent(_, unitID, price, old_ownerTeamID, msgFromTeamID)
		local spec, fullView = spGetSpectatingState()
		if not spec or not fullView then
            if not spAreTeamsAllied(msgFromTeamID, myTeamID) then return end
		end
		if Script.LuaUI("UnitSold") then
			Script.LuaUI.UnitSold(unitID, price, old_ownerTeamID, msgFromTeamID)
		end
	end
end
