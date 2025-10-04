local function techsplit_balanceTweaks(name, uDef)

	if name == "corgol" then 
		uDef.speed = 37
		uDef.weapondefs.cor_gol.damage = {
			default = 1600,
			subs = 356,
			vtol = 98,
		}
		uDef.weapondefs.cor_gol.reloadtime = 4
		uDef.weapondefs.cor_gol.range = 700
		uDef.customparams.techlevel = 3
	end

	if name == "armfboy" then
		uDef.customparams.techlevel = 3
	end

	if name == "armshltx" then
		uDef.buildoptions[10] = "armfboy"
	end

	if name == "corgant" then
		uDef.buildoptions[10] = "corgol"
	end

	if name == "coravp" then 
		uDef.buildoptions[5] = ""
	end

	if name == "armalab" then
		uDef.buildoptions[10] = ""
	end

	return uDef
end

return {
	techsplit_balanceTweaks = techsplit_balanceTweaks,
}
