local TransferVerbs = VFS.Include("modules/transfer/lib/mission_verbs.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")

return {
	---@param file MissionDslFile
	ForFile = function(file)
		return { env = { Transfer = TransferVerbs.MakeTransfer(file.groups or {}) } }
	end,
	---@param runtime MissionRuntime
	Context = function(runtime)
		return {
			---@param fiat boolean|nil skip the mode's say (Transfer.Give)
			TransferGroup = function(groupName, teamID, fiat)
				local units = runtime.GroupUnits(groupName)
				if units == nil then
					runtime.Log(LOG.WARNING, "Transfer.Units: no roster group named " .. groupName)
					return
				end
				-- Policy is decided per giving team, so a group whose units were
				-- spawned for different teams asks once per owner.
				local byOwner = {}
				for _, unitID in ipairs(units) do
					if Spring.ValidUnitID(unitID) then
						local owner = Spring.GetUnitTeam(unitID)
						if owner ~= nil and owner ~= teamID then
							byOwner[owner] = byOwner[owner] or {}
							local batch = byOwner[owner]
							batch[#batch + 1] = unitID
						end
					end
				end
				-- Through the module that owns transfer, never Spring.TransferUnit: one
				-- pipeline validates, prices and announces every handover.
				--
				-- The engine clears the neutral flag as part of the transfer, so
				-- nothing here has to: measured, neutral=true team=2 going in,
				-- neutral=false team=0 coming out.
				--
				-- Hold fire is NOT cleared, and must be. A base that has changed hands
				-- is expected to defend its new owner, and an inherited outpost that
				-- sits out the waves it exists to survive is worse than one that never
				-- arrived.
				local Transfer = ModuleHandler.Get("transfer")
				for owner, batch in pairs(byOwner) do
					if fiat then
						Transfer.Give(batch, teamID)
					else
						Transfer.Units(batch, teamID, owner)
					end
				end
				for _, unitID in ipairs(units) do
					runtime.ReleaseHoldFire(unitID)
				end
			end,
		}
	end,
}
