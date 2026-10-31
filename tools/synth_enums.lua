-- tools/synth_enums.lua <product>: enums the client builds from data (not in Blizzard_APIDocumentationGenerated)
-- are synthesized from every Enum.X.Y the shipped Blizzard Lua references: members numbered in sorted order,
-- values are stable but NOT the client's. The list of synthesized names is written next to globals.yaml.
local product = assert(arg[1], 'usage: lua tools/synth_enums.lua <product>')
local yaml = require('wowapi.yaml')
local plfile, pldir, plpath = require('pl.file'), require('pl.dir'), require('pl.path')
local gfile = ('data/products/%s/globals.yaml'):format(product)
local g = yaml.parseFile(gfile)
g.Enum = g.Enum or {}
local used = {}
for root, _, files in pldir.walk(('extracts/%s/Interface/AddOns'):format(product)) do
  for _, f in ipairs(files) do
    if f:sub(-4) == '.lua' then
      local src = plfile.read(plpath.join(root, f)) or ''
      for x, y in src:gmatch('Enum%.([A-Za-z0-9_]+)%.([A-Za-z0-9_]+)') do
        used[x] = used[x] or {}
        used[x][y] = true
      end
    end
  end
end
local synthesized, total = {}, 0
for x, members in pairs(used) do
  if g.Enum[x] == nil then
    local names = {}
    for y in pairs(members) do names[#names + 1] = y end
    table.sort(names)
    local e = {}
    for i, y in ipairs(names) do e[y] = i - 1 end
    g.Enum[x] = e
    g.Enum[x .. 'Meta'] = { MinValue = 0, MaxValue = #names - 1, NumValues = #names }
    synthesized[#synthesized + 1] = x .. ' (' .. #names .. ')'
    total = total + #names
  end
end
table.sort(synthesized)
plfile.write(gfile, yaml.pprint(g))
plfile.write(('data/products/%s/synthesized-enums.txt'):format(product),
  'Enums below are not in the client API docs; member values are synthesized (sorted order), not the client values.'
  .. string.char(10) .. table.concat(synthesized, string.char(10)) .. string.char(10))
print(('synth_enums %s: %d enums, %d members synthesized'):format(product, #synthesized, total))
