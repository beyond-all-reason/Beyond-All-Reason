local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Attack and Move Notification",
		desc = "v0.31 Notifes when a unit is attacked or a move command failed",
		author = "knorke & very_bad_soldier",
		date = "Dec , 2011",
		license = "GPLv2",
		layer = 0,
		enabled = true
	}
end

local alarmInterval = 15        --seconds

local spGetLocalTeamID = Spring.GetLocalTeamID
local spPlaySoundFile = Spring.PlaySoundFile
local spEcho = Spring.Echo
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spIsUnitInView = Spring.IsUnitInView
local spGetUnitPosition = Spring.GetUnitPosition
local spSetLastMessagePosition = Spring.SetLastMessagePosition
local random = math.random

local lastAlarmTime = nil
local lastCommanderAlarmTime = nil
local localTeamID = nil

local isCommander = {}
local unitHumanName = {}
local unitUnderattackSounds = {}

local function refreshUnitInfo()
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams.iscommander then
			isCommander[unitDefID] = true
		end
		if not unitDef.customParams.nohealthbars then
			unitHumanName[unitDefID] = unitDef.translatedHumanName
			if unitDef.sounds.underattack and #unitDef.sounds.underattack > 0 then
				unitUnderattackSounds[unitDefID] = unitDef.sounds.underattack
			end
		end
	end
end

function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
	localTeamID = spGetLocalTeamID()
end

function widget:GameStart()
	widget:PlayerChanged()
end

function widget:Initialize()
	refreshUnitInfo()

	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		widget:PlayerChanged()
	end

	localTeamID = spGetLocalTeamID()
	lastAlarmTime = spGetTimer()
	lastCommanderAlarmTime = spGetTimer()
	math.randomseed(os.time())
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if localTeamID ~= unitTeam or damage < 10 then
		return
	end
	--Spring.Echo(corcomID, unitID)
	local now = spGetTimer()
	if isCommander[unitDefID] then
		--commander under attack must always be played! (10 sec retrigger alert though)
		--Spring.Echo("Commander under attack!")
		if spDiffTimers(now, lastCommanderAlarmTime) < alarmInterval then
			return
		end
		lastCommanderAlarmTime = now
	else
		if spIsUnitInView(unitID) then
			return --ignore other teams and units in view
		end
		if spDiffTimers(now, lastAlarmTime) < alarmInterval then
			return
		end
	end
	if unitHumanName[unitDefID] then
		lastAlarmTime = now
		spEcho( Spring.I18N('ui.moveAttackNotify.underAttack', { unit = unitHumanName[unitDefID] }) )

		if unitUnderattackSounds[unitDefID] then
			local id = random(1, #unitUnderattackSounds[unitDefID]) --pick a sound from the table by random --(id 138, name warning2, volume 1)
			local soundFile = unitUnderattackSounds[unitDefID][id].name
			--if not udef.decoyfor or (udef.decoyfor ~= 'armcom' and udef.decoyfor ~= 'corcom') then
			spPlaySoundFile(soundFile, unitUnderattackSounds[unitDefID][id].volume, nil, "sfx")
			--end
		end

		local x, y, z = spGetUnitPosition(unitID)
		if x and y and z then
			spSetLastMessagePosition(x, y, z)
		end
	end
end

function widget:UnitMoveFailed(unitID, unitDefID, unitTeam)
	spEcho( Spring.I18N('ui.moveAttackNotify.cantMove', { unit = unitHumanName[unitDefID] }) )
end

function widget:LanguageChanged()
	refreshUnitInfo()
end
