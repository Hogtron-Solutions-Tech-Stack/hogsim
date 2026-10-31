-- tools/synth_globals.lua <product>: things the client builds from data, absent from the API docs, synthesized from
-- what the shipped Blizzard Lua references: Enum.X.Y members (sorted numbering), LE_* globals (sequential ints),
-- Constants.X.Y groups (members = 0). Values are stable but NOT the client's; synthesized.txt lists every one.
local product = assert(arg[1], 'usage: lua tools/synth_globals.lua <product>')
local yaml = require('wowapi.yaml')
local plfile, pldir, plpath = require('pl.file'), require('pl.dir'), require('pl.path')
local gfile = ('data/products/%s/globals.yaml'):format(product)
local g = yaml.parseFile(gfile)
g.Enum = g.Enum or {}
g.Constants = g.Constants or {}
local enumUse, constUse, leUse = {}, {}, {}
for root, _, files in pldir.walk(('extracts/%s/Interface/AddOns'):format(product)) do
  for _, f in ipairs(files) do
    if f:sub(-4) == '.lua' then
      local src = plfile.read(plpath.join(root, f)) or ''
      for x, y in src:gmatch('Enum%.([A-Za-z0-9_]+)%.([A-Za-z0-9_]+)') do
        enumUse[x] = enumUse[x] or {}
        enumUse[x][y] = true
      end
      for x, y in src:gmatch('Constants%.([A-Za-z0-9_]+)%.([A-Za-z0-9_]+)') do
        constUse[x] = constUse[x] or {}
        constUse[x][y] = true
      end
      for le in src:gmatch('[^%w_](LE_[A-Z0-9_]+)') do
        leUse[le] = true
      end
    end
  end
end
local report, counts = {}, { enums = 0, enumMembers = 0, constGroups = 0, constMembers = 0, le = 0 }
local function sortedKeys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end
for _, x in ipairs(sortedKeys(enumUse)) do
  if g.Enum[x] == nil then
    local names = sortedKeys(enumUse[x])
    local e = {}
    for i, y in ipairs(names) do e[y] = i - 1 end
    g.Enum[x] = e
    g.Enum[x .. 'Meta'] = { MinValue = 0, MaxValue = #names - 1, NumValues = #names }
    counts.enums, counts.enumMembers = counts.enums + 1, counts.enumMembers + #names
    report[#report + 1] = 'Enum.' .. x .. ' (' .. #names .. ' members, sorted numbering)'
  end
end
for _, x in ipairs(sortedKeys(constUse)) do
  if g.Constants[x] == nil then
    local names = sortedKeys(constUse[x])
    local c = {}
    for _, y in ipairs(names) do c[y] = 0 end
    g.Constants[x] = c
    counts.constGroups, counts.constMembers = counts.constGroups + 1, counts.constMembers + #names
    report[#report + 1] = 'Constants.' .. x .. ' (' .. #names .. ' members = 0)'
  end
end
local nextLe = 100000
for _, le in ipairs(sortedKeys(leUse)) do
  if g[le] == nil then
    g[le] = nextLe
    nextLe = nextLe + 1
    counts.le = counts.le + 1
    report[#report + 1] = le .. ' = ' .. g[le]
  end
end
plfile.write(gfile, yaml.pprint(g))
plfile.write(('data/products/%s/synthesized.txt'):format(product),
  'Synthesized by tools/synth_globals.lua: not in the client API docs; values are placeholders, not client values.'
  .. string.char(10) .. table.concat(report, string.char(10)) .. string.char(10))
print(('synth_globals %s: enums %d (%d members), constant groups %d (%d members), LE_* %d'):format(
  product, counts.enums, counts.enumMembers, counts.constGroups, counts.constMembers, counts.le))
