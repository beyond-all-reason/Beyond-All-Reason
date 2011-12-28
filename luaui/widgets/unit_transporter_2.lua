include("keysym.h.lua")
--- widget options:
local opts={
	min_travel_distance=180, --- smallest travel distance that units are transported for.
	default_drop_distance=70, --- used as fallback whenever we're repairing or building and build distance is undefined
	dgun_drop_distance=70, --- used when landing to dgun
	use_guard_order=false, --- true: use guard order on transports to keep them near unit, false:use move commands instead.
	eject_distance=50, --- todo: find a way to get transport speed and max. deceleration, and calculate it properly?
	logging=false,
	error_logging=true
}

function widget:GetInfo()
	return {
		name	= "Transporter 2",
		desc	= "Select units, press ctrl-m to have (air) transports assist those units at moving. Press ctrl+n to undo that. You can also 'guard' unit with transport (any transport, even amphibious one) for same effect.",
		author	= "dizekat",
		date	= "2008-12-30",
		license	= "GPL v2",
		layer	= 0,
		enabled	= true
	}
end

local transport_states={
	idle=0,--- doing nothing atm
	approaching=1,--- going to unit for pick up, unit not stopped yet
	picking_up=2,--- unit stopped, picking it up
	loaded=3, --- unit loaded into transport, going to destination.
	arrived=4
}

local transports = {}--- [guard_id]={target=guarded_id, state=transport_states.idle, queve={}, restore_selection=false}
local guarded_units = {}

local waiting_units= {}

local function LogMessage(...)
	if opts.logging and ... then
		Spring.Echo(...)
	end
end

local function LogError(...)
	if opts.error_logging and ... then
		Spring.Echo(...)
	end	
end

local function IsWaiting_lagged(unit_id)
	local commands=Spring.GetCommandQueue(unit_id)
	if commands and commands[1] and commands[1].id==CMD.WAIT then
		return true
	end
	return false
end


--- ugly workarounds:
--- the command queve is lagged behind
--- so it fails if i determine wait state from command queve
--- hence the workarounds.

local function OnSetWait(unit_id)
	waiting_units[unit_id]=true	
end

local function OnClearWait(unit_id)
	waiting_units[unit_id]=nil
end

local function OnToggleWait(unit_id)
	if waiting_units[unit_id] then
		waiting_units[unit_id]=nil
	else
		waiting_units[unit_id]=true
	end	
end

local function SetWait(unit_id)
	if not waiting_units[unit_id] then
		if not IsWaiting_lagged(unit_id) then
			Spring.GiveOrderToUnit(unit_id,CMD.WAIT, {},{""})
		end
	end	
	OnSetWait(unit_id)
end
local function ClearWait(unit_id)
	if waiting_units[unit_id] then		
		if IsWaiting_lagged(unit_id) then
			Spring.GiveOrderToUnit(unit_id,CMD.WAIT, {},{""})
		end
	end
	OnClearWait(unit_id)	
end

local function UpdateWait(unit_id)
	waiting_units[unit_id]=IsWaiting_lagged(unit_id) 
end

local function IsWaiting(unit_id)
	return waiting_units[unit_id]
end

local function CheckConsistency(id)-- check that all structures for id are set correctly.
	--LogError("CheckConsistency")
	if not id then
		LogError("CheckConsistency: param is nil")
		return
	end
	local i=0
	local transport=transports[id]
	if transport then
		i=i+1		
		if transport.target then
			local unit=guarded_units[transport.target]
			if unit then
				if unit.guard~=id then
					LogError("CheckConsistency: transport has target which has different guard from transport")
				end
			else
				LogError("CheckConsistency: transport's target not registered in guarded_units")		
			end
		else
			LogError("CheckConsistency: transport has no target")		
		end
	end
	
	local guarded_unit=guarded_units[id]	
	if guarded_unit then
		i=i+1
		if guarded_unit.guard then
			local t=transports[guarded_unit.guard]
			if t then
				if t.target~=id then
					LogError("CheckConsistency: unit has guard which is guarding other unit")
				end
			else
				LogError("CheckConsistency: unit's guard is not in transports")		
			end
		else
			LogError("CheckConsistency: unit has no guard")
		end
	end
	if i>1 then
		LogError("CheckConsistency: the id is present both in transports and guarded_units")
	end
