local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Garbage Collector",
		desc = "Runs a gradual full garbage collection when RAM use grows past a limit",
		author = "Beherith",
		date = "2022.12.20",
		license = "GPL v2",
		layer = 3,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	-- Backstop for the unsynced LuaRules state. The engine's incremental collector normally keeps
	-- garbage bounded; if the footprint still passes the limit, a full cycle is run gradually
	-- (a bounded amount of collector stepping per frame) instead of one stalling
	-- collectgarbage("collect"), and the limit is raised above what survived so live data does
	-- not trigger it again.
	local basememlimit = 700000
	local garbagelimit = basememlimit -- in kilobytes, will adjust upwards as needed
	local checkFrequency = 29
	local stepKB = 1024 -- collector stepping per frame while a gradual cycle runs, about 1 ms

	local stepping = false
	local stepStartFrame, stepStartMem

	-- Adaptive collector budget: the engine caps its collector work per Lua state and frame
	-- (LuaGarbageCollectionRunTimeMult ms, 1 in BAR). Very large games produce garbage faster
	-- than that, so when the footprint keeps climbing the cap is raised a step, and lowered
	-- again once memory stops growing.
	local capMin, capMax, cap = 1, 4, 1
	local trendWindow = 1800 -- frames
	local growthStepKB = 20000 -- growth over the window that raises the cap
	local trendFrame, trendMem

	local function adaptCap(n, ramuse)
		if not trendFrame then
			trendFrame, trendMem = n, ramuse
			return
		end
		if n - trendFrame < trendWindow then
			return
		end
		local growth = ramuse - trendMem
		trendFrame, trendMem = n, ramuse
		local newCap = cap
		if growth > growthStepKB then
			newCap = math.min(capMax, cap + 1)
		elseif growth < growthStepKB / 4 then
			newCap = math.max(capMin, cap - 1)
		end
		if newCap ~= cap then
			cap = newCap
			Spring.GarbageCollectCtrl(nil, nil, nil, nil, nil, nil, cap)
			Spring.Echo(
				string.format(
					"BAR LuaRules memory %s %d MB in the last minute, garbage collector budget set to %d ms",
					growth >= 0 and "grew" or "shrank",
					math.floor(math.abs(growth) / 1000),
					cap
				)
			)
		end
	end

	local function raiseLimit(notgarbagemem)
		garbagelimit = math.min(1200000, basememlimit + notgarbagemem) -- peak 1.2 GB
	end

	local function fullCollect()
		-- load time only, nothing is running yet
		local ramuse = gcinfo()
		if ramuse > garbagelimit then
			collectgarbage("collect")
			collectgarbage("collect")
			local notgarbagemem = gcinfo()
			raiseLimit(notgarbagemem)
			Spring.Echo(
				string.format(
					"BAR using %d MB RAM > %d MB limit, performed garbage collection down to %d MB and adjusted limit to %d MB",
					math.floor(ramuse / 1000),
					math.floor(garbagelimit / 1000),
					math.floor(notgarbagemem / 1000),
					math.floor(garbagelimit / 1000)
				)
			)
		end
	end

	local function stepCycle(n)
		-- collectgarbage("step") answers true once a full cycle has completed
		if not collectgarbage("step", stepKB) then
			return
		end
		stepping = false
		local notgarbagemem = gcinfo()
		raiseLimit(notgarbagemem)
		trendFrame, trendMem = n, notgarbagemem
		Spring.Echo(
			string.format(
				"BAR gradual garbage collection done in %d frames: %d MB -> %d MB, limit adjusted to %d MB",
				n - stepStartFrame,
				math.floor(stepStartMem / 1000),
				math.floor(notgarbagemem / 1000),
				math.floor(garbagelimit / 1000)
			)
		)
	end

	function gadget:GameStart()
		fullCollect()
	end

	function gadget:Initialize()
		fullCollect()
	end

	function gadget:GameFrame(n)
		if stepping then
			stepCycle(n)
		elseif n % checkFrequency == 0 then
			local ramuse = gcinfo()
			adaptCap(n, ramuse)
			if ramuse > garbagelimit then
				stepping = true
				stepStartFrame, stepStartMem = n, ramuse
				Spring.Echo(
					string.format(
						"BAR using %d MB RAM > %d MB limit, starting a gradual garbage collection",
						math.floor(ramuse / 1000),
						math.floor(garbagelimit / 1000)
					)
				)
			end
		end
	end
end
