local resources = {
	graphics = {
		 maps = {
			detailtex = 'default/detailtex2.bmp',
			watertex  = 'default/ocean.jpg',
		 },
		 groundfx = {
			groundflash      = 'default/groundflash.tga',
			groundflashwhite = 'default/groundflashwhite.tga',
			groundring       = 'default/groundring.tga',
			seismic          = 'default/circles.tga',
			circlefx0        = 'default/circlefx0.png',
			circlefx1        = 'default/circlefx1.png',
			circlefx2        = 'default/circlefx2.png',
			circlefx3        = 'default/circlefx3.png',
			radarfx2ground   = 'ui/radarping2.png',
			scar50glow		 = 'projectiletextures/decal_scar_50_glow.tga',
			centersplatsh    = 'default/centersplatsh_white.tga',
		 },
		 projectiletextures = {
			circularthingy    = 'default/circularthingy.tga',
			gfxtexture        = 'projectiletextures/nanopart.tga',
			laserend          = 'default/laserend.tga',
			laserfalloff      = 'default/laserfalloff.tga',
			randdots          = 'default/randdots.tga',
			smoketrail        = 'default/smoketrail.tga',
			smoketrailaa      = 'default/smoketrailaa.tga',
			railguntrail      = 'default/railguntrail.tga',
			trail             = 'default/trail.tga',
			wake              = 'default/wake.tga',
			wakegrey          = 'projectiletextures/wakegrey.tga',
			flashside3        = 'projectiletextures/flashside3.tga',
			flare             = 'default/flare.tga',
			flare2            = 'default/flare2.tga',
			explo             = 'default/explo.tga',
			explo2            = 'default/explo2.tga',
			sakexplo2         = 'default/sakexplo2.tga',
			explofade         = 'default/explofade.tga',
			exploflare        = 'projectiletextures/exploflare.tga',
			heatcloud         = 'default/explo.tga',
			blastwave         = 'projectiletextures/blastwave.tga',
			flame             = 'default/flame.tga',
			flame_dark        = 'projectiletextures/flame.tga',
			flame_alt         = 'gpl/flame.tga',
			flame_alt2        = 'gpl/flame_alt.tga',
			fire              = 'gpl/fire.tga',
			firesmoke         = 'gpl/smoke_orange.png',
			flamestream       = 'atmos/flamestream.tga',
			treefire          = 'gpl/treefire.png',
			muzzlesideflipped = 'default/muzzlesideflipped.tga',
			muzzleside        = 'default/muzzleside.tga',
			muzzlefront       = 'default/muzzlefront.tga',
			largebeam         = 'default/largelaserfalloff.tga',
			gunshotxl         = 'default/gunshotxl.tga',
			lightningarc	  = 'atmos/lightningarc.tga',

			radarfx1          = 'ui/radarping1.png',
			radarfx2          = 'ui/radarping2.png',
			radarfx1old       = 'ui/radar1xx.tga',
			radarfx2old       = 'ui/radar2.tga',

			lavachunk		  = 'atmos/lavachunk.tga',
			lavasplats		  = 'atmos/lavasplats.tga',
			lavaplosion		  = 'atmos/lavaplosion.tga',

			fogdirty          = 'atmos/fogdirty.tga',
			rain              = 'atmos/rain.tga',
			cloudpuff         = 'atmos/cloudpuff.tga',
			cloudmist         = 'atmos/cloudmist.tga',
			barmist           = 'atmos/barmist.tga',
			sandblast         = 'atmos/sandblast.tga',
			smoke_puff        = 'projectiletextures/smoke_puff.png',
			smoke_puff2       = 'projectiletextures/smoke_puff2.png',
			smoke_puff_red    = 'atmos/smoke_puff_red.png',
			dirtrush          = 'atmos/dirtdebrisexplo.tga',
			explowater        = 'projectiletextures/explowater.tga',
			waterrush         = 'projectiletextures/waterrush.tga',
			waterfoam         = 'atmos/waterfoam.tga',
			subwak            = 'projectiletextures/subwake.tga',
			scar50			  = 'projectiletextures/decal_scar_50.tga',


			--Animated Explosion effect (test)
			-- barexplo_29 = 'anims/barexplo_29.png',
			-- barexplo_0 = 'anims/barexplo_1.png',
			-- barexplo_1 = 'anims/barexplo_4.png',
			-- barexplo_2 = 'anims/barexplo_7.png',
			-- barexplo_3 = 'anims/barexplo_10.png',
			-- barexplo_4 = 'anims/barexplo_13.png',
			-- barexplo_5 = 'anims/barexplo_16.png',
			-- barexplo_6 = 'anims/barexplo_19.png',
			-- barexplo_7 = 'anims/barexplo_22.png',
			-- barexplo_8 = 'anims/barexplo_25.png',

			--Chicken Defense effects
			uglynovaexplo           = 'CC/uglynovaexplo.tga',
			sporetrail              = 'GPL/sporetrail.tga',
			sporetrail_xl           = 'GPL/sporetrail_xl.tga',
			blooddrop               = 'PD/blooddrop.tga',
			blooddrop2              = 'chickens/blooddrop2.tga',
			blooddrop2white         = 'chickens/blooddrop2_white.tga',
			bloodblast              = 'PD/bloodblast.tga',
			bloodblast2             = 'chickens/bloodblast2.tga',
			bloodblast2white        = 'chickens/bloodblast2_white.tga',
			bloodsplat              = 'PD/bloodsplat.tga',
			bloodsplat2             = 'chickens/bloodsplat2.tga',
			bloodsplat2white        = 'chickens/bloodsplat2_white.tga',
			bloodspark2             = 'chickens/blood_splat.tga',
			bloodspark2white        = 'chickens/blood_splat_white.tga',
			bloodcentersplatsh      = 'chickens/blood_centersplatsh.tga',
			bloodcentersplatshwhite = 'chickens/blood_centersplatsh_white.tga',
			blooddropwhite          = 'PD/blooddropwhite.tga',
			bloodblastwhite         = 'PD/bloodblastwhite.tga',
			lightningbeam			= 'PD/lightning.tga',
		 },
	  }
   }

VFS.Include('gamedata/VFSUtils.lua')
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
