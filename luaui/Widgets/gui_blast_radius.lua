include("keysym.h.lua")

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Blast Radius",
		desc = "Displays blast radius while placing buildings (META)\nand of selected units (META+X)",
		author = "very_bad_soldier",
		date = "April 7, 2009",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

--These can be modified if needed
local blastCircleDivs = 96
local blastLineWidth = 1.0
local blastAlphaValue = 0.5

--------------------------------------------------------------------------------
local blastColor = { 1.0, 0.0, 0.0 }
local expBlastAlphaValue = 1.0
local expBlastColor = { 1.0, 0.0, 0.0 }
local explodeTag = "deathExplosion"
local selfdTag = "selfDExplosion"
local aoeTag = "damageAreaOfEffect"

local lastColorChangeTime = 0.0
local selfdCycleDir = false
local selfdCycleTime = 0.3
local expCycleTime = 0.5

-------------------------------------------------------------------------------

local udefTab = UnitDefs
local weapNamTab = WeaponDefNames
local weapTab = WeaponDefs

local spGetKeyState = Spring.GetKeyState
local spGetModKeyState = Spring.GetModKeyState
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetGameSeconds = Spring.GetGameSeconds
local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spEcho = Spring.Echo

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glDepthTest = gl.DepthTest
local glTexture = gl.Texture
local glDrawGroundCircle = gl.DrawGroundCircle
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glBillboard = gl.Billboard

local sqrt = math.sqrt
local lower = string.lower

local spIsSphereInView = Spring.IsSphereInView
local spGetGroundHeight = Spring.GetGroundHeight

local font, chobbyInterface

-- Pre-cached blast data per unitDefID (computed once, static)
local blastDataCache = {}
for udid, udef in pairs(udefTab) do
	local explodeName = udef[explodeTag] and lower(udef[explodeTag])
	local selfdName = udef[selfdTag] and lower(udef[selfdTag])
	local explodeWep = explodeName and weapNamTab[explodeName]
	local selfdWep = selfdName and weapNamTab[selfdName]
	if explodeWep and selfdWep then
		local eRadius = weapTab[explodeWep.id][aoeTag]
		local sRadius = weapTab[selfdWep.id][aoeTag]
		local sameRadius = (eRadius == sRadius)
		blastDataCache[udid] = {
			explodeRadius = eRadius,
			selfdRadius = sRadius,
			selfdFontSize = sqrt(sRadius),
			explodeFontSize = sqrt(eRadius),
			sameRadius = sameRadius,
			hasBoth = true,
			label = sameRadius and (weapTab[selfdWep.id].damages[0] .. " / " .. weapTab[explodeWep.id].damages[0]) or "SELF-D",
		}
	elseif explodeWep then
		blastDataCache[udid] = {
			explodeRadius = weapTab[explodeWep.id][aoeTag],
		}
	end
end

-----------------------------------------------------------------------------------

function widget:Initialize()
	widget:ViewResize()
end

function widget:ViewResize()
	font = WG.fonts.getFont(1, 1.5)
end

local selectedUnits = Spring.GetSelectedUnits()
function widget:SelectionChanged(sel)
	selectedUnits = sel
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == "LobbyOverlayActive" then
		chobbyInterface = (msg:sub(1, 19) == "LobbyOverlayActive1")
	end
end

function widget:DrawWorld()
	if chobbyInterface then
		return
	end
	DrawBuildMenuBlastRange()

	if #selectedUnits > 0 then
		local keyPressed = spGetKeyState(KEYSYMS.X)
		local _, _, meta = spGetModKeyState()
		if meta and keyPressed then
			DrawBlastRadiusSelectedUnits()
		end
	end

	ResetGl()
end

