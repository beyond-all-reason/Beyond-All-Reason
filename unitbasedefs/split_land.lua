local function splitLandTweaks(name, uDef)
    if name == "armfast" then
        uDef.speed = 330
        uDef.maxacc = 1.2
        uDef.maxdec = 0.02
        uDef.turnrate = 150
    end

    if name == "cortermite" then
        uDef.objectname = ""

    return uDef
end

return {
    splitLandTweaks = splitLandTweaks,
}