end

local function UnGuardUnit(id)
	LogMessage("unguarding")
	if transports[id] and transports[id].target then
		guarded_units[transports[id].target]=nil
	end
	if guarded_units[id] and guarded_units[id].guard then
		transports[guarded_units[id].guard]=nil
	end
	transports[id]=nil
	guarded_units[id]=nil
end

local function GuardUnit(guard_id,guarded_id)
	UnGuardUnit(guard_id)
	UnGuardUnit(guarded_id)	
	local guard_ud = UnitDefs[Spring.GetUnitDefID(guard_id)]
	local guarded_ud = UnitDefs[Spring.GetUnitDefID(guarded_id)]
	if guard_ud.isTransport and (not guarded_ud.isTransport) and (not guarded_ud.isBuilding) and (not guarded_ud.isFactory) and (guarded_ud.canMove) then -- transport must guard non-transport non-building
		LogMessage("adding transport to list")
		transports[guard_id]={target=guarded_id, state=transport_states.idle, queve={}, restore_selection=false}--loading=false, loaded=false, picking=false,
		guarded_units[guarded_id]={guard=guard_id, inside_transport=false, waiting=false}
	end
end

local function RemoveTransport(id)
	LogMessage("removing transport from list")
	if transports[id] then
		guarded_units[transports[id].target]=nil
	end
	transports[id]=nil	
end

function widget:Initialize()
  if Spring.GetSpectatingState() or Spring.IsReplay() then
    widgetHandler:RemoveWidget()
    --return false
  end
  --return true
end

function my_r_sq(x,y,z)
	return x*x+y*y+z*z
end

local pickup_radius=150


local function GetUnitOrFeaturePosition(id)
	if id<=Game.maxUnits then
		return Spring.GetUnitPosition(id)
	else
		return Spring.GetFeaturePosition(id-Game.maxUnits)
	end
end


local function UpdateUnitCommands(transport_id, commands, no_pickup)
	if not transport_id then
		return
	end
	local transport=transports[transport_id]
	if not transport then
		return
	end
	
	local tx, ty, tz
	local ux, uy, uz
	
	if transport_id then
		tx, ty, tz = Spring.GetUnitPosition(transport_id)
	end
	if transport.target then
		 ux, uy, uz = Spring.GetUnitPosition(transport.target)
	end
	if (not tz)or(not uz) then -- failed to get positions.
		LogMessage("failed to get positions")
		RemoveTransport(transport_id)
		return
	end	
--	LogMessage("1")
	local command
	if commands then
		command=commands[1]
	end
	--[[	
	if command then
		if command.id==CMD.WAIT then
			command=commands[2]
		end
	end
	]]--
	if not command then
		--LogMessage("unit has no commands...?")		
		--LogMessage("no orders")
		if (transport.state==transport_states.approaching)or(transport.state==transport_states.picking_up) then
			LogMessage("cancelling transport orders")
			if transport_id and tx and transports[transport_id] then
				if opts.use_guard_order then 
					Spring.GiveOrderToUnit(transport_id, CMD.GUARD, {transport.target}, {""}) 
				else
					Spring.GiveOrderToUnit(transport_id, CMD.MOVE, {ux,uy,uz}, {""}) 					
				end
				transports[transport_id].state=transport_states.idle
			end
		end
		return
	end	
	
	
