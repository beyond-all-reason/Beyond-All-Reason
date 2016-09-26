function gadget:GetInfo()
	return {
		name = "Randomised Death Sounds",
		desc = "Assign and play classes of unit death sounds",
		author = "FLOZi (C. Lawrence), rewrite of DeathSounds.lua by Argh",
		date = "19/05/2011",
		license = "Public Domain",
		layer = 1,
		enabled = true
	}
end

-- Localisations
local random = math.random

-- Synced Read
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitNeutral = Spring.GetUnitNeutral
local GetUnitPosition = Spring.GetUnitPosition

-- Unsynced Ctrl
local PlaySoundFile = Spring.PlaySoundFile

-- constants
local DEFAULT_VOLUME = 15
local SOUNDS_PATH = "sounds/deathsounds/"
local GAIA_TEAM_ID = Spring.GetGaiaTeamID()

-- variables
local soundClasses = {}
local soundClassSizes = {}
local udSoundCache = {}
local udVolumeCache = {}

-- included for RecursiveFileSearch
 local VFSUtils = VFS.Include('gamedata/VFSUtils.lua')

if (gadgetHandler:IsSyncedCode()) then
-- SYNCED

	function gadget:Initialize()
		local subDirs = VFS.SubDirs(SOUNDS_PATH)
		for i = 1, #subDirs do
			local subDir = subDirs[i]
			if not subDir:match("/%.svn") then
				local dirName = string.gsub(subDir,SOUNDS_PATH,'')
				dirName = string.gsub(dirName,"/",'')
				-- Spring.Echo (dirName)
				soundClasses[dirName] = RecursiveFileSearch(subDir)
				soundClassSizes[dirName] = #soundClasses[dirName]			
			end
		end
		for unitDefID, unitDef in pairs(UnitDefs) do
			local cp = unitDef.customParams
			if cp and cp.death_sounds then
				udSoundCache[unitDefID] = cp.death_sounds
				udVolumeCache[unitDefID] = cp.death_volume or DEFAULT_VOLUME
			end
		end
	end


	function gadget:UnitDestroyed(unitID, unitDefID, teamId,attackerID)
		--if attackerID ~= nil then --Add this so that units who are destroyed via lua (like salvaging) or self destructed, will not play an overlapping sound effect
			local soundClass = udSoundCache[unitDefID]
			-- Spring.Echo (soundClass)
			-- Spring.Echo (soundClasses)
			-- Spring.Echo (soundClassSizes)
			if soundClass then
				local choice = random(soundClassSizes[soundClass])
				local x, y, z = GetUnitPosition(unitID)
				local volume = udVolumeCache[unitDefID]
				--Spring.Echo("OmgSounds!")
				PlaySoundFile(soundClasses[soundClass][choice], volume, x, y, z)
			end
		--end
	end

end