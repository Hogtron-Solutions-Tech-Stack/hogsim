local tbl = ...
local out = {}
for k in pairs(tbl) do out[#out + 1] = k end
return out
