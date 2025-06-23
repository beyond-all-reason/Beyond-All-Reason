local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Garbage Collector",
		desc = "Does full garbage collection event when RAM use grows",
		author = "Beherith",
		date = "2022.12.20",
		license = "GPL v2",
		layer = 3,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	local basememlimit = 700000
	local garbagelimit = basememlimit -- in kilobytes, will adjust upwards as needed
	local checkFrequency = 29
	
	local function CheckRamLimitGC()
		local ramuse = gcinfo()
		--Spring.Echo("RAMUSE",i,n, RAMUSE)
		if ramuse > garbagelimit then 
			collectgarbage("collect")
			collectgarbage("collect")
			local notgarbagemem = gcinfo()
			local newgarbagelimit = math.min(1200000, basememlimit + notgarbagemem) -- peak 1 GB
			Spring.Echo(string.format("BAR using %d MB RAM > %d MB limit, performing garbage collection down to %d MB and adjusting limit to %d MB", 
				math.floor(ramuse/1000), 
				math.floor(garbagelimit/1000), 
				math.floor(notgarbagemem/1000), 
				math.floor(newgarbagelimit/1000) 
				))
			garbagelimit = newgarbagelimit
		end
	end
	
	function gadget:GameStart()
		CheckRamLimitGC()
	end

	function gadget:Initialize()
		CheckRamLimitGC()
	end
	
	function gadget:GameFrame(n)
		if n % checkFrequency == 0 then 
			CheckRamLimitGC()
		end
	end
end
