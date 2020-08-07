function widget:GetInfo()
    return {
        name	= "MapLights",
        desc	= "Adds static lights to maps",
        author	= "Beherith",
        date	= "2020",
        license	= "GNU GPL, v2 or later",
        layer	= 5,
        enabled	= false,
    }
end

-- a table of lights

local maplights = {
    {lightname = 'maplight1', lightID = nil, pos = {500, 150, 5000}, rgba = {1.0, 0.0, 1.0, 1.0}, radius = 250,},
    {lightname = 'maplight2', lightID = nil, pos = {500, 150, 4000}, rgba = {0, 0.0, 1.0, 2.0}, radius = 250,},
  } 


function widget:Initialize()
  --Spring.Echo("Loading Maplights")
  --Spring.Echo(WG, WG['lighteffects'], WG['lighteffects'].createLight,Script.LuaUI("GadgetCreateLight"))
  if (WG and WG['lighteffects'] and WG['lighteffects'].createLight) or Script.LuaUI("GadgetCreateLight") then
    
    for _, lightparams in pairs(maplights) do
  
      if WG then
        lightparams.lightID = WG['lighteffects'].createLight(
          lightparams.lightname,
          lightparams.pos[1],
          lightparams.pos[2],
          lightparams.pos[3],
          lightparams.radius,
          lightparams.rgba)
      else
          lightparams.lightID = Script.LuaUI.GadgetCreateLight(
          lightparams.lightname,
          lightparams.pos[1],
          lightparams.pos[2],
          lightparams.pos[3],
          lightparams.radius,
          lightparams.rgba)
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

