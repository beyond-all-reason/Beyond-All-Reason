
local QueuedSpawnList = {}
local function AddToSpawnQueue(unitName, posx, posy, posz, facing, team, frame, blocking, resurrected)
	
    local blocking = blocking
    if blocking == nil then blocking = UnitDefNames[unitName].blocking end

    local resurrected = resurrected
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
            for i = 1, #QueuedSpawnList do
                local TestedQueueFrame = QueuedSpawnList[i].frame
                if TestedQueueFrame >= QueueSpawnCommand.frame then
                    table.insert(QueuedSpawnList, i, QueueSpawnCommand)
                    break
                elseif i == #QueuedSpawnList then
                    table.insert(QueuedSpawnList, QueueSpawnCommand)
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
		for i = 1,QueuedSpawnsNumber do
			if QueuedSpawnList[1] and n >= QueuedSpawnList[1].frame then
				local unitID = Spring.CreateUnit(
                    QueuedSpawnList[1].unitName, 
                    QueuedSpawnList[1].posx, 
                    QueuedSpawnList[1].posy, 
                    QueuedSpawnList[1].posz,
                    QueuedSpawnList[1].facing,
                    QueuedSpawnList[1].team
                )
				if unitID and QueuedSpawnList[1].blocking == false then
					Spring.SetUnitBlocking(unitID, false, false, true)
				end
                if unitID and QueuedSpawnList[1].resurrected == true then
					Spring.SetUnitRulesParam(unitID, "resurrected", 1, {inlos=true})
                    Spring.SetUnitHealth(unitID, 10)
				elseif unitID then
                    GG.ScavengersSpawnEffectUnitID(unitID)
                end
                table.remove(QueuedSpawnList, 1)
			elseif not QueuedSpawnList[1] then
                break
            end
		end
	end
end


local QueuedDestroyList = {}
local function AddToDestroyQueue(unitID, selfd, reclaimed, frame)
    local selfd = selfd
    if selfd == nil then selfd = false end

    local reclaimed = reclaimed
    if reclaimed == nil then reclaimed = false end

    if Spring.ValidUnitID(unitID) then
		local QueueDestroyCommand = {
            unitID = unitID,
            frame = frame, 
            selfd = selfd, 
            reclaimed = reclaimed, 
        }
        if #QueuedDestroyList > 0 then
            for i = 1, #QueuedDestroyList do
                local TestedQueueFrame = QueuedDestroyList[i].frame
                if TestedQueueFrame >= QueueDestroyCommand.frame then
                    table.insert(QueuedDestroyList, i, QueueDestroyCommand)
                    break
                elseif i == #QueuedDestroyList then
                    table.insert(QueuedDestroyList, QueueDestroyCommand)
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
			if QueuedDestroyList[1] and n >= QueuedDestroyList[1].frame then
				Spring.DestroyUnit(
                    QueuedDestroyList[1].unitID,
                    QueuedDestroyList[1].selfd,
                    QueuedDestroyList[1].reclaimed
                )
				table.remove(QueuedDestroyList, 1)
			elseif not QueuedDestroyList[1] then
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