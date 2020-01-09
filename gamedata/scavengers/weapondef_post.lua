-- this file gets included in alldefs_post.lua
function convertToPurple(value)
    value = string.gsub(value, '-red', '-purple')
    value = string.gsub(value, '-green', '-purple')
    value = string.gsub(value, '-blue', '-purple')
    value = string.gsub(value, '-yellow', '-purple')
    return value
end

function scav_Wdef_Post(name, wDef)
    if wDef.weapontype == "Cannon" then
		wDef.rgbcolor = {0.95, 0.36, 1}
		--wDef.colormap = [[0.95 0.32 1]]   
    elseif wDef.weapontype == "LightningCannon" then
	    wDef.rgbcolor = {0.95, 0.32, 1}
	    wDef.customparams.expl_light_color = {0.95, 0.32, 1}
		wDef.customparams.light_color = {0.95, 0.32, 1}	
		wDef.explosiongenerator = "custom:genericshellexplosion-medium-lightning2-purple"
        --wDef.colormap = [[0.95 0.32 1]]  
    elseif wDef.weapontype == "BeamLaser" or wDef.weapontype == "LaserCannon" or wDef.weapontype == "DGun" then
        wDef.rgbcolor = {0.95, 0.32, 1}
        wDef.rgbcolor2 = {1, 0.8, 1}
        wDef.explosiongenerator = convertToPurple(wDef.explosiongenerator)
    end
    return wDef
end