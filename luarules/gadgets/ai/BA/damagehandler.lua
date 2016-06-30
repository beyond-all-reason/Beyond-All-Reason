eps track of hits to our units

local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("DamageHandler: " .. inStr)
	end
end

DamageHandler = class(Module)

function DamageHandler:Name()
	return "DamageHandler"
end

function DamageHandler:internalName()
	return "damagehandler"
end

function DamageHandler:Init()
	self.lastHealth = {}
end

-- note: the attacker is always nil if it's on any team other than the AI's (not even allies register)
-- note: unitdamaged will not be called on self-destruct
--[[
function DamageHandler:UnitDamaged(unit, attacker, damage)
	-- if unit ~= nil then game:SendToConsole(unit:Team() .. " attacked (" .. game:GetTeamID() .. ")") end
	-- if attacker ~= nil then game:SendToConsole("by " .. attacker:Team() .. " (" .. game:GetTeamID() .. ")") end
	local friendlyFire = false
	if attacker ~= nil then
		if ai.friendlyTeamID[attacker:Team()] then friendlyFire = true end
	end
	if unit ~= nil and not friendlyFire then
		local unitID = unit:ID()
		local health = unit:GetHealth()
		local last = self.lastHealth[unitID]
		if last then
			local damage = self.lastHealth[unitID] - health
			-- game:SendToConsole(damage .. " damage to " .. unit:Name())
			-- self:DamageReport(damage, unit:GetPosition(), unit:Name())
		end
		self.lastHealth[unitID] = health
	end
end
]]--

function DamageHandler:UnitBuilt(unit)
	local unitID = unit:ID()
	self.lastHealth[unitID] = unit:GetHealth()
end

function DamageHandler:UnitDead(unit)
	local unitID = unit:ID()
	self.lastHealth[unitID] = nil
end

-- DangerCheck(attackerName, attackerID)
