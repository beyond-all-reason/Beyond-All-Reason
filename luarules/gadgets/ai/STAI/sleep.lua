STSleep = class(Module)

function STSleep:Name()
	return "Sleep"
end

function STSleep:internalName()
	return "sleep"
end

function STSleep:Init()
	self.sleeping = {}
end

function STSleep:GetSleeper(key)
	for i = 1, #self.sleeping do
		local sleeper = self.sleeping[i]
		if sleeper.key == key then
			return sleeper
		end
	end
	local sleeper = { key = key, frames = 0 }
	self.sleeping[#self.sleeping+1] = sleeper
	return sleeper
end

function STSleep:Update()
	local done = {}
	local count = 0
	for i = 1, #self.sleeping do
		local sleeper = self.sleeping[i]
		local frames = sleeper.frames
		if (frames-1) < 1 then
			-- limit the number of things woken up each frame to 50
			if #done < 50 then
				self:Wakeup(sleeper)
				table.insert(done,sleeper.key)
			end
		end
		sleeper.frames = frames -1
	end
	for i=1,#done do
		self:Kill(done[i])
	end
	count = nil
	done = nil
end

-- Pass in a function to be called in the future,
-- and how many frames to wait. Note that if the AI is busy,
-- there may be minor delays of several frames
function STSleep:Wait(functor, frames)
	if functor == nil then
		self.game:SendToConsole("error: functor == nil in STSleep:Wait ")
	else
		local sleeper = self:GetSleeper(functor)
		sleeper.frames = frames
	end
end

function STSleep:Wakeup(sleeper)
	if sleeper == nil then
		self.game:SendToConsole("key == nil in STSleep:Wakeup()")
		return
	end
	local key = sleeper.key
	if type(key) == "table" then
		if key.wakeup ~= nil then
			key:wakeup()
		else
			self.game:SendToConsole("key:wakeup == nil in STSleep:Wakeup")
		end
	else
		key()
	end
end

function STSleep:Kill(key)
	for i = #self.sleeping, 1, -1 do
		local sleeper = self.sleeping[i]
		if sleeper.key == key then
			table.remove(self.sleeping, i)
			-- return
		end
	end
end
