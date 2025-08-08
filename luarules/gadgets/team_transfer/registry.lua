local Registry = {}

-- Simple helper for bulk hook registration/cleanup
function Registry.RegisterHooks(hookList, handlers)
    for _, hookName in ipairs(hookList) do
        local handler = handlers[hookName]
        if not handler then
            error("Missing handler for hook '" .. hookName .. "' - all hooks in hookList must have matching handlers")
        end
        if type(handler) ~= "function" then
            error("Handler for hook '" .. hookName .. "' must be a function, got " .. type(handler))
        end
        Script.AddSyncedActionFallback(hookName, handler)
    end
end

function Registry.UnregisterHooks(hookList)
    for _, hookName in ipairs(hookList) do
        Script.RemoveSyncedActionFallback(hookName)
    end
end

return Registry