--	LogMessage("2")
	
	--- unit has commands
		
	-- find proper drop distance, initially 0
	local drop_distance=0.0
	local px, py, pz
	
	-- if its a kind of build command, drop at 0.8*buildDistance if avaliable (for some odd reason, buildDistance is bit too far)
	if command.id<0 or command.id==CMD.REPAIR or command.id==CMD.RECLAIM or command.id==CMD.RESURRECT then
		drop_distance=opts.default_drop_distance
		local def= UnitDefs[Spring.GetUnitDefID(transport.target)]
		if def and def.buildDistance then
			drop_distance=0.8*def.buildDistance
		end
	elseif command.id==CMD.MANUALFIRE then
		drop_distance=opts.dgun_drop_distance;
	end
					
	--- get the command position
	local handle_command=false	
	if (command.id==CMD.MOVE or command.id<0) then 		
		px = command.params[1]
		py = command.params[2]
		pz = command.params[3]
		handle_command=true
		transports[transport_id].track_target=nil
	elseif command.id==CMD.REPAIR or command.id==CMD.RECLAIM or command.id==CMD.RESURRECT or command.id==CMD.MANUALFIRE or command.id==CMD.GUARD then
		if table.getn(command.params)==4 or table.getn(command.params)==3 then
			px = command.params[1]
			py = command.params[2]
			pz = command.params[3]					
			handle_command=true
			transports[transport_id].track_target=nil;
		elseif table.getn(command.params)==1 then
			px, py, pz = GetUnitOrFeaturePosition(command.params[1])
			if command.id==CMD.GUARD then
				transports[transport_id].track_target=command.params[1]
			else
				transports[transport_id].track_target=nil
			end
			handle_command=true
		end	
	end
--	LogMessage("command id: ",command.id);
--	LogMessage("3")
	--- make sure that we got coordinates correctly.
	handle_command=handle_command and (not ((px==nil) or (ux==nil) or (tx==nil)))
	
--	LogMessage("4")
	
	if handle_command then
--		LogMessage("unit has command which must be handled")		 
		local dx=px-ux
		local dy=py-uy
		local dz=pz-uz
		local rsq=my_r_sq(dx,dy,dz)
		local s=1.0/math.sqrt(rsq)
		dx=dx*s
		dy=dy*s
		dz=dz*s						
		if not (drop_distance==0) then 
			px=px-dx*drop_distance
			pz=pz-dz*drop_distance
			py=Spring.GetGroundHeight(px, pz)
		end
		
		if transport.state==transport_states.loaded then
			LogMessage("updating transport unload point")
			Spring.GiveOrderToUnit(transport_id, CMD.UNLOAD_UNIT, {px,py,pz}, {""})
			
		end
		if(rsq>(opts.min_travel_distance+drop_distance)*(opts.min_travel_distance+drop_distance)) then
			LogMessage("transport guarding: unit wants to move")
			--- set transport on iddle if guarded unit's wait has been undone
			if transports[transport_id].state==transport_states.picking_up and not IsWaiting(transport.target) then
				transports[transport_id].state=transport_states.idle
			end
			
			if transport.state==transport_states.idle then
				Spring.GiveOrderToUnit(transport_id, CMD.LOAD_UNITS, {transport.target}, {""})
				transports[transport_id].state= transport_states.approaching
			end			
			if transports[transport_id].state==transport_states.approaching and (my_r_sq(tx-ux,ty-uy,tz-uz)<pickup_radius*pickup_radius) then
				if not no_pickup then
					SetWait(transport.target)
					--- selection saving
					local selected_units = Spring.GetSelectedUnits() --- ugly
					transport.restore_selection=false
					for _, unit_id in ipairs(selected_units) do
						if unit_id==transport.target then
							LogMessage("loading selected unit")
							transport.restore_selection=true
							break
						end

					end
					Spring.SendCommands({"@+C-S@group9"})


					Spring.GiveOrderToUnit(transport_id, CMD.UNLOAD_UNIT, {px,py,pz}, {"shift"})
					if opts.use_guard_order then 
						Spring.GiveOrderToUnit(transport_id, CMD.GUARD, {transport.target}, {"shift"}) 
					end			
					transports[transport_id].state=transport_states.picking_up
				end
			end									
		else--- the move is too short
			if transports[transport_id].state==transport_states.approaching then --- if we are approaching, cancel pickup
				if opts.use_guard_order then 
					Spring.GiveOrderToUnit(transport_id, CMD.GUARD, {transport.target}, {""}) 
				else
					Spring.GiveOrderToUnit(transport_id, CMD.MOVE, {ux,uy,uz}, {""}) 
				end
				transports[transport_id].state=transport_states.idle
			end
		end		
	end
