local groundx2 = piece 'groundx2' 
local hips = piece 'hips' 
local body = piece 'body' 
local lleg = piece 'lleg' 
local lfoot = piece 'lfoot' 
local rleg = piece 'rleg' 
local rfoot = piece 'rfoot' 
local head = piece 'head' 
local laser = piece 'laser' 
local laserflare = piece 'laserflare' 
local gun = piece 'gun' 
local gunflare = piece 'gunflare' 

local gun_1 = 1

-- Signal definitions
local SIG_WALK = 2
local SIG_STOP = 4
local SIG_AIM = 8
local SIG_AIM_3 = 16

local _, basepos, _

local function still_building_p()
	local _,_,_,_,buildProgress = Spring.GetUnitHealth(unitID);
	if (buildProgress == 1) then return false; else return true; end
end

local function get_health_percent()
	local health,maxHealth = Spring.GetUnitHealth(unitID);
	return ((health / maxHealth) * 100);
end

local function SmokeUnit(healthpercent, sleeptime, smoketype)
	while still_building_p() do Sleep(400); end
	
	while (true) do
		local health_percent = get_health_percent();
		
		if (health_percent < 66) then
			local smoketype = 258;
			if (math.random(1, 66) < health_percent) then smoketype = 257; end
			Spring.UnitScript.EmitSfx(body, smoketype);
		end
		
		local sleep_time = health_percent * 50;
		if (sleep_time < 200) then 
		  sleep_time = 200; end
		Sleep(sleep_time);
	end
end

