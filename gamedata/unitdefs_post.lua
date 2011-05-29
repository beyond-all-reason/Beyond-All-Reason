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
      Spring.Echo(name)
			ud.transportbyenemy = false
		end
  end
	
end
