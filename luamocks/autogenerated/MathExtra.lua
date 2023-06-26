---MathExtra

---
---Parameters
---@param x number
---@param y number
---@return number sqrt(x*x+y*y)
function math.hypot(x, y) end

---Parameters
---@param x1 number
---@param x2 number (optional)
---@param x3 number (optional)
---@param xn number (optional)
---@return number diagonal
function math.diag(x1[, x2[, x3[, xn]]]) end

---@return number clamped
function math.clamp() end

---Parameters
---@param x number
---@return number sign
function math.sgn(x) end

---Parameters
---@param x number
---@param y number
---@param a number
---@return number (x+(y-x)*a)
function math.mix(x, y, a) end

---Parameters
---@param x number
---@param decimals number
---@return number rounded
function math.round(x, decimals) end

---Parameters
---@param x number
---@return number erf
function math.erf(x) end

---Parameters
---@param edge0 number
---@param edge1 number
---@param v number
---@return number smoothstep
function math.smoothstep(edge0, edge1, v) end

