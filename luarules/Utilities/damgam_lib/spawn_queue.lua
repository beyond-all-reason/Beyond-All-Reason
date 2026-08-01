
local QueuedSpawnList = {}
local function AddToSpawnQueue(unitName, posx, posy, posz, facing, team, frame, blocking, resurrected)

    if blocking == nil then blocking = UnitDefNames[unitName].blocking end
    if resurrected == nil then resurrected = false end

	if UnitDefNames[unitName] then
		local QueueSpawnCommand = {
            unitName = unitName,
            frame = frame,
            posx = posx,
            posy = posy,
            posz = posz,
            facing = facing,
            team = team,
            blocking = blocking,
            resurrected = resurrected,
        }
        if #QueuedSpawnList > 0 then
            local len = #QueuedSpawnList
            for i = 1, len do
                local TestedQueueFrame = QueuedSpawnList[i].frame
                if TestedQueueFrame >= QueueSpawnCommand.frame then
                    table.insert(QueuedSpawnList, i, QueueSpawnCommand)
                    break
                elseif i == len then
                    QueuedSpawnList[len + 1] = QueueSpawnCommand
                    break
                end
            end
        else
            QueuedSpawnList[1] = QueueSpawnCommand
        end
	else
		Spring.Echo("[Spawn Queue] Failed to queue "..unitName..", invalid unitDefName")
	end
end

local function SpawnUnitsFromQueue(n) -- Call this every frame in your gadget.
	local QueuedSpawnsNumber = #QueuedSpawnList
	if QueuedSpawnsNumber > 0 then
		local removedCount = 0
		for i = 1,QueuedSpawnsNumber do
			local item = QueuedSpawnList[1]
			if item and n >= item.frame then
				local unitID = Spring.CreateUnit(
                    item.unitName,
                    item.posx,
                    item.posy,
                    item.posz,
                    item.facing,
                    item.team
                )
				if unitID and item.blocking == false then
					Spring.SetUnitBlocking(unitID, false, false, true)
				end
                if unitID and item.resurrected == true then
					Spring.SetUnitRulesParam(unitID, "resurrected", 1, {inlos=true})
                    Spring.SetUnitHealth(unitID, 10)
				elseif unitID then
                    GG.ScavengersSpawnEffectUnitID(unitID)
                end
                table.remove(QueuedSpawnList, 1)
			elseif not item then
                break
            end
		end
	end
end


local QueuedDestroyList = {}
local function AddToDestroyQueue(unitID, selfd, reclaimed, frame)
    if selfd == nil then selfd = false end
    if reclaimed == nil then reclaimed = false end

    if Spring.ValidUnitID(unitID) then
		local QueueDestroyCommand = {
            unitID = unitID,
            frame = frame,
            selfd = selfd,
            reclaimed = reclaimed,
        }
        if #QueuedDestroyList > 0 then
            local len = #QueuedDestroyList
            for i = 1, len do
                local TestedQueueFrame = QueuedDestroyList[i].frame
                if TestedQueueFrame >= QueueDestroyCommand.frame then
                    table.insert(QueuedDestroyList, i, QueueDestroyCommand)
                    break
                elseif i == len then
                    QueuedDestroyList[len + 1] = QueueDestroyCommand
                    break
                end
            end
        else
            QueuedDestroyList[1] = QueueDestroyCommand
        end
	else
		--Spring.Echo("[Spawn Queue] Failed to queue destruction of unit "..unitID..", invalid unit")
	end
end

local function DestroyUnitsFromQueue(n) -- Call this every frame in your gadget.
	local QueuedDestroyNumber = #QueuedDestroyList
	if QueuedDestroyNumber > 0 then
		for i = 1,QueuedDestroyNumber do
			local item = QueuedDestroyList[1]
			if item and n >= item.frame then
				Spring.DestroyUnit(
                    item.unitID,
                    item.selfd,
                    item.reclaimed
                )
				table.remove(QueuedDestroyList, 1)
			elseif not item then
				break
			end
		end
	end
end

return {
    AddToSpawnQueue = AddToSpawnQueue,
    AddToDestroyQueue = AddToDestroyQueue,
    SpawnUnitsFromQueue = SpawnUnitsFromQueue,
    DestroyUnitsFromQueue = DestroyUnitsFromQueue,
}
