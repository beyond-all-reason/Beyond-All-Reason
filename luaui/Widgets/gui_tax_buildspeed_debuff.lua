local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Buildspeed Debuff Bar",
		desc = "Shows a pulsating icon above builder units debuffed after being transferred to an ally  in easytax modoption.",
		author = "RebelNode",
		date = "2026",
		license = "GNU GPL v2",
		layer = -1,
		enabled = true,
	}
end

if not Spring.GetModOptions().easytax then
	return false
end

local debuffedUnits = {} -- unitID -> { startFrame, expireFrame, yoffset }

local spGetGameFrame = Spring.GetGameFrame
local glDrawFuncAtUnit = gl.DrawFuncAtUnit
local glTranslate = gl.Translate
local glBillboard = gl.Billboard
local glColor = gl.Color
local glTexRect = gl.TexRect
local glTexture = gl.Texture
local mathSin = math.sin
local mathPi = math.pi
local mathCeil = math.ceil
local mathMax = math.max
local mathMin = math.min

local ICON_SIZE = 16 -- world units half-width
local ICON_TEX = "luaui/images/easytax/share.dds"
local font

local unitYOffset = {}
for udid, unitDef in pairs(UnitDefs) do
	unitYOffset[udid] = unitDef.height + 14
end

local function drawIcon(yoffset, secsLeft)
	glTranslate(0, yoffset, 10)
	glBillboard()

	-- Pulsate between 0.5 and 1.0 alpha every 2 seconds
	local alpha = 0.75 + 0.25 * mathSin(os.clock() * mathPi)

	glColor(1, 1, 1, alpha)
	glTexture(ICON_TEX)
	glTexRect(-ICON_SIZE, -ICON_SIZE, ICON_SIZE, ICON_SIZE)
	glTexture(false)

	if font then
		glColor(1, 1, 1, 1)
		font:Begin()
		font:Print(tostring(secsLeft) .. " s", 0, -3, 10, "co")
		font:End()
	end
end

function widget:DrawWorld()
	if next(debuffedUnits) == nil then
		return
	end
	if Spring.IsGUIHidden() then
		return
	end
	local gf = spGetGameFrame()
	gl.DepthTest(false)

	for unitID, data in pairs(debuffedUnits) do
		local secsLeft = mathCeil((data.expireFrame - gf) / 30)
		glDrawFuncAtUnit(unitID, false, drawIcon, data.yoffset, secsLeft)
	end

	glColor(1, 1, 1, 1)
	gl.DepthTest(true)
end

local function onUnitBuildspeedDebuff(unitID, startFrame, expireFrame)
	local unitDefID = Spring.GetUnitDefID(unitID)
	debuffedUnits[unitID] = {
		startFrame = startFrame,
		expireFrame = expireFrame,
		yoffset = unitYOffset[unitDefID] or 20,
	}
end

local function onUnitBuildspeedDebuffEnd(unitID)
	debuffedUnits[unitID] = nil
end

function widget:UnitDestroyed(unitID)
	debuffedUnits[unitID] = nil
end

function widget:ViewResize()
	font = WG["fonts"].getFont(nil, 1.2, 0.2, 20)
end

function widget:Initialize()
	widget:ViewResize()
	widgetHandler:RegisterGlobal("UnitBuildspeedDebuffHealthbars", onUnitBuildspeedDebuff)
	widgetHandler:RegisterGlobal("UnitBuildspeedDebuffEndHealthbars", onUnitBuildspeedDebuffEnd)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("UnitBuildspeedDebuffHealthbars")
	widgetHandler:DeregisterGlobal("UnitBuildspeedDebuffEndHealthbars")
end
