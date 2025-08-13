local GadgetManager = {}

-- Generic gadget builder pattern
function GadgetManager.CreateGadget(gadgetName)
    local builder = {
        gadgetName = gadgetName,
        syncedActions = {},
        customRegistrations = {},
        customCleanups = {},
    }
    
    -- Fluent API for SyncedActionFallback registration
    function builder:WithSyncedAction(actionName, handler)
        if not handler then
            error("Missing handler for SyncedActionFallback '" .. actionName .. "' in gadget " .. self.gadgetName)
        end
        if type(handler) ~= "function" then
            error("Handler for SyncedActionFallback '" .. actionName .. "' must be a function, got " .. type(handler))
        end
        self.syncedActions[actionName] = handler
        return self
    end
    
    -- gadgets can register any custom logic
    function builder:WithCustomRegistration(registerFunc, cleanupFunc)
        table.insert(self.customRegistrations, registerFunc)
        table.insert(self.customCleanups, cleanupFunc)
        return self
    end
    
    function builder:Register()
        for actionName, handler in pairs(self.syncedActions) do
            Script.AddSyncedActionFallback(actionName, handler)
        end
        
        for _, registerFunc in ipairs(self.customRegistrations) do
            registerFunc()
        end
        
        return self
    end
    
    function builder:Unregister()
        for actionName, _ in pairs(self.syncedActions) do
            Script.RemoveSyncedActionFallback(actionName)
        end
        
        for _, cleanupFunc in ipairs(self.customCleanups) do
            cleanupFunc()
        end
        
        return self
    end
    
    return builder
end

return GadgetManager