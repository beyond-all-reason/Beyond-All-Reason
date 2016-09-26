local resources = {
      graphics = {
         trees = {
			bark     = 'default/Bark.bmp',
            leaf     = 'default/bleaf.bmp',
            gran1    = 'default/gran.bmp',
            gran2    = 'default/gran2.bmp',
            birch1   = 'default/birch1.bmp',
            birch2   = 'default/birch2.bmp',
            birch3   = 'default/birch3.bmp',
         },
         maps = {
            detailtex   = 'default/detailtex2.bmp',
            watertex	= 'default/ocean.jpg',
         },
         groundfx = {
            groundflash = 'default/groundflash.tga',
            groundring  = 'default/groundring.tga',
            seismic     = 'default/circles.tga',
         },
         projectiletextures = {
            circularthingy		= 'default/circularthingy.tga',
            laserend			= 'default/laserend.tga',
            laserfalloff		= 'default/laserfalloff.tga',
            randdots			= 'default/randdots.tga',
            smoketrail			= 'default/smoketrail.tga',
            wake				= 'default/wake.tga',
            flare				= 'default/flare.tga',
            explo				= 'default/explo.tga',
            explofade			= 'default/explofade.tga',
            heatcloud			= 'default/explo.tga',
            flame				= 'default/flame.tga',
            muzzleside			= 'default/muzzleside.tga',
            muzzlefront			= 'default/muzzlefront.tga',
            largebeam			= 'default/largelaserfalloff.tga',
			null='PD/null.tga',
         },
      }
   }

local VFSUtils = VFS.Include('gamedata/VFSUtils.lua')

local function AutoAdd(subDir, map, filter)
  local dirList = RecursiveFileSearch("bitmaps/" .. subDir)
  for _, fullPath in ipairs(dirList) do
    local path, key, ext = fullPath:match("bitmaps/(.*/(.*)%.(.*))")
    if not fullPath:match("/%.svn") then
    local subTable = resources["graphics"][subDir] or {}
    resources["graphics"][subDir] = subTable
      if not filter or filter == ext then
        if not map then
          table.insert(subTable, path)
        else -- a mapped subtable
          subTable[key] = path
        end
      end
    end
  end
end

-- Add default caustics, smoke and scars
AutoAdd("caustics", false)
AutoAdd("smoke", false, "tga")
AutoAdd("scars", false)
-- Add mod groundfx and projectiletextures
AutoAdd("groundfx", true)
AutoAdd("projectiletextures", true)

return resources

