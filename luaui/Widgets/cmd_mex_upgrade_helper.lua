function widget:GetInfo()
	return {
		name = "MexUpg Helper",
		desc = "",
		author = "author: BigHead",
		date = "September 13, 2007",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = true -- loaded by default?
	}
end

local upgradeMouseCursor = "upgmex"

local CMD_UPGRADEMEX = 31244
local CMD_AREA_MEX = 10100

local builderDefs, rightClickUpgradeParams

local GetUnitDefID = Spring.GetUnitDefID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local TraceScreenRay = Spring.TraceScreenRay
local GetActiveCommand = Spring.GetActiveCommand
local GetSelectedUnits = Spring.GetSelectedUnits
local GetSelectedUnitsCount = Spring.GetSelectedUnitsCount

local pressMouseX, pressMouseY

--local isT2Builder = {}
--local isT1Mex = {}
--for unitDefID, unitDef in pairs(UnitDefs) do
--	if unitDef.buildSpeed and unitDef.buildOptions[1] and unitDef.customParams.techlevel == '2' then
--		isT2Builder[unitDefID] = true
--	end
--	if unitDef.extractsMetal > 0 and unitDef.extractsMetal < 0.002 then
--		isT1Mex[unitDefID] = true
--	end
--end


local function registerUpgradePairs(v)
	builderDefs = v
	return true
end

function widget:Initialize()
	widgetHandler:RegisterGlobal('registerUpgradePairs', registerUpgradePairs)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('registerUpgradePairs')
end

function widget:GameFrame(n)
	if n > 1 then
		Spring.SendCommands("luarules registerUpgradePairs 1")
		widgetHandler:RemoveCallIn("GameFrame")
	end
end

local selectedUnits = GetSelectedUnits()
function widget:SelectionChanged(sel)
	selectedUnits = sel
end

function widget:MousePress(x, y, b)
	if rightClickUpgradeParams then
		local mx, my, b, b2, b3 = Spring.GetMouseState()
		pressMouseX, pressMouseY = mx, my
		return true
	end
end

function widget:MouseRelease(x, y, b)
	if rightClickUpgradeParams then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		local options = {}
		if shift then
			options = { "shift" }
		end
		GiveOrderToUnit(rightClickUpgradeParams.builderID, CMD_UPGRADEMEX, { rightClickUpgradeParams.mexID }, options)
		return true
	end
end

-- FIRST NEED TO FIND AWAY TO MAKE THE AREAMEX CMD NOT JUST ACTIVE, BUT AT THE DRAGGING STAGE TOO
-- transform upgrade-mex cmd to area-mex cmd when dragging
--unction widget:MouseMove(mx, my, dx, dy, mButton)
--	if rightClickUpgradeParams then
--		local vsx, vsy = Spring.GetViewGeometry()
--		local gracePx = math.floor((vsx+vsy) * 0.0025)
--		if mx > pressMouseX + gracePx or mx < pressMouseX - gracePx and my > pressMouseY + gracePx or my < pressMouseY - gracePx then
--			Spring.SetActiveCommand(Spring.GetCmdDescIndex(CMD_AREA_MEX), 1, true, false, Spring.GetModKeyState())
--			rightClickUpgradeParams = nil
--		end
--	end
--nd

function widget:IsAbove(x, y)
	if not builderDefs then
		return
	end
	rightClickUpgradeParams = nil

	if GetActiveCommand() ~= 0 then
		return false
	end
	if GetSelectedUnitsCount() ~= 1 then
		return false
	end

	local selectedUnits = GetSelectedUnits()
	local builderID = selectedUnits[1]
	local upgradePairs = builderDefs[GetUnitDefID(builderID)]
	if not upgradePairs then
		return false
	end

	local type, unitID = TraceScreenRay(x, y)
	if type ~= "unit" then
		return false
	end

	local upgradeTo = upgradePairs[GetUnitDefID(unitID)]
	if not upgradeTo then
		return false
	end

	rightClickUpgradeParams = { builderID = builderID, mexID = unitID, upgradeTo = upgradeTo }
	Spring.SetMouseCursor(upgradeMouseCursor)
	return true
end