local function walklegs()
	SetSignalMask( SIG_WALK)
	while true do
	
		Move( body , y_axis, 0.000000  )
		Move( head , y_axis, 0.000000 , 1.993289 )
		Move( rfoot , y_axis, 0.000000  )
		Move( lfoot , y_axis, 0.000000  )
		Turn( lleg , x_axis, math.rad(-41.346154), math.rad(34.353199) )
		Turn( rleg , x_axis, math.rad(54.725275), math.rad(133.397005) )
		Turn( rfoot , x_axis, math.rad(-34.648352), math.rad(46.437053) )
		Turn( lfoot , x_axis, math.rad(13.368132), math.rad(106.929349) )
		Sleep( 106)
		Move( body , z_axis, 0.350000 , 1.789157 )
		Move( lleg , y_axis, -0.200000 , 7.394978 )
		Move( rleg , y_axis, 0.500000 , 3.936347 )
		Turn( hips , z_axis, math.rad(-(5.159341)), math.rad(75.891706) )
		Turn( body , x_axis, math.rad(6.071429), math.rad(43.647561) )
		Turn( lleg , x_axis, math.rad(-41.346154) )
		Turn( rleg , x_axis, math.rad(55.335165), math.rad(7.274592) )
		Turn( rfoot , x_axis, math.rad(-17.934066), math.rad(199.363170) )
		Turn( lfoot , x_axis, math.rad(34.648352), math.rad(253.824311) )
		Sleep( 58)
		Move( body , z_axis, 0.700000 , 4.174699 )
		Move( lleg , y_axis, 0.639978 , 10.019015 )
		Move( rleg , y_axis, 1.000000 , 5.963855 )
		Turn( hips , z_axis, math.rad(-(10.324176)), math.rad(61.604658) )
		Turn( body , x_axis, math.rad(12.159341), math.rad(72.614854) )
		Turn( lleg , x_axis, math.rad(-32.225275), math.rad(108.791207) )
		Turn( rleg , x_axis, math.rad(55.945055), math.rad(7.274592) )
		Turn( rfoot , x_axis, math.rad(-1.203297), math.rad(199.559775) )
		Turn( lfoot , x_axis, math.rad(17.016484), math.rad(210.307823) )
		Sleep( 49)
		Move( lleg , y_axis, 1.350000 , 8.468937 )
		Move( rleg , y_axis, 1.900000 , 10.734940 )
		Move( rfoot , y_axis, 0.000000  )
		Turn( hips , z_axis, math.rad(-(14.582418)), math.rad(50.791079) )
		Turn( lleg , x_axis, math.rad(-10.934066), math.rad(253.955384) )
		Turn( rleg , x_axis, math.rad(18.225275), math.rad(449.910629) )
		Turn( rfoot , x_axis, math.rad(-17.626374), math.rad(195.889714) )
		Turn( lfoot , x_axis, 0, math.rad(202.967701) )
		Sleep( 55)
		Move( lleg , y_axis, 0.950000 , 2.657718 )
		Move( rleg , y_axis, 1.939978 , 0.265626 )
		Move( rfoot , y_axis, 0.000000  )
		Turn( hips , z_axis, math.rad(-(12.159341)), math.rad(16.099639) )
		Turn( lleg , x_axis, math.rad(3.027473), math.rad(92.764588) )
		Turn( rleg , x_axis, math.rad(4.857143), math.rad(88.821817) )
		Turn( rfoot , x_axis, math.rad(-22.192308), math.rad(30.337414) )
		Turn( rfoot , y_axis, 0 )
		Turn( lfoot , x_axis, math.rad(-16.714286), math.rad(111.054652) )
		Sleep( 107)
		Move( hips , z_axis, 0.000000  )
		Move( lleg , y_axis, 0.950000  )
		Move( rleg , y_axis, 1.989978 , 0.332215 )
		Move( rfoot , y_axis, 0.000000  )
		Turn( hips , z_axis, math.rad(-(9.714286)), math.rad(16.245667) )
		Turn( lleg , x_axis, math.rad(11.549451), math.rad(56.622538) )
		Turn( rleg , x_axis, math.rad(-8.500000), math.rad(88.748802) )
		Turn( rfoot , x_axis, math.rad(-26.747253), math.rad(30.264400) )
		Turn( rfoot , y_axis, 0 )
		Turn( lfoot , x_axis, math.rad(-24.324176), math.rad(50.562356) )
		Sleep( 122)
		Move( hips , z_axis, 0.000000  )
		Move( body , z_axis, 0.469983 , 1.528301 )
		Move( lleg , y_axis, 0.469983 , 3.189375 )
		Move( rleg , y_axis, 1.769983 , 1.461712 )
		Turn( hips , z_axis, math.rad(-(5.769231)), math.rad(26.212110) )
		Turn( body , x_axis, math.rad(8.802198), math.rad(22.305849) )
		Turn( lleg , x_axis, math.rad(17.016484), math.rad(36.324582) )
		Turn( rleg , x_axis, math.rad(-25.225275), math.rad(111.127666) )
		Turn( rfoot , x_axis, math.rad(-8.181319), math.rad(123.357548) )
		Turn( lfoot , x_axis, math.rad(-20.670330), math.rad(24.277232) )
		Sleep( 129)
		Move( hips , z_axis, 0.000000  )
		Move( body , z_axis, 0.250000 , 1.196611 )
		Move( lleg , y_axis, 0.000000 , 2.556501 )
		Move( rleg , y_axis, 1.539978 , 1.251126 )
		Turn( hips , z_axis, math.rad(-(1.813187)), math.rad(21.519140) )
		Turn( body , x_axis, math.rad(5.467033), math.rad(18.141832) )
		Turn( lleg , x_axis, math.rad(29.791209), math.rad(69.488889) )
		Turn( rleg , x_axis, math.rad(-41.956044), math.rad(91.008029) )
		Turn( rfoot , x_axis, math.rad(10.324176), math.rad(100.661759) )
		Turn( lfoot , x_axis, math.rad(-29.181319), math.rad(46.296039) )
		Sleep( 150)
		Move( lleg , y_axis, 0.000000  )
		Move( rleg , y_axis, 0.819983 , 4.783859 )
		Turn( hips , z_axis, math.rad(-(0.901099)), math.rad(6.060182) )
		Turn( body , x_axis, math.rad(2.725275), math.rad(18.217050) )
		Turn( lleg , x_axis, math.rad(38.005495), math.rad(54.578142) )
		Turn( rfoot , x_axis, math.rad(10.324176) )
		Turn( lfoot , x_axis, math.rad(-33.137363), math.rad(26.285125) )
		Sleep( 121)
		Move( lleg , y_axis, 0.000000  )
		Move( rleg , y_axis, 0.900000 , 0.682904 )
		Turn( hips , z_axis, math.rad(-(0.000000)), math.rad(7.690414) )
		Turn( body , x_axis, 0, math.rad(23.258812) )
		Turn( lleg , x_axis, math.rad(55.945055), math.rad(153.104866) )
		Turn( rfoot , x_axis, math.rad(1.203297), math.rad(77.841985) )
		Turn( lfoot , x_axis, math.rad(-31.615385), math.rad(12.989295) )
		Sleep( 83)
		Move( body , z_axis, 0.469983 , 1.877441 )
		Move( lleg , y_axis, 0.500000 , 4.267241 )
		Turn( hips , z_axis, math.rad(-(-3.324176)), math.rad(28.370123) )
		Turn( body , x_axis, math.rad(5.769231), math.rad(49.237403) )
		Turn( lleg , x_axis, math.rad(46.214286), math.rad(83.047080) )
		Turn( rleg , x_axis, math.rad(-51.082418), math.rad(77.888882) )
		Turn( rfoot , x_axis, math.rad(15.802198), math.rad(124.594069) )
		Turn( lfoot , x_axis, math.rad(-19.445055), math.rad(103.867472) )
		Sleep( 67)
		Move( body , z_axis, 0.700000 , 2.743576 )
		Move( lleg , y_axis, 1.000000 , 5.963855 )
		Turn( hips , z_axis, math.rad(-(-6.681319)), math.rad(40.043031) )
		Turn( body , x_axis, math.rad(11.549451), math.rad(68.944793) )
		Turn( lleg , x_axis, math.rad(55.335165), math.rad(108.791207) )
		Turn( rleg , x_axis, math.rad(-60.203297), math.rad(108.791207) )
		Turn( rfoot , x_axis, math.rad(45.604396), math.rad(355.472000) )
		Turn( lfoot , x_axis, math.rad(-12.159341), math.rad(86.901890) )
		Sleep( 51)
		Move( hips , y_axis, -0.219983  )
		Move( lleg , y_axis, 1.289978 , 3.458774 )
		Move( rleg , y_axis, 0.619983 , 3.339962 )
		Turn( hips , z_axis, math.rad(-(-11.247253)), math.rad(54.461140) )
		Turn( lleg , x_axis, math.rad(36.780220), math.rad(221.318019) )
		Turn( rleg , x_axis, math.rad(-46.214286), math.rad(166.856878) )
		Turn( rfoot , x_axis, math.rad(31.923077), math.rad(163.186817) )
		Turn( lfoot , x_axis, math.rad(-14.582418), math.rad(28.901762) )
		Sleep( 39)
		Move( hips , y_axis, -0.450000 , 2.743576 )
		Move( lleg , y_axis, 1.589978 , 3.578313 )
		Move( rleg , y_axis, 1.129999 , 6.083323 )
		Turn( hips , z_axis, math.rad(-(-15.802198)), math.rad(54.330067) )
		Turn( lleg , x_axis, math.rad(18.225275), math.rad(221.318019) )
		Turn( rleg , x_axis, math.rad(-32.225275), math.rad(166.856878) )
		Turn( rfoot , x_axis, math.rad(18.225275), math.rad(163.383421) )
		Turn( lfoot , x_axis, math.rad(-17.016484), math.rad(29.032835) )
		Sleep( 55)
		Move( lleg , y_axis, 1.789978 , 1.706897 )
		Move( rleg , y_axis, 1.339978 , 1.792062 )
		Turn( hips , z_axis, math.rad(-(-13.368132)), math.rad(20.773494) )
		Turn( lleg , x_axis, math.rad(4.549451), math.rad(116.716084) )
		Turn( rleg , x_axis, math.rad(-18.538462), math.rad(116.809870) )
		Turn( rfoot , x_axis, math.rad(4.549451), math.rad(116.716084) )
		Turn( lfoot , x_axis, math.rad(-21.582418), math.rad(38.967885) )
		Sleep( 69)
		Move( lleg , y_axis, 1.989978 , 1.706897 )
		Move( rleg , y_axis, 1.539978 , 1.706897 )
		Turn( hips , z_axis, math.rad(-(-10.934066)), math.rad(20.773494) )
		Turn( lleg , x_axis, math.rad(-9.104396), math.rad(116.528522) )
		Turn( rleg , x_axis, math.rad(-4.857143), math.rad(116.762981) )
		Turn( rfoot , x_axis, math.rad(-9.104396), math.rad(116.528522) )
		Turn( lfoot , x_axis, math.rad(-26.137363), math.rad(38.874100) )
		Sleep( 97)
		Move( body , z_axis, 0.400000 , 1.993289 )
		Move( lleg , y_axis, 1.419983 , 3.787215 )
		Move( rleg , y_axis, 0.939978 , 3.986577 )
		Turn( hips , z_axis, math.rad(-(-6.681319)), math.rad(28.256507) )
		Turn( body , x_axis, math.rad(8.181319), math.rad(22.378864) )
		Turn( lleg , x_axis, math.rad(-30.401099), math.rad(141.501584) )
		Turn( rleg , x_axis, math.rad(4.857143), math.rad(64.544585) )
		Turn( rfoot , x_axis, math.rad(-14.890110), math.rad(38.441992) )
		Turn( lfoot , x_axis, math.rad(-15.192308), math.rad(72.722178) )
		Sleep( 127)
		Move( body , z_axis, 0.100000 , 1.631868 )
		Move( lleg , y_axis, 0.839978 , 3.154972 )
		Move( rleg , y_axis, 0.350000 , 3.209221 )
		Turn( hips , z_axis, math.rad(-(-2.412088)), math.rad(23.222740) )
		Turn( body , x_axis, math.rad(4.857143), math.rad(18.082056) )
		Turn( lleg , x_axis, math.rad(-51.692308), math.rad(115.814818) )
		Turn( rleg , x_axis, math.rad(14.582418), math.rad(52.901221) )
		Turn( rfoot , x_axis, math.rad(-20.670330), math.rad(31.441856) )
		Turn( lfoot , x_axis, math.rad(-4.247253), math.rad(59.536288) )
		Sleep( 136)
	Move( hips , y_axis, -0.219983 , 1.251191 )
	Move( hips , z_axis, 0.000000  )
	Move( body , z_axis, 0.500000 , 2.175824 )
	Move( lleg , y_axis, 0.419983 , 2.284588 )
	Move( rleg , y_axis, 0.169983 , 0.979213 )
	Turn( hips , z_axis, math.rad(-(-1.203297)), math.rad(6.575292) )
	Turn( body , x_axis, math.rad(2.412088), math.rad(13.300024) )
	Turn( lleg , x_axis, math.rad(-46.516484), math.rad(28.154207) )
	Turn( rleg , x_axis, math.rad(34.648352), math.rad(109.149861) )
	Turn( rfoot , x_axis, math.rad(-27.659341), math.rad(38.017148) )
	Turn( rfoot , y_axis, 0 )
	Turn( lfoot , x_axis, math.rad(-2.725275), math.rad(8.278891) )
	Sleep( 137)
	end
end

local function stoped()
	SetSignalMask( SIG_STOP)
	Move( body , x_axis, 0.000000 , 1.000000 )
	Turn( rleg , x_axis, 0, math.rad(200.000000) )
	Turn( rfoot , x_axis, 0, math.rad(200.000000) )
	Turn( lleg , x_axis, 0, math.rad(200.000000) )
	Turn( lfoot , x_axis, 0, math.rad(200.000000) )
end

function script.Create()
	Hide( gunflare)
	Hide( laserflare)
	StartThread(SmokeUnit)
end

function script.StartMoving()
	Signal( SIG_STOP)
	StartThread(walklegs)
end

function script.StopMoving()
	Signal( SIG_WALK)
	StartThread(stoped)
end

local function RestoreAfterDelay()
	Sleep( 3000)
	Turn( head , y_axis, 0, math.rad(90.000000))
	WaitForTurn(head, y_axis)
end

function script.AimWeapon(num, heading, pitch)
	local _, basepos, _ = Spring.GetUnitPosition(unitID)
	if num == 2 then
		Signal( SIG_AIM)
		SetSignalMask( SIG_AIM)
		Turn( head , y_axis, heading , math.rad(200.000000) )
		WaitForTurn(head, y_axis)
		--Spring.Echo("Weapon one position :" .. basepos)
		StartThread(RestoreAfterDelay)
		if basepos > -18 then
			return true
		else
			return false
		end
	elseif num == 1 then
		Signal( SIG_AIM_3)
		SetSignalMask( SIG_AIM_3)
		Turn( head , y_axis, heading , math.rad(60.000000) )
		WaitForTurn(head, y_axis)
		--Spring.Echo("Weapon two position :" .. basepos)
		if basepos < -16 then
			return true
		else
			return false
		end
	
	end
end

function script.FireWeapon(num)
	if num == 2 then
		if gun_1 == 1 then
			Sleep( 200)
		else
			Sleep( 200)
		end
		gun_1 = gun_1 + 1
		if gun_1 == 3 then
		  gun_1 = 1
		end
	elseif num == 1 then
		Sleep( 200)
	end
end

function script.AimFromWeapon(num)
	return head
end

function script.QueryWeapon(num)
	  if num == 1 then
		    return head
	  elseif num == 2 then
		    if gun_1 == 1 then
		    return gunflare --laserflare
		  else
		    return laserflare --gunflare
		    end
	 end
end

function script.Killed(recentDamage, maxHealth)
	local severity = recentDamage / maxHealth

	if  (severity <= .25)  then
		Explode(body, SFX.NONE)
		Explode(gun, SFX.NONE)
		Explode(head, SFX.NONE)
		Explode(hips, SFX.NONE)
		Explode(lfoot, SFX.NONE)
		Explode(lleg, SFX.NONE)
		Explode(rfoot, SFX.NONE)
		Explode(rleg, SFX.NONE)
			return 1
	
	elseif  (severity <= .50)  then
		Explode(body, SFX.NONE)
		Explode(gun, SFX.FALL)
		Explode(head, SFX.SHATTER)
		Explode(hips, SFX.FALL)
		Explode(lfoot, SFX.FALL)
		Explode(lleg, SFX.FALL)
		Explode(rfoot, SFX.FALL)
		Explode(rleg, SFX.FALL)
		return 2
	else
		Explode(body, SFX.NONE)
		Explode(gun, SFX.FALL + SFX.SMOKE  + SFX.FIRE  + SFX.EXPLODE_ON_HIT )
		Explode(head, SFX.SHATTER)
		Explode(hips,  SFX.FALL + SFX.SMOKE  + SFX.FIRE  + SFX.EXPLODE_ON_HIT )
		Explode(lfoot,  SFX.FALL + SFX.SMOKE  + SFX.FIRE  + SFX.EXPLODE_ON_HIT )
		Explode(lleg,  SFX.FALL + SFX.SMOKE  + SFX.FIRE  + SFX.EXPLODE_ON_HIT )
		Explode(rfoot,  SFX.FALL + SFX.SMOKE  + SFX.FIRE  + SFX.EXPLODE_ON_HIT )
		Explode(rleg,  SFX.FALL + SFX.SMOKE  + SFX.FIRE  + SFX.EXPLODE_ON_HIT )

	return 3
	end
end