--[[
    Gadget Manager Examples - TeamTransfer Integration Patterns
    
    This file demonstrates how to use the GadgetManager builder pattern
    for easy TeamTransfer integration in your gadgets.
]]--

local GadgetManager = Spring.Utilities.Include("luarules/modules/gadget_manager.lua")

--[[
    Example 1: Simple reason-based handlers
    Perfect for gadgets that need different logic per transfer reason
]]--
local function ExampleSimpleReasonHandlers()
    local transferManager = GadgetManager.CreateTeamTransferManager("MyGadget")
        :ForReason(GG.TeamTransfer.REASON.GIVEN, function(unitID, unitDefID, oldTeam, newTeam)
            Spring.Echo("Unit was given via /give command")
        end)
        :ForReason(GG.TeamTransfer.REASON.CAPTURE, function(unitID, unitDefID, oldTeam, newTeam)
            Spring.Echo("Unit was captured")
            -- Maybe award experience points for capture
        end)
        :Register()
    
    -- Later in gadget:Shutdown()
    transferManager:Unregister()
end

--[[
    Example 2: Same handler for multiple reasons
    Perfect when you want to handle multiple transfer types the same way
]]--
local function ExampleSharedHandler()
    local function handleTransfer(unitID, unitDefID, oldTeam, newTeam)
        -- Update some unit state or trigger effects
        Spring.Echo("Unit " .. unitID .. " changed teams")
    end
    
    local transferManager = GadgetManager.CreateTeamTransferManager("MyGadget")
        :ForReason(GG.TeamTransfer.REASON.GIVEN, handleTransfer)
        :ForReason(GG.TeamTransfer.REASON.TAKE, handleTransfer)
        :ForReason(GG.TeamTransfer.REASON.CAPTURE, handleTransfer)
        :Register()
end

--[[
    Example 3: Using built-in transfer handlers
    Leverage common patterns without writing custom logic
]]--
local function ExampleBuiltInHandlers()
    local myUnitSubSystems = {} -- Your unit tracking system
    
    local transferManager = GadgetManager.CreateTeamTransferManager("MyGadget")
        -- Forward transfers to sub-units (like carrier spawner pattern)
        :ForReason(GG.TeamTransfer.REASON.GIVEN, 
            GadgetManager.TransferHandlers.ForwardToSubUnits(
                function(unitID) return myUnitSubSystems[unitID] end,
                GG.TeamTransfer.REASON.SOME_CUSTOM_REASON
            )
        )
        -- Update unit state on transfer
        :ForReason(GG.TeamTransfer.REASON.CAPTURE,
            GadgetManager.TransferHandlers.UpdateUnitState(function(unitID, newTeam)
                myUnitSubSystems[unitID] = { team = newTeam, capturedAt = Spring.GetGameFrame() }
            end)
        )
        -- Log transfers for debugging
        :ForReason(GG.TeamTransfer.REASON.TAKE,
            GadgetManager.TransferHandlers.LogTransfer("TakeCommand")
        )
        :Register()
end

--[[
    Example 4: Adding transfer validators
    Control whether transfers are allowed
]]--
local function ExampleWithValidators()
    local transferManager = GadgetManager.CreateTeamTransferManager("MyGadget")
        :ForReason(GG.TeamTransfer.REASON.GIVEN, function(unitID, unitDefID, oldTeam, newTeam)
            -- Handle successful transfer
        end)
        :WithValidator(function(unitID, unitDefID, oldTeam, newTeam, reason)
            -- Block transfers of certain unit types
            if UnitDefs[unitDefID].name == "special_unit" then
                return false
            end
            return true
        end)
        :WithValidator(function(unitID, unitDefID, oldTeam, newTeam, reason)
            -- Block transfers during certain game states
            if Spring.GetGameFrame() < 1800 then -- First 30 seconds
                return false
            end
            return true
        end)
        :Register()
end

--[[
    Integration Pattern for your gadget:
    
    1. Include at top of file:
       local GadgetManager = Spring.Utilities.Include("luarules/modules/gadget_manager.lua")
       local transferManager
    
    2. In gadget:Initialize():
       transferManager = GadgetManager.CreateTeamTransferManager("YourGadgetName")
           :ForReason(reason1, handler1)
           :ForReason(reason2, handler2)
           :WithValidator(validatorFunc)
           :Register()
    
    3. In gadget:Shutdown():
       if transferManager then
           transferManager:Unregister()
       end
]]--
