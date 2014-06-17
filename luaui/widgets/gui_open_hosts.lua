
if not (Spring.GetConfigInt("LuaSocketEnabled", 0) == 1) then
	Spring.Echo("Lua Socket is disabled, Open Host List cannot run")
	return false
end

function widget:GetInfo()
return {
	name    = "Open Host List",
	desc    = "Shows a list of open hosts",
	author  = "Bluestone, dansan, abma, BrainDamage",
	date    = "June 2014",
	license = "GNU GPL, v2 or later",
	layer   = -5,
	enabled = true,
}
end


---------------------------------------------------------
------------- Get the data from the socket and process it into the battleList
---------------------------------------------------------

local socket = socket

local client
local set
local headersent

local host = "replays.springrts.com"
local port = 8222

local battleList = {}
local updateTime = 10
local prevTimer = Spring.GetTimer()
local needUpdate = true


local myPlayerID = Spring.GetMyPlayerID()
local amISpec = Spring.GetSpectatingState()

local function dumpConfig()
	-- dump all luasocket related config settings to console
	for _, conf in ipairs({"TCPAllowConnect", "TCPAllowListen", "UDPAllowConnect", "UDPAllowListen"  }) do
		Spring.Echo(conf .. " = " .. Spring.GetConfigString(conf, ""))
	end

end

-- split a string at the next line break, or return nil if there is no such line break
local function getLine(str)
    if not str then return nil,nil end
    local breakPos = string.find(str,'\n')
    if not breakPos then 
        return nil,nil
    else
        local line = string.sub(str,1,breakPos-2) .. ',' --remove the (two!?) end of line chars, add a final comma since it makes parsing the line easier 
        local data = string.sub(str,breakPos+1,string.len(str))
        return line,data
    end
end

-- turn the string "XX",YY into the pair of strings XX,YY
local function extract(str) 
    if not str then return nil,nil end
    local breakPos = string.find(str,',')
    if not breakPos then
        return nil,nil
    else
        local e = string.sub(str,2,breakPos-2)
        local line = string.sub(str,breakPos+1,string.len(str)) 
        return e,line
    end
end

-- i hate lua
function toboolean(v)
    return (type(v) == "string" and (v == "true" or v == "True")) or (type(v) == "number" and v ~= 0) or (type(v) == "boolean" and v)
end



-- something to do with sockets...
local function newset()
    local reverse = {}
    local set = {}
    return setmetatable(set, {__index = {
        insert = function(set, value)
            if not reverse[value] then
                table.insert(set, value)
                reverse[value] = table.getn(set)
            end
        end,
        remove = function(set, value)
            local index = reverse[value]
            if index then
                reverse[value] = nil
                local top = table.remove(set)
                if top ~= value then
                    reverse[top] = index
                    set[index] = top
                end
            end
        end
    }})
end

-- initiates a connection to host:port, returns true on success
local function SocketConnect(host, port)
	client=socket.tcp()
	client:settimeout(0)
	res, err = client:connect(host, port)
	if not res and not res=="timeout" then
		Spring.Echo("OpenHostList: Error in connect to " .. host .. ": " .. err)
        widgetHandler:RemoveWidget() 
		return false
	end
	set = newset()
	set:insert(client)
	return true
end

function widget:Initialize()
	--dumpConfig() //use for debugging
	--Spring.Echo(socket.dns.toip("localhost"))
	--FIXME dns-request seems to block
	SocketConnect(host, port)
end

function widget:Shutdown()
    DeleteLists()
end

