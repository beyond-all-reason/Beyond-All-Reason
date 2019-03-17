keyFramesWalk = {
	{
		stepTime = 15000,
		[lthigh] = {
			Turn = {-40, -5, 0},
			Move = {0, 0, 0},
			},
		[lleg] = {
			Turn = {20, 0, 0},
			Move = {0, 0, 0},
			},
		[lfoot] = {
			Turn = {-20, 0, 0},
			Move = {0, 0, 0},
			},
		[rthigh] = {
			Turn = {20, -5, 0},
			Move = {0, 0, 0},
			},
		[rleg] = {
			Turn = {50, 0, 0},
			Move = {0, 0, 0},
			},
		[rfoot] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[pelvis] = {
			Turn = {0, 8, 0},
			Move = {0, 0, 1.5},
			},
		[torso] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[larm] = {
			Turn = {10, 0, 0},
			Move = {0, 0, 0},
			},
		[rarm] = {
			Turn = {-5, 0, 0},
			Move = {0, 0, 0},
			},
	},
	{
		stepTime = 15000,
		[lthigh] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[lleg] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[lfoot] = {
			Turn = {-10, 0, 0},
			Move = {0, 0, 0},
			},
		[rthigh] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[rleg] = {
			Turn = {60, 0, 0},
			Move = {0, 0, 0},
			},
		[rfoot] = {
			Turn = {-10, 0, 0},
			Move = {0, 0, 0},
			},
		[pelvis] = {
			Turn = {0, 0, 0},
			Move = {0, 0.5, 0},
			},
		[torso] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[larm] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[rarm] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
	},
	{
		stepTime = 15000,
		[lthigh] = {
			Turn = {20, 5, 0},
			Move = {0, 0, 0},
			},
		[lleg] = {
			Turn = {50, 0, 0},
			Move = {0, 0, 0},
			},
		[lfoot] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[rthigh] = {
			Turn = {-40, 5, 0},
			Move = {0, 0, 0},
			},
		[rleg] = {
			Turn = {20, 0, 0},
			Move = {0, 0, 0},
			},
		[rfoot] = {
			Turn = {-20, 0, 0},
			Move = {0, 0, 0},
			},
		[pelvis] = {
			Turn = {0, -8, 0},
			Move = {0, 0, 1.5},
			},
		[torso] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[larm] = {
			Turn = {-5, 0, 0},
			Move = {0, 0, 0},
			},
		[rarm] = {
			Turn = {10, 0, 0},
			Move = {0, 0, 0},
			},
	},
	{
		stepTime = 15000,
		[lthigh] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[lleg] = {
			Turn = {60, 0, 0},
			Move = {0, 0, 0},
			},
		[lfoot] = {
			Turn = {-10, 0, 0},
			Move = {0, 0, 0},
			},
		[rthigh] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[rleg] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[rfoot] = {
			Turn = {-10, 0, 0},
			Move = {0, 0, 0},
			},
		[pelvis] = {
			Turn = {0, 0, 0},
			Move = {0, 0.5, 0},
			},
		[torso] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[larm] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
		[rarm] = {
			Turn = {0, 0, 0},
			Move = {0, 0, 0},
			},
	},
}

for step, data in pairs(keyFramesWalk) do
	local timer = data.stepTime
	for piecenum, anims in pairs(data) do
		if type(anims) == "table" then
			for typeAnim, goal in pairs(anims) do
				if typeAnim == "Turn" then
					for i = 1,3 do
						goal[i] = math.rad(goal[i])
					end
				end
			end
		end
	end
end

for step, data in pairs(keyFramesWalk) do
	local timer = data.stepTime
	for piecenum, anims in pairs(data) do
		if type(anims) == "table" then
			for typeAnim, goal in pairs(anims) do
				if keyFramesWalk[step-1] then
					for i = 1,3 do
						if keyFramesWalk[step-1][piecenum][typeAnim] then
							keyFramesWalk[step][piecenum][typeAnim][i+3] = math.abs(goal[i] - keyFramesWalk[step-1][piecenum][typeAnim][i])
						end
					end
				elseif keyFramesWalk[#keyFramesWalk] then
					for i = 1,3 do
						if keyFramesWalk[#keyFramesWalk]and keyFramesWalk[#keyFramesWalk][piecenum] and keyFramesWalk[#keyFramesWalk][piecenum][typeAnim] then
							keyFramesWalk[step][piecenum][typeAnim][i+3] = math.abs(goal[i] - keyFramesWalk[#keyFramesWalk][piecenum][typeAnim][i])
						end
					end
				end
				keyFramesWalk[step][piecenum][typeAnim][7] = timer
			end
		end
	end
	data.stepTime = nil
end


function walk()
	isInLoop = true
	while (isMoving) and not (isAiming) do
		local keyFrame = keyFramesWalk[step]
		local timer = 0
		for pieceNum, anims in pairs(keyFrame) do
			local tTurn = anims.Turn
			local tMove = anims.Move
			timer = tTurn[7]
			timedTurn(pieceNum, 1, tTurn[1], tTurn[4], tTurn[7] / currentSpeed)
			timedTurn(pieceNum, 2, tTurn[2], tTurn[5], tTurn[7] / currentSpeed)
			timedTurn(pieceNum, 3, tTurn[3], tTurn[6], tTurn[7] / currentSpeed)
			timedMove(pieceNum, 1, tMove[1], tMove[4], tMove[7] / currentSpeed)
			timedMove(pieceNum, 2, tMove[2], tMove[5], tMove[7] / currentSpeed)
			timedMove(pieceNum, 3, tMove[3], tMove[6], tMove[7] / currentSpeed)
		end
		Sleep(timer / currentSpeed)
		step = step + 1
		if step > #keyFramesWalk then
			step = 1
		end
	end
	isInLoop = false
end

function walklegs()
	isInLoop = true
	while (isMoving) and not (isAiming) do
		local keyFrame = keyFramesWalk[step]
		local timer = 0
		for pieceNum, anims in pairs(keyFrame) do
			timer = tTurn[7]
			local tTurn = anims.Turn
			local tMove = anims.Move
			timedTurn(pieceNum, 1, tTurn[1], tTurn[4], tTurn[7] / currentSpeed)
			timedTurn(pieceNum, 2, tTurn[2], tTurn[5], tTurn[7] / currentSpeed)
			timedTurn(pieceNum, 3, tTurn[3], tTurn[6], tTurn[7] / currentSpeed)
			timedMove(pieceNum, 1, tMove[1], tMove[4], tMove[7] / currentSpeed)
			timedMove(pieceNum, 2, tMove[2], tMove[5], tMove[7] / currentSpeed)
			timedMove(pieceNum, 3, tMove[3], tMove[6], tMove[7] / currentSpeed)
		end
		Sleep(timer / currentSpeed)
		step = step + 1
		if step > #keyFramesWalk then
			step = 1
		end
	end
	isInLoop = false
end

function RestoreLegs()

end

function RestoreArms()

end