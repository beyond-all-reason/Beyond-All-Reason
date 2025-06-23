local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Cob Debug",
		desc = "Decodes lua_CobDebug messages from COB Unit scripts",
		author = "Beherith",
		date = "2024.04.07",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true, --  loaded by default?
	}
end


if gadgetHandler:IsSyncedCode() then
	local callinids = {
		[1]	= "Debug",
		[2]	= "Open",
		[3]	= "Close",
		[4]	= "TryTransition",
		[5]	= "Killed",
		[6]	= "ExecuteRestoreAfterDelay",
		[7]	= "SetStunned",
		[8]	= "Walk",
		[9]	= "StopWalking",
		[10]	= "Create",
		[11]	= "Activate",
		[12]	= "Deactivate",
		[13]	= "StartMoving",
		[14]	= "StopMoving",
		[15]	= "SetSFXOccupy",
		[16]	= "MoveRate0",
		[17]	= "MoveRate1",
		[18]	= "MoveRate2",
		[19]	= "MoveRate3",
		[20]	= "SetDirection",
		[21]	= "SetSpeed",
		[22]	= "RockUnit",
		[23]	= "HitByWeapon",
		[24]	= "HitByWeaponID",
		[25]	= "SetMaxReloadTime",
		[26]	= "StartBuilding",
		[27]	= "StopBuilding",
		[28]	= "QueryNanoPiece",
		[29]	= "QueryBuildInfo",
		[30]	= "Falling",
		[31]	= "Landed",
		[32]	= "QueryTransport",
		[33]	= "BeginTransport",
		[34]	= "EndTransport",
		[35]	= "TransportPickup",
		[36]	= "TransportDrop",
		[37]	= "StartUnload",
		[38]	= "QueryLandingPadCount",
		[39]	= "QueryLandingPad",
		[40]	= "AimWeapon1",
		[41]	= "AimFromWeapon1",
		[42]	= "FireWeapon1",
		[43]	= "Shot1",
		[44]	= "QueryWeapon1",
		[45]	= "EndBurst1",
		[46]	= "BlockShot1",
		[47]	= "TargetWeight1",
		[48]	= "AimWeapon2",
		[49]	= "AimFromWeapon2",
		[50]	= "FireWeapon2",
		[51]	= "Shot2",
		[52]	= "QueryWeapon2",
		[53]	= "EndBurst2",
		[54]	= "BlockShot2",
		[55]	= "TargetWeight2",
		[56]	= "AimWeapon3",
		[57]	= "AimFromWeapon3",
		[58]	= "FireWeapon3",
		[59]	= "Shot3",
		[60]	= "QueryWeapon3",
		[61]	= "EndBurst3",
		[62]	= "BlockShot3",
		[63]	= "TargetWeight3",
		[64]	= "AimWeapon4",
		[65]	= "AimFromWeapon4",
		[66]	= "FireWeapon4",
		[67]	= "Shot4",
		[68]	= "QueryWeapon4",
		[69]	= "EndBurst4",
		[70]	= "BlockShot4",
		[71]	= "TargetWeight4",
		[72]	= "AimWeapon5",
		[73]	= "AimFromWeapon5",
		[74]	= "FireWeapon5",
		[75]	= "Shot5",
		[76]	= "QueryWeapon5",
		[77]	= "EndBurst5",
		[78]	= "BlockShot5",
		[79]	= "TargetWeight5",
		[80]	= "AimWeapon6",
		[81]	= "AimFromWeapon6",
		[82]	= "FireWeapon6",
		[83]	= "Shot6",
		[84]	= "QueryWeapon6",
		[85]	= "EndBurst6",
		[86]	= "BlockShot6",
		[87]	= "TargetWeight6",
		[1000]	= "SIGNAL",
	}

	local count = 0 -- ensures that identical calls within a frame dont get eaten from logs
	local lastgf = 0
	
	local function ResolveLine(unitDefID, line)
		local cobname = string.sub(UnitDefs[unitDefID].scriptName, 1, -4)
		
		-- we have to reload and cant cache because the dev might have reloaded the cob script
		local bosfile = VFS.LoadFile(cobname..'bos')
		
		local boslines = string.lines(bosfile)
		
		local function_pattern = '^[%w_]+%('
		
		if boslines[line] == nil then return "included", -1 end
		-- todo: walk up until you match a function declaration
		for i = line, 1, -1 do
			if string.find(boslines[i], function_pattern) then
				--Spring.Echo("MATCH",i, boslines[i])
				return boslines[i], i
			end
		end
		return "?", -1
		--Spring.Echo(cobname, boslines[line])
	end

	local function CobDebug(unitID, unitDefID, team, cmdid, line, p1,p2,p3,p4,p5,p6,p7,p8)
		ResolveLine(unitDefID, line)
		
		
		if lastgf == Spring.GetGameFrame() then
			count = count + 1
		else
			lastgf = Spring.GetGameFrame()
			count = 0
		end
		--  f:<01368.000> u:27656 armstump.FireWeapon1:97
		local funcname = ""
		if cmdid == 1 then 
			funcname = ResolveLine(unitDefID, line)
		else
			funcname = callinids[cmdid] or tostring(cmdid)
		end
			
		local msg = string.format("f:<%05d.%03d> u:%05d %s.%s:%d ",
			lastgf, count, unitID or -1, UnitDefs[unitDefID].name or "?", funcname, line or -1
		)
		if p1 then msg = msg .. " p1=" .. tostring(p1) end 
		if p2 then msg = msg .. " p2=" .. tostring(p2) end 
		if p3 then msg = msg .. " p3=" .. tostring(p3) end 
		if p4 then msg = msg .. " p4=" .. tostring(p4) end 
		if p5 then msg = msg .. " p5=" .. tostring(p5) end 
		if p6 then msg = msg .. " p6=" .. tostring(p6) end 
		if p7 then msg = msg .. " p7=" .. tostring(p7) end 
		if p8 then msg = msg .. " p8=" .. tostring(p8) end 
		
		Spring.Echo(msg)
	end

	function gadget:Initialize()
		gadgetHandler:RegisterGlobal("CobDebug", CobDebug)
	end

	function gadget:Shutdown()
		gadgetHandler:DeregisterGlobal("CobDebug")
	end
	

end	-- UNSYNCED

