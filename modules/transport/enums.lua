local M = {}

M.ModOptions = {
	TransportEnemy = "transportenemy",
	CommanderTransportSlow = "comm_trans_slow",
}

---@class TransportEnemyFields
---@field NotCommanders "notcoms"
---@field None "none"

---@type TransportEnemyFields
M.TransportEnemy = {
	NotCommanders = "notcoms",
	None = "none",
}

return M
