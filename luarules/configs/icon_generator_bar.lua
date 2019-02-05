-- $Id: icon_generator.lua 4354 2009-04-11 14:32:28Z licho $
-----------------------------------------------------------------------
-----------------------------------------------------------------------
--
--  Icon Generator Config File
--

--// Info
if (info) then
  local ratios      = {["1to1"]=(1/1)} --{["16to10"]=(10/16), ["1to1"]=(1/1), ["5to4"]=(4/5)} --, ["4to3"]=(3/4)}
  local resolutions = {{256,256}} --{{128,128},{64,64}}
  local schemes     = {""}

  return schemes,resolutions,ratios
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------

--// filename ext
imageExt = ".png"

--// render into a fbo in 4x size
renderScale = 4

--// faction colors (check (and needs) LuaRules/factions.lua)
factionTeams = {
  arm     = 1,   --// arm
  core    = 1,   --// core
  chicken = 2,   --// chicken
  unknown = 2,   --// unknown
}
factionColors = {
  arm     = {0, 0.2, 1},   --// arm
  core    = {1, 0.7, 0.2},   --// core
  chicken = {1.0,0.8,0.2},   --// chicken
  unknown = {1.0, 0, 0},   --// unknown -- This is what is being used to color the units when processed, as it cannot tell the side of a unit when using "/luarules buildicon unitName"
}


-----------------------------------------------------------------------
-----------------------------------------------------------------------

--// render options textured
textured = (scheme~="bw")
lightAmbient = {0.2,0.2,0.2}
lightDiffuse = {1.25,1.25,1.25}
lightPos     = {-0.5,0.6,0.5}

--// Ambient Occlusion & Outline settings
aoPower     =  3
aoContrast  =  3
aoTolerance =  1
olContrast  =  0
olTolerance =  0

--// halo (white)
halo  = false --(scheme~="bw")


-----------------------------------------------------------------------
-----------------------------------------------------------------------

--// backgrounds
background = false
local function Greater30(a)     return a>30;  end
local function GreaterEq15(a)   return a>=15; end
local function GreaterZero(a)   return a>0;   end
local function GreaterEqZero(a) return a>=0;  end
local function GreaterFour(a)   return a>4;   end
local function LessEqZero(a)    return a<=0;  end
local function IsCoreOrChicken(a)
	if a then return a.chicken
	else return false end
