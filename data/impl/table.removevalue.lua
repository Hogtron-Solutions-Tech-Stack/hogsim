local tbl, value = ...
for i, v in ipairs(tbl) do
  if v == value then
    table.remove(tbl, i)
    return i
  end
end
return nil
