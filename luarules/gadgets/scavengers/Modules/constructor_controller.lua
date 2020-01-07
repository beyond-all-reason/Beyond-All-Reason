if commanderlimit > Spring.GetTeamUnitDefCount(GaiaTeamID, UnitDefNames.armcom_scav.id) + Spring.GetTeamUnitDefCount(GaiaTeamID, UnitDefNames.corcom_scav.id) then
	local r = math.random(0,1)
	if r == 0 then
		Spring.CreateUnit("armcom"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
	else
		Spring.CreateUnit("corcom"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
	end
end



if (not scavStructure and Spring.GetCommandQueue(scav, 0) <= 1) or (string.find(UnitDefs[scavDef].name, "com_scav") and Spring.GetCommandQueue(scav, 0) <= 1) then
						
						if string.find(UnitDefs[scavDef].name,"com_scav") then
							local x,y,z = Spring.GetUnitPosition(scav)
							local posx = math.random(x-1000,x+1000)
							local posz = math.random(z-1000,z+1000)
							local posy = Spring.GetGroundHeight(posx, posz)
							if posy > 0 then
								if n > 50000 then
									local r = math.random(0,1)
									if r == 0 then
										blueprint = ScavengerConstructorBlueprintsT3[math.random(1,#ScavengerConstructorBlueprintsT3)]
									else
										blueprint = ScavengerConstructorBlueprintsT2[math.random(1,#ScavengerConstructorBlueprintsT2)]
									end
								elseif n > 36000 then
									local r = math.random(0,2)
									if r == 0 then
										blueprint = ScavengerConstructorBlueprintsT2[math.random(1,#ScavengerConstructorBlueprintsT2)]
									elseif r == 1 then
										blueprint = ScavengerConstructorBlueprintsT1[math.random(1,#ScavengerConstructorBlueprintsT1)]
									else
										blueprint = ScavengerConstructorBlueprintsStart[math.random(1,#ScavengerConstructorBlueprintsStart)]
									end
								elseif n > 18000 then
									local r = math.random(0,1)
									if r == 0 then
										blueprint = ScavengerConstructorBlueprintsT1[math.random(1,#ScavengerConstructorBlueprintsT1)]
									else
										blueprint = ScavengerConstructorBlueprintsStart[math.random(1,#ScavengerConstructorBlueprintsStart)]
									end
								else
									blueprint = ScavengerConstructorBlueprintsStart[math.random(1,#ScavengerConstructorBlueprintsStart)]
								end
							elseif posy <= 0 then	
								if n > 60000 then
									local r = math.random(0,3)
									if r == 0 then
										blueprint = ScavengerConstructorBlueprintsT3Sea[math.random(1,#ScavengerConstructorBlueprintsT3Sea)]
									elseif r == 1 then
										blueprint = ScavengerConstructorBlueprintsT2Sea[math.random(1,#ScavengerConstructorBlueprintsT2Sea)]
									elseif r == 2 then
										blueprint = ScavengerConstructorBlueprintsT1Sea[math.random(1,#ScavengerConstructorBlueprintsT1Sea)]
									else
										blueprint = ScavengerConstructorBlueprintsStartSea[math.random(1,#ScavengerConstructorBlueprintsStartSea)]
									end
								elseif n > 39000 then
									local r = math.random(0,2)
									if r == 0 then
										blueprint = ScavengerConstructorBlueprintsT2Sea[math.random(1,#ScavengerConstructorBlueprintsT2Sea)]
									elseif r == 1 then
										blueprint = ScavengerConstructorBlueprintsT1Sea[math.random(1,#ScavengerConstructorBlueprintsT1Sea)]
									else
										blueprint = ScavengerConstructorBlueprintsStartSea[math.random(1,#ScavengerConstructorBlueprintsStartSea)]
									end
								elseif n > 18000 then
									local r = math.random(0,1)
									if r == 0 then
										blueprint = ScavengerConstructorBlueprintsT1Sea[math.random(1,#ScavengerConstructorBlueprintsT1Sea)]
									else
										blueprint = ScavengerConstructorBlueprintsStartSea[math.random(1,#ScavengerConstructorBlueprintsStartSea)]
									end
								else
									blueprint = ScavengerConstructorBlueprintsStartSea[math.random(1,#ScavengerConstructorBlueprintsStartSea)]
								end	
							end
							
							posradius = blueprint(scav, posx, posy, posz, GaiaTeamID, true)
							canConstructHere = posOccupied(posx, posy, posz, posradius)
							if canConstructHere then
								canConstructHere = posCheck(posx, posy, posz, posradius)
							end
							if canConstructHere then
								-- let's do this shit
								blueprint(scav, posx, posy, posz, GaiaTeamID, false)
								local x = math.random(x-1000,x+1000)
								local z = math.random(z-1000,z+1000)
								local y = Spring.GetGroundHeight(x,z)
								Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift"})
								local x = math.random(x-100,x+100)
								local z = math.random(z-100,z+100)
								local y = Spring.GetGroundHeight(x,z)
								Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift"})
							else
								local x,y,z = Spring.GetUnitPosition(scav)
								local x = math.random(x-500,x+500)
								local z = math.random(z-500,z+500)
								local y = Spring.GetGroundHeight(x,z)
								Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift"})
								local x,y,z = Spring.GetUnitPosition(scav)
								local x = math.random(x-100,x+100)
								local z = math.random(z-100,z+100)
								local y = Spring.GetGroundHeight(x,z)
								Spring.GiveOrderToUnit(scav, CMD.MOVE,{x,y,z}, {"shift"})
							end