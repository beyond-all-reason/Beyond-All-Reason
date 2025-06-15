shard_include( "behaviour" )
BehaviourFactory = class(AIBase)

function BehaviourFactory:Init()
	self.behaviours = shard_include( "behaviours" )
	self.scoutslist = {}
	self.DebugEnabled = false
end

function BehaviourFactory:AddBehaviours(unit)
	if unit == nil then
		self.game:SendToConsole("Warning: Shard BehaviourFactory:AddBehaviours was asked to provide behaviours to a nil unit")
		return
	end
	if not unit:Internal():IsMine(self.game:GetTeamID()) then
		self.game:SendToConsole('caution BehaviourFactory:AddBehaviours was asked to provide behaviour to not my unit',unit:Internal():Name())
	end
	-- add behaviours here
	-- unit:AddBehaviour(behaviour)
	local b = self.behaviours[unit:Internal():Name()]
	if b == nil then
		b = self:defaultBehaviours(unit)
	end
	for i,behaviour in ipairs(b) do
		local t = behaviour()
		t:SetAI(self.ai)
		t:SetUnit(unit)
		t:Init()
		unit:AddBehaviour(t)
	end
end

function BehaviourFactory:defaultBehaviours(unit)
	local b = {}
	local u = unit:Internal()
	local un = u:Name()
	local army = self.ai.armyhst
	-- game:SendToConsole(un, "getting default behaviours")
	if army.unitTable[un].isFactory or army.unitTable[un].speed > 0 then
		table.insert(b, BootBST)
	end

	if army.commanderList[un] then
		table.insert(b, CommanderBST)
		table.insert(b,BuildersBST)
	end
	if army.techs[un] then
		table.insert(b,BuildersBST)
	end
	if army.engineers[un] then
		table.insert(b,EngineerBST)
	end
	if army.rezs[un] then
		--self:EchoDebug()
		if math.random() > 0.5 then
			table.insert(b, ReclaimBST)
		else
			table.insert(b, AttackerBST)
		end
	end
