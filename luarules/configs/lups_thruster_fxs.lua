local tbl = {
  -- ZK config:
  --gunshipheavytrans = {
  --  {class='AirJet', options={color={0.2,0.4,0.8}, width=8, length=35, baseLength = 9, piece="engineEmit", onActive=true, noIconDraw = true}},
  --},
  --gunshipskirm = {
  --  {class='AirJet', options={color={0.6,0.1,0.0}, width=3.5, length=22, baseLength = 6, piece="thrust1", onActive=true, noIconDraw = true}},
  --  {class='AirJet', options={color={0.6,0.1,0.0}, width=3.5, length=22, baseLength = 6, piece="thrust2", onActive=true, noIconDraw = true}},
  --},
  --planefighter = {
  --  --{class='AirJet', options={color={0.6,0.1,0.0}, width=3.5, length=55, piece="nozzle1", texture2=":c:bitmaps/gpl/lups/jet2.bmp", onActive=true}},
  --  --{class='AirJet', options={color={0.6,0.1,0.0}, width=3.5, length=55, piece="nozzle2", texture2=":c:bitmaps/gpl/lups/jet2.bmp", onActive=true}},
  --},
  --planeheavyfighter = {
  --  {class='AirJet', options={color={0.6,0.1,0.0}, width=3.5, length=55, piece="thrust1", onActive=true, noIconDraw = true}},
  --  {class='AirJet', options={color={0.6,0.1,0.0}, width=3.5, length=55, piece="thrust2", onActive=true, noIconDraw = true}},
  --  {class='AirJet', options={color={0.6,0.1,0.0}, width=3.5, length=55, piece="thrust3", onActive=true, noIconDraw = true}},
  --},
}
local tbl2 = {}

for unitName, data in pairs(tbl) do
  local unitDef = UnitDefNames[unitName] or {}
  data.baseSpeed = data.baseSpeed or (unitDef and unitDef.speed/30)
  data.maxDeltaSpeed = data.maxDeltaSpeed or 3
  data.accelMod = data.accelMod or 1
  data.minSpeed = data.minSpeed or 1
  for index, fx in ipairs(data) do
    local opts = fx.options
    if opts.length then
      opts.baseLength = opts.baseLength or 0
      opts.linearLength = opts.length - opts.baseLength
    end
    if opts.size then
      opts.baseSize = opts.size
    end
  end
  
  local unitDefID = unitDef.id
  if unitDefID then
    tbl2[unitDefID] = data
  end
end

return tbl2
