if (Spring.GetModOptions) then
	local modOptions = Spring.GetModOptions()

	for name, ud in pairs(UnitDefs) do  
		if (ud.unitname == "armcom" or ud.unitname == "corcom") then
			ud.energystorage = modOptions.startenergy or 1000
			ud.metalstorage = modOptions.startmetal or 1000
		end
		if ud.builddistance and ((ud.builddistance*1) < 128) then
		  ud.builddistance = 128
		end
	end
	
end
