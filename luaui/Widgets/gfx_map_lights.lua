local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "MapLights",
		desc = "Adds static lights to maps",
		author = "Beherith",
		date = "2020",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = false,
	}
end



-- Localized functions for performance

-- Localized Spring API for performance
local spEcho = Spring.Echo

-- a table of lights
-- Important: the A param is a multiplier to the power of the light (mults RGB).
-- RGBA is NOT clamped to [0;1]
-- falloffsquared = 1 is default, is a term multiplied with the squared distance of the light when attenuating it
--    higher values decrease the amount of light in areas far away from the light source
--    Values of ~ 1.5 are recommended when using HUGE area lights (which fall WAY outside the use case of deferred rendering anyway, and are not very performant either)

local maplights = {
	-- redcomet remake
	--{lightname = 'maplight1', lightID = nil, pos = {2286, 425, 2429}, rgba = {0.4, 0.15, 0.05, 2}, radius = 1250,falloffsquared = 1.5},
	--{lightname = 'maplight2', lightID = nil, pos = {3847, 425, 1596}, rgba = {0.4, 0.15, 0.05, 2}, radius = 1250,falloffsquared = 1.5},

	-- altored divide
	--  {lightname = 'fireflies-center', lightID = nil, pos = {3000, 250, 4250}, rgba = {0.3, 0.32, 0.07, 2}, radius = 1000,falloffsquared = 1.5},
	--  {lightname = 'fireflies-right', lightID = nil, pos = {7370, 300, 4000}, rgba = {0.3, 0.32, 0.07, 2}, radius = 1000,falloffsquared = 1.5},
	--  {lightname = 'fireflies-top', lightID = nil, pos = {3410, 250, 3595}, rgba = {0.3, 0.32, 0.07, 1.2}, radius = 600,falloffsquared = 1.0},
	--   {lightname = 'statues-low', lightID = nil, pos = {765, 300, 4329}, rgba = {0.32, 0.22, 0.07, 2}, radius = 1150,falloffsquared = 1.5},
	{ lightname = 'statues-high', lightID = nil, pos = { 955, 300, 3462 }, rgba = { 0.32, 0.22, 0.07, 10.0 }, radius = 1150, falloffsquared = 0.01 },
	--    {lightname = 'mountain', lightID = nil, pos = {5482, 500, 4733}, rgba = {0.49, 0.48, 0.45, 1.5}, radius = 1150,falloffsquared = 1.5},
	--  {lightname = 'dark', lightID = nil, pos = {4000, 500, 4800}, rgba = {0.13,0.17,0.05, 2}, radius = 3000,falloffsquared = 1.7},
}

function widget:Initialize()
	--spEcho("Loading Maplights")
	--spEcho(WG, WG['lighteffects'], WG['lighteffects'].createLight,Script.LuaUI("GadgetCreateLight"))
	if (WG and WG['lighteffects'] and WG['lighteffects'].createLight) or Script.LuaUI("GadgetCreateLight") then

		for _, lightparams in pairs(maplights) do

			if WG then
				lightparams.lightID = WG['lighteffects'].createLight(
					lightparams.lightname,
					lightparams.pos[1],
					lightparams.pos[2],
					lightparams.pos[3],
					lightparams.radius,
					lightparams.rgba,
					lightparams.falloffsquared
				)
			else
				lightparams.lightID = Script.LuaUI.GadgetCreateLight(
					lightparams.lightname,
					lightparams.pos[1],
					lightparams.pos[2],
					lightparams.pos[3],
					lightparams.radius,
					lightparams.rgba,
					lightparams.falloffsquared
				)
			end
		end
	end
end

function widget:Shutdown()
	for _, lightparams in pairs(maplights) do
		if lightparams.lightID and ((WG and WG['lighteffects'] and WG['lighteffects'].removeLight) or Script.LuaUI("GadgetRemoveLight")) then
			if WG then
				WG['lighteffects'].removeLight(lightparams.lightID)
			else
				Script.LuaUI.GadgetRemoveLight(lightparams.lightID)
			end
		end
	end
end

