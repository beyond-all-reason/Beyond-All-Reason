local flare = piece "flare"


function walk()
end

function stopwalk()
end

function script.StartMoving()
end
	
function script.StopMoving()
end



function script.AimFromWeapon1()
	return flare
end

function script.QueryWeapon1()
	return flare
end
function script.AimWeapon1(heading, pitch)
	return true
end

function script.FireWeapon1()
	return true
end

function script.Shot1()
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