end
backgrounds = {
--//chicken queen has air movementtype
  {check={name="chickenq"},                                  texture="LuaRules/Images/IconGenBkgs/bg_ground_rock.png"},

--[[terraforms
  {check={name="rampup"},                                    texture="LuaRules/Images/IconGenBkgs/rampup.png"},
  {check={name="rampdown"},                                  texture="LuaRules/Images/IconGenBkgs/rampdown.png"},
  {check={name="levelterra"},                                texture="LuaRules/Images/IconGenBkgs/level.png"},
  {check={name="armblock"},                                  texture="LuaRules/Images/IconGenBkgs/block.png"},
  {check={name="corblock"},                                  texture="LuaRules/Images/IconGenBkgs/block.png"},
  {check={name="armtrench"},                                 texture="LuaRules/Images/IconGenBkgs/trench.png"},
  {check={name="cortrench"},                                 texture="LuaRules/Images/IconGenBkgs/trench.png"},
]]--
--//air
  {check={canFly=true},                                      texture="LuaRules/Images/IconGenBkgs/bg_air.png"},
--//hovers
  {check={factions=IsCoreOrChicken,canHover=true},                                    texture="LuaRules/Images/IconGenBkgs/bg_hover_rock.png"},
  {check={factions=IsCoreOrChicken,floatOnWater=true,minWaterDepth=LessEqZero},            texture="LuaRules/Images/IconGenBkgs/bg_hover_rock.png"},
  {check={factions=IsCoreOrChicken,waterline=GreaterZero,minWaterDepth=LessEqZero},   texture="LuaRules/Images/IconGenBkgs/bg_hover_rock.png"},
  --{check={canHover=true},                                    texture="LuaRules/Images/IconGenBkgs/bg_hover.png"},
  {check={floatOnWater=true,minWaterDepth=LessEqZero},            texture="LuaRules/Images/IconGenBkgs/bg_hover.png"},
  {check={waterline=GreaterZero,minWaterDepth=LessEqZero},   texture="LuaRules/Images/IconGenBkgs/bg_hover.png"},
--//subs
  {check={waterline=GreaterEq15,minWaterDepth=GreaterZero},  texture="LuaRules/Images/IconGenBkgs/bg_underwater.png"},
  {check={floatOnWater=false,minWaterDepth=GreaterFour},          texture="LuaRules/Images/IconGenBkgs/bg_underwater.png"},
--//sea
  {check={floatOnWater=true,minWaterDepth=GreaterZero},           texture="LuaRules/Images/IconGenBkgs/bg_water.png"},
--//amphibous
  {check={factions=IsCoreOrChicken,maxWaterDepth=Greater30,minWaterDepth=LessEqZero}, texture="LuaRules/Images/IconGenBkgs/bg_amphibous_rock.png"},
  {check={maxWaterDepth=Greater30,minWaterDepth=LessEqZero}, texture="LuaRules/Images/IconGenBkgs/bg_amphibous.png"},
--//ground
  {check={factions=IsCoreOrChicken},                         texture="LuaRules/Images/IconGenBkgs/bg_ground_rock.png"},
  {check={},                                                 texture="LuaRules/Images/IconGenBkgs/bg_ground.png"},
}


-----------------------------------------------------------------------
-----------------------------------------------------------------------

--// default settings for rendering
--//zoom   := used to make all model icons same in size (DON'T USE, it is just for auto-configuration!)
--//offset := used to center the model in the fbo (not in the final icon!) (DON'T USE, it is just for auto-configuration!)
--//rot    := facing direction
--//angle  := topdown angle of the camera (0 degree = frontal, 90 degree = topdown)
--//clamp  := clip everything beneath it (hide underground stuff)
--//scale  := render the model x times as large and then scale down, to replaces missing AA support of FBOs (and fix rendering of very tine structures like antennas etc.))
--//unfold := unit needs cob to unfolds
--//move   := send moving cob events (works only with unfold)
--//attack := send attack cob events (works only with unfold)
--//shotangle := vertical aiming, useful for arties etc. (works only with unfold+attack)
--//wait   := wait that time in gameframes before taking the screenshot (default 300) (works only with unfold)
--//border := free space around the final icon (in percent/100)
--//empty  := empty model (used for fake units in CA)
--//attempts := number of tries to scale the model to fit in the icon

defaults = {border=0.05, angle=26, rot="right", clamp=-10000, scale=1.5, empty=false, attempts=10, wait=300, zoom=1.0, offset={0,0,0},};


-----------------------------------------------------------------------
-----------------------------------------------------------------------

--// per unitdef settings
unitConfigs = {
  
  
  [UnitDefNames.cormex.id] = {
    clamp  = 0,
    unfold = true,
    wait   = 600,
  },
  [UnitDefNames.cordoom.id] = {
    unfold = true,
  },


}

for i=1,#UnitDefs do
  if (UnitDefs[i].canFly) then
    if (unitConfigs[i]) then
      if (unitConfigs[i].unfold ~= false) then
        unitConfigs[i].unfold = true
        unitConfigs[i].move   = true
      end
    else
      unitConfigs[i] = {unfold = true, move = true}
    end
  elseif (UnitDefs[i].canKamikaze) then
    if (unitConfigs[i]) then
      if (not unitConfigs[i].border) then
        unitConfigs[i].border = 0.156
      end
    else
      unitConfigs[i] = {border = 0.156}
    end
  end
end