end


local function UpdateTransport(transport_id, transport)--- processes different cases one by one, with return when case is handled


			
	local tx, ty, tz
	local ux, uy, uz
	
	if transport_id then
		tx, ty, tz = Spring.GetUnitPosition(transport_id)
	end
	if transport.target then
		 ux, uy, uz = Spring.GetUnitPosition(transport.target)
	end
	if (not tz)or(not uz) then -- failed to get positions.
		LogMessage("failed to get positions")
		RemoveTransport(transport_id)
		return
	end	
	
	
	if transport.state==transport_states.loaded then --- handle loaded transports.
		LogMessage("updating loaded transport")
		SetWait(transport.target)	
		if transport.track_target then --- tracking target with a loaded transport.
			local x,y,z
			if transport.track_target<Game.maxUnits then
				x, y, z = Spring.GetUnitPosition(transport.track_target)
			else
				x, y, z = Spring.GetFeaturePosition(transport.track_target-Game.maxUnits)
			end
			if ((tx-x)*(tx-x)+(tz-z)*(tz-z))<(opts.default_drop_distance*opts.default_drop_distance) then
				LogMessage("Transport arrived.")
				transport.state=transport_states.arrived
			elseif not (x==nil or y==nil or z==nil) then
				Spring.GiveOrderToUnit(transport_id, CMD.UNLOAD_UNIT, {x,y,z}, {""})
				if opts.use_guard_order then 
					Spring.GiveOrderToUnit(transport_id, CMD.GUARD, {transport.target}, {"shift"}) 
				end			
			end
		end
		--return
	end	
	
	local commands=Spring.GetCommandQueue(transport.target)
		
	--- transport isnt loaded.
	
	--- check if transport is too damaged
	if transport.state~=transport_states.loaded and transport.state~=transport_states.arrived then
		local health,maxHealth,paralyzeDamage,capture,build = Spring.GetUnitHealth(transport_id)
		if (health==nil)    then health=-1 end
		if (maxHealth==nil) then maxHealth=1 elseif(maxHealth<1) then maxHealth=1 end
		if(health/maxHealth<0.3) then
			LogMessage("transport is too damaged, removing")
			if opts.use_guard_order then 
				Spring.GiveOrderToUnit(transport_id, CMD.GUARD, {transport.target}, {""}) 
			end
			local transport_commands=Spring.GetCommandQueue(transport_id)
			RemoveTransport(transport_id)
			return		
		end
	end
	
	
	

	local transport_commands=Spring.GetCommandQueue(transport_id)
	
	if transport.state==transport_states.idle then
		LogMessage("transport is idle")
		if (not opts.use_guard_order) then
			local tmp=Spring.GetUnitIsTransporting(transport_id)
			if table.getn(tmp)>0 then
				Spring.GiveOrderToUnit(transport_id, CMD.UNLOAD_UNIT, {tx,ty,tz}, {""}) 
				Spring.GiveOrderToUnit(transport_id, CMD.MOVE, {ux,uy,uz}, {"shift"}) 
			else
				Spring.GiveOrderToUnit(transport_id, CMD.MOVE, {ux,uy,uz}, {""}) 
			end
		end
	end
	
	local commands=Spring.GetCommandQueue(transport.target)	
	--[[
	if not commands then
		LogMessage("WTF")	
	end
	if not commands[1] then
		LogMessage("WTF2")	
	end ]]--
	UpdateUnitCommands(transport_id,commands, false)
end

