-- Enum.GameRule is built by the client from data, not documented; synthesize it from the names Blizzard code uses.
local yaml = require('wowapi.yaml')
local g = yaml.parseFile('data/products/wowf/globals.yaml')
local names = {}
for line in io.lines(arg[1]) do
  if line ~= '' then names[#names + 1] = line end
end
table.sort(names)
local e = {}
for i, n in ipairs(names) do e[n] = i - 1 end
g.Enum = g.Enum or {}
g.Enum.GameRule = e
g.Enum.GameRuleMeta = { MinValue = 0, MaxValue = #names - 1, NumValues = #names }
require('pl.file').write('data/products/wowf/globals.yaml', yaml.pprint(g))
print('Enum.GameRule synthesized with ' .. #names .. ' rules')
