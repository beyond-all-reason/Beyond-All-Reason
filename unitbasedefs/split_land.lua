local function splitLandTweaks(name, uDef)
    if name == "armfast" then
        uDef.speed = 330
        uDef.maxacc = 1.2
        uDef.maxdec = 0.02
        uDef.turnrate = 150
    end

    return uDef
end

return {
    splitLandTweaks = splitLandTweaks,
}