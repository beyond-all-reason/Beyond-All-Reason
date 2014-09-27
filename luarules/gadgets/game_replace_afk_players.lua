function gadget:GetInfo()
  return {
    name      = "Substitution",
    desc      = "Allows players absent at gamestart to be replaced by specs",
    author    = "Bluestone",
    date      = "June 2014",
    license   = "GNU GPL, v3 or later",
    layer     = 1, --run after game_intial_spawn 
    enabled   = true  
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (tonumber(Spring.GetModOptions().mo_noowner) or 0) == 1 then
	gadgetHandler:RemoveGadget() -- don't run in FFA mode
end

-----------------------------
if gadgetHandler:IsSyncedCode() then 
-----------------------------

local substitutes = {}
local players = {}
local absent = {}
local replaced = false

local gaiaTeamID = Spring.GetGaiaTeamID()

function gadget:RecvLuaMsg(msg, playerID)
	if msg=='\145' then
        substitutes[playerID] = nil
        --Spring.Echo("received removal", playerID)
    end
    if msg=='\144' then
        -- do the same eligibility check as in unsynced
        local customtable = select(10,Spring.GetPlayerInfo(playerID))
        local tsMu = customtable.skill 
        local tsSigma customtable.skilluncertainty
        ts = tsMu and tonumber(tsMu:match("%d+%.?%d*"))
        tsSigma = tonumber(tsSigma)
        local eligible = tsMu and tsSigma and (tsSigma<=2) and (not string.find(tsMu, ")")) and (not players[playerID]) 
        if eligible then
            substitutes[playerID] = ts
        end
        --Spring.Echo("received", playerID, eligible, ts)
    end
end

function gadget:Initialize()
    -- record a list of which playersIDs are players on which teamID
    local allyTeamList = Spring.GetAllyTeamList()
    for _,allyTeamID in pairs(allyTeamList) do
        local teamList = Spring.GetTeamList(allyTeamID)
        for _,teamID in pairs(teamList) do
        if teamID~=gaiaTeamID then
            local playerList = Spring.GetPlayerList(teamID)
            for _,playerID in pairs(playerList) do
                local _,_,spec = Spring.GetPlayerInfo(playerID)
                if not spec then
                    players[playerID] = teamID
                end
            end
        end
        end
    end
end

function gadget:GameSetup(state, newReady, playerStates)
    FindSubs(false)
    return true, newReady
end

function FindSubs(real)
    -- make a copy of the substitutes table
    local substitutesLocal = {}
    for k,v in pairs(substitutes) do
        substitutesLocal[k] = v
    end
    absent = {}
    
    -- make a list of absent players (only ones with valid ts)
    for playerID,_ in pairs(players) do
        local _,active,spec = Spring.GetPlayerInfo(playerID)
        local present = active and not spec
        if not present then
            local customtable = select(10,Spring.GetPlayerInfo(playerID)) -- player custom table
            local tsMu = customtable.skill
            ts = tsMu and tonumber(tsMu:match("%d+%.?%d*")) 
            if ts then
                absent[playerID] = ts
                --Spring.Echo("absent:", playerID, ts)
            end
        end
    end
    --Spring.Echo(#absent)
    
    -- for each one, try and find a suitable replacement & substitute if so
    for playerID,ts in pairs(absent) do
        local validSubs = {}
        for subID,subts in pairs(substitutesLocal) do
            local _,active,spec = Spring.GetPlayerInfo(subID)
            if active and spec and math.abs(ts-subts)<=4.5 then 
                validSubs[#validSubs+1] = subID
            end
        end
        local willSub = false
        --Spring.Echo(#validSubs, #substitutesLocal)
        if #validSubs>0 then
            local sID
            if real then
                -- do the replacement 
                sID = (#validSubs>1) and validSubs[math.random(1,#validSubs)] or validSubs[1]
                local teamID = players[playerID]
                Spring.AssignPlayerToTeam(sID, teamID)
                replaced = true
                
                local incoming,_ = Spring.GetPlayerInfo(sID)
                local outgoing,_ = Spring.GetPlayerInfo(playerID)            
                Spring.Echo("Player " .. incoming .. " was substituted in for " .. outgoing)
            end
            substitutesLocal[sID] = nil
            willSub = true
        end
        if not real then
            -- tell luaui who we would substitute if the game started now
            Spring.SetGameRulesParam("Player" .. playerID .. "willSub", willSub and 1 or 0)
        end
    end

end

function gadget:GameStart()
    FindSubs(true)
end

function gadget:GameFrame(n)
    if n~=1 then return end

    if replaced then
        -- if at least one player was replaced, reveal startpoints to all
        Spring.Echo("Revealing start points to all")
       
        local coopStartPoints = GG.coopStartPoints or {} 
        local revealed = {}
        for pID,p in pairs(coopStartPoints) do --first do the coop starts
            local name,_,tID = Spring.GetPlayerInfo(pID)
            SendToUnsynced("MarkStartPoint", p[1], p[2], p[3], name, tID)
            revealed[pID] = true
        end
            
        local teamStartPoints = GG.teamStartPoints or {}
        for tID,p in pairs(teamStartPoints) do
            p = teamStartPoints[tID]
            local playerList = Spring.GetPlayerList(tID)
            local name = ""
            for _,pID in pairs(playerList) do --now do all pIDs for this team which were not coop starts
                if not revealed[pID] then
                    local pName,_ = Spring.GetPlayerInfo(pID) 
                    if pName and absent[pID]==nil then --AIs might not have a name, don't write the name of the dropped player
                        name = name .. pName .. ", "
                        revealed[pID] = true
                    end
                end
            end
            name = string.sub(name, 1, math.max(string.len(name)-2,1)) --remove final ", "
            SendToUnsynced("MarkStartPoint", p[1], p[2], p[3], name, tID)
        end
    end
    
    gadgetHandler:RemoveGadget()
end

-----------------------------
else -- begin unsynced section
-----------------------------

local x = 500
local y = 500

local myPlayerID = Spring.GetMyPlayerID()
local spec,_ = Spring.GetSpectatingState()

local eligible

local vsx, vsy = Spring.GetViewGeometry()
function gadget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()
end

local subsButton
local bX = vsx * 0.8
local bY = vsy * 0.8 
local bH = 30
local bW = 140
local offer = false

function gadget:GameSetup(state, newReady, playerStates)
    return true, newReady
end --wierdness

function MakeButton()
	subsButton = gl.CreateList(function()
		-- draws background rectangle
		gl.Color(0.1,0.1,.45,0.18)                              
		gl.Rect(bX,bY+bH, bX+bW, bY)
	
		-- draws black border
		gl.Color(0,0,0,1)
		gl.BeginEnd(GL.LINE_LOOP, function()
			gl.Vertex(bX,bY)
			gl.Vertex(bX,bY+bH)
			gl.Vertex(bX+bW,bY+bH)
			gl.Vertex(bX+bW,bY)
		end)
		gl.Color(1,1,1,1)
	end)
end

function Initialize()
    gadgetHandler:AddSyncAction("MarkStartPoint", MarkStartPoint)
    
    local customtable = select(10,Spring.GetPlayerInfo(myPlayerID)) -- player custom table
    local tsMu = customtable.skill 
	local tsSigma = customtable.skilluncertainty
    ts = tsMu and tonumber(tsMu:match("%d+%.?%d*"))
    tsSigma = tonumber(tsSigma)
    eligible = tsMu and tsSigma and (tsSigma<=2) and (not string.find(tsMu, ")")) and spec
    
    MakeButton()
end


function gadget:DrawScreen()
    if eligible then
        -- ask each spectator if they would like to replace an absent player
		-- draw button
		gl.CallList(subsButton)
		
		-- text
		local x,y = Spring.GetMouseState()
		if x > bX and x < bX+bW and y > bY and y < bY+bH then
			colorString = "\255\255\230\0"
		else
			colorString = "\255\255\255\255"
		end
        local textString
        if not offer then
            textString = "Offer to play"
        else
            textString = "Withdraw offer"
        end
		gl.Text(colorString .. textString, bX+10, bY+9, 20, "o")
		gl.Color(1,1,1,1)
    end
end

function gadget:MousePress(sx,sy)
	-- pressing b
	if sx > bX and sx < bX+bW and sy > bY and sy < bY+bH and eligible then
        --Spring.Echo("sent", myPlayerID, ts)
        if not offer then
            Spring.SendLuaRulesMsg('\144')
            Spring.Echo("If player(s) are afk when the game starts, you might be used as a substitute")
            offer = true
            bW = 160
            MakeButton()
        else
            Spring.SendLuaRulesMsg('\145')
            Spring.Echo("Your offer to substitute has been withdrawn")
            offer = false
            bW = 140
            MakeButton()
        end
	end
end

function gadget:MouseRelease(x,y)
	return false
end

function MarkStartPoint(_,x,y,z,name,tID)
    Spring.MarkerAddPoint(x, y, z, colourNames(tID) .. name, true)
end

function colourNames(teamID)
    	nameColourR,nameColourG,nameColourB,nameColourA = Spring.GetTeamColor(teamID)
		R255 = math.floor(nameColourR*255)  
        G255 = math.floor(nameColourG*255)
        B255 = math.floor(nameColourB*255)
        if ( R255%10 == 0) then
                R255 = R255+1
        end
        if( G255%10 == 0) then
                G255 = G255+1
        end
        if ( B255%10 == 0) then
                B255 = B255+1
        end
	return "\255"..string.char(R255)..string.char(G255)..string.char(B255) --works thanks to zwzsg
end 

function gadget:GameFrame(n)
    if n>=5 then
        gadgetHandler:RemoveGadget()
    end
end

-----------------------------
end -- end unsynced section
-----------------------------
