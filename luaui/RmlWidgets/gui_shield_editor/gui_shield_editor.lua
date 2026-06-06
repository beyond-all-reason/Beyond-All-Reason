if not RmlUi then return end

local widget = widget

function widget:GetInfo()
	return {
		name    = "Shield Shader Editor",
		desc    = "Art tool: live-tweak ShieldSphereColor.frag parameters via WG.ShieldEditorParams",
		author  = "art-tool",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 9999,
		enabled = false, -- off by default; art team enables manually
	}
end

-----------------------------------------------------------------
-- Constants / defaults
-----------------------------------------------------------------

local MODEL_NAME = "shield_editor"
local RML_PATH   = "luaui/RmlWidgets/gui_shield_editor/gui_shield_editor.rml"

local DEFAULTS = {
	maxAlpha      = 0.45,
	blueTintR     = 0.38,
	blueTintG     = 0.72,
	blueTintB     = 0.74,
	rimSharpness  = 1.5,
	rimAlpha      = 0.45,
	rimColorGain  = 2.2,
	chromaSplit   = 0.5,
	bloomStrength = 1.10,
	bloomAlpha    = 0.28,
	hexScale      = 9.0,
	hexOpacity    = 0.13,
	hexFireProb   = 0.18,
	hexFireGain   = 1.8,
	refractSplit  = 0.010,
	refractRimAmp = 2.5,
	hexTintR      = 0.97,
	hexTintG      = 0.41,
	hexTintB      = 1.38,
	flowScale     = 2.4,
	flowSpeed     = 1.13,
	flowIntensity = 4.0,
	impactWaveSpeed = 1.0,
	impactWaveStrength = 1.0,
	breathSpeed   = 0.018,
	arcBurstFreq  = 0.013,
	arcBurstGain  = 0.4,
	rotYSpeed     = 0.00022,
	rotZSpeed     = 0.000065,
	zoomNear      = 200.0,
	zoomFar       = 2600.0,
	zoomMinMult   = 0.24,
	zoomCurve     = 1.6,
}

-----------------------------------------------------------------
-- State
-----------------------------------------------------------------

local widgetState = {
	rmlContext = nil,
	dmHandle   = nil,
	document   = nil,
}

-- Live params table — gadget reads this directly via getParams().
-- Updated from slider events; initialised from DEFAULTS.
local params = {}
for k, v in pairs(DEFAULTS) do params[k] = v end

-- Slider element refs keyed by param name, populated in Initialize.
local sliderEls = {}
local displayEls = {}

-----------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------

-- Expose a getter for the gadget to call via Script.LuaUI.GetShieldEditorParams().
local function getParams()
	return params
end

local function fmt(v)
	-- 3 significant decimal places, strip trailing zeros
	return string.format("%.3g", v)
end

local function setParam(key, rawStr)
	local v = tonumber(rawStr) or DEFAULTS[key]
	params[key] = v
	local dv = displayEls[key]
	if dv then dv.inner_rml = fmt(v) end
end

local function resetAll()
	for k, def in pairs(DEFAULTS) do
		params[k] = def
		local sl = sliderEls[k]
		if sl then sl:SetAttribute("value", tostring(def)) end
		local dv = displayEls[k]
		if dv then dv.inner_rml = fmt(def) end
	end
end

-----------------------------------------------------------------
-- Slider config: { paramKey, idSuffix } — order matches RML
-----------------------------------------------------------------

local SLIDERS = {
	"maxAlpha", "blueTintR", "blueTintG", "blueTintB",
	"rimSharpness", "rimAlpha", "rimColorGain", "chromaSplit", "bloomStrength", "bloomAlpha",
	"hexScale", "hexOpacity", "hexFireProb", "hexFireGain",
	"refractSplit", "refractRimAmp", "hexTintR", "hexTintG", "hexTintB",
	"flowScale", "flowSpeed", "flowIntensity",
	"impactWaveSpeed", "impactWaveStrength",
	"breathSpeed", "arcBurstFreq", "arcBurstGain",
	"rotYSpeed", "rotZSpeed",
	"zoomNear", "zoomFar", "zoomMinMult", "zoomCurve",
}

local function exportConfig()
	-- Build a Lua snippet that can be pasted back into DEFAULTS.
	local lines = { "-- Shield Editor export -- paste into DEFAULTS table:" }
	for _, key in ipairs(SLIDERS) do
		lines[#lines + 1] = string.format("\t%-14s = %s,", key, fmt(params[key]))
	end
	local out = table.concat(lines, "\n")
	Spring.Echo(out)
	-- Also write to a file in the Spring write dir for easy copy-paste.
	local path = "shield_editor_export.lua"
	local f = io.open(path, "w")
	if f then
		f:write(out .. "\n")
		f:close()
		Spring.Echo("[ShieldEditor] Saved to " .. path)
	end
end

local function wireSliders(doc)
	for _, key in ipairs(SLIDERS) do
		local sl = doc:GetElementById("se-sl-" .. key)
		local dv = doc:GetElementById("se-dv-" .. key)
		sliderEls[key]  = sl
		displayEls[key] = dv
		if sl then
			local k = key -- capture for closure
			sl:AddEventListener("change", function(event)
				setParam(k, sl:GetAttribute("value"))
			end, false)
		end
	end

	local resetBtn = doc:GetElementById("se-reset")
	if resetBtn then
		resetBtn:AddEventListener("click", function(event)
			resetAll()
		end, false)
	end

	local exportBtn = doc:GetElementById("se-export")
	if exportBtn then
		exportBtn:AddEventListener("click", function(event)
			exportConfig()
		end, false)
	end
end

-----------------------------------------------------------------
-- Data model (no function keys needed — all imperative now)
-----------------------------------------------------------------

local initialModel = {}

-----------------------------------------------------------------
-- Widget lifecycle
-----------------------------------------------------------------

function widget:Initialize()
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then
		Spring.Echo("[ShieldEditor] RmlUi shared context unavailable")
		return false
	end

	local dm = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initialModel, self)
	if not dm then
		Spring.Echo("[ShieldEditor] Failed to open data model")
		return false
	end
	widgetState.dmHandle = dm

	-- Register getter so gadget can call Script.LuaUI.GetShieldEditorParams()
	widgetHandler:RegisterGlobal("GetShieldEditorParams", getParams)

	local document = widgetState.rmlContext:LoadDocument(RML_PATH)
	if not document then
		Spring.Echo("[ShieldEditor] Failed to load RML: " .. RML_PATH)
		widget:Shutdown()
		return false
	end
	widgetState.document = document
	document:Show(RmlUi.RmlModalFlag.None, RmlUi.RmlFocusFlag.None)

	wireSliders(document)

	return true
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("GetShieldEditorParams")

	if widgetState.rmlContext and widgetState.dmHandle then
		widgetState.rmlContext:RemoveDataModel(MODEL_NAME)
	end

	if widgetState.document then
		widgetState.document:Close()
		widgetState.document = nil
	end

	widgetState.dmHandle = nil
	widgetState.rmlContext = nil
end

-- Never consume keyboard events — let chat, hotkeys, and Enter pass through.
function widget:KeyPress(key, mods, isRepeat)   return false end
function widget:KeyRelease(key, mods)           return false end
function widget:TextInput(utf8char)             return false end
