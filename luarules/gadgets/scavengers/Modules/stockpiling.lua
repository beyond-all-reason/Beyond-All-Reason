
function ScavStockpile(n, scav)
    Spring.GiveOrderToUnit(scav, CMD.STOCKPILE, {}, {})
end
