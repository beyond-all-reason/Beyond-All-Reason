---@meta callins

---Call-ins the transfer module sends to LuaUI, from modules/transfer/gadgets/game_share_policy_forwarding.lua.
---@class (partial) Widget
---
---A unit's buildspeed debuff started or was renewed; the healthbars draw its remaining time.
---@field UnitBuildspeedDebuffHealthbars? fun(self, unitID: UnitID, startFrame: integer, expireFrame: integer)
