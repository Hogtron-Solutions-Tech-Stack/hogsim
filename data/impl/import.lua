local api, name = ...
local key = name
if type(name) == 'string' and name:sub(1, 1) == '.' then
  key = (api.currentAddon or '') .. name
end
local mod = api.modules and api.modules[key]
if mod == nil then
  api.log(1, 'import(%s): no module %s, returning the global environment', tostring(name), tostring(key))
  return api.env
end
return mod
