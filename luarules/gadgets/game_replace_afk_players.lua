function gadget:GetInfo()
  return {
    name      = "Substitution",
    desc      = "Allows players absent at gamestart to be replaced by specs\nPrevents joinas to non-empty teams",
    author    = "Bluestone",
    date      = "June 2014",
    license   = "GNU GPL, v3 or later",
    layer     = 2, --run after game initial spawn and mo_coop (because we use readyStates)
    enabled   = true  
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-----------------------------
if gadgetHandler:IsSyncedCode() then 
-----------------------------

-- TS difference required for substitutions 
-- idealDiff is used if possible, validDiff as fall-back, otherwise no
local validDiff = 4 
local idealDiff = 2

local substitutes = {}
local players = {}
local absent = {}
local replaced = false
local gameStarted = false

local gaiaTeamID = Spring.GetGaiaTeamID()
local SpGetPlayerList = Spring.GetPlayerList
local SpIsCheatingEnabled = Spring.IsCheatingEnabled

function gadget:RecvLuaMsg(msg, playerID)
    local checkChange = (msg=='\144' or msg=='\145')

	if msg=='\145' then
        substitutes[playerID] = nil
        --Spring.Echo("received removal", playerID)
    end
    if msg=='\144' then
        -- do the same eligibility check as in unsynced
        local customtable = select(10,Spring.GetPlayerInfo(playerID))
        local tsMu = customtable.skill 
        local tsSigma = customtable.skilluncertainty
        ts = tsMu and tonumber(tsMu:match("%d+%.?%d*"))
        tsSigma = tonumber(tsSigma)
        local eligible = tsMu and tsSigma and (tsSigma<=2) and (not string.find(tsMu, ")")) and (not players[playerID]) 
        if eligible then
            substitutes[playerID] = ts
        end
        --Spring.Echo("received", playerID, eligible, ts)
    end

    if checkChange then
        --Spring.Echo("FindSubs", "RecvLuaMsg")
        FindSubs(false)
    end
end

function gadget:AllowStartPosition(x,y,z,playerID,readyState)
    FindSubs(false)
    return true
end


function gadget:Initialize()
    -- record a list of which playersIDs are players on which teamID
    local teamList = Spring.GetTeamList()
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

function FindSubs(real)
    --Spring.Echo("FindSubs", "real=", real)
    
    -- make a copy of the substitutes table
    local substitutesLocal = {}
    local i = 0
    for pID,ts in pairs(substitutes) do
        substitutesLocal[pID] = ts
        i = i + 1
    end
    absent = {}
    
    --local theSubs = ""
    --for k,v in pairs(substitutesLocal) do theSubs = theSubs .. tostring(k) .. "[" .. v .. "]" .. "," end
    --Spring.Echo("#subs: " .. i , theSubs)
    
    -- make a list of absent players (only ones with valid ts)
    for playerID,_ in pairs(players) do
        local _,active,spec = Spring.GetPlayerInfo(playerID)
        local readyState = Spring.GetGameRulesParam("player_" .. playerID .. "_readyState")
        local noStartPoint = (readyState==3) or (readyState==0)
        local present = active and (not spec) and (not noStartPoint)
        if not present then
            local customtable = select(10,Spring.GetPlayerInfo(playerID)) -- player custom table
            local tsMu = customtable.skill
            ts = tsMu and tonumber(tsMu:match("%d+%.?%d*")) 
            if ts then
                absent[playerID] = ts
                --Spring.Echo("absent:", playerID, ts)
            end
        end
        -- if present, tell LuaUI that won't be substituted
        if not absent[playerID] then
            Spring.SetGameRulesParam("Player" .. playerID .. "willSub", 0)
        end
    end
    --Spring.Echo("#absent: " .. #absent)
    
    -- for each one, try and find a suitable replacement & substitute if so
    for playerID,ts in pairs(absent) do
        -- construct a table of who is ideal/valid 
        local idealSubs = {}
        local validSubs = {}
        for subID,subts in pairs(substitutesLocal) do
            local _,active,spec = Spring.GetPlayerInfo(subID)
            if active and spec then
                if  math.abs(ts-subts)<=validDiff then 
                    validSubs[#validSubs+1] = subID
                end
				if math.abs(ts-subts)<=idealDiff then
                    idealSubs[#idealSubs+1] = subID 
                end
            end
        end
        --Spring.Echo("ideal: " .. #idealSubs .. " for pID " .. playerID)
        --Spring.Echo("valid: " .. #validSubs .. " for pID " .. playerID)

        local willSub = false --are we going to substitute anyone (for real)
        if #validSubs>0 then
            -- choose who
            local sID
            if #idealSubs>0 then
                sID = (#idealSubs>1) and idealSubs[math.random(1,#idealSubs)] or idealSubs[1]
                --Spring.Echo("picked ideal sub", sID)
            else
                sID = (#validSubs>1) and validSubs[math.random(1,#validSubs)] or validSubs[1]
                --Spring.Echo("picked valid sub", sID)
            end
            
            --Spring.Echo("real", real)
            if real then
                -- do the replacement 
                local teamID = players[playerID]
                Spring.AssignPlayerToTeam(sID, teamID)
                players[sID] = teamID
                replaced = true
                
                local incoming,_ = Spring.GetPlayerInfo(sID)
                local outgoing,_ = Spring.GetPlayerInfo(playerID)            
                Spring.Echo("Player " .. incoming .. " was substituted in for " .. outgoing)
            end
            substitutesLocal[sID] = nil
            willSub = true

            -- tell luaui that we would substitute if the game started now
            --Spring.Echo("wouldSub: " .. (sID or "-1") .. " for pID " .. playerID)
            Spring.SetGameRulesParam("Player" .. playerID .. "willSub", willSub and 1 or 0)
        end

    end

end

function gadget:GameStart()
    gameStarted = true
    FindSubs(true)
end

function gadget:GameFrame(n)
    if n==1 and replaced then
        -- if at least one player was replaced, reveal startpoints to all       
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
                    local pName,active,spec = Spring.GetPlayerInfo(pID) 
                    if pName and absent[pID]==nil and active and not spec then --AIs might not have a name, don't write the name of the dropped player
                        name = name .. pName .. ", "
                        revealed[pID] = true
                    end
                end
            end
            if name ~= "" then
                name = string.sub(name, 1, math.max(string.len(name)-2,1)) --remove final ", "
            end
            SendToUnsynced("MarkStartPoint", p[1], p[2], p[3], name, tID)
        end
    end
    
    if n%5==0 then
        CheckJoined() -- there is no PlayerChanged or PlayerAdded in synced code
    end
end


--------------------------- 

function CheckJoined()
    local pList = SpGetPlayerList(true)
    local cheatsOn = SpIsCheatingEnabled() 
    if cheatsOn then return end
    
    for _,pID in ipairs(pList) do
        if not players[pID] then
            local _,active,spec,_,aID = Spring.GetPlayerInfo(pID)
            if active and not spec then 
                --Spring.Echo("handle join", pID, active, spec)
                HandleJoinedPlayer(pID,aID)
            end
        end
    end
end

function HandleJoinedPlayer(jID, aID)
    -- see if we can find a missing player to sub in for within the joined ally team, force spec if not
    local playerList = Spring.GetPlayerList()
    for _,pID in ipairs(playerList) do
        local _,active,spec,teamID,allyTeamID = Spring.GetPlayerInfo(pID)
        if aID==allyTeamID and jID~=pID and (not active or spec) and gameStarted then
            Spring.AssignPlayerToTeam(jID, teamID) 
            --Spring.Echo("allow joinas", jID, tID)
            players[jID] = teamID
            return
        end
    end
    --Spring.Echo("deny joinas", jID)
    SendToUnsynced("ForceSpec", jID)
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
    if (tonumber(Spring.GetModOptions().mo_noowner) or 0) == 1 then
        gadgetHandler:RemoveGadget() -- don't run in FFA mode
        return 
    end

    gadgetHandler:AddSyncAction("MarkStartPoint", MarkStartPoint)
    gadgetHandler:AddSyncAction("ForceSpec", ForceSpec)
    
    -- match the equivalent check in synced
    local customtable = select(10,Spring.GetPlayerInfo(myPlayerID)) 
    local tsMu = "30"--customtable.skill 
	local tsSigma = "0"--customtable.skilluncertainty
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
    else
        gadgetHandler:RemoveCallIn("DrawScreen") -- no need to waste cycles
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
            return true
        else
            Spring.SendLuaRulesMsg('\145')
            Spring.Echo("Your offer to substitute has been withdrawn")
            offer = false
            bW = 140
            MakeButton()
            return true
        end
	end
    return false
end

function gadget:MouseRelease(x,y)
end

function gadget:GameStart()
    eligible = false -- no substitutions after game start
end


local revealed = false
function MarkStartPoint(_,x,y,z,name,tID)
    local _,_,spec = Spring.GetPlayerInfo(myPlayerID)
    if not spec then
        Spring.MarkerAddPoint(x, y, z, colourNames(tID) .. name, true)
        revealed = true
    end
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
    if n~=5 then return end
    
    if revealed then    
        Spring.Echo("Substitution occurred, revealed start positions to all")
    end
  
    gadgetHandler:RemoveCallIn("GameFrame")
end

function ForceSpec(_,pID)
    local myID = Spring.GetMyPlayerID()
    if pID==myID then
        Spring.SendCommands("spectator")
    end
end

function gadget:ShutDown()
    gadgetHandler:RemoveSyncAction("MarkStartPoint")
    gadgetHandler:RemoveSyncAction("ForceSpec")
end

-----------------------------
end -- end unsynced section
-----------------------------
