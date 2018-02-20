------------------------------------------------------
-- License:	Public Domain
-- Author:	Nemo, Smoth
-- Date:	3/18/2011
-------------------------------------------------------
local	inStance	= false

function walk()
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)	
	
	Turn(right_l, z_axis, 0, math.rad(135))
	Turn(left_l, z_axis, 0, math.rad(130))
	Turn(foot_l, y_axis, 0, math.rad(130))
	Turn(foot_r, y_axis, 0, math.rad(130))
	Turn(foot_l, x_axis, 0, math.rad(130))
	Turn(foot_r, x_axis, 0, math.rad(130))
	Turn(foot_l, z_axis, 0, math.rad(130))
	Turn(foot_r, z_axis, 0, math.rad(130))
	
	Turn(right_l, y_axis, 0, math.rad(135))
	Turn(left_l, y_axis, 0, math.rad(130))
	
	--Spring.Echo("walk",isAiming) 
	local firststep=true
	while true do
		if (isAiming == false) then
			if (leftArm == true ) then
				Turn(l_arm, x_axis, math.rad(-25), math.rad(35 * speedMult))
			end
			if (rightArm == true ) then
				Turn(r_arm, x_axis, math.rad(25), math.rad(45 * speedMult)) 
			end
		end
			Turn(base, y_axis, math.rad(-5), math.rad(25 * speedMult))
			Turn(base, z_axis, math.rad(2), math.rad(2 * speedMult))
		Turn(shin_r, x_axis, math.rad(85), math.rad(137.5 * speedMult))	
		Turn(right_l, x_axis, math.rad(-60), math.rad(70 * speedMult))
		Turn(left_l, x_axis, math.rad(30), math.rad(70 * speedMult))
		Sleep(600/speedMult)

		Move(cod, y_axis, 0.4, 20)
		if (firststep) then
			firststep=false
		else
			Sleep(500/speedMult)	
		end
		Turn(shin_r, x_axis, math.rad(10), math.rad(185 * speedMult))
		
		Move(cod, y_axis, -1.5, 10)
		
		--Spring.Echo("walk",isAiming) 
		if (isAiming == false) then
			if (rightArm == true ) then
				Turn(r_arm, x_axis, math.rad(-25), math.rad(35 * speedMult))
			end
			if (leftArm == true ) then
				Turn(l_arm, x_axis, math.rad(25), math.rad(45 * speedMult)) 
			end
		end
			Turn(base, y_axis, math.rad(5), math.rad(25 * speedMult))
			Turn(base, z_axis, math.rad(-2), math.rad(2 * speedMult))
		Turn(shin_l, x_axis, math.rad(85), math.rad(137.5 * speedMult))
		Turn(left_l, x_axis, math.rad(-60), math.rad(70 * speedMult))
		Turn(right_l, x_axis, math.rad(30), math.rad(70 * speedMult))

		Sleep(658/speedMult)

		Move(cod, y_axis, 0.4, 20)
		
		Sleep(500/speedMult)

		Turn(shin_l, x_axis, math.rad(10), math.rad(185 * speedMult))
		
		Move(cod, y_axis, -1.5, 10)
	end
end

function poser()
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)	
	if(heavy == true ) then
		SquatStance()
	else
		StandStance()
	end
end

function StandStance()
	Sleep(200)
	Move(cod, y_axis, 0, now)
	Turn(base, z_axis, 0, now)
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)	
	
	Move(cod, y_axis, math.rad(-0.5), math.rad(8000))
	
	Turn(base, x_axis, math.rad(-2), math.rad(395))
	if (isAiming == false) then
		if (leftArm == true ) then
			Turn(l_arm, x_axis, math.rad(10), math.rad(395))
			Turn(l_arm, y_axis, math.rad(5), math.rad(395))
			Turn(l_arm, z_axis, math.rad(9), math.rad(395))
			Turn(l_forearm, x_axis, math.rad(-38), math.rad(395))
		end

		if (rightArm == true ) then
			Turn(r_arm, x_axis, math.rad(10), math.rad(395))
			Turn(r_arm, y_axis, math.rad(-5), math.rad(395))
			Turn(r_arm, z_axis, math.rad(-9), math.rad(395))
			Turn(r_forearm, x_axis, math.rad(-38), math.rad(395))
		end
	end
	
	Turn(right_l, x_axis, 0, math.rad(235))
	Turn(right_l, y_axis, math.rad(-18), math.rad(135))	
	Turn(right_l, z_axis, math.rad(-15), math.rad(135))
	
	Turn(left_l, x_axis, 0, math.rad(235))
	Turn(left_l, y_axis, math.rad(18), math.rad(135))	
	Turn(left_l, z_axis, math.rad(15), math.rad(135))
	
	Turn(shin_l, x_axis, 0, math.rad(235))
	Turn(shin_r, x_axis, 0, math.rad(230))

	Turn(foot_l, x_axis, math.rad(1), math.rad(395))
	Turn(foot_l, y_axis, math.rad(5), math.rad(130))
	Turn(foot_l, z_axis, math.rad(-15), math.rad(130))
	
	Turn(foot_r, x_axis, math.rad(1), math.rad(395))
	Turn(foot_r, y_axis, math.rad(-5), math.rad(130))
	Turn(foot_r, z_axis, math.rad(15), math.rad(130))

	Sleep(0)
end

function SquatStance ()
	Sleep(200)
	Move(cod, y_axis, -1.5, now)
	Turn(base, z_axis, 0, now)
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)	
	
	Turn(base, x_axis, math.rad(5), math.rad(395))
	Turn(cod, x_axis, math.rad(-5), math.rad(395))
	
	if (isAiming == false) then
		if (leftArm == true ) then
			Turn(l_arm, x_axis, math.rad(15), math.rad(395))
			Turn(l_arm, y_axis, math.rad(5), math.rad(395))
			Turn(l_arm, z_axis, math.rad(10), math.rad(395))
			Turn(l_forearm, x_axis, math.rad(-50), math.rad(395))
		end

		if (rightArm == true ) then
			Turn(r_arm, x_axis, math.rad(15), math.rad(395))
			Turn(r_arm, y_axis, math.rad(-5), math.rad(395))
			Turn(r_arm, z_axis, math.rad(-10), math.rad(395))
			Turn(r_forearm, x_axis, math.rad(-50), math.rad(395))
		end
	end
	
	Turn(right_l, x_axis, math.rad(-24), math.rad(235))
	Turn(right_l, y_axis, math.rad(-10), math.rad(135))	
	Turn(right_l, z_axis, math.rad(-20), math.rad(135))
	
	Turn(left_l, x_axis, math.rad(-24), math.rad(235))
	Turn(left_l, y_axis, math.rad(10), math.rad(135))	
	Turn(left_l, z_axis, math.rad(20), math.rad(135))
	
	Turn(shin_l, x_axis, math.rad(45), math.rad(235))
	Turn(shin_r, x_axis, math.rad(45), math.rad(230))

	Turn(foot_l, x_axis, math.rad(-11), math.rad(395))
	Turn(foot_l, y_axis, math.rad(10), math.rad(130))
	Turn(foot_l, z_axis, math.rad(-20), math.rad(130))
	
	Turn(foot_r, x_axis, math.rad(-11), math.rad(395))
	Turn(foot_r, y_axis, math.rad(-10), math.rad(130))
	Turn(foot_r, z_axis, math.rad(20), math.rad(130))

	LookAround()

	Sleep(0)
end

function FixArms(leftflag, rightflag)
	Turn(l_arm, z_axis, 0, math.rad(395))
	Turn(r_arm, z_axis, 0, math.rad(395))
	
	if (leftflag == true ) then
		Turn(l_arm, x_axis, 0, math.rad(395))
		Turn(l_arm, y_axis, 0, math.rad(395))

		Turn(l_forearm, x_axis, 0, math.rad(395))
	end
	if (rightflag == true ) then
		Turn(r_arm, x_axis, 0, math.rad(395))
		Turn(r_arm, y_axis, 0, math.rad(395))

		Turn(r_forearm, x_axis, 0, math.rad(395))
	end
end

function Dash(leftflag, rightflag)
	Turn(head, x_axis, math.rad(-20), math.rad(395))
	Turn(cod, x_axis, math.rad(20), math.rad(395))
	
	if (isAiming == false) then
		Turn(l_arm, x_axis, math.rad(30), math.rad(395))
		Turn(l_arm, y_axis, math.rad(10), math.rad(395))
		Turn(l_forearm, x_axis, math.rad(-45), math.rad(395))

		Turn(r_arm, x_axis, math.rad(30), math.rad(395))
		Turn(r_arm, y_axis, math.rad(-10), math.rad(395))
		Turn(r_forearm, x_axis, math.rad(-45), math.rad(395))
	end
	
	Turn(right_l, x_axis, math.rad(-50), math.rad(235))
	
	Turn(left_l, x_axis, math.rad(40), math.rad(235))
	
	Turn(shin_l, x_axis, 0, math.rad(235))
	Turn(shin_r, x_axis, math.rad(90), math.rad(230))

	Turn(foot_l, x_axis, math.rad(20), math.rad(395))
	
	Turn(foot_r, x_axis, math.rad(20), math.rad(395))

	Sleep(50)
end

function AmIBored()
	--[[Spring.Echo("isAiming: " , isAiming, "isBuilding: " , isBuilding, 
				"isAiming == false and isBuilding == false", isAiming == false and isBuilding == false)]]--
	return isAiming == false and isBuilding == false and isMoving == false
end

function LookAround()
	
	while true do
		if AmIBored() then
			Turn(base, y_axis, 0, 5)
			
			local randomRotDegrees	= math.random(10, 50)
			local randomRotRadians	= math.rad(randomRotDegrees)
			randomAnim = math.random(1, 3)	
			--Spring.Echo("LookAround",isMoving, randomAnim, AmIBored())
			if randomAnim >= 2  and AmIBored() then
				Turn(base, y_axis, randomRotRadians, 0.34*randomAnim)
				Turn(head, y_axis, randomRotRadians/2, 0.18*randomAnim)
				Sleep(400)
			end
			
			if randomAnim == 2 and AmIBored() then
				if (isAiming == false and isMoving  == false) then
					Turn(r_arm, x_axis, -1.1, randomRotDegrees/10)
					Turn(l_arm, x_axis, 0.1, 2)
					Sleep(400)
				end		
			else
				Turn(r_arm, x_axis, -0.15, 0.18)
				Turn(l_arm, x_axis, 0.1, 2)
				Sleep(400)
			end

			if randomAnim <= 2 and AmIBored() then
				Turn(base, y_axis, -randomRotRadians, 0.34*randomAnim)
				Turn(head, y_axis, -randomRotRadians/2, 0.18*randomAnim)
				Sleep(400)
			end

			if AmIBored() then
				Sleep(500)
			end
				
			if randomAnim == 1 and AmIBored() then
				Turn(r_arm, x_axis, 0.1, 2)
				Turn(l_arm, x_axis, -randomRotDegrees/95, randomRotDegrees/20)
				Sleep(400)
			else
				if randomAnim == 2 then
				Turn(r_arm, x_axis, 0.1, 0.1)
				else
					Turn(r_arm, x_axis, 0.1, 0.5)
				end
				Turn(l_arm, x_axis, -0.15, 0.18)
				Sleep(500)
			end
			Sleep(600)
		else-- not aiming, not building oh lawd!
			Sleep(600)		
		end
	end
end