-- called when data was received through socket
local function SocketDataReceived(sock, data)
    -- load data into battleList
	--Spring.Echo("data!")
    --Spring.Echo(data)
    local line
    battleList = {}
    while data do
        local battle  = {}
        line,data = getLine(data)
        -- Spring.Echo(line)
        if line and not (string.find(line,"START") or string.find(line,"END") or string.find(line,"battleID")) then --ignore the three 'padding' lines
            --extract battle info from line            
            battle.ID, line         = extract(line) 
            battle.founder, line    = extract(line)
            battle.passworded, line = extract(line)
            battle.rankLimit, line  = extract(line)
            battle.engineVer, line  = extract(line)
            battle.map, line        = extract(line)
            battle.title, line      = extract(line)
            battle.gameName, line   = extract(line)
            battle.locked, line     = extract(line)
            battle.specCount, line  = extract(line)
            battle.playerCount, line= extract(line)
            battle.isInGame, line   = extract(line) -- line should now be nil
            
            -- i hate lua
            battle.ID           = tonumber(battle.ID)
            battle.passworded   = toboolean(battle.passworded)
            battle.rankLimit    = tonumber(battle.rankLimit) or 0
            battle.locked       = toboolean(battle.locked)
            battle.specCount    = tonumber(battle.specCount) or 0
            battle.playerCount  = tonumber(battle.playerCount) or 0
            battle.isInGame     = toboolean(battle.isInGame)
            
            -- add battle to list
            battleList[#battleList+1] = battle
        end    
    end
    
    --Spring.Echo(#battleList)
    CreateBattleList()
end

-- called when a socket is open and we want to send something to it
local function SocketSendRequest(sock)
    --Spring.Echo("Sending to socket")
    sock:send("ALL MOD balanc\r\n\r\n") --see http://imolarpg.dyndns.org/trac/balatest/ticket/562 for what info can be requested
end

-- called when a connection is closed
local function SocketClosed(sock)
    --Spring.Echo("Closed Socket")
end

function widget:Update()
    amISpec = Spring.GetSpectatingState()
    if not amISpec then return end

	if set==nil or #set<=0 then
		return -- no sockets?
	end
    
    -- update every 10 seconds, and once at the start
    local timer = Spring.GetTimer()
    local diffSecs = Spring.DiffTimers(timer,prevTimer)
    if diffSecs < updateTime and not needUpdate then 
        return
    end
    prevTimer = timer
            
	-- update socket state
	local readable, writeable, err = socket.select(set, set, 0)
    --Spring.Echo(#readable, #writeable)
	
    -- check for error
    if err~=nil then
		-- some error happened in select
		if err=="timeout" then
			-- nothing to do, return
            Spring.Echo("Socket timed out")
			return
		end
		Spring.Echo("Error in socket.select: " .. error)
	end
    
    -- see if we received anything back
	for _, input in ipairs(readable) do
		local s, status, partial = input:receive('*a') --try to read all data
		if status == "timeout" or status == nil then
            --Spring.Echo("Socket data:")
			SocketDataReceived(input, s or partial)
            if needUpdate then
                needUpdate = false
            end
		elseif status == "closed" then
            --Spring.Echo("Socket closed")
			SocketClosed(input)
			input:close()
			set:remove(input)
        else
        --Spring.Echo(s, status, partial)
		end
	end
    
    -- ask for an update
    for __, output in ipairs(writeable) do
       -- socket is writeable
       SocketSendRequest(output)
    end

end

---------------------------------------------------------
------------- Draw on screen
---------------------------------------------------------

local spIsGUIHidden = Spring.IsGUIHidden

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glPolygonMode = gl.PolygonMode
local glRect = gl.Rect
local glText = gl.Text
local glShape = gl.Shape

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale

local GL_FILL = GL.FILL
local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_LINE_STRIP = GL.LINE_STRIP

local vsx, vsy = Spring.GetViewGeometry()
function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()
end

local textSize = 0.75
local textMargin = 0.125
local lineWidth = 0.0625

local posX = 0.3
local posY = 0

local buttonGL
local battlesGL
local show = false -- show the battles?

local function DrawL()
	local vertices = {
		{v = {0, 1, 0}},
		{v = {0, 0, 0}},
		{v = {1, 0, 0}},
	}
	glShape(GL_LINE_STRIP, vertices)
end

function DrawButton()
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
    glColor(0, 0, 0, 0.2)
    glRect(0, 0, 8, 1)
    DrawL()
    glText("Open Battles", textMargin, textMargin, textSize, "no")
end

function BattleType(battle) 
    if battle.passworded or (battle.locked and false) or battle.rankLimit>0 or battle.playerCount==0 then return nil end
    if battle.playerCount==0 then return nil end
    
    local founder = battle.founder
    if founder=="BlackHoleHost1" or founder=="BlackHoleHost2" or founder=="BlackHoleHost6" or founder=="[ACE]Ortie" or founder=="[ACE]Perge" or founder=="[ACE]Pirine" then
        return "team"
    elseif founder=="BlackHoleHost3" or founder=="[ACE]Sure" then
        return "ffa"
    elseif founder=="BlackHoleHost5" or founder=="[ACE]Censur" or founder=="[ACE]Embleur" then
        return "1v1"
    elseif founder=="[ACE]Sombri" then
        return "chickens" 
    end
    return nil
end

function DrawBattles()
    -- select which battles to display
    local tID_1, tID_2, ffaID, oID, cID  
    for ID,battle in pairs(battleList) do
        --Spring.Echo(battle.founder, BattleType(battle))
        if BattleType(battle)=="team" then
            if tID_1 and battle.playerCount > battleList[tID_1].playerCount then
                tID_2 = tID_1
                tID_1 = ID
            elseif tID_2 and battle.playerCount > battleList[tID_2].playerCount then
                tID_2 = ID
            elseif not tID_1 then
                tID_1 = ID
            elseif not tID_2 then
                tID_2 = ID
            end
        end
        if BattleType(battle)=="ffa" then
            if ffaID and battle.playerCount > battleList[ffaID].playerCount then
                ffaID = ID
            elseif not ffaID then
                ffaID = ID
            end
        end
        if BattleType(battle)=="1v1" then
            if oID and battle.playerCount > battleList[oID].playerCount then
                oID = ID
            elseif not ffaID then
                oID = ID
            end
        end
        if BattleType(battle)=="chickens" then
            if cID and battle.playerCount > battleList[cID].playerCount then
                cID = ID
            elseif not cID then
                cID = ID
            end
        end    
    end
    
    -- prepare battle display
    gl.Color(1,1,1,1)
    local n = 1
    local w = 0
    local ctext, ffatext,otext,t2text,t1text
    if cID then
        local plural_p = ""
        if battleList[cID].playerCount > 1 then plural_p = "s" end
        local plural_s = ""
        if battleList[cID].specCount > 1 then plural_s = "s" end
        local ingame
        if battleList[cID].isInGame then ingame = "\255\255\0\0ingame\255\255\255\255" else ingame = "\255\0\255\0open\255\255\255\255" end
        ctext = "Chickens: " .. battleList[cID].founder .. " (" .. battleList[cID].playerCount .. " player" .. plural_p .. ", " .. battleList[cID].specCount .. " spec" .. plural_s .. ", " .. ingame .. ")"
        w = math.max(w,gl.GetTextWidth(ctext))
        n = n + 1
    end
    if ffaID then
        local plural_p = ""
        if battleList[ffaID].playerCount > 1 then plural_p = "s" end
        local plural_s = ""
        if battleList[ffaID].specCount > 1 then plural_s = "s" end
        local ingame
        if battleList[ffaID].isInGame then ingame = "\255\255\0\0ingame\255\255\255\255" else ingame = "\255\0\255\0open\255\255\255\255" end
        ffatext = "FFA: " .. battleList[ffaID].founder .. " (" .. battleList[ffaID].playerCount .. " player" .. plural_p .. ", " .. battleList[ffaID].specCount .. " spec" .. plural_s .. ", " .. ingame .. ")"
        w = math.max(w,gl.GetTextWidth(ffatext))
        n = n + 1
    end
    if oID then
        local plural_p = ""
        if battleList[oID].playerCount > 1 then plural_p = "s" end
        local plural_s = ""
        if battleList[oID].specCount > 1 then plural_s = "s" end
        local ingame
        if battleList[oID].isInGame then ingame = "\255\255\0\0ingame\255\255\255\255" else ingame = "\255\0\255\0open\255\255\255\255" end
        otext = "1v1: " .. battleList[oID].founder .. " (" .. battleList[oID].playerCount .. " player" .. plural_p .. ", " .. battleList[oID].specCount .. " spec" .. plural_s .. ", " .. ingame .. ")"
        w = math.max(w,gl.GetTextWidth(otext))
        n = n + 1
    end
    if tID_2 then
        local plural_p = ""
        if battleList[tID_2].playerCount > 1 then plural_p = "s" end
        local plural_s = ""
        if battleList[tID_2].specCount > 1 then plural_s = "s" end
        local ingame
        if battleList[tID_2].isInGame then ingame = "\255\255\0\0ingame\255\255\255\255" else ingame = "\255\0\255\0open\255\255\255\255" end
        t2text = "Team: " .. battleList[tID_2].founder .. " (" .. battleList[tID_2].playerCount .. " player" .. plural_p .. ", " .. battleList[tID_2].specCount .. " spec" .. plural_s .. ", " .. ingame .. ")"
        w = math.max(w,gl.GetTextWidth(t2text))
        n = n + 1
    end
    if tID_1 then
        local plural_p = ""
        if battleList[tID_1].playerCount > 1 then plural_p = "s" end
        local plural_s = ""
        if battleList[tID_1].specCount > 1 then plural_s = "s" end
        local ingame
        if battleList[tID_1].isInGame then ingame = "\255\255\0\0ingame\255\255\255\255" else ingame = "\255\0\255\0open\255\255\255\255" end
        t1text = "Team: " .. battleList[tID_1].founder .. " (" .. battleList[tID_1].playerCount .. " player" .. plural_p .. ", " .. battleList[tID_1].specCount .. " spec" .. plural_s .. ", " .. ingame .. ")"
        w = math.max(w,gl.GetTextWidth(t1text))
        n = n + 1
    end    
    w = w * textSize + 0.5

    -- draw box
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
    glColor(0, 0, 0, 0.2)
    glRect(0, 1, w, n)

    -- draw text
    local m = 1.1
    gl.BeginText()
    if ctext then 
        gl.Text(ctext,textMargin,textMargin+m,textSize,"no")
        m = m + 1
    end
    if ffatext then
        gl.Text(ffatext,textMargin,textMargin+m,textSize,"no")
        m = m + 1
    end
    if otext then
        gl.Text(otext,textMargin,textMargin+m,textSize,"no")
        m = m + 1
    end
    if t2text then
        gl.Text(t2text, textMargin,textMargin+m,textSize,"no")
        m = m + 1
    end
    if t1text then
        gl.Text(t1text,textMargin,textMargin+m,textSize,"no")
        m = m + 1
    end
    gl.EndText()

    
    
end

function CreateBattleList()
    if battlesGL then 
        glDeleteList(battlesGL) 
        battlesGL = nil
    end
    battlesGL = glCreateList(DrawBattles)
end

function DeleteLists()
    if buttonGL then
        glDeleteList(buttonGL)
        buttonGL = nil
    end
    if battlesGL then
        glDeleteList(battlesGL)
        battlesGL = nil
    end
end

function widget:DrawScreen()
    if spIsGUIHidden() then return end
    if not buttonGL then
        buttonGL = gl.CreateList(DrawButton)
    end
    
    glLineWidth(lineWidth)

    glPushMatrix()
        glTranslate(posX*vsx, posY*vsy, 0)
        glScale(16, 16, 1)
        glCallList(buttonGL)
        if show then
            if battlesGL then
                glCallList(battlesGL)
            end
        end
    glPopMatrix()

    glColor(1, 1, 1, 1)
    glLineWidth(1)
end

---------------------------------------------------------
------------- Show the battle list?
---------------------------------------------------------

function widget:MousePress(x, y, button)
	if spIsGUIHidden() then return false end
    
	tx = (x - posX*vsx)/16
    ty = (y - posY*vsy)/16
    if tx < 0 or tx > 8 or ty < 0 or ty > 1 then return false end

    -- show/hide battles
    show = not show
    if show then
        needUpdate = true
    end

	return true
end

function widget:GetConfigData(data)
	return {
		posX = posX,
		posY = posY,
        show = show,
	}
end

function widget:SetConfigData(data)
	posX = data.posX or posX
	posY = data.posY or posY
    show = data.show or show
end
