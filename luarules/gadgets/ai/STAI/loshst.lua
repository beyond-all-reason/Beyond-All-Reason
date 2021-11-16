
local DebugDrawEnabled = false


LosHST = class(Module)

local losGridElmos = 256
local losGridElmosHalf = losGridElmos / 2

function LosHST:Name()
	return "LosHST"
end

function LosHST:internalName()
	return "loshst"
end



function LosHST:Init()
	self.DebugEnabled = true
	self.knownEnemies = {}
	self.ai.friendlyTeamID = {}
end

function LosHST:Update()
	local f = self.game:Frame()
	if f % 23 == 0 then
		--self.RADAR = scanEnemies2()
        self.ai.friendlyTeamID = {}
        self.ai.friendlyTeamID[self.game:GetTeamID()] = true
        for teamID, _ in pairs(self.ai.alliedTeamIds) do
            self.ai.friendlyTeamID[teamID] = true
        end
		-- update enemy jamming and populate list of enemies
		local enemies = self.game:GetEnemies()
		if enemies ~= nil then
			local enemyList = {}
			for i, e in pairs(enemies) do
				--self:unitLosState(e:ID())
				local upos = e:GetPosition()
				if not upos then --is dead
					self:cleanEnemy(e:ID())
				elseif self.ai.buildsitehst:isInMap(upos) then
					enemy = self:scanEnemy(e)
					if enemy then
						self.knownEnemies[e:ID()] = enemy
					end
				end
			end
		end
		self:Draw() --debugit
	end
end

function LosHST:UnitDead(unit)
	if self.knownEnemies[unit:ID()] then
		self:cleanEnemy(unit:ID())
	end
end

function LosHST:UnitDamaged(unit, attacker, damage)
	if  attacker ~= nil and attacker:AllyTeam() ~= self.ai.allyId then --TODO --WARNING NOTE ATTENTION CAUTION TEST ALERT
		self:scanEnemy(attacker,true) --a shoting unit is individuable by a medium player so is managed as a unit in LOS :full view
	end
end

function LosHST:cleanEnemy(id)

	if self.ai.IDsWeAreAttacking[id] then
		--self.ai.attackhst:TargetDied(self.ai.IDsWeAreAttacking[id])
	end
	if self.ai.IDsWeAreRaiding[id] then
		--self.ai.raidhst:TargetDied(self.ai.IDsWeAreRaiding[id])
	end
	if self.knownEnemies[id] then
		self:EchoDebug('clean',id,self.knownEnemies[id].name,self.knownEnemies[id].guls,self.knownEnemies[id].SPEED>0)
		table.remove(self.knownEnemies,id)
	end
end

function LosHST:scanEnemy(enemy,isShoting)
	-- game:SendToConsole("updating known enemies")
	local t = {} --a temporary table
	t.id = enemy:ID()
	t.name = enemy:Name()
	local ut =self.ai.armyhst.unitTable[t.name]
	if not t.name then
		self:Warn('nil name')
	end
	t.position = enemy:GetPosition() --if is died pos is nil -- exixtance check
	--we are interessed where the unit is right now, this is the threatening DEFENSIVE
	t.HIT = ut.HIT -- this is the most important OFFENSIVE data
	t.hitBy = ut.hitBy
	t.knownid = true
	t.hidden = false
	t.mobile = ut.speed > 0
	t.health = enemy:GetHealth()


	t.mType =ut.mtype
	t.GULS = Spring.GetUnitLosState(t.id ,self.ai.allyId,true)

	if not t.position then
		t = nil
		self:Warn('how do you are there????? ? ?  ?  ?   ?   ?     ?        ?                 ?              ?')
	elseif not t.position or t.GULS == 0 then--enemy dead,or not in sensor at all
		t = nil
	else
		self:EchoDebug('GULS',t.id,t.GULS)

		if isShoting or t.GULS >=7 or (t.GULS == 4 and ut.speed == 0) or (t.GULS == 6 and ut.speed == 0) then
			t.view = 1
			--full view

		elseif t.GULS == 2  or (t.GULS == 6) then -- blip RADAR check speed to hazard a mobile/immobile bet
			t.view = 0
			--pure radar
		elseif t.GULS == 4 then --mobile HIDDEN i see you one time, you are somewhere!!
			t.view = -1
			--pure radar
		else
			t = nil
			self:Warn('unespected GULS response',GULS,t.id,t.position.x,t.position.z,t.name)
		end
		if t then
			t.layer = self:setPosLayer(t.name,t.position)
			t.speedX,t.speedY,t.speedZ, t.SPEED = Spring.GetUnitVelocity ( t.id )
			self:EchoDebug(t.name,'X-Z SPEED',t.speedX,t.speedZ,t.SPEED)
			t.target = {x = t.position.x+( t.speedX*30),y = t.position.y,z = t.position.z + (t.speedZ*30)}
			t.dirX,t.dirY,t.dirZ = Spring.GetUnitDirection ( t.id )
			self:EchoDebug(t.name,'dir X-Z',t.dirX,t.dirZ)

		else
			self:cleanEnemy(enemy:ID())
		end
 	end


	return t
end

-- function LosHST:IsKnownEnemy(unit)
-- 	local id = unit:ID()
-- 	return self.knownEnemies[id]
-- end


function LosHST:viewPos(upos)
	local LosOrRadar, inLos, inRadar, jammed = Spring.GetPositionLosState(upos.x, upos.y, upos.z, self.ai.allyId)
	if Spring.IsPosInAirLos(upos.x, upos.y, upos.z, self.ai.allyId) then return 1 end
	if inLos and upos.y < 0 then return -1 end
	if inLos then return 0 end
	if inRadar then return true end
	--if inRadar then return nil end

	--if inRadar and upos.y < 0 and not jammed then return 'inSonar' -1 end
	--if inRadar and upos.y >= 0 and not jammed then return 'inRadar' 0 end
	return nil
end

function LosHST:setPosLayer(unitName,Pos)
	local ut = self.ai.armyhst.unitTable[unitName]
	local float = false
	if ut.mtype == 'air' then
		self.ai.needAntiAir = true --TODO need to move from here
		return 1
	end
	if Pos.y < 0 then
		return -1
	end
	if Spring.GetGroundHeight(Pos.x,Pos.z) < 0 then --TEST  WARNING
		float = true
	end

	return 0 , float
end



function LosHST:Draw()
	self.map:EraseAll(5)

	for id,data in pairs(self.knownEnemies) do

		local u = self.game:GetUnitByID(id)
		u:EraseHighlight(nil, nil, 5 )
-- 		self:Warn('unitidlosdraw',id,u:GetPosition())
-- 		print(u:GetPosition())
 		if not u:GetPosition() then
 			self:Warn('unit dead',id)
 			self:cleanEnemy(id)

-- 		self:Warn('losname',data.name)

		else
			self:Warn('draw',data.name,data.GULS,data.id)
			if data.view ==1 then
				if data.layer == 1 then
					u:DrawHighlight({1,1,0,1} , nil, 5 )
				end
				if data.layer == -1 then
					u:DrawHighlight({1,0,1,1} , nil, 5 )
				end
				if data.layer == 0 then
					u:DrawHighlight({0,1,1,1} , nil, 5 )
				end
			end
			if data.view == 0 then
				u:DrawHighlight({1,1,1,1} , nil, 5 )
			end
			if data.view == -1 then
				u:DrawHighlight({0,0,0,1} , nil, 5 )
			end
			self:EchoDebug('speeeed',data.SPEED,data.name)
			if data.SPEED and data.SPEED > 0 then
				map:DrawLine(data.position, {x=data.position.x+(data.speedX*30),y=data.position.y,z=data.position.z+(data.speedZ*30)}, {1,0,0,1}, nil, false, 5 )

			end
		end
	end
end




