-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Stun Metal Storage",
    desc      = "Makes stunned storage drop capactiy",
    author    = "Nixtux",
    date      = "June 15, 2014",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
	return false
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local storageDefs = {
  --Arm 
  [ UnitDefNames['armmstor'].id ] = true,
  [ UnitDefNames['armuwms'].id ] = true,
  [ UnitDefNames['armuwadvms'].id ] = true,

  ---Core 
  [ UnitDefNames['cormstor'].id ] = true,
  [ UnitDefNames['coruwms'].id ] = true,
  [ UnitDefNames['coruwadvms'].id ] = true,
 }

local storageunits = {}
local stunnedstorage = {}
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

-- Speed-ups

local uDefs = UnitDefs
local GetUnitDefID         = Spring.GetUnitDefID
local SpGetAllUnits        = Spring.GetAllUnits

local ipairs = ipairs
local pairs = pairs

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------


function gadget:GameFrame(n)
    if (((n+18) % 30) < 0.1) then
        for unitID, _ in pairs(storageunits) do
	        local uDefID = GetUnitDefID(unitID) ; if not uDefID then break end
	        local uDef = uDefs[uDefID]
	        local storage = storageunits[unitID].storage
	        local _,stunned = Spring.GetUnitIsStunned(unitID)

	        if stunned and (storageunits[unitID].isEMPed == false) then
		        local currentLevel,totalstorage = Spring.GetTeamResources(Spring.GetUnitTeam(unitID),"metal")
		        local newstoragetotal = totalstorage - storage
		        --Spring.Echo("current storage level " .. currentLevel .. "   total storage " .. totalstorage .. "   new storage level " ..newstoragetotal)
  		        Spring.SetTeamResource(Spring.GetUnitTeam(unitID), "ms", newstoragetotal)
		        if currentLevel > (newstoragetotal) then
				    local x,y,z = Spring.GetUnitPosition(unitID)
				    local height = storageunits[unitID].height * 0.70
				    Spring.SpawnCEG("METAL_STORAGE_LEAK",x,y+height,z,0,0,0)
		        end
		        storageunits[unitID].isEMPed = true
		        stunnedstorage[unitID] = true 
	        end
        end
        for unitID,_ in pairs(stunnedstorage) do
	        local _,stunned = Spring.GetUnitIsStunned(unitID)
	        local team = Spring.GetUnitTeam(unitID)
	        if not stunned and team ~= nil then
				local storage = storageunits[unitID].storage
	            local _,totalstorage = Spring.GetTeamResources(team,"metal")
	            Spring.SetTeamResource(Spring.GetUnitTeam(unitID), "ms", totalstorage+storage)
	            stunnedstorage[unitID] = nil
	            storageunits[unitID].isEMPed = false
	        end
	    end
    end
end
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local function SetupUnit(unitID,unitDefID)
    local ud = UnitDefs[unitDefID]
    if (ud == nil)or(ud.height == nil) then return nil end
    storageunits[unitID] = {isEMPed = false, height = ud.height, storage = ud.metalStorage}
end

--testing only
--[[
function gadget:Initialize() --testing only
    for _, unitID in ipairs(SpGetAllUnits()) do
    local unitDefID = GetUnitDefID(unitID)
        if (storageDefs[unitDefID]) then
        SetupUnit(unitID,unitDefID)
        end
    end
end
--]]

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
    if (storageDefs[unitDefID]) then
        SetupUnit(unitID,unitDefID)
    end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if (storageunits[unitID]) and storageunits[unitID].isEMPed == true then
		local storage = storageunits[unitID].storage
		local _,totalstorage = Spring.GetTeamResources(oldTeam,"metal")
		Spring.SetTeamResource(oldTeam, "ms", totalstorage + storage)
        _, totalstorage = Spring.GetTeamResources(newTeam,"metal")
		local newstoragetotal = totalstorage - storage
  		Spring.SetTeamResource(newTeam, "ms", newstoragetotal)
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam) --we use UnitPreDamaged so as we get in before unit_transportfix has its effect
    if (storageDefs[unitDefID]) then
        local hp = Spring.GetUnitHealth(unitID)
        if damage > hp and not paralyzer then  --unit's can have 0 health
            if storageunits[unitID] and storageunits[unitID].isEMPed == true then
                local _,totalstorage = Spring.GetTeamResources(unitTeam,"metal")
                Spring.SetTeamResource(unitTeam, "ms", totalstorage + storageunits[unitID].storage) --Add back before unit is destoryed
            end
            storageunits[unitID] = nil
            stunnedstorage[unitID] = nil
        end
    end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
