--just copy from duck

function walk()
end

function stopwalk()
end

function script.StartMoving()
end
	
function script.StopMoving()
end


--[[
function script.Killed(recentDamage, maxHealth)
	local snd
	local rnd = math.random (0,100)
	local x,y,z = GetUnitPosition(unitID)
	
	if  rnd < 50 then
		snd = 'sounds/critters/duckcry1.wav'
	else
		snd = 'sounds/critters/duckcry2.wav'
	end
	PlaySoundFile(snd,volume,x,y,z,0,0,0,'battle')
end
]]--

