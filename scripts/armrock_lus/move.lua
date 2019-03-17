function walk()
	isInLoop = true
	while (isMoving) and not (isAiming) do
		if(isMoving ) and step == 1 and not (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(-40), ang(40),t)
			timedTurn(lleg, 1, ang(45), ang(0),t)
			timedTurn(lfoot, 1, ang(-20), ang(10),t)

			timedTurn(rthigh, 1, ang(10), ang(20),t)
			timedTurn(rleg, 1, ang(5), ang(0),t)
			timedTurn(rfoot, 1, ang(0), ang(10),t)
			
			timedTurn(lmisspod, 1, ang(10), ang(10),t)
			timedTurn(rshield, 1, ang(-10), ang(10),t)
			
			timedTurn(pelvis, 2, ang(0), ang(5),t)
			timedTurn(rthigh, 2, ang(0), ang(5),t)
			timedTurn(lthigh, 2, ang(0), ang(5),t)
			
			timedMove(pelvis, 2, dist(0.25), dist(0.25),t)
			
			Sleep(t)
			step = 2
		end
		if(isMoving ) and step == 2 and not (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(-60), ang(10),t)
			timedTurn(lleg, 1, ang(60), ang(15),t)
			timedTurn(lfoot, 1, ang(-20), ang(0),t)
			
			timedTurn(rthigh, 1, ang(30), ang(20),t)
			timedTurn(rleg, 1, ang(20), ang(15),t)
			timedTurn(rfoot, 1, ang(-10), ang(10),t)

			timedTurn(lmisspod, 1, ang(15), ang(5),t)
			timedTurn(rshield, 1, ang(-15), ang(5),t)
			
			timedTurn(pelvis, 2, ang(-5), ang(5),t)
			timedTurn(rthigh, 2, ang(5), ang(5),t)
			timedTurn(lthigh, 2, ang(5), ang(5),t)

			timedMove(pelvis, 2, dist(0.5), dist(0.25),t)
			
			Sleep(t)
			step = 3
		end
		if(isMoving ) and step == 3 and not (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(-40), ang(20),t)
			timedTurn(lleg, 1, ang(30), ang(30),t)
			timedTurn(lfoot, 1, ang(-20), ang(20),t)

			timedTurn(rthigh, 1, ang(35), ang(5),t)
			timedTurn(rleg, 1, ang(45), ang(25),t)
			timedTurn(rfoot, 1, ang(-10), ang(0),t)
			
			timedTurn(lmisspod, 1, ang(10), ang(5),t)
			timedTurn(rshield, 1, ang(-10), ang(5),t)
			
			timedTurn(pelvis, 2, ang(-10), ang(5),t)
			timedTurn(rthigh, 2, ang(10), ang(5),t)
			timedTurn(lthigh, 2, ang(10), ang(5),t)
			
			timedMove(pelvis, 2, dist(0.25), dist(0.25),t)
			
			Sleep(t)
			step = 4
		end
		if(isMoving ) and step == 4 and not (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(-10), ang(30),t)
			timedTurn(lleg, 1, ang(5), ang(25),t)
			timedTurn(lfoot, 1, ang(-10), ang(10), t)
			
			timedTurn(rthigh, 1, ang(0), ang(35),t)
			timedTurn(rleg, 1, ang(45), ang(0),t)
			timedTurn(rfoot, 1, ang(-10), ang(0),t)
		
			timedTurn(lmisspod, 1, ang(0), ang(5),t)
			timedTurn(rshield, 1, ang(0), ang(5),t)
		
			timedTurn(pelvis, 2, ang(-5), ang(5),t)
			timedTurn(rthigh, 2, ang(5), ang(5),t)
			timedTurn(lthigh, 2, ang(5), ang(5),t)
			
			timedMove(pelvis, 2, dist(0), dist(0.25),t)
			
			Sleep(t)
			step = 5
		end
		if(isMoving ) and step == 5 and not (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(10), ang(20),t)
			timedTurn(lleg, 1, ang(5), ang(0),t)
			timedTurn(lfoot, 1, ang(0), ang(10),t)

			timedTurn(rthigh, 1, ang(-40), ang(40),t)
			timedTurn(rleg, 1, ang(45), ang(0),t)
			timedTurn(rfoot, 1, ang(-20), ang(10),t)

			timedTurn(lmisspod, 1, ang(-10), ang(10),t)
			timedTurn(rshield, 1, ang(10), ang(10),t)
			
			timedTurn(pelvis, 2, ang(0), ang(5),t)
			timedTurn(rthigh, 2, ang(0), ang(5),t)
			timedTurn(lthigh, 2, ang(0), ang(5),t)
			
			timedMove(pelvis, 2, dist(0.25), dist(0.25),t)
			
			Sleep(t)
			step = 6
		end
		if(isMoving ) and step == 6 and not (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(30), ang(20),t)
			timedTurn(lleg, 1, ang(20), ang(15),t)
			timedTurn(lfoot, 1, ang(-10), ang(10),t)

			timedTurn(rthigh, 1, ang(-60), ang(20),t)
			timedTurn(rleg, 1, ang(60), ang(15),t)
			timedTurn(rfoot, 1, ang(-20), ang(10),t)

			timedTurn(lmisspod, 1, ang(-15), ang(5),t)
			timedTurn(rshield, 1, ang(15), ang(5),t)
			
			timedTurn(pelvis, 2, ang(5), ang(5),t)
			timedTurn(rthigh, 2, ang(-5), ang(5),t)
			timedTurn(lthigh, 2, ang(-5), ang(5),t)

			timedMove(pelvis, 2, dist(0.5), dist(0.25),t)
			
			Sleep(t)
			step = 7
		end
		if(isMoving ) and step == 7 and not (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(35), ang(5),t)
			timedTurn(lleg, 1, ang(45), ang(25),t)
			timedTurn(lfoot, 1, ang(-10), ang(0),t)
			
			timedTurn(rthigh, 1, ang(-40), ang(20),t)
			timedTurn(rleg, 1, ang(30), ang(30),t)
			timedTurn(rfoot, 1, ang(-20), ang(0),t)

			timedTurn(lmisspod, 1, ang(-10), ang(5),t)
			timedTurn(rshield, 1, ang(10), ang(5),t)
			
			timedTurn(pelvis, 2, ang(10), ang(5),t)
			timedTurn(rthigh, 2, ang(-10), ang(5),t)
			timedTurn(lthigh, 2, ang(-10), ang(5),t)
			
			timedMove(pelvis, 2, dist(0.25), dist(0.25),t)
			
			Sleep(t)
			step = 8
		end
		if(isMoving ) and step == 8 and not (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(0), ang(35),t)
			timedTurn(lleg, 1, ang(45), ang(0),t)
			timedTurn(lfoot, 1, ang(-10), ang(0),t)
			
			timedTurn(rthigh, 1, ang(-10), ang(30),t)
			timedTurn(rleg, 1, ang(5), ang(25),t)
			timedTurn(rfoot, 1, ang(-10), ang(10),t)

			timedTurn(lmisspod, 1, ang(0), ang(10),t)
			timedTurn(rshield, 1, ang(0), ang(10),t)
			
			timedTurn(pelvis, 2, ang(5), ang(5),t)
			timedTurn(rthigh, 2, ang(-5), ang(5),t)
			timedTurn(lthigh, 2, ang(-5), ang(5),t)
			
			timedMove(pelvis, 2, dist(0), dist(0.25),t)
			
			Sleep(t)
			step = 1
		end
	end
	isInLoop = false
end

function walklegs()
	isInLoop = true
	while (isMoving) and (isAiming) do
		if(isMoving ) and step == 1 and (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(-40), ang(40),t)
			timedTurn(lleg, 1, ang(45), ang(0),t)
			timedTurn(lfoot, 1, ang(-20), ang(10),t)

			timedTurn(rthigh, 1, ang(10), ang(20),t)
			timedTurn(rleg, 1, ang(5), ang(0),t)
			timedTurn(rfoot, 1, ang(0), ang(10),t)
			
			timedTurn(pelvis, 2, ang(0), ang(5),t)
			timedTurn(rthigh, 2, ang(0), ang(5),t)
			timedTurn(lthigh, 2, ang(0), ang(5),t)
			
			timedMove(pelvis, 2, dist(0.25), dist(0.25),t)
			
			Sleep(t)
			step = 2
		end
		if(isMoving ) and step == 2 and (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(-60), ang(10),t)
			timedTurn(lleg, 1, ang(60), ang(15),t)
			timedTurn(lfoot, 1, ang(-20), ang(0),t)
			
			timedTurn(rthigh, 1, ang(30), ang(20),t)
			timedTurn(rleg, 1, ang(20), ang(15),t)
			timedTurn(rfoot, 1, ang(-10), ang(10),t)
			
			timedTurn(pelvis, 2, ang(-5), ang(5),t)
			timedTurn(rthigh, 2, ang(5), ang(5),t)
			timedTurn(lthigh, 2, ang(5), ang(5),t)

			timedMove(pelvis, 2, dist(0.5), dist(0.25),t)
			
			Sleep(t)
			step = 3
		end
		if(isMoving ) and step == 3 and (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(-40), ang(20),t)
			timedTurn(lleg, 1, ang(30), ang(30),t)
			timedTurn(lfoot, 1, ang(-20), ang(20),t)

			timedTurn(rthigh, 1, ang(35), ang(5),t)
			timedTurn(rleg, 1, ang(45), ang(25),t)
			timedTurn(rfoot, 1, ang(-10), ang(0),t)
		
			timedTurn(pelvis, 2, ang(-10), ang(5),t)
			timedTurn(rthigh, 2, ang(10), ang(5),t)
			timedTurn(lthigh, 2, ang(10), ang(5),t)
			
			timedMove(pelvis, 2, dist(0.25), dist(0.25),t)
			
			Sleep(t)
			step = 4
		end
		if(isMoving ) and step == 4 and (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(-10), ang(30),t)
			timedTurn(lleg, 1, ang(5), ang(25),t)
			timedTurn(lfoot, 1, ang(-10), ang(10), t)
			
			timedTurn(rthigh, 1, ang(0), ang(35),t)
			timedTurn(rleg, 1, ang(45), ang(0),t)
			timedTurn(rfoot, 1, ang(-10), ang(0),t)
		
			timedTurn(pelvis, 2, ang(-5), ang(5),t)
			timedTurn(rthigh, 2, ang(5), ang(5),t)
			timedTurn(lthigh, 2, ang(5), ang(5),t)
			
			timedMove(pelvis, 2, dist(0), dist(0.25),t)
			
			Sleep(t)
			step = 5
		end
		if(isMoving ) and step == 5 and (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(10), ang(20),t)
			timedTurn(lleg, 1, ang(5), ang(0),t)
			timedTurn(lfoot, 1, ang(0), ang(10),t)

			timedTurn(rthigh, 1, ang(-40), ang(40),t)
			timedTurn(rleg, 1, ang(45), ang(0),t)
			timedTurn(rfoot, 1, ang(-20), ang(10),t)
		
			timedTurn(pelvis, 2, ang(0), ang(5),t)
			timedTurn(rthigh, 2, ang(0), ang(5),t)
			timedTurn(lthigh, 2, ang(0), ang(5),t)
			
			timedMove(pelvis, 2, dist(0.25), dist(0.25),t)
			
			Sleep(t)
			step = 6
		end
		if(isMoving ) and step == 6 and (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(30), ang(20),t)
			timedTurn(lleg, 1, ang(20), ang(15),t)
			timedTurn(lfoot, 1, ang(-10), ang(10),t)

			timedTurn(rthigh, 1, ang(-60), ang(20),t)
			timedTurn(rleg, 1, ang(60), ang(15),t)
			timedTurn(rfoot, 1, ang(-20), ang(10),t)
		
			timedTurn(pelvis, 2, ang(5), ang(5),t)
			timedTurn(rthigh, 2, ang(-5), ang(5),t)
			timedTurn(lthigh, 2, ang(-5), ang(5),t)

			timedMove(pelvis, 2, dist(0.5), dist(0.25),t)
			
			Sleep(t)
			step = 7
		end
		if(isMoving ) and step == 7 and (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(35), ang(5),t)
			timedTurn(lleg, 1, ang(45), ang(25),t)
			timedTurn(lfoot, 1, ang(-10), ang(0),t)
			
			timedTurn(rthigh, 1, ang(-40), ang(20),t)
			timedTurn(rleg, 1, ang(30), ang(30),t)
			timedTurn(rfoot, 1, ang(-20), ang(0),t)

			timedTurn(pelvis, 2, ang(10), ang(5),t)
			timedTurn(rthigh, 2, ang(-10), ang(5),t)
			timedTurn(lthigh, 2, ang(-10), ang(5),t)
			
			timedMove(pelvis, 2, dist(0.25), dist(0.25),t)
			
			Sleep(t)
			step = 8
		end
		if(isMoving ) and step == 8 and (isAiming) then
			local t = 8000 / currentSpeed
			timedTurn(lthigh, 1, ang(0), ang(35),t)
			timedTurn(lleg, 1, ang(45), ang(0),t)
			timedTurn(lfoot, 1, ang(-10), ang(0),t)
			
			timedTurn(rthigh, 1, ang(-10), ang(30),t)
			timedTurn(rleg, 1, ang(5), ang(25),t)
			timedTurn(rfoot, 1, ang(-10), ang(10),t)
		
			timedTurn(pelvis, 2, ang(5), ang(5),t)
			timedTurn(rthigh, 2, ang(-5), ang(5),t)
			timedTurn(lthigh, 2, ang(-5), ang(5),t)
			
			timedMove(pelvis, 2, dist(0), dist(0.25),t)
			
			Sleep(t)
			step = 1
		end
	end
	isInLoop = false
end

function RestoreLegs()
	timedMove(pelvis, 2, dist(0), ang(10), 500)
	timedTurn(pelvis, 2, ang(0), ang(10), 500)
	timedTurn(pelvis, 3, ang(0), ang(10), 500)
	timedTurn(lthigh, 1, ang(0), ang(40), 500)
	timedTurn(rthigh, 1, ang(0), ang(40), 500)
	timedTurn(rleg, 1, ang(0), ang(40), 500)
	timedTurn(rfoot, 1, ang(0), ang(40), 500)
	timedTurn(rfoot, 3, ang(0), ang(40), 500)
	timedTurn(lleg, 1, ang(0), ang(40), 500)
	timedTurn(lfoot, 1, ang(0), ang(40), 500)
end

function RestoreArms()
	timedTurn(torso, 2,  ang(0), ang(40), 500)
	timedTurn(torso, 1,  ang(0), ang(40), 500)
	timedTurn(torso, 3,  ang(0), ang(40), 500)
	timedTurn(lmisspod, 1, ang(0), ang(40), 500)
	timedTurn(rshield, 1, ang(0), ang(40), 500)
	timedMove(rshield, 1, dist(0), dist(1.5), 500)
end