-- 	if army.engineers[un] then
-- 		if math.random() > 0.5 then
-- 			table.insert(b, ReclaimBST)
-- 		else
-- 			table.insert(b, AttackerBST)
-- 		end
-- 	end
	if army.wartechs[un] then
		--self:EchoDebug()
		table.insert(b,BuildersBST)
	end
	if army.amptechs[un] then
		table.insert(b,BuildersBST)
		--self:EchoDebug()
	end
	if army.jammers[un] then
		--self:EchoDebug()
		table.insert(b, AttackerBST)
	end
	if army.radars[un] then
		--self:EchoDebug()
		--table.insert(b, AttackerBST)
	end
	if army.scouts[un] then
		--self:EchoDebug()
		table.insert(b, ScoutBST)
	end
	if army.raiders[un] then
		table.insert(b, RaidBST)
 		table.insert(b, ScoutBST)
		--self:EchoDebug()
	end
	if army.breaks[un] then
		table.insert(b, AttackerBST)
		--self:EchoDebug()
	end
	if army.artillerys[un] then
		table.insert(b, AttackerBST)
		--self:EchoDebug()
	end
	if army.battles[un] then
		table.insert(b, AttackerBST)
		--self:EchoDebug()
	end

	if army.bomberairs[un] then
		--self:EchoDebug()
		table.insert(b, BomberBST)
	end
	if army.airgun[un] then
		table.insert(b, RaidBST)
		--self:EchoDebug()
	end
	if army.fighterairs[un] then
		--self:EchoDebug()
	end
	if army.paralyzers[un] then
		--self:EchoDebug()
	end

	if army.antiairs[un] then
		--self:EchoDebug()
	end
	if army.subkillers[un] then
		table.insert(b, AttackerBST)
		--self:EchoDebug()
	end
	if army.heavyAmphibious[un] then
		table.insert(b, AttackerBST)
		--self:EchoDebug()
	end
	if army.amphibious[un] then
		--table.insert(b, ScoutBST)
		table.insert(b, AttackerBST)
		--table.insert(b, RaidBST)
		--self:EchoDebug()
	end
	if army.transports[un] then
		--self:EchoDebug()
	end
	if army.spys[un] then
		--self:EchoDebug()
	end
	if army.miners[un] then
		--self:EchoDebug()
	end
	if army.spiders[un] then
		table.insert(b, ScoutBST)
		table.insert(b, RaidBST)
		--self:EchoDebug()
	end
	if army.antinukes[un] then
		table.insert(b, AntinukeBST)
		--self:EchoDebug()
	end
	if army.crawlings[un] then
		--self:EchoDebug()
	end
	if army.cloakables[un] then
		--self:EchoDebug()
	end
	if army._nano_[un] then
		--table.insert(b, WardBST)
		table.insert(b, CleanerBST)
	end



	if self.ai.armyhst.unitTable[un].isBuilding then
		--table.insert(b, WardBST) --tells defending units to rush to threatened buildings
		if self.ai.armyhst._silo_[un] then
			table.insert(b, NukeBST)
		elseif self.ai.armyhst._antinuke_[un] then
			table.insert(b, AntinukeBST)
		--elseif self.ai.armyhst.bigPlasmaList[un] then
		--	table.insert(b, BombardBST)
		elseif self.ai.armyhst.unitTable[un].isStaticBuilder then
			table.insert(b,LabsBST)
		end
	end

	local alreadyHave = {}
	for i = #b, 1, -1 do
		local behaviour = b[i]
		if alreadyHave[behaviour] then
			--game:SendToConsole(self.ai.id, "duplicate behaviour", u:ID(), u:Name())
			table.remove(b, i)
		else
			alreadyHave[behaviour] = true
		end
	end
	--game:SendToConsole(self.ai.id, #b, "behaviours", u:ID(), u:Name())

	return b
end
--[[
    if army.factoryMobilities[un] then
   --self:EchoDebug()
   elseif army._mex_[un] then
   --self:EchoDebug()
   elseif army._nano_[un] then
   --self:EchoDebug()
   elseif army._wind_[un] then
   --self:EchoDebug()
   elseif army._tide_[un] then
   --self:EchoDebug()
   elseif army._advsol_[un] then
   --self:EchoDebug()
   elseif army._solar_[un] then
   --self:EchoDebug()
   elseif army._estor_[un] then
   --self:EchoDebug()
   elseif army._mstor_[un] then
   --self:EchoDebug()
   elseif army._convs_[un] then
   --self:EchoDebug()
   elseif army._llt_[un] then
   --self:EchoDebug()
   elseif army._popup1_[un] then
   --self:EchoDebug()
   elseif army._specialt_[un] then
   --self:EchoDebug()
   elseif army._heavyt_[un] then
   --self:EchoDebug()
   elseif army._aa1_[un] then
   --self:EchoDebug()
   elseif army._flak_[un] then
   --self:EchoDebug()
   elseif army._fus_[un] then
   --self:EchoDebug()
   elseif army._popup2_[un] then
   --self:EchoDebug()
   elseif army._jam_[un] then
   --self:EchoDebug()
   elseif army._radar_[un] then
   --self:EchoDebug()
   elseif army._geo_[un] then
   --self:EchoDebug()
   elseif army._silo_[un] then
   --self:EchoDebug()
   elseif army._antinuke_[un] then
   --self:EchoDebug()
   elseif army._sonar_[un] then
   --self:EchoDebug()
   elseif army._shield_[un] then
   --self:EchoDebug()
   elseif army._juno_[un] then
   --self:EchoDebug()
   elseif army._laser2_[un] then
   --self:EchoDebug()
   elseif army._lol_[un] then
   --self:EchoDebug()
   elseif army._coast1_[un] then
   --self:EchoDebug()
   elseif army._coast2_[un] then
   --self:EchoDebug()
   elseif army._plasma_[un] then
   --self:EchoDebug()
   elseif army._torpedo1_[un] then
   --self:EchoDebug()
   elseif army._torpedo2_[un] then
   --self:EchoDebug()
   elseif army._torpedoground_[un] then
   --self:EchoDebug()
   elseif army._aabomb_[un] then
   --self:EchoDebug()
   elseif army._aaheavy_[un] then
   --self:EchoDebug()
   elseif army._aa2_[un] then
   --self:EchoDebug()
   else
   self:EchoDebug('mobile unit not in category')
   end

   ]]
