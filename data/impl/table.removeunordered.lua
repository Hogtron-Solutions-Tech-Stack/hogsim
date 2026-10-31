local tbl, index = ...
local n = #tbl
tbl[index] = tbl[n]
tbl[n] = nil
