function gadget:GetInfo()
  return {
    name      = "Dev Helper Cmds",
    desc      = "provides various luarules commands to help developers, can only be used after /cheat",
    author    = "Bluestone",
    date      = "",
    license   = "Horses",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

----------------------------------------
-- SYNCED
if (gadgetHandler:IsSyncedCode()) then
----------------------------------------

    function LoadMissiles()
        if not Spring.IsCheatingEnabled() then return end

        for _,unitID in pairs(Spring.GetAllUnits()) do
            Spring.SetUnitStockpile(unitID, math.max(5, select(2,Spring.GetUnitStockpile(unitID)))) --no effect if the unit can't stockpile
        end

    end

    function HalfHealth()
        if not Spring.IsCheatingEnabled() then return end

        -- reduce all units health to 1/2 of its current value
        for _,unitID in pairs(Spring.GetAllUnits()) do
            Spring.SetUnitHealth(unitID,Spring.GetUnitHealth(unitID)/2)
        end
    end

    function gadget:Initialize()
        gadgetHandler:AddChatAction('loadmissiles', LoadMissiles, "")
        gadgetHandler:AddChatAction('halfhealth', HalfHealth, "")
    end

    function gadget:RecvLuaMsg(msg, playerID)
        if not Spring.IsCheatingEnabled() then return end

        local words = {}
        for word in msg:gmatch("%w+") do table.insert(words, word) end
        if words[1] == "givecat" then
            GiveCat(words)
        elseif words[1] == "destroyselunits" then
            DestroySelUnits(words,playerID)
        end
    end


    function gadget:Shutdown()
        gadgetHandler:RemoveChatAction('loadmissiles')
        gadgetHandler:RemoveChatAction('halfhealth')
    end

    function GiveCat(words)
        if #words<5 then return end
        local ox = tonumber(words[2])
        local oz = tonumber(words[3])
        local teamID = tonumber(words[4])
        local giveUnits = {}
        for n=5,#words do
            giveUnits[#giveUnits+1] = tonumber(words[n])
        end

        local arrayWidth = math.ceil(math.sqrt(#giveUnits))
        local spacing = 120
        local n = 0
        local x,z = ox,oz
        for _,uDID in ipairs(giveUnits) do
            local y = Spring.GetGroundHeight(x,z)
            Spring.CreateUnit(uDID, x,y,z, "n", teamID)
            n = n + 1
            if n%arrayWidth==0 then
                x = ox
                z = z + spacing
            else
                x = x + spacing
            end
        end
    end

    function DestroySelUnits(words, playerID)
        if #words<2 then return end

        for n=2,#words do
            local unitID = tonumber(words[n])
            local h,mh = Spring.GetUnitHealth(unitID)
            Spring.DestroyUnit(unitID)
        end
    end



----------------------------------------
-- UNSYNCED
else
----------------------------------------

    function gadget:Initialize()
        gadgetHandler:AddChatAction('givecat', GiveCat, "")   -- doing it via GotChatMsg ensures it will only listen to the caller
        gadgetHandler:AddChatAction('destroyselunits', MakeWreck, "")  -- doing it via GotChatMsg ensures it will only listen to the caller
    end

    function gadget:Shutdown()
        gadgetHandler:RemoveChatAction('givecat')
        gadgetHandler:RemoveChatAction('destroyselunits')
    end

    function MakeWreck (_,line, words, playerID)
        if not Spring.IsCheatingEnabled() or playerID ~= Spring.GetMyPlayerID() then return end

        local selUnits = Spring.GetSelectedUnits()
        local msg = "destroyselunits"
        for _,unitID in ipairs(selUnits) do
            msg = msg .. " " .. tostring(unitID)
        end
        Spring.SendLuaRulesMsg(msg)
    end

    function GiveCat(_,line, words, playerID)
        if not Spring.IsCheatingEnabled() or playerID ~= Spring.GetMyPlayerID() then return end

        local unitTypes = {}
        local techLevels = {}

        local facSuffix = { --ignore t3
            ["veh"] = "vp", ["kbot"] = "lab", ["air"] = "ap", ["ship"] = "sy", ["hover"] = "hp" --hover are special case, no t2 fac
        }
        local techSuffix = {
            ["t1"] = "", ["t2"] = "a" --t3 added later
        }
        for t,suffix in pairs(facSuffix) do
            local acceptableUDIDs = {}
            for _,uDID in ipairs(UnitDefNames["cor" .. suffix].buildOptions) do
                acceptableUDIDs[uDID] = true
            end
            for _,uDID in ipairs(UnitDefNames["arm" .. suffix].buildOptions) do
                acceptableUDIDs[uDID] = true
            end
            if t~="hover" then
                for _,uDID in ipairs(UnitDefNames["arma" .. suffix].buildOptions) do
                    acceptableUDIDs[uDID] = true
                end
                for _,uDID in ipairs(UnitDefNames["cora" .. suffix].buildOptions) do
                    acceptableUDIDs[uDID] = true
                end
            end
            if UnitDefNames['armcom_bar'] then
                for _,uDID in ipairs(UnitDefNames["cor" .. suffix..'_bar'].buildOptions) do
                    acceptableUDIDs[uDID] = true
                end
                for _,uDID in ipairs(UnitDefNames["arm" .. suffix..'_bar'].buildOptions) do
                    acceptableUDIDs[uDID] = true
                end
                if t~="hover" then
                    for _,uDID in ipairs(UnitDefNames["arma" .. suffix..'_bar'].buildOptions) do
                        acceptableUDIDs[uDID] = true
                    end
                    for _,uDID in ipairs(UnitDefNames["cora" .. suffix..'_bar'].buildOptions) do
                        acceptableUDIDs[uDID] = true
                    end
                end
            end
            unitTypes[t] = acceptableUDIDs
        end

        for t,techSuffix in pairs(techSuffix) do
            local acceptableUDIDs = {}
            for t2,facSuffix in pairs(facSuffix) do
                if not (t=="t2" and t2=="hover") then
                    for _,uDID in ipairs(UnitDefNames["cor" .. techSuffix .. facSuffix].buildOptions) do
                        acceptableUDIDs[uDID] = true
                    end
                    for _,uDID in ipairs(UnitDefNames["arm" .. techSuffix .. facSuffix].buildOptions) do
                        acceptableUDIDs[uDID] = true
                    end
                    if UnitDefNames['armcom_bar'] then
                        for _,uDID in ipairs(UnitDefNames["cor" .. techSuffix .. facSuffix..'_bar'].buildOptions) do
                            acceptableUDIDs[uDID] = true
                        end
                        for _,uDID in ipairs(UnitDefNames["arm" .. techSuffix .. facSuffix..'_bar'].buildOptions) do
                            acceptableUDIDs[uDID] = true
                        end
                    end
                end
            end
            techLevels[t] = acceptableUDIDs
        end
        local t3Units = {}
        for _,uDID in ipairs(UnitDefNames["corgant"].buildOptions) do
            t3Units[uDID] = true
        end
        for _,uDID in ipairs(UnitDefNames["armshltx"].buildOptions) do
            t3Units[uDID] = true
        end
        if UnitDefNames['armcom_bar'] then
            for _,uDID in ipairs(UnitDefNames["corgant_bar"].buildOptions) do
                t3Units[uDID] = true
            end
            for _,uDID in ipairs(UnitDefNames["armshltx_bar"].buildOptions) do
                t3Units[uDID] = true
            end
        end
        techLevels['t3'] = t3Units
        techSuffix['t3'] = 't3'

        local Accept = {} -- table of conditions that must be satisfied for the unitDef to be given

        -- factions
        if string.find(line, "arm") then
            local Condition = function (ud) return ud.name:sub(1,3)=="arm" end
            Accept[#Accept+1] = Condition
        end
        if string.find(line, "core") then
            local Condition  = function (ud) return ud.name:sub(1,3)=="cor" end
            Accept[#Accept+1] = Condition
        end
        if string.find(line, "chicken") then
            local Condition = function (ud) return string.find(ud.name, 'chicken') end
            Accept[#Accept+1] = Condition
        end

        -- unit types
        for t,suffix in pairs(facSuffix) do
            if string.find(line, t) then
                local Condition = function(ud) return unitTypes[t][ud.id] end
                Accept[#Accept+1] = Condition
            end
        end

        -- tech levels
        for t,suffix in pairs(techSuffix) do
            if string.find(line, t) then
                local Condition = function(ud) return techLevels[t][ud.id] end
                Accept[#Accept+1] = Condition
            end
        end

        -- other cats
        if string.find(line, "con") then
            local Condition = function (ud) return ud.isBuilder end
            Accept[#Accept+1] = Condition
        end
        if string.find(line, "mex") then
            local Condition = function (ud) return ud.isExtractor end
            Accept[#Accept+1] = Condition
        end
        if string.find(line, "trans") then
            local Condition = function (ud) return ud.isTransport end
            Accept[#Accept+1] = Condition
        end
        if string.find(line, "fac") then
            local Condition = function (ud) return ud.isFactory end
            Accept[#Accept+1] = Condition
        end
        if string.find(line, "building") then
            local Condition = function (ud) return ud.isBuilding end
            Accept[#Accept+1] = Condition
        end
        if string.find(line, "mobile") then
            local Condition = function (ud) return not ud.isBuilding end
            Accept[#Accept+1] = Condition
        end
        if string.find(line, "all") then
            local Condition = function (ud) if ud.name ~= 'meteor' and ud.name ~= 'roost' then return true end end
            Accept[#Accept+1] = Condition
        end

        -- team
        local _,_,_,teamID = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
        if string.match(line, ' ([0-9].*)') then
            teamID = string.match(line, ' ([0-9].*)')
        end


        -- give units
        local giveUnits = {}
        for _,ud in pairs(UnitDefs) do
            local give = true
            for _,Condition in ipairs(Accept) do
                if not Condition(ud) then
                    give = false
                    break
                end
            end
            if give then
                giveUnits[#giveUnits+1] = ud.id
            end
        end

        Spring.Echo("givecat found " .. #giveUnits .. " units")
        if #giveUnits==0 then return end

        local mx,my = Spring.GetMouseState()
        local t,pos = Spring.TraceScreenRay(mx,my, true)
        local n = 0
        local ox,oz = math.floor(pos[1]), math.floor(pos[3])
        local x,z = ox,oz

        local msg = "givecat " .. x .. " " .. z .. " " .. teamID
        for _,uDID in ipairs(giveUnits) do
            msg = msg .. " " .. uDID
        end

        Spring.SendLuaRulesMsg(msg)

    end


----------------------------------------
end
----------------------------------------
