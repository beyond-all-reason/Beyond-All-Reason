local function unbaUnitTweaks(name, uDef)
    -- if name == "corcom" then
    --     uDef.maxvelocity = uDef.maxvelocity*2
    -- end
	if name == "armcom" or name == "corcom" then
		uDef.maxdamage = 7500
	end

	if Spring.GetModOptions().unbatech == true then
		--------------------------------------------
		---					ARM					 ---
		--------------------------------------------
		if name == "armca" then
			uDef.buildoptions[11] = "disabled" --alab
		end
		if name == "armck" then
			uDef.buildoptions[10] = "disabled" --alab
		end
		if name == "armcv" then
			uDef.buildoptions[10] = "disabled" --alab
		end
		if name == "armcv" then
			uDef.buildoptions[10] = "disabled" --alab
		end
		if name == "armcs" then
			uDef.buildoptions[16] = "disabled" --alab
		end
		if name == "armbeaver" then
			uDef.buildoptions[14] = "disabled" --alab
		end 
		if name == "armaap" then
			uDef.buildoptions[1] = "disabled" --adv con
		end   
		if name == "armalab" then
			uDef.buildoptions[1] = "disabled" --adv con
		end   
		if name == "armavp" then
			uDef.buildoptions[1] = "disabled" --adv con
			uDef.buildoptions[2] = "disabled" --consul
		end      
		if name == "armasy" then
			uDef.buildoptions[1] = "disabled" --adv con
		end  

		--------------------------------------------
		---					COR					 ---
		--------------------------------------------
		if name == "corca" then
			uDef.buildoptions[11] = "disabled" --alab
		end
		if name == "corck" then
			uDef.buildoptions[10] = "disabled" --alab
		end
		if name == "corcv" then
			uDef.buildoptions[10] = "disabled" --alab
		end
		if name == "corcv" then
			uDef.buildoptions[10] = "disabled" --alab
		end
		if name == "corcs" then
			uDef.buildoptions[16] = "disabled" --alab
		end
		if name == "cormuskrat" then
			uDef.buildoptions[14] = "disabled" --alab
		end 
		if name == "coraap" then
			uDef.buildoptions[1] = "disabled" --adv con
		end   
		if name == "coralab" then
			uDef.buildoptions[1] = "disabled" --adv con
			uDef.buildoptions[2] = "disabled" --freaker
		end   
		if name == "coravp" then
			uDef.buildoptions[1] = "disabled" --adv con
		end         
		if name == "corasy" then
			uDef.buildoptions[1] = "disabled" --adv con
		end 
	end
      
    return uDef
end

local function unbaWeaponTweaks(name, wDef)
	if Spring.GetModOptions().unbatech == true then



		
	end
    return wDef
end

return {
    unbaUnitTweaks = unbaUnitTweaks,
    unbaWeaponTweaks = unbaWeaponTweaks,
}