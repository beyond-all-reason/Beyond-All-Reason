
if Spring.GetModOptions and (tonumber(Spring.GetModOptions().barmodels) or 0) ~= 0 then
    function gadget:GetInfo()
      return {
        name      = "barmodels notifier",
        desc      = "",
        author    = "Floris",
        date      = "April 2018",
        license   = "",
        layer     = 0,
        enabled   = true,
      }
    end

    if (gadgetHandler:IsSyncedCode()) then return end

    function gadget:Initialize()
        Spring.SendLuaRulesMsg('barmodels enabled')
    end
end