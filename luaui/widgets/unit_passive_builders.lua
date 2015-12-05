function widget:GetInfo()
    return {
        name      = "Passive builders v5",
        desc      = "Allows to set builders (nanos, labs and cons) on passive mode",
        author    = "[teh]decay",
        date      = "20 aug 2015",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        version   = 5,
        enabled   = true  -- loaded by default
    }
end

-- project page on github: https://github.com/SpringWidgets/passive-builders

-- Changelog:
-- v2 [teh]decay Fixed bug with rezz bots and spys
-- v3 [teh]decay exclude Commando from "passive" builders
-- v4 [teh]decay add ability to select which builders to put on passive mode: nanos, cons, labs
-- v5 [teh]Flow restyled + relative position + bugfix

-- some code was used from "Wind Speed" widget. Thx to Jazcash and Floris!

local bgcorner = ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"

local CMD_PASSIVE       	= 34571
local spGetMyTeamID     	= Spring.GetMyTeamID
local spGetTeamUnits    	= Spring.GetTeamUnits
local spGetUnitDefID    	= Spring.GetUnitDefID
local spGiveOrderToUnit 	= Spring.GiveOrderToUnit
local spGetMyPlayerID		= Spring.GetMyPlayerID
local spGetPlayerInfo		= Spring.GetPlayerInfo
local spGetSpectatingState	= Spring.GetSpectatingState

local glTexRect				= gl.TexRect
local glText				= gl.Text
local glTexture				= gl.Texture
local glColor				= gl.Color
local glPushMatrix			= gl.PushMatrix
local glPopMatrix			= gl.PopMatrix
local glTranslate			= gl.Translate

local coreCommando = UnitDefNames["commando"]

local passiveLabs = false;
local passiveNanos = true;
local passiveCons = false;

local xRelPos, yRelPos		= 0.7, 0.7	-- (only used here for now)
local vsx, vsy				= gl.GetViewSizes()
local xPos, yPos            = xRelPos*vsx, yRelPos*vsy

local panelWidth = 105;
local panelHeight = 95;

local sizeMultiplier = 1
local IsSpec = spGetSpectatingState()

local function isBuilder(ud)
    if not passiveCons and not passiveLabs and not passiveNanos then
        return false
    end

    --nano
    if ud and ud.isBuilder and not ud.canMove and not ud.isFactory then
        if passiveNanos then
            return true
        else
            return false
        end
    end

    --factory
    if ud and ud.isBuilder and ud.isFactory then
        if passiveLabs then
            return true
        else
            return false
        end
    end

    --cons
    if ud and ud.isBuilder and not ud.canManualFire and ud.canAssist
            and ud.id ~= coreCommando.id and not ud.isFactory and ud.canMove then
        if passiveCons then
            return true
        else
            return false
        end
    end

    return false
end

local function passivateBuilder(unitID)
    spGiveOrderToUnit(unitID, CMD_PASSIVE, {1}, {})
end

local function activateBuilder(unitID)
    spGiveOrderToUnit(unitID, CMD_PASSIVE, {0}, {})
end

function widget:DrawScreen()
    -- do not delete this method or "widget:TweakDrawScreen()" will not be called
    
    if (WG['guishader_api'] ~= nil) then
        WG['guishader_api'].RemoveRect('passivebuilders')
    end
end


function widget:TweakDrawScreen()
	if not IsSpec then
		glColor(0, 0, 0, 0.6)
		RectRound(xPos, yPos, xPos + (panelWidth*sizeMultiplier), yPos + (panelHeight*sizeMultiplier), 8*sizeMultiplier)
		glColor(1, 1, 1, 1)
		glText("Passive mode", xPos + (10*sizeMultiplier), yPos + (76*sizeMultiplier), 13*sizeMultiplier, "n")
		glColor(1, 1, 1, 0.2)
		drawCheckbox(xPos + (12*sizeMultiplier), yPos + (10*sizeMultiplier), passiveCons,  "cons")
		drawCheckbox(xPos + (12*sizeMultiplier), yPos + (30*sizeMultiplier), passiveNanos, "nanos")
		drawCheckbox(xPos + (12*sizeMultiplier), yPos + (50*sizeMultiplier), passiveLabs,  "labs")
		processGuishader()
	end
end


local function DrawRectRound(px,py,sx,sy,cs)
	gl.TexCoord(0.8,0.8)
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)
	
	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)
	
	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)
	
	local offset = 0.07		-- texture offset, because else gaps could show
	local o = offset
	-- top left
	--if py <= 0 or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, py+cs, 0)
	-- top right
	--if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom left
	--if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, sy-cs, 0)
	-- bottom right
	--if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, sy-cs, 0)
end


function RectRound(px,py,sx,sy,cs)
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
	gl.Texture(false)
end

