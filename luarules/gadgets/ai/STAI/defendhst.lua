DefendHST = class(Module)

function DefendHST:Name()
	return "DefendHST"
end

function DefendHST:internalName()
	return "defendhst"
end

function DefendHST:Init()
	self.DebugEnabled = false
	self.units = {}
	self.squads = {}
	self.targets = {}
end

function DefendHST:Update()
	------
end

function DefendHST:assignToDanger()
	for X,cells in pairs (self.DANGER) do
		for Z, cell in pairs(cells) do



end

function DefendHST:checkBuilders()
end

function DefendHST:checkEnemies()
	local checked = {}
	local dangers = {}
	local defaultDanger = {
		armedM = 0,
		pos = {x=0,y=0,z=0},
		units = {},
		counter = 0,
		layers = {},
		cells = {}
		}
	for X,cells in pairs(self.ai.targethst.ENEMIES) do
		for Z,cell in pairs(cells) do
			if not checked [cell] then
				local armedM = self.ai.maphst:getCellsFields(cell.POS,{'armedM'},self.ai.targethst.ENEMIES)
				if armedM > 0 then
					dangers[X] = dangers[X] or {}
					dangers[X][Z] = dangers[X][Z] or  defaultDanger
					dangers[X][Z].armedM = dangers[X][Z].armedM + armedM
					dangers[X][Z].pos = self.ai.tool:sumPos(dangers[X][Z].pos,cell.POS)
					dangers[X][Z].units = self.ai.tool:tableConcat({dangers[X][Z].units,cell.units})
					dangers[X][Z].counter = dangers[X][Z].counter + 1
					dangers[X][Z].cells = table.insert(dangers[X][Z].cells,cell)
				end
			checked[cell] = true
			end
		end
	end
end
