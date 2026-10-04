stepTimes = {12800,	12800,	12800,	12800, 12800,12800,12800,12800}
keyFramesWalk = {				--Step1						Step2						Step3						Step4...
								--x		y		z			x		y		z			x		y		z			x		y		z
	[lthigh] = 			{Turn = {{40,0,0},{30,0,0},{0,0,0},{-25,0,0},{-30,0,0},{-10,0,0},{0,0,0},{10,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[lleg] = 				{Turn = {{20,0,0},{-15,0,0},{-30,0,0},{-40,0,0},{0,0,0},{20,0,0},{30,0,0},{20,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[lfoot] =				{Turn = {{20,0,0},{45,0,0},{30,0,0},{15,0,0},{-30,0,0},{-30,0,0},{-30,0,0},{-10,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},

	[rthigh] = 				{Turn = {{-30,0,0},{-10,0,0},{0,0,0},{10,0,0},{40,0,0},{30,0,0},{0,0,0},{-25,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[rleg] = 				{Turn = {{0,0,0},{20,0,0},{30,0,0},{20,0,0},{20,0,0},{-15,0,0},{-30,0,0},{-40,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[rfoot] = 				{Turn = {{-30,0,0},{-30,0,0},{-30,0,0},{-10,0,0},{20,0,0},{45,0,0},{30,0,0},{15,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[pelvis] = 				{Turn = {{0,0,2},{0,0,1},{0,0,0.5},{0,0,0},{0,0,-2},{0,0,-1},{0,0,-0.5},{0,0,0}},
							Move = {{0,1.5,0},{0,3,0},{0,1.5,0},{0,1.5,0},{0,1.5,0},{0,3,0},{0,1.5,0},{0,1.5,0}}},
	 
	[torso] = 				{Turn = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[luparm] =				{Turn = {{-5,0,0},{-2.5,0,0},{0,0,0},{2.5,0,0},{5,0,0},{2.5,0,0},{0,0,0},{-2.5,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[ruparm] = 				{Turn = {{5,0,0},{2.5,0,0},{0,0,0},{-2.5,0,0},{-5,0,0},{-2.5,0,0},{0,0,0},{2.5,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
}

PiecesToLock = { -- what pieces should be excluded from animation when moving? (and restored before aiming)
	[torso] = true,
	[luparm] = true,
	[ruparm] = true,
	[pelvis] = true,
}

-- keyFramesWalk[pieceNum][Type][Step][axis] = goal
-- keyFramesWalk[pieceNum][Type][Step][axis+3] = amount

for pieceNum, v in pairs(keyFramesWalk) do
	for Type, steps in pairs(v) do
		for step, goal in pairs(steps) do
			local timer = stepTimes[step]
			if Type == "Turn" then
				for i = 1,3 do
					goal[i] = math.rad(goal[i])
				end
			end
		end
	end
end
for pieceNum, v in pairs(keyFramesWalk) do
	for Type, steps in pairs(v) do
		for step, goal in pairs(steps) do
			local timer = stepTimes[step]
			if keyFramesWalk[pieceNum][Type][step-1] then
				for i = 1,3 do
					keyFramesWalk[pieceNum][Type][step][i+3] = math.abs(goal[i] - keyFramesWalk[pieceNum][Type][step-1][i])
				end	
			elseif keyFramesWalk[pieceNum][Type][#stepTimes] then
				for i = 1,3 do
					keyFramesWalk[pieceNum][Type][step][i+3] = math.abs(goal[i] - keyFramesWalk[pieceNum][Type][#stepTimes][i])
				end
			end
		end
	end
end


function walk()
	isInLoop = true
	while (isMoving) and not (isAiming) and not (isUW) do
		local keyFrame = keyFramesWalk
		local timer = stepTimes[step]
		for pieceNum, anims in pairs(keyFrame) do
			local tTurn = anims.Turn[step]
			local tMove = anims.Move[step]
			timedTurn(pieceNum, 1, tTurn[1], tTurn[4], timer / currentSpeed)
			timedTurn(pieceNum, 2, tTurn[2], tTurn[5], timer / currentSpeed)
			timedTurn(pieceNum, 3, tTurn[3], tTurn[6], timer / currentSpeed)
			timedMove(pieceNum, 1, tMove[1], tMove[4], timer / currentSpeed)
			timedMove(pieceNum, 2, tMove[2], tMove[5], timer / currentSpeed)
			timedMove(pieceNum, 3, tMove[3], tMove[6], timer / currentSpeed)
		end
		Sleep(timer / currentSpeed)
		step = step + 1
		if step > #stepTimes then
			step = 1
		end
	end
	isInLoop = false
end

function walklegs()
	isInLoop = true
	while (isMoving) and (isAiming) and not (isUW) do
		local keyFrame = keyFramesWalk
		local timer = stepTimes[step]
		for pieceNum, anims in pairs(keyFrame) do
			if not PiecesToLock[pieceNum] then
				local tTurn = anims.Turn[step]
				local tMove = anims.Move[step]
				timedTurn(pieceNum, 1, tTurn[1], tTurn[4], timer / currentSpeed)
				timedTurn(pieceNum, 2, tTurn[2], tTurn[5], timer / currentSpeed)
				timedTurn(pieceNum, 3, tTurn[3], tTurn[6], timer / currentSpeed)
				timedMove(pieceNum, 1, tMove[1], tMove[4], timer / currentSpeed)
				timedMove(pieceNum, 2, tMove[2], tMove[5], timer / currentSpeed)
				timedMove(pieceNum, 3, tMove[3], tMove[6], timer / currentSpeed)
			end
		end
		Sleep(timer / currentSpeed)
		step = step + 1
		if step > #stepTimes then
			step = 1
		end
	end
	isInLoop = false
end

function swim()
	isInLoop = true
	if (isMoving) and (isUW) then
		-- swim transform anim	
		Move(ruparm, 3, 14, 14)
		Move(luparm, 3, 14, 14)
		Move(ruparm, 2, -5, 5)
		Move(luparm, 2, -5, 5)
		Turn(ruparm, 1, ang(175),ang(80))	
		Turn(luparm, 1, ang(175),ang(80))	
		Turn(rthigh, 1, ang(85), ang(100))	
		Turn(lthigh, 1, ang(85), ang(100))	
		Turn(rleg, 1, ang(30),ang(50))	
		Turn(lleg, 1, ang(30),ang(50))	
		Turn(rfoot, 1, ang(45),ang(60))	
		Turn(lfoot, 1, ang(45),ang(60))	
		Sleep(500)
	end
	while (isMoving) and (isUW) do
		-- swim transform anim	
		Move(ruparm, 3, 14, 14)
		Move(luparm, 3, 14, 14)
		Move(ruparm, 2, -5, 5)
		Move(luparm, 2, -5, 5)
		Turn(ruparm, 1, ang(180),ang(80))	
		Turn(luparm, 1, ang(180),ang(80))	
		Turn(rthigh, 1, ang(85), ang(100))	
		Turn(lthigh, 1, ang(85), ang(100))	
		Turn(rleg, 1, ang(30),ang(50))	
		Turn(lleg, 1, ang(30),ang(50))	
		Turn(rfoot, 1, ang(45),ang(60))	
		Turn(lfoot, 1, ang(45),ang(60))	
		Sleep(500)
	end
	RestoreArms()
	Sleep(800)
	isInLoop = false
end


function RestoreLegs()
	if isUW then
		Turn(rthigh, 1, ang(85), ang(100))	
		Turn(lthigh, 1, ang(85), ang(100))
		Turn(rleg, 1, ang(30), ang(50))	
		Turn(lleg, 1, ang(30), ang(50))	
		Turn(rfoot, 1, ang(45), ang(60))	
		Turn(lfoot, 1, ang(45), ang(60))	
	else
		for pieceNum, data in pairs(keyFramesWalk) do
			if not PiecesToLock[pieceNum] then
				timedTurn(pieceNum, 1, 0, ang(30), 150)
				timedTurn(pieceNum, 2, 0, ang(30), 150)
				timedTurn(pieceNum, 3, 0, ang(30), 150)
				timedMove(pieceNum, 1, 0, 1.5, 150)
				timedMove(pieceNum, 2, 0, 1.5, 150)
				timedMove(pieceNum, 3, 0, 1.5, 150)
			end
		end
	end
	Sleep(500)
end

function RestoreArms()
	if isUW then
		Move(ruparm, 3, 14, 14)
		Move(luparm, 3, 14, 14)
		Move(ruparm, 2, -5, 5)
		Move(luparm, 2, -5, 5)
		Turn(ruparm, 1, ang(180),ang(80))	
		Turn(luparm, 1, ang(180),ang(80))	
		Move(laaturret, 2, -5.5)
		Move(raaturret, 2, -5.5)
		Turn(laacannon, 1, ang(27.5))
		Turn(raacannon, 1, ang(27.5))
	else
		for pieceNum, data in pairs(PiecesToLock) do
			timedTurn(pieceNum, 1, 0, ang(30), 150)
			timedTurn(pieceNum, 2, 0, ang(30), 150)
			timedTurn(pieceNum, 3, 0, ang(30), 150)
			timedMove(pieceNum, 1, 0, 1.5, 150)
			timedMove(pieceNum, 2, 0, 1.5, 150)
			timedMove(pieceNum, 3, 0, 1.5, 150)
		end
		Move(laaturret, 2, -5.5)
		Move(raaturret, 2, -5.5)
		Turn(laacannon, 1, ang(27.5))
		Turn(raacannon, 1, ang(27.5))
	end
end