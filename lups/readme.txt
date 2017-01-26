
 Lua Particle System (LUPS)

Licensed under the terms of the GNU GPL, v2 or later.



 ** Implementation **
First, you need to differ between synced and unsynced FX,
so there are 2 LUPS instances running:
 one in LuaUI (widget) and
 one in LuaRules (gadget).
(To start a new instance simply include lups/lups.lua)



 ** Why differ between synced and unsynced FX? **
LuaUI has only a limited access to engine values, so it
could never determine the unittype of enemy units in airlos,
nor is it able to catch weapon explosion or to interact with
cob.



 ** Which files are used by LUPS? **
the core uses the following:
 lups/*
 bitmaps/GPL/lups/*
 LuaUI/Widgets/lups_wrapper.lua
 LuaRules/Gadgets/lups_wrapper.lua (only if you want synced
	FX like shockwaves/nanolasers)
and there are the managers:
 LuaUI/Widgets/gfx_lups_manager.lua
 LuaRules/Gadgets/gfx_lups_manager.lua
the shockwaves gadget:
 LuaRules/Gadgets/lups_shockwaves.lua



 ** What are those managers? **
LUPS itself doesn't start any FX. It needs other lua files
to tell LUPS when it should start a new FX.
There are many widgets and gadgets, which start LUPS FXs,
but the most interesting ones are the managers (and perhaps
the shockwaves gadget).
Also the manager in LuaRules differ from that one in LuaUI.
The manager in LuaUI starts FXs everytime an new unit gets
finished or an enemy unit enters the LOS, so those FX only
vanish if the unit dies or leaves the LOS again.
The LuaRules manager is much less customizable, it creates
very special FXs like cloaking and it also manage parts of
the LUPS nano particle handling.



 ** How do I implement my own FX? **
Okay, in the case you use the LuaUI manager and you want to
create a per-unit FX (like a fusion FX, airjets, ...):

 1. open LuaUI/Widgets/gfx_lups_manager.lua
    (don't shock the file seems huge, but most is only config,
     and yeah it needs a cleanup ... someday :x)
 2. scroll down (~50% scrollbar)
    you will find the following table/array:
    "local UnitEffects = {...}"
    It holds the FX per-unitdef.
 3. create a new sub-table like the following:
  [UnitDefNames["%UNITDEF_NAME%"].id] = {
    {class='%FXCLASS%',options=%MY_FXOPTIONS_TABLE%}
  },



 ** What FXClasses exist and how do I know their options? **
All FXClasses are located here:
 /lups/ParticleClasses/*
If you open on of those files, you will see a function like this:

  function ShieldSphereParticle.GetInfo()
    return {
      name      = "ShieldSphere",
    }
  end

That returned name is what you fill in %FXCLASS% (uppercase
doesn't matter), also it is in most cases same as the filename.
To see possible options of the FXClass scroll a bit down, you
will find a table like this:

 ShieldSphereParticle.Default = {
   pos        = {0,0,0}, -- start pos
   layer      = -23,
   life       = 0, --in frames
   size       = 0,
   sizeGrowth = 0,
   margin     = 1,
   colormap1  = { {0, 0, 0, 0} },
   colormap2  = { {0, 0, 0, 0} },
   repeatEffect = false,
 }

The table contains all options and their default values.
So an example fx placed in LuaUI/Widgets/gfx_lups_manager.lua
could look like this:
  [UnitDefNames["armcom"].id] = {
    {class='ShieldSphere',options={ life=3000, repeatEffect=true, size=300, colormap1={1,0,0,0.5}, colormap2={0,1,0,0.5} } }
  },



  ** How do I start my own FX from my widget/gadget? **
First, you need a link to the interface, to do so you need
to access the global shared table of the widget-/gadgetHandler.
for LuaUI:
  local LupsApi = WG.Lups
for LuaRules:
  local LupsApi = GG.Lups
(nil check those, it is possible that Lups hasn't started yet!)

That Api contains the following functions:
  LupsApi.GetStats()
  LupsApi.GetErrorLog(minPriority)
->  LupsApi.AddParticles(class,options)   //returns a fxID
->  LupsApi.RemoveParticles(fxID)
  LupsApi.AddParticlesArray({ {class=className, ..FX options..},{class=className, ..FX options..},.. } )
  LupsApi.HasParticleClass(className)
and
  LupsApi.Config = {...}  //contains the options of lups.cfg



  ** Example usage of AddParticles() **
LupsApi.AddParticles('ShieldSphere', {
  unit=unitID,
  piece="head",
  pos={0,100,0},
  life=3000,
  repeatEffect=true,
  size=300,
  colormap1={1,0,0,0.5},
  colormap2={0,1,0,0.5}
})



  ** How do I bind a FX to an unit/unitpiece? **
There are some special options tags, those are:
  unit := binds fx to unitID
  piece:= binds fx to pieceNAME
  pos  := worldspace coord or offset coord from the unit/unitpiece center
  onActive := only show FX if the unit is active (e.g. used for airjets - a plane is active, if it flies)



  ** Can I modify FX on runtime? **
Sure you can. There is only one issue in 76b1 (it will
be fixed in the next spring release):
you can't modify widgets if they are in a .sdd, so you
have to copy it to your local widgets folder,
then you can run:
 /luaui reload
each time you modified the file.



  ** I heard some options can contain Lua code? **
Yeah, but only the SimpleParticles class support them and
_only_ in the "partpos" param:

LupsApi.AddParticles('SimpleParticles', {
  ...
  partpos = "r*cos(beta)*sin(alpha),r*cos(alpha),r*sin(beta)*sin(alpha) | r=random()*20, alpha=2*math.pi*random(), beta=2*math.pi*random()"
  ...
})

The syntax is a bit extended so it looks similar to the
definitions of a mathical sets, but it can still contain
any lua code.

Valid examples are:
  "x,y,z | x=10,y=30,z=0"
  "10,30,0"
  "random(),random(),random()"
  "x,y,z | r=random(), if (r>10) then x=10; y=30; z=0; else x=-10; y=-30; z=-0; end"