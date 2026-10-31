local object = ...
for i = 2, select('#', ...) do
  local mixin = select(i, ...)
  if mixin then
    for k, v in pairs(mixin) do
      object[k] = v
    end
  end
end
return object
