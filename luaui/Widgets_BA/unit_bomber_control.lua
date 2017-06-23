function widget:GetInfo()
	return {
		name	= "Bomber control",
		desc	= "Makes bombers execute queue properly [v1.1]",
		author	= "dizekat",
		date	= "2010-02-04",
		license	= "GPL v2 or later",
		layer	= 5,
		enabled	= true
	}
end

--fixed for 0.83 (by vbs)

local bombers={armpnix=true, armcybr=true, corgripn=true, armthund=true, armsb=true, corhurc=true, corsb=true, corshad=true, cortitan=true}
local bomber_uds={}

local GetUnitWeaponState   = Spring.GetUnitWeaponState
local GetUnitDefID         = Spring.GetUnitDefID
local GiveOrderToUnit      = Spring.GiveOrderToUnit
local GetGameFrame         = Spring.GetGameFrame
local GetMyTeamID          = Spring.GetMyTeamID
local GetUnitTeam          = Spring.GetUnitTeam
local GetGameFrame         = Spring.GetGameFrame
local GetCommandQueue      = Spring.GetCommandQueue
local GetUnitStates        = Spring.GetUnitStates

local my_bombers={}

local function AddUnit(unit_id, unit_udid_)
	local unit_udid=unit_udid_
	if GetUnitTeam(unit_id)==GetMyTeamID() then --my unit
		if unit_udid==nil then
			unit_udid=GetUnitDefID(unit_id)
		end
		local ud=UnitDefs[unit_udid]
		if ud and bomber_uds[unit_udid] then
			if  ud.primaryWeapon then
				local _,reloaded_,reloadFrame = GetUnitWeaponState(unit_id,ud.primaryWeapon)		
				my_bombers[unit_id]={reloaded=reloaded_, reload_frame}
				--Spring.Echo("bomber added")
			end
		end
	end	
end

function widget:UnitCreated(unit_id, unit_udid, unit_tid)
	if unit_tid==Spring.GetMyTeamID() then
		AddUnit(unit_id,unit_udid)
	end
end

local function RemoveUnit(unit_id)
	my_bombers[unit_id]=nil
end

function widget:UnitDestroyed(unit_id, unit_udid, unit_tid)
	RemoveUnit(unit_id)
end


function widget:UnitGiven(unit_id, unit_udid, old_team, new_team)
	RemoveUnit(unit_id)
	if new_team==GetMyTeamID() then
		AddUnit(unit_id,unit_udid)
	end	
end


local function UpdateUnitsList()
	local my_team=GetMyTeamID()
	my_bombers={}
	for _,unit_id in ipairs(Spring.GetTeamUnits(my_team)) do
		AddUnit(unit_id,nil)
	end
end

function widget:Initialize()
	for i,ud in pairs(UnitDefs) do
		if bombers[ud.name] then
			bomber_uds[i]=ud
			--bomber_uds[i]=true
			ud.reloadTime    = 0
			ud.primaryWeapon = 0
			ud.shieldPower   = 0
			for i=1,#ud.weapons do
				local WeaponDefID = ud.weapons[i].weaponDef;
				local WeaponDef   = WeaponDefs[ WeaponDefID ];
				if (WeaponDef.reload>ud.reloadTime) then
					ud.reloadTime    = WeaponDef.reload;
					ud.primaryWeapon = i;
				end
			end
		end
	end
	UpdateUnitsList()
end

local current_team=1234567

function widget:Update(dt)
	local gameFrame = GetGameFrame()
    if ((gameFrame%15)<1) then
		local my_team=GetMyTeamID()
		if my_team~=current_team then
			current_team=my_team
			UpdateUnitsList()
		end
    end
	if ((gameFrame%3)<1) then
		for bomber_id,bomber_data in pairs(my_bombers) do
		    local udid = GetUnitDefID(bomber_id)
			local ud = UnitDefs[udid or -1]
			if ud and ud.primaryWeapon then
				local _,reloaded,reload_frame = GetUnitWeaponState(bomber_id, ud.primaryWeapon)
				local did_shot=(bomber_data.reloaded and not reloaded) or (bomber_data.reload_frame~=reload_frame)
				bomber_data.reloaded=reloaded
				bomber_data.reload_frame=reload_frame
				if did_shot then
					local commands=GetCommandQueue(bomber_id,50)
					if commands and commands[1] and commands[1].id==CMD.ATTACK and commands[2] then
						local got_next_orders=false
						for i=2,#commands do
							if commands[i].id ~= CMD.SET_WANTED_MAX_SPEED then
								got_next_orders=true
								break
							end
						end
						if got_next_orders then
							--Spring.Echo(CMD[commands[2].id])
							GiveOrderToUnit(bomber_id, CMD.REMOVE,{commands[1].tag},{})
							local states=GetUnitStates(bomber_id)
							if states and (states['repeat']) then
								GiveOrderToUnit(bomber_id, commands[1].id,commands[1].params,{'shift'})
							end
						end
					end
				end
			end
		end
	end	
end


