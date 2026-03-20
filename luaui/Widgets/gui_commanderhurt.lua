local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name      = "Commander Hurt Vignette",
        desc      = "Shows a red vignette when commander is out of view and gets damaged",
        author    = "Floris",
        date      = "February 2018",
        license   = "GNU GPL, v2 or whatever",
        layer     = 111,
        enabled   = true
    }
end


-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID
local spGetSpectatingState = Spring.GetSpectatingState

---------------------------------------------------------------------------------------------------
--  Declarations
---------------------------------------------------------------------------------------------------

local vignetteTexture	= ":n:"..LUAUI_DIRNAME.."Images/vignette.dds"

local duration = 1.55
local maxOpacity = 0.55
local opacity = 0

local myTeamID = spGetMyTeamID()
local dList

local comUnitDefIDs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef and unitDef.customParams.iscommander then
		comUnitDefIDs[unitDefID] = true
	end
end

--------------------------------------------------------------------------------

function createList()
	local vsx, vsy = gl.GetViewSizes()
	dList = gl.CreateList(function()
		gl.Texture(vignetteTexture)
		gl.TexRect(-(vsx/25), -(vsy/25), vsx+(vsx/25), vsy+(vsy/25))
		gl.Texture(false)
	end)
end

function widget:Initialize()
	createList()
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
	if damage > 3 and unitTeam == myTeamID and comUnitDefIDs[unitDefID] and not Spring.IsUnitVisible(unitID) then
		if spGetSpectatingState() then
			widgetHandler:RemoveWidget()
			return
		end
		opacity = maxOpacity
	end
end

function widget:ViewResize(newX,newY)
	if dList ~= nil then
		gl.DeleteList(dList)
	end
	createList()
end


function widget:Update(dt)
	if opacity > 0 then
		opacity = opacity - (maxOpacity * (dt/duration))
	end
end

function widget:DrawScreen()
	if opacity > 0.01 then
		gl.Color(1,0,0,opacity)
		gl.CallList(dList)
	end
end

function widget:Shutdown()
	if dList ~= nil then
		gl.DeleteList(dList)
	end
end
