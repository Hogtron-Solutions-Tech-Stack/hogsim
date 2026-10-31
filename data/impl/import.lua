local api, name = ...
local mods = api.modules or {}
local candidates = {}
if type(name) == 'string' and name:sub(1, 1) == '.' then
  candidates[#candidates + 1] = (api.currentModuleDir or api.currentAddon or '') .. name
  candidates[#candidates + 1] = (api.currentAddon or '') .. name
else
  candidates[#candidates + 1] = name
end
for _, key in ipairs(candidates) do
  if mods[key] ~= nil then
    return mods[key]
  end
end
api.log(1, 'import(%s): no module among %s, returning the global environment', tostring(name), table.concat(candidates, ' '))
return api.env