function Eject(unit_id)
	local transport_id=unit_id
	if guarded_units[unit_id] then
		transport_id=guarded_units[unit_id].guard	
	end
	local x,y,z=Spring.GetUnitPosition(transport_id)
	if z then
		commands=Spring.GetCommandQueue(transport_id)
		if commands and commands[1] and (table.getn(commands[1].params)==3 or table.getn(commands[1].params)==4) then
			local ox,oy,oz=commands[1].params[1],commands[1].params[2],commands[1].params[3]
			local dx,dy,dz=ox-x,oy-y,oz-z
			local s=opts.eject_distance/math.sqrt(dx*dx+dy*dy+dz*dz)
			dx,dy,dz=dx*s,dy*s,dz*s
			x,y,z=x+dx,y+dy,z+dz
		end
		Spring.GiveOrderToUnit(transport_id, CMD.UNLOAD_UNIT, {x,y,z}, {""}) 
		if transports[transport_id] then
			RemoveTransport(transport_id)
		end
	end
end


function widget:CommandNotify(id, params, options)
	local selected_units = Spring.GetSelectedUnits()
	if id == CMD.GUARD or id==CMD.MOVE or id==CMD.LOAD_UNIT or id==CMD.LOAD_UNITS or id==CMD.UNLOAD_UNIT or id==CMD.UNLOAD_UNITS then
		for i = 1, table.getn(selected_units) do
			if transports[selected_units[i]] then
				RemoveTransport(selected_units[i])
			end
		end
	end
	if (id == CMD.GUARD) then
		if table.getn(params)<1 then 
			return 
		end
		local guarded=params[1]
		if guarded_units[guarded] then 
			return 
		end
		local guards = Spring.GetSelectedUnits()
		local i
		for i = 1, table.getn(guards) do
			local guard_id=guards[i]
			local guard_ud = UnitDefs[Spring.GetUnitDefID(guard_id)]
			if guard_ud.isTransport then				
				GuardUnit(guard_id, guarded)
			end
		end
	end
	--- intercept commands to the units inside transport
	local sel = Spring.GetSelectedUnits()
	
	local hack_skip_commander=false
	
	if not options.shift then
		for i,unit_id in ipairs(sel) do
			if id==CMD.WAIT then
				OnToggleWait(unit_id)
			else
				OnClearWait(unit_id)
			end
			--LogMessage("Command notify for id=", unit_id, " i=", i);			
			if guarded_units[unit_id] and guarded_units[unit_id].guard then
				guarded_units[unit_id].waiting=false				
				--LogMessage("updating unit commands.");
				--LogMessage("command id: ",id);
				UpdateUnitCommands(guarded_units[unit_id].guard,{ {id=id, params=params, options=options} },true)
			end
		end
		
	end
end

function widget:UnitCmdDone(unit_id, unitDefID, unitTeam, cmdID, cmdTag)	
	if unitTeam~=Spring.GetMyTeamID() then
		return
	end
	if cmdID==CMD.WAIT then
		LogMessage("hurray")
	end 
	local transport=transports[unit_id]
	if transport then			
		if cmdID==CMD.LOAD_UNITS or cmdID==CMD.LOAD_UNIT then
			LogMessage("transport guarding: load done")			
			transport.state=transport_states.loaded
			--- group based selection preserving
			if transport.restore_selection then
				LogMessage("transport guarding: restoring selection")
				Spring.SendCommands({"@-S@group9"})
			end
			-- doesnt work
			-- Spring.SelectUnitArray({transports[unit_id].target})
		elseif cmdID==CMD.UNLOAD_UNITS or cmdID==CMD.UNLOAD_UNIT then
			LogMessage("transport guarding: unload done")
			
--[[
			local selected_units = Spring.GetSelectedUnits()
			if not selected_units or table.getn(selected_units)<1 then 
				Spring.SelectUnitArray({transports[unit_id].target})
			end		
--]]
			transports[unit_id].state=transport_states.idle
			transports[unit_id].track_target=nil;
			local commands=Spring.GetCommandQueue(transports[unit_id].target)
									
			ClearWait(transports[unit_id].target)
			--[[
			if commands and commands[1] and commands[1].id==CMD.WAIT and guarded_units[transports[unit_id].target].waiting then
				---local tmp=IsWaiting(transports[unit_id].target)
				Spring.GiveOrderToUnit(transports[unit_id].target,CMD.WAIT, {},{""})
				guarded_units[transports[unit_id].target].waiting=false
				---local tmp2=IsWaiting(transports[unit_id].target)
			end ]]--		
		end
	end
