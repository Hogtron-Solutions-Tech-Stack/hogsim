local tbl = ...
local out = {}
for _, v in pairs(tbl) do out[#out + 1] = v end
return out