--[[ suggested of beherith
LOS
15 1111 have the los so other info are useless LOS
14 1110
13 1101
12 1100
11 1011
10 1010
9  1001
8  1000 last of LOS
RADAR
7 0111 in radar, already seen and have continous coverage so keep the ID last IDDD
6 0110 in R already in L but intermittent so pure RADAR
5 0101 in radar, and in continous coverage after los, but never in los so IMPOSSIBLE
4 0100 in PURE radar, never in los

3 0011 just already seen but not in R or L tecnically IMPOSSIBLE
2 0010  just already seen but not in R or L usable for a building that we know its already there and mobile that is there but where?

1 0001 not in radar not in los but continous.... IMPOSSIBLE
]]--





--[[ 1los 2 prev los 3 in rad 4 continous rad maybe this is correct
LOS
15 1111 have the los so other info are useless LOS
14 1110
13 1101
12 1100
11 1011
10 1010
9  1001
8  1000 last of LOS first time i see it

7 0111 see one time, in radar with continous LOS

RADAR
6 0110 see one time, in radar but intermittent so if mobile then RADAR, if building then LOS
5 0101 see one time, no in radar but have continous radar?? IMPOSSIBLE
4 0100 see on time, now HIDDEN but if is a building then LOS

3 0011 never seen ,in radar, with continous coverage ?? IMPOSSIBLE
2 0010 just in radar, never seen in losRADAR PURE

1 0001 not in radar not in los but continous.... IMPOSSIBLE
]]--


--[[int LuaSyncedRead::GetUnitLosState(lua_State* L)
{
    const CUnit* unit = ParseUnit(L, __func__, 1);
    if (unit == nullptr)
        return 0;

    const int allyTeamID = GetEffectiveLosAllyTeam(L, 2);
    unsigned short losStatus;
    if (allyTeamID < 0) {
        losStatus = (allyTeamID == CEventClient::AllAccessTeam) ? (LOS_ALL_MASK_BITS | LOS_ALL_BITS) : 0;
    } else {
        losStatus = unit->losStatus[allyTeamID];
    }

    constexpr int currMask = LOS_INLOS   | LOS_INRADAR;
    constexpr int prevMask = LOS_PREVLOS | LOS_CONTRADAR;

    const bool isTyped = ((losStatus & prevMask) == prevMask);

    if (luaL_optboolean(L, 3, false)) {
        // return a numeric value
        if (!CLuaHandle::GetHandleFullRead(L))
            losStatus &= ((prevMask * isTyped) | currMask);

        lua_pushnumber(L, losStatus);
        return 1;
    }

    lua_createtable(L, 0, 3);
    if (losStatus & LOS_INLOS) {
        HSTR_PUSH_BOOL(L, "los", true);
    }
    if (losStatus & LOS_INRADAR) {
        HSTR_PUSH_BOOL(L, "radar", true);
    }
    if ((losStatus & LOS_INLOS) || isTyped) {
        HSTR_PUSH_BOOL(L, "typed", true);
    }
    return 1;
}
ugh this is nasty
ok raw means it returns number instead of table
so the numeric integer of the mask bits
and I dont think you can get wether a unit is seen in airlos or regular los
its either seen or not
raw is generally preferred, as is much faster in than creating a table
isnt 'typed' meaning that its a radar dot that has been revealed or not?
I definately think so
so if you use raw = true
then result = 15 ( 1 1 1 1 ) means in radar, in los, known unittype
also, if result is > 2, that means that the unitdefID is known
cause the unitdefID of a unit is 'forgotten' if the unit leaves radar
so the key info here is these 4 bits:
I think the bits might be:
bit 0 : LOS_INLOS, unit is in LOS right now,
bit 1 : LOS_INRADAR unit is in radar right now,
bit 2: LOS_PREVLOS unit was in los at least once already, so the unitDefID can be queried
bit 3: LOS_CONTRADAR: unit has had continous radar coverage since it was spotted in LOS]]--