function ChangeBlastColor()
	--cycle red/yellow
	local time = spGetGameSeconds()
	local timediff = (time - lastColorChangeTime)

	local addValueSelf = timediff / selfdCycleTime
	local addValueExp = timediff / expCycleTime

	if blastColor[2] >= 1.0 then
		selfdCycleDir = false
	elseif blastColor[2] <= 0.0 then
		selfdCycleDir = true
	end

	local expCycleDir
	if expBlastColor[2] >= 1.0 then
		expCycleDir = false
	elseif expBlastColor[2] <= 0.0 then
		expCycleDir = true
	end

	if not selfdCycleDir then
		blastColor[2] = blastColor[2] - addValueSelf
		if blastColor[2] < 0 then
			blastColor[2] = 0
		end
	else
		blastColor[2] = blastColor[2] + addValueSelf
		if blastColor[2] > 1 then
			blastColor[2] = 1
		end
	end

	if not expCycleDir then
		expBlastColor[2] = expBlastColor[2] - addValueExp
		if expBlastColor[2] < 0 then
			expBlastColor[2] = 0
		end
	else
		expBlastColor[2] = expBlastColor[2] + addValueExp
		if expBlastColor[2] > 1 then
			expBlastColor[2] = 1
		end
	end

	lastColorChangeTime = time
end

function DrawBuildMenuBlastRange()
	local _, cmd_id, cmd_type = spGetActiveCommand()
	if not cmd_id or cmd_type ~= 20 then
		return
	end

	local _, _, meta = spGetModKeyState()
	if not meta then
		return
	end

	local unitDefID = -cmd_id
	local data = blastDataCache[unitDefID]
	if not data or not data.explodeRadius then
		return
	end

	local mx, my = spGetMouseState()
	local _, coords = spTraceScreenRay(mx, my, true, true)
	if not coords then
		return
	end

	local centerX, _, centerZ = Spring.Pos2BuildPos(unitDefID, coords[1], 0, coords[3])

	glLineWidth(blastLineWidth)
	glColor(expBlastColor[1], expBlastColor[2], expBlastColor[3], blastAlphaValue)
	glDrawGroundCircle(centerX, 0, centerZ, data.explodeRadius, blastCircleDivs)
	glLineWidth(1)
	glColor(1, 1, 1, 1)

	ChangeBlastColor()
end

function DrawUnitBlastRadius(unitID, data)
	local x, y, z = spGetUnitPosition(unitID)
	if not x then
		return
	end

	local maxRadius = data.selfdRadius > data.explodeRadius and data.selfdRadius or data.explodeRadius
	if not spIsSphereInView(x, y, z, maxRadius) then
		return
	end

	local height = spGetGroundHeight(x, z)

	glColor(blastColor[1], blastColor[2], blastColor[3], blastAlphaValue)
	glDrawGroundCircle(x, y, z, data.selfdRadius, blastCircleDivs)

	glPushMatrix()
	glTranslate(x - (data.selfdRadius / 1.5), height, z + (data.selfdRadius / 1.5))
	glBillboard()

	font:Begin()
	font:Print(data.label, 0.0, 0.0, data.selfdFontSize, "")
	glPopMatrix()

	if not data.sameRadius then
		glColor(expBlastColor[1], expBlastColor[2], expBlastColor[3], expBlastAlphaValue)
		glDrawGroundCircle(x, y, z, data.explodeRadius, blastCircleDivs)

		glPushMatrix()
		glTranslate(x - (data.explodeRadius / 1.6), height, z + (data.explodeRadius / 1.6))
		glBillboard()
		font:Print("EXPLODE", 0.0, 0.0, data.explodeFontSize, "cn")
		glPopMatrix()
	end
	font:End()
end

function DrawBlastRadiusSelectedUnits()
	glLineWidth(blastLineWidth)

	for i = 1, #selectedUnits do
		local unitID = selectedUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		local data = unitDefID and blastDataCache[unitDefID]
		if data and data.hasBoth then
			DrawUnitBlastRadius(unitID, data)
		end
	end

	ChangeBlastColor()
end

--Commons
function ResetGl()
	glColor(1.0, 1.0, 1.0, 1.0)
	glLineWidth(1.0)
	glDepthTest(false)
	glTexture(false)
end

function printDebug(value)
	if debug then
		if type(value) == "boolean" then
			if value == true then
				spEcho("true")
			else
				spEcho("false")
			end
		elseif type(value) == "table" then
			spEcho("Dumping table:")
			for key, val in pairs(value) do
				spEcho(key, val)
			end
		else
			spEcho(value)
		end
	end
end
