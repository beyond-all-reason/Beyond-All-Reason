if (Spring.GetModOptions) then
	local modOptions = Spring.GetModOptions()

  if (modOptions.mo_transportenemy == "com") then
  	for name,ud in pairs(UnitDefs) do  
      if (name == "armcom" or name == "corcom" or name == "armdecom" or name == "cordecom") then
        ud.transportbyenemy = false
      end
    end
  elseif (modOptions.mo_transportenemy == "all") then
  	for name, ud in pairs(UnitDefs) do  
			ud.transportbyenemy = false
		end
  end
  if (modOptions.mo_storageowner == "com") then
  	for name, ud in pairs(UnitDefs) do  
      if (name == "armcom" or name == "corcom") then
        ud.energyStorage = modOptions.startenergy or 1000
        ud.metalStorage = modOptions.startmetal or 1000
      end
    end
  end
	
end

for name, ud in pairs(UnitDefs) do
	if (ud.maxvelocity) then 
		ud.turninplacespeedlimit = ud.maxvelocity or 0
	end
	if ud.category and (ud.category:find("TANK",1,true) or ud.category:find("HOVER",1,true)) then
		if (ud.maxvelocity) then 
			ud.turninplace = 0
			ud.turninplacespeedlimit = (ud.maxvelocity/2) or 0
		end
	elseif ud.category and (ud.category:find("KBOT",1,true)) then
		if (ud.maxvelocity) and (ud.turninplace) then 
			ud.turninplaceanglelimit = 91
		end
	end
end 