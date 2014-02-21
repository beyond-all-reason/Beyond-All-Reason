--NOTE: unitdefs_post does not deal with the normal lua UnitDefs table, it deals with the UnitDefs table built from unit definition files.

if (Spring.GetModOptions) then
	local modOptions = Spring.GetModOptions()

  if (modOptions.mo_transportenemy == "notcoms") then
  	for name,ud in pairs(UnitDefs) do  
      if (name == "armcom" or name == "corcom" or name == "armdecom" or name == "cordecom") then
        ud.transportbyenemy = false
      end
    end
  elseif (modOptions.mo_transportenemy == "none") then
  	for name, ud in pairs(UnitDefs) do  
			ud.transportbyenemy = false
		end
  end
  
end



local cons = {['armcv'] = true,
	['armacv']  = true,
	['consul'] = true,
	['armbeaver'] = true,
	['armch'] = true,
	['corcv'] = true,
	['coracv'] = true,
	['cormuskrat'] = true,
	['corch'] = true,}
	
local turninplacebots= {['corck'] = true,
	['corack'] = true,
	['corfast'] = true,
	['armck'] = true,
	['armack'] = true,
	['armfark'] = true,}
	
	
for name, ud in pairs(UnitDefs) do

	if not ud.canfly then
		if ud.maxvelocity then
			ud.turninplacespeedlimit = (ud.maxvelocity*0.66) or 0
			ud.turninplaceanglelimit = 140
		end	
		if ud.brakerate then
			ud.brakerate = ud.brakerate * 3.0		
		end
	end
	
	if ud.movementclass and (ud.movementclass:find("TANK",1,true) or ud.movementclass:find("HOVER",1,true)) then
		--Spring.Echo('tank or hover:',ud.name,ud.movementclass)
		if cons[name] then
			--Spring.Echo('tank or hover con:',ud.name,ud.moveData)
			ud.turninplace=1
			ud.turninplaceanglelimit=60
			ud.acceleration=ud.acceleration*2
			ud.brakerate=ud.brakerate*2
		elseif (ud.maxvelocity) then 
			ud.turninplace = 0
			ud.turninplacespeedlimit = (ud.maxvelocity*0.66) or 0
		end
	elseif ud.movementclass and (ud.movementclass:find("KBOT",1,true)) then
		if turninplacebots[name] then
			--Spring.Echo('turninplacekbot:',ud.name)
			ud.turninplace=1
			ud.turninplaceanglelimit=60
			ud.acceleration=ud.acceleration*2
			ud.brakerate=ud.brakerate*2
		elseif (ud.maxvelocity) then 
			ud.turninplaceanglelimit = 140
		end
	end
	
	-- make all heaps non-rezzable
	fDefs = ud.featuredefs
	if fDefs then
		for fName, fd in pairs(fDefs) do
			if fd.category == "heaps" then
				fd.resurrectable = false
			end	
		end
	end	
end

-- Setting collisionvolumetest true for all units
for name, ud in pairs(UnitDefs) do
		ud.collisionvolumetest = 1
end