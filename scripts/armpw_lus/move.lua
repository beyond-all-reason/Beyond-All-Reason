
function walk()
	isInLoop = true
	while (isMoving) and not (isAiming) do
		if(isMoving) and step == 1 and not (isAiming) then
			Move(pelvis, 2,  dist(-0.539978), dist(4.608433) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(10.692308), ang(91.253318) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-53.489011), ang(456.501042) *  currentSpeed / 100)
			Turn(torso, 2,  ang(5.747253), ang(49.049832) *  currentSpeed / 100)
			Turn(luparm, 1,  ang(38.670330), ang(330.031265) *  currentSpeed / 100)
			Turn(ruparm, 1,  ang(-18.093407), ang(154.417870) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(53.489011), ang(456.501042) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(53.489011), ang(456.501042) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-37.846154), ang(322.997349) *  currentSpeed / 100)
			Sleep(6800 / currentSpeed)
			step = 2
		end
		if(isMoving ) and step == 2 and not (isAiming) then
		
			Move(pelvis, 2,  dist(-0.300000), dist(2.862388) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-10.280220), ang(250.154250) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-41.549451), ang(142.411619) *  currentSpeed / 100)
			Turn(torso, 2,  ang(3.280220), ang(29.426056) *  currentSpeed / 100)
			Turn(luparm, 1,  ang(32.093407), ang(78.447636) *  currentSpeed / 100)
			Turn(ruparm, 1,  ang(-11.093407), ang(83.493976) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(41.967033), ang(137.430822) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(81.879121), ang(338.629023) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-31.258242), ang(78.578709) *  currentSpeed / 100)
			Sleep(5300 / currentSpeed)
			step = 3

		end
		if(isMoving ) and step == 3 and not (isAiming) then
		
			Move(pelvis, 2,  dist(-0.150000), dist(1.789157) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-18.093407), ang(93.193435) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-24.681319), ang(201.198201) *  currentSpeed / 100)
			Turn(torso, 2,  ang(0.000000), ang(39.125516) *  currentSpeed / 100)
			Turn(luparm, 1,  ang(27.148352), ang(58.983186) *  currentSpeed / 100)
			Turn(ruparm, 1,  ang(-7.401099), ang(44.040782) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(24.681319), ang(206.178998) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(85.582418), ang(44.171856) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-23.027473), ang(98.174233) *  currentSpeed / 100)
			Sleep(3800 / currentSpeed)
			step = 4
		end
		if(isMoving ) and step == 4 and not (isAiming) then
		
			Move(pelvis, 2,  dist(0.000000), dist(2.970000) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-42.379121), ang(480.857137) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(5.335165), ang(594.326383) *  currentSpeed / 100)
			Turn(torso, 2,  ang(-3.280220), ang(64.948356) *  currentSpeed / 100)
			Turn(luparm, 1,  ang(8.214286), ang(374.894507) *  currentSpeed / 100)
			Turn(ruparm, 1,  ang(9.027473), ang(325.285726) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(6.571429), ang(358.575822) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-9.027473), ang(178.743965) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(104.516484), ang(374.894507) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(0.000000), ang(455.943965) *  currentSpeed / 100)
			Sleep(3000 / currentSpeed)
			step = 5
		end
		if(isMoving ) and step == 5 and not (isAiming) then
		
			Move(pelvis, 2,  dist(-0.200000), dist(2.385542) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-69.945055), ang(328.798490) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(14.802198), ang(112.920032) *  currentSpeed / 100)
			Turn(torso, 2,  ang(-6.159341), ang(34.341323) *  currentSpeed / 100)
			Turn(luparm, 1,  ang(-3.692308), ang(142.018410) *  currentSpeed / 100)
			Turn(ruparm, 1,  ang(17.681319), ang(103.220573) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(15.214286), ang(103.089499) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-25.093407), ang(191.629815) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(107.401099), ang(34.406854) *  currentSpeed / 100)
			Sleep(3800 / currentSpeed)
			step = 6
		end
		if(isMoving ) and step == 6 and not (isAiming) then
		
			Move(pelvis, 2,  dist(-0.400000), dist(2.385542) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-75.291209), ang(63.767379) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(20.137363), ang(63.636305) *  currentSpeed / 100)
			Turn(torso, 2,  ang(-8.214286), ang(24.510790) *  currentSpeed / 100)
			Turn(luparm, 1,  ang(-10.280220), ang(78.578709) *  currentSpeed / 100)
			Turn(ruparm, 1,  ang(25.093407), ang(88.409242) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(26.324176), ang(132.515555) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-33.725275), ang(102.958426) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(64.604396), ang(510.466698) *  currentSpeed / 100)
			Sleep(5300 / currentSpeed)
			step = 7
		end
		if(isMoving ) and step == 7 and not (isAiming) then
		
			Move(pelvis, 2,  dist(-0.550000), dist(1.280172) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-56.780220), ang(157.981716) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(24.258242), ang(35.169571) *  currentSpeed / 100)
			Turn(torso, 2,  ang(-6.159341), ang(17.537893) *  currentSpeed / 100)
			Turn(luparm, 1,  ang(-23.857143), ang(115.872015) *  currentSpeed / 100)
			Turn(ruparm, 1,  ang(31.258242), ang(52.613678) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(38.670330), ang(105.368038) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-38.670330), ang(42.203487) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(56.780220), ang(66.775295) *  currentSpeed / 100)
			Sleep(6800 / currentSpeed)
			step = 8
		end
		if(isMoving ) and step == 8 and not (isAiming) then
		
			Move(pelvis, 2,  dist(-0.300000), dist(2.981928) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-44.846154), ang(142.346088) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(5.335165), ang(225.708991) *  currentSpeed / 100)
			Turn(torso, 2,  ang(-3.280220), ang(34.341323) *  currentSpeed / 100)
			Turn(luparm, 1,  ang(-16.038462), ang(93.258966) *  currentSpeed / 100)
			Turn(ruparm, 1,  ang(19.725275), ang(137.561896) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(67.071429), ang(338.760097) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-12.324176), ang(146.999208) *  currentSpeed / 100)
			Sleep(5300 / currentSpeed)
			step = 9
		end
		if(isMoving ) and step == 9 and not (isAiming) then
		
			Move(pelvis, 2,  dist(-0.139978), dist(1.908696) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-22.615385), ang(265.162184) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-12.736264), ang(215.550780) *  currentSpeed / 100)
			Turn(torso, 2,  ang(0.000000), ang(39.125516) *  currentSpeed / 100)
			Turn(luparm, 1,  ang(-1.637363), ang(171.772145) *  currentSpeed / 100)
			Turn(ruparm, 1,  ang(10.280220), ang(112.657885) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(79.412088), ang(147.195812) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-27.967033), ang(127.665832) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(37.027473), ang(235.605055) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-15.626374), ang(39.387663) *  currentSpeed / 100)
			Sleep(3800 / currentSpeed)
			step = 10
		end
		if( isMoving ) and step == 10 and not (isAiming) then
		
			Move(pelvis, 2,  dist(0.000000), dist(2.771564) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(2.868132), ang(504.573637) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-42.379121), ang(586.928569) *  currentSpeed / 100)
			Turn(torso, 2,  ang(3.280220), ang(64.948356) *  currentSpeed / 100)
			Turn(luparm, 1,  ang(11.505495), ang(260.228588) *  currentSpeed / 100)
			Turn(ruparm, 1,  ang(1.225275), ang(179.287911) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(90.104396), ang(211.707698) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-15.214286), ang(252.504391) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(6.571429), ang(603.029671) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-9.434066), ang(122.607698) *  currentSpeed / 100)
			Sleep(3000 / currentSpeed)
			step = 11
		end
		if(isMoving ) and step == 11 and not (isAiming) then
		
			Move(pelvis, 2,  dist(-0.189978), dist(2.266003) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(13.159341), ang(122.750565) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-57.192308), ang(176.687411) *  currentSpeed / 100)
			Turn(torso, 2,  ang(6.159341), ang(34.341323) *  currentSpeed / 100)
			Turn(luparm, 1,  ang(21.390110), ang(117.900830) *  currentSpeed / 100)
			Turn(ruparm, 1,  ang(-6.989011), ang(97.977628) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-19.324176), ang(117.966372) *  currentSpeed / 100)
			Sleep(3800 / currentSpeed)
			step = 12
		end
		if(isMoving ) and step == 12 and not (isAiming) then
			Move(pelvis, 2,  dist(-0.400000), dist(2.505082) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(16.445055), ang(39.191047) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-67.071429), ang(117.835299) *  currentSpeed / 100)
			Turn(torso, 2,  ang(8.214286), ang(24.510790) *  currentSpeed / 100)
			Turn(luparm, 1,  ang(25.093407), ang(44.171856) *  currentSpeed / 100)
			Turn(ruparm, 1,  ang(-12.324176), ang(63.636305) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(55.549451), ang(412.161392) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-2.868132), ang(147.261355) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(24.681319), ang(216.009531) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-33.324176), ang(166.987952) *  currentSpeed / 100)
			Sleep(5300 / currentSpeed)
			step = 1
		end
	end
	isInLoop = false
end

function dist(v)
	return v
end

function walklegs()
	isInLoop = true
	while (isMoving ) and (isAiming) do
		if(isMoving ) and step == 1 and (isAiming) then
			Move(pelvis, 2,  dist(-0.539978), dist(4.608433) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(10.692308), ang(91.253318) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-53.489011), ang(456.501042) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(53.489011), ang(456.501042) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(53.489011), ang(456.501042) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-37.846154), ang(322.997349) *  currentSpeed / 100)
			Sleep(6800 / currentSpeed)
			step = 2
		end
		if(isMoving ) and step == 2 and (isAiming) then
		
			Move(pelvis, 2,  dist(-0.300000), dist(2.862388) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-10.280220), ang(250.154250) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-41.549451), ang(142.411619) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(41.967033), ang(137.430822) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(81.879121), ang(338.629023) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-31.258242), ang(78.578709) *  currentSpeed / 100)
			Sleep(5300 / currentSpeed)
			step = 3
		end
		if(isMoving ) and step == 3 and (isAiming) then
		
			Move(pelvis, 2,  dist(-0.150000), dist(1.789157) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-18.093407), ang(93.193435) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-24.681319), ang(201.198201) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(24.681319), ang(206.178998) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(85.582418), ang(44.171856) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-23.027473), ang(98.174233) *  currentSpeed / 100)
			Sleep(3800 / currentSpeed)
			step = 4
		end
		if(isMoving ) and step == 4 and (isAiming) then
		
			Move(pelvis, 2,  dist(0.000000), dist(2.970000) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-42.379121), ang(480.857137) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(5.335165), ang(594.326383) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(6.571429), ang(358.575822) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-9.027473), ang(178.743965) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(104.516484), ang(374.894507) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(0.000000), ang(455.943965) *  currentSpeed / 100)
			Sleep(3000 / currentSpeed)
			step = 5
		end
		if(isMoving ) and step == 5 and (isAiming) then
		
			Move(pelvis, 2,  dist(-0.200000), dist(2.385542) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-69.945055), ang(328.798490) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(14.802198), ang(112.920032) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(15.214286), ang(103.089499) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-25.093407), ang(191.629815) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(107.401099), ang(34.406854) *  currentSpeed / 100)
			Sleep(3800 / currentSpeed)
			step = 6
		end
		if(isMoving ) and step == 6 and (isAiming) then
		
			Move(pelvis, 2,  dist(-0.400000), dist(2.385542) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-75.291209), ang(63.767379) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(20.137363), ang(63.636305) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(26.324176), ang(132.515555) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-33.725275), ang(102.958426) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(64.604396), ang(510.466698) *  currentSpeed / 100)
			Sleep(5300 / currentSpeed)
			step = 7
		end
		if(isMoving ) and step == 7 and (isAiming) then
		
			Move(pelvis, 2,  dist(-0.550000), dist(1.280172) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-56.780220), ang(157.981716) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(24.258242), ang(35.169571) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(38.670330), ang(105.368038) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-38.670330), ang(42.203487) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(56.780220), ang(66.775295) *  currentSpeed / 100)
			Sleep(6800 / currentSpeed)
			step = 8
		end
		if(isMoving ) and step == 8 and (isAiming) then
		
			Move(pelvis, 2,  dist(-0.300000), dist(2.981928) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-44.846154), ang(142.346088) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(5.335165), ang(225.708991) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(67.071429), ang(338.760097) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-12.324176), ang(146.999208) *  currentSpeed / 100)
			Sleep(5300 / currentSpeed)
			step = 9
		end
		if(isMoving ) and step == 9 and (isAiming) then
		
			Move(pelvis, 2,  dist(-0.139978), dist(1.908696) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(-22.615385), ang(265.162184) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-12.736264), ang(215.550780) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(79.412088), ang(147.195812) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-27.967033), ang(127.665832) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(37.027473), ang(235.605055) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-15.626374), ang(39.387663) *  currentSpeed / 100)
			Sleep(3800 / currentSpeed)
			step = 10
		end
		if( isMoving ) and step == 10 and (isAiming) then
		
			Move(pelvis, 2,  dist(0.000000), dist(2.771564) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(2.868132), ang(504.573637) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-42.379121), ang(586.928569) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(90.104396), ang(211.707698) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-15.214286), ang(252.504391) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(6.571429), ang(603.029671) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-9.434066), ang(122.607698) *  currentSpeed / 100)
			Sleep(3000 / currentSpeed)
			step = 11
		end
		if(isMoving ) and step == 11 and (isAiming) then
		
			Move(pelvis, 2,  dist(-0.189978), dist(2.266003) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(13.159341), ang(122.750565) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-57.192308), ang(176.687411) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-19.324176), ang(117.966372) *  currentSpeed / 100)
			Sleep(3800 / currentSpeed)
			step = 12
		end
		if(isMoving ) and step == 12 and (isAiming) then
			Move(pelvis, 2,  dist(-0.400000), dist(2.505082) *  currentSpeed / 100)
			Turn(rthigh, 1,  ang(16.445055), ang(39.191047) *  currentSpeed / 100)
			Turn(lthigh, 1,  ang(-67.071429), ang(117.835299) *  currentSpeed / 100)
			Turn(lleg, 1,  ang(55.549451), ang(412.161392) *  currentSpeed / 100)
			Turn(lfoot, 1,  ang(-2.868132), ang(147.261355) *  currentSpeed / 100)
			Turn(rleg, 1,  ang(24.681319), ang(216.009531) *  currentSpeed / 100)
			Turn(rfoot, 1,  ang(-33.324176), ang(166.987952) *  currentSpeed / 100)
			Sleep(5300 / currentSpeed)
			step = 1
		end
	end
	isInLoop = false
end

function RestoreLegs()
	Move(pelvis, 2,  dist(0), dist(120))
	Turn(rthigh, 1,  ang(0), ang(400))
	Turn(lthigh, 1,  ang(0), ang(400))
	Turn(lleg, 1,  ang(0), ang(400))
	Turn(lfoot, 1,  ang(0), ang(400))
	Turn(rleg, 1,  ang(0), ang(400))
	Turn(rfoot, 1,  ang(0), ang(400))
end

function RestoreArms()
	Turn(torso, 2,  ang(0), ang(120))
	Turn(luparm, 1,  ang(0), ang(120))
	Turn(ruparm, 1,  ang(0), ang(120))
	Turn(lloarm, 1,  ang(-45), ang(120))
	Turn(rloarm, 1,  ang(-45), ang(120))
end