stepTimes = {8000,	6000,	6000,	8000, 8000,6000,6000,8000}
keyFramesWalk = {				--Step1						Step2						Step3						Step4...
								--x		y		z			x		y		z			x		y		z			x		y		z
	[lthigh] = 			{Turn = {{30,7,0},{20,3.5,0},{-5,0,0},{-25,-3.5,0},{-30,-7,0},{-10,-3.5,0},{0,0,0},{10,3.5,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[lleg] = 				{Turn = {{10,0,0},{25,0,0},{75,0,0},{60,0,0},{0,0,0},{7,0,0},{0,0,0},{5,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[lfoot] =				{Turn = {{-15,0,0},{-15,0,0},{0,0,0},{-10,0,0},{7,0,0},{4,0,0},{0,0,0},{0,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},

	[rthigh] = 				{Turn = {{-30,7,0},{-10,3.5,0},{0,0,0},{10,-3.5,0},{30,-7,0},{20,-3.5,0},{-5,0,0},{-25,3.5,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[rleg] = 				{Turn = {{0,0,0},{7,0,0},{0,0,0},{5,0,0},{10,0,0},{25,0,0},{75,0,0},{60,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[rfoot] = 				{Turn = {{7,0,0},{4,0,0},{0,0,0},{0,0,0},{-15,0,0},{-15,0,0},{0,0,0},{-10,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[pelvis] = 				{Turn = {{0,-10,0},{0,-5,0},{0,0,0},{0,5,0},{0,10,0},{0,5,0},{0,0,0},{0,-5,0}},
							Move = {{0,1,0},{0,0.5,0},{0,0,0},{0,0.5,0},{0,1,0},{0,0.5,0},{0,0,0},{0,0.5,0}}},
	 
	[torso] = 				{Turn = {{0,7,0},{0,3.5,0},{0,0,0},{0,-3.5,0},{0,-7,0},{0,-3.5,0},{0,0,0},{0,3.5,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[larm] =				{Turn = {{-5,0,0},{-2.5,0,0},{0,0,0},{2.5,0,0},{5,0,0},{2.5,0,0},{0,0,0},{-2.5,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
	 
	[rarm] = 				{Turn = {{5,0,0},{2.5,0,0},{0,0,0},{-2.5,0,0},{-5,0,0},{-2.5,0,0},{0,0,0},{2.5,0,0}},
							Move = {{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}}},
}

PiecesToLock = { -- what pieces should be excluded from animation when moving? (and restored before aiming)
	[torso] = true,
	[larm] = true,
	[rarm] = true,
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
	while (isMoving) and not (isAiming) do
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
	while (isMoving) and (isAiming) do
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

function RestoreLegs()
	for pieceNum, data in pairs(keyFramesWalk) do
		if not PiecesToLock[pieceNum] then
			timedTurn(pieceNum, 1, 0, ang(30), 500)
			timedTurn(pieceNum, 2, 0, ang(30), 500)
			timedTurn(pieceNum, 3, 0, ang(30), 500)
			timedMove(pieceNum, 1, 0, 1.5, 500)
			timedMove(pieceNum, 2, 0, 1.5, 500)
			timedMove(pieceNum, 3, 0, 1.5, 500)
		end
	end
	Sleep(500)
end

function RestoreArms()
	for pieceNum, data in pairs(PiecesToLock) do
			timedTurn(pieceNum, 1, 0, ang(30), 500)
			timedTurn(pieceNum, 2, 0, ang(30), 500)
			timedTurn(pieceNum, 3, 0, ang(30), 500)
			timedMove(pieceNum, 1, 0, 1.5, 500)
			timedMove(pieceNum, 2, 0, 1.5, 500)
			timedMove(pieceNum, 3, 0, 1.5, 500)
	end
end