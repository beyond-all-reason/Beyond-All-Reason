
function scavStockpile(n, scav)
    for i = 1,10 do
        Spring.GiveOrderToUnit(scav, CMD.STOCKPILE, {}, {})
    end
end

return {
    ScavStockpile = scavStockpile
}