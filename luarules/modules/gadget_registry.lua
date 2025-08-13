local GadgetRegistry = {}

-- Helper for bulk SyncedActionFallback registration/cleanup
function GadgetRegistry.RegisterSyncedActionFallbacks(fallbackList, handlers)
    for _, fallbackName in ipairs(fallbackList) do
        local handler = handlers[fallbackName]
        if not handler then
            error("Missing handler for SyncedActionFallback '" .. fallbackName .. "' - all fallbacks in list must have matching handlers")
        end
        if type(handler) ~= "function" then
            error("Handler for SyncedActionFallback '" .. fallbackName .. "' must be a function, got " .. type(handler))
        end
        Script.AddSyncedActionFallback(fallbackName, handler)
    end
end

function GadgetRegistry.UnregisterSyncedActionFallbacks(fallbackList)
    for _, fallbackName in ipairs(fallbackList) do
        Script.RemoveSyncedActionFallback(fallbackName)
    end
end

return GadgetRegistry
