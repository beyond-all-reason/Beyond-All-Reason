---@meta actions

---@class (partial) MissionContext
---@field Carry fun(carrierName: string, cargoName: string, fx: number, fz: number)
---@field IsCarried fun(cargoName: string): boolean
---@field IsDelivered fun(cargoName: string): boolean

---@class TransportCarryChain : MissionEffect
---@field By fun(carrier: MissionUnitRef): TransportCarryChain
---@field To fun(fx: number, fz: number): TransportCarryChain

---@class TransportActions
---@field Carry fun(cargo: MissionUnitRef): TransportCarryChain a carrier picks the unit up and sets it down at a spot
---@field Carried fun(cargo: MissionUnitRef): MissionCondition aboard a transport right now
---@field Delivered fun(cargo: MissionUnitRef): MissionCondition set down after a Carry; latched

---@type TransportActions
Transport = {}
