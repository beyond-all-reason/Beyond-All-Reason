local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Commander Hurt Vignette",
		desc = "Shows a red vignette when commander is out of view and gets damaged",
		author = "Floris",
		date = "February 2018",
		license = "GNU GPL, v2 or whatever",
		layer = 111,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetLocalTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spIsUnitVisible = Spring.IsUnitVisible
local glColor = gl.Color
local glCallList = gl.CallList
local osClock = os.clock

---------------------------------------------------------------------------------------------------
--  Declarations
---------------------------------------------------------------------------------------------------

local vignetteTexture = ":n:" .. LUAUI_DIRNAME .. "Images/vignette.dds"

local duration = 1.55
local maxOpacity = 0.55
local minOpacity = 0.01
local fadeSpeed = maxOpacity / duration -- opacity lost per second

local hurtTime = 0 -- os.clock() of the last hit on an unseen commander
local drawing = false -- DrawScreen is only registered while the vignette is visible

local myTeamID = spGetMyTeamID()
local dList

local comUnitDefIDs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef and unitDef.customParams.iscommander then
		comUnitDefIDs[unitDefID] = true
	end
end

--------------------------------------------------------------------------------

local function createList()
	local vsx, vsy = gl.GetViewSizes()
	dList = gl.CreateList(function()
		gl.Texture(vignetteTexture)
		gl.TexRect(-(vsx / 25), -(vsy / 25), vsx + (vsx / 25), vsy + (vsy / 25))
		gl.Texture(false)
	end)
end

local function setDrawing(active)
	if active == drawing then
		return
	end
	drawing = active
	if active then
		widgetHandler:UpdateCallIn("DrawScreen")
	else
		widgetHandler:RemoveCallIn("DrawScreen")
	end
end

function widget:Initialize()
	createList()
	widgetHandler:RemoveCallIn("DrawScreen")
	if Spring.IsReplay() or spGetGameFrame() > 0 then
		widget:PlayerChanged()
	end
end

function widget:PlayerChanged(playerID)
	myTeamID = spGetMyTeamID()
	if spGetSpectatingState() and spGetGameFrame() > 0 then
		widgetHandler:RemoveWidget()
	end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if comUnitDefIDs[unitDefID] and unitTeam == myTeamID and damage > 3 and not spIsUnitVisible(unitID) then
		if spGetSpectatingState() then
			widgetHandler:RemoveWidget()
			return
		end
		hurtTime = osClock()
		setDrawing(true)
	end
end

function widget:ViewResize(newX, newY)
	if dList ~= nil then
		gl.DeleteList(dList)
	end
	createList()
end

function widget:DrawScreen()
	local opacity = maxOpacity - (osClock() - hurtTime) * fadeSpeed
	if opacity > minOpacity then
		glColor(1, 0, 0, opacity)
		glCallList(dList)
		glColor(1, 1, 1, 1)
	else
		setDrawing(false)
	end
end

function widget:Shutdown()
	if dList ~= nil then
		gl.DeleteList(dList)
	end
end