end



function widget:GameFrame(n)	
	if ((n%30)<1) then
		local transport_id
		local transport
		for transport_id,transport in pairs(transports) do
			local tx, ty, tz
			if transport_id then
				tx, ty, tz = Spring.GetUnitPosition(transport_id)
			end
			if not tx then
				LogMessage("removing dead transport from list")
					--transports[transport_id]=nil
				RemoveTransport(transport_id)
			else
				CheckConsistency(transport_id)
				UpdateTransport(transport_id, transport)			
			end
		end --end loop
	end
end



--- section borrowed from hook_quicktrans.lua , with modifications and clean-up

local function FindIdleTransport(targetID)
	local leastQCount=1000
	local leastDist = 50000000
	leastDist=leastDist*leastDist
	local idleTrans = nil
	local uList = Spring.GetTeamUnits(Spring.GetMyTeamID())
	
	local ux,uy,uz = Spring.GetUnitPosition(targetID)
	if not ux then 
		return
	end
	
	for _, ID in ipairs(uList) do
		UD = UnitDefs[Spring.GetUnitDefID(ID)]
		if UD.isTransport and UD.canFly then
			local tx,ty,tz = Spring.GetUnitPosition(ID)
			local queve=Spring.GetCommandQueue(ID)
			if tx and queve then				
				local count=table.getn(queve)
				if count==1 and queve[1].id==CMD.GUARD and queve[1].params[1]==targetID then
					count=-1
				end				
				if transports[ID] then --- already assigned, only reassign if theres nothing with count<100
					count=count+100 
				end				
				local dist=my_r_sq(tx-ux,ty-uy,tz-uz)
				if count<leastQCount or (count==leastQCount and dist<leastDist) then
					leastQCount=count
					leastDist=dist
					idleTrans=ID				
				end
			end
		end
	end
	return idleTrans
end

---end of section borrowed from hook_quicktrans.lua




function widget:KeyPress(key, modifier, isRepeat)
	if (modifier.ctrl) then	
		if not key then 
			return 
		end
		if (key == KEYSYMS.M) then
			LogMessage("guard key")
			local selected_units = Spring.GetSelectedUnits()
			for i = 1, table.getn(selected_units) do
				if (not guarded_units[selected_units[i]]) or (not guarded_units[selected_units[i]].guard) then
					local transport_id=FindIdleTransport(selected_units[i])
					if transport_id then
						LogMessage("assigning transport to guard")
						local x,y,z=Spring.GetUnitPosition(transport_id)
						if x then						
							Spring.GiveOrderToUnit(transport_id, CMD.UNLOAD_UNIT, {x,y,z}, {""})
						end
						if opts.use_guard_order then 
							Spring.GiveOrderToUnit(transport_id, CMD.GUARD, {selected_units[i]}, {"shift"})
						end
						GuardUnit(transport_id,selected_units[i])
						CheckConsistency(transport_id)
						CheckConsistency(selected_units[i])
					else
						LogMessage("no transport found")
					end
				end
			end
		end
		if (key == KEYSYMS.N) then
			LogMessage("unguard key")
			local selected_units = Spring.GetSelectedUnits()
			for i = 1, table.getn(selected_units) do
				if guarded_units[selected_units[i]] then
					CheckConsistency(selected_units[i])
					UnGuardUnit(selected_units[i])
				end
			end
		end
		if (key==KEYSYMS.E) then
			LogMessage("Eject!!!")
			local selected_units = Spring.GetSelectedUnits()
			if selected_units and table.getn(selected_units)>=1 then				
				for i,unit_id in ipairs(selected_units) do
					CheckConsistency(unit_id)
					Eject(unit_id)	
					
				end
			else
				for transport_id,transport in pairs(transports) do
					CheckConsistency(transport_id)
					Eject(transport_id)
				end
			end
		end
	end
end

--function widget:TextCommand(command)
--	if command then
--		Spring.Echo("command "..command)
--	end
--end