function drawCheckbox(x, y, state, text)
    glPushMatrix()
    glTranslate(x, y, 0)
    glColor(1, 1, 1, 0.2)
    RectRound(0, 0, 16*sizeMultiplier, 16*sizeMultiplier, 3*sizeMultiplier)
    glColor(1, 1, 1, 1)
    if state then
        glTexture('LuaUI/Images/tick.png')
        glTexRect(0, 0, 16*sizeMultiplier, 16*sizeMultiplier)
        glTexture(false)
    end
    glText(text, 23*sizeMultiplier, 4*sizeMultiplier, 12*sizeMultiplier, "n")
    glPopMatrix()
end

function widget:IsAbove(mx, my)
    return widgetHandler:InTweakMode() and mx > xPos and my > yPos and mx < xPos + (panelWidth*sizeMultiplier) and my < yPos + (panelHeight*sizeMultiplier)
end

function widget:TweakMousePress(mx, my, mb)
	if not IsSpec then
		if mb == 2 and widget:IsAbove(mx,my) then
			return true
		end

		if mb == 1 then
			if mb == 1 then
				if mx > xPos + (12*sizeMultiplier) and my > yPos + (10*sizeMultiplier) and mx < (xPos + ((panelWidth-12)*sizeMultiplier)) and my < (yPos + ((10 + 16)*sizeMultiplier)) then
					passiveCons = not passiveCons
					refreshUints()
				elseif mx > xPos + (12*sizeMultiplier) and my > yPos + (30*sizeMultiplier) and mx < (xPos + ((panelWidth-12)*sizeMultiplier)) and my < (yPos + ((30 + 16)*sizeMultiplier)) then
					passiveNanos = not passiveNanos
					refreshUints()
				elseif mx > xPos + (12*sizeMultiplier) and my > yPos + (50*sizeMultiplier) and mx < (xPos + ((panelWidth-12)*sizeMultiplier)) and my < (yPos + ((50 + 16)*sizeMultiplier)) then
					passiveLabs = not passiveLabs
					refreshUints()
				end
			end
		end
	end
end

function widget:TweakMouseMove(mx, my, dx, dy)
	if not IsSpec then
		if xPos + dx >= -1 and xPos + (panelWidth*sizeMultiplier) + dx - 1 <= vsx then
			xRelPos = xRelPos + dx/vsx
		end
		if yPos + dy >= -1 and yPos + (panelHeight*sizeMultiplier) + dy - 1<= vsy then 
			yRelPos = yRelPos + dy/vsy
		end
		xPos, yPos = xRelPos * vsx,yRelPos * vsy
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
    if (unitTeam ~= spGetMyTeamID()) then
        return
    end

    if (isBuilder(UnitDefs[unitDefID])) then
        passivateBuilder(unitID)
    end
end


function widget:UnitGiven(unitID, unitDefID, unitTeam)
    widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
    widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:GetConfigData()
    return {
        passiveLabs = passiveLabs,
        passiveNanos = passiveNanos,
        passiveCons = passiveCons,
        xRelPos = xRelPos, yRelPos = yRelPos
    }
end

function widget:SetConfigData(data)
    if data.passiveLabs ~= nil then
        passiveLabs = data.passiveLabs
    else
        passiveLabs = false
    end

    if data.passiveNanos ~= nil then
        passiveNanos = data.passiveNanos
    else
        passiveNanos = true
    end

    if data.passiveCons ~= nil then
        passiveCons = data.passiveCons
    else
        passiveCons = false
    end

    if data.xRelPos ~= nil then
		xRelPos = data.xRelPos or xRelPos
		yRelPos = data.yRelPos or yRelPos
		xPos = xRelPos * vsx
		yPos = yRelPos * vsy
    end

    refreshUints()
end

function refreshUints()
    local _, _, spec, _ = spGetPlayerInfo(spGetMyPlayerID())
    if spec then
        return
    end

    local myUnits = spGetTeamUnits(spGetMyTeamID())
    for _, unitID in ipairs(myUnits) do
        local unitDefID = spGetUnitDefID(unitID)
        local ud = UnitDefs[unitDefID];

        -- re-activate all builders
        if ud and ud.isBuilder and not ud.canManualFire and ud.canAssist and ud.id ~= coreCommando.id then
            activateBuilder(unitID)
        end

        -- passivate only required builders
        if (isBuilder(ud)) then
            passivateBuilder(unitID)
        end
    end
end

  
function widget:ViewResize(viewSizeX, viewSizeY)
	vsx, vsy = viewSizeX, viewSizeY
	xPos, yPos = xRelPos*vsx, yRelPos*vsy
	sizeMultiplier = 0.55 + (vsx*vsy / 8000000)
end

function widget:PlayerChanged(playerID)
	IsSpec = GetSpectatingState()
end

function processGuishader()
    if (WG['guishader_api'] ~= nil) then
        WG['guishader_api'].InsertRect(xPos, yPos, xPos + (panelWidth*sizeMultiplier), yPos + (panelHeight*sizeMultiplier), 'passivebuilders')
    end
end

function widget:Shutdown()
    if (WG['guishader_api'] ~= nil) then
        WG['guishader_api'].RemoveRect('passivebuilders')
    end
end

