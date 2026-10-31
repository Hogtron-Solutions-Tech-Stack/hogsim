-- Spike probe 4: manifest replacement (listfile tocs + ManifestInterfaceData), Bindings.xml, TOC condition syntax. Read-only.
local product = arg[1] or 'wowf'
local build = require('wowapi.yaml').parseFile('data/products/' .. product .. '/build.yaml')
local keys = {}
for line in require('pl.file').read('vendor/tactkeys/WoW.txt'):gmatch('[^\r\n]+') do
  local k, v = line:match('^([0-9A-F]+) ([0-9A-F]+)')
  if k then keys[k:lower()] = v:lower() end
end
local casc = require('casc')
local _, cdn, ckey = casc.cdnbuild('http://us.patch.battle.net:1119/' .. product, 'us')
local handle = assert(casc.open({ bkey = build.hash, cache = 'cache', cacheFiles = true, cdn = cdn, ckey = ckey,
  keys = keys, locale = casc.locale.US, zerofillEncryptedChunks = true }))
-- 1. listfile: blizzard tocs + bindings
local tocs, binds = {}, {}
for line in io.lines('vendor/listfile/community-listfile.csv') do
  local id, p = line:match('^(%d+);(.*)$')
  if p then
    local dir, name = p:match('^interface/addons/(blizzard_[%w_]+)/(blizzard_[%w_]+)%.toc$')
    if dir and dir == name then tocs[#tocs + 1] = { id = tonumber(id), path = p } end
    if p:match('^interface/addons/blizzard_[%w_]+/bindings%.xml$') then binds[#binds + 1] = { id = tonumber(id), path = p } end
  end
end
table.sort(tocs, function(a, b) return a.path < b.path end)
print('listfile blizzard tocs=' .. #tocs, 'bindings.xml under blizzard addons=' .. #binds)
local okName, okId, missing, sample = 0, 0, {}, {}
for _, t in ipairs(tocs) do
  local byName = handle:readFile(t.path)
  local byId = handle:readFile(t.id)
  if byName then okName = okName + 1 end
  if byId then okId = okId + 1 end
  if not byName and not byId then missing[#missing + 1] = t.path:match('/(blizzard_[%w_]+)/') end
  if byName and #sample < 3 then sample[#sample + 1] = t.path end
end
print('readable by NAME=' .. okName, 'by FDID=' .. okId, 'neither=' .. #missing)
print('  missing sample:', table.concat(missing, ' '):sub(1, 400))
for _, b in ipairs(binds) do
  print('BINDINGS', b.path, handle:readFile(b.path) and 'readable' or (handle:readFile(b.id) and 'by-id-only' or 'MISSING'))
end
-- 2. ManifestInterfaceData: does it list AddOns tocs?
local mid = handle:readFile(1375801)
local n, tocRows, s2 = 0, 0, {}
for _, fp in require('dbc').rows(mid, 's?') do
  n = n + 1
  if fp:lower():find('addons', 1, true) then
    tocRows = tocRows + 1
    if #s2 < 4 then s2[#s2 + 1] = fp end
  end
end
print('ManifestInterfaceData rows=' .. n, 'rows mentioning AddOns=' .. tocRows, table.concat(s2, ' | '))
-- 3. TOC condition syntax samples
local shown = {}
for _, a in ipairs({ 'Blizzard_ActionBar', 'Blizzard_FrameXML', 'Blizzard_SharedXML', 'Blizzard_UnitFrame' }) do
  local c = handle:readFile('Interface/AddOns/' .. a .. '/' .. a .. '.toc')
  for line in (c or ''):gmatch('[^\r\n]+') do
    for _, tok in ipairs({ 'Family', 'Game ', 'AllowLoadEnvironment', 'LoadIntoEnvironment', 'ExcludeLoadGameType camelot', 'AllowLoadGameType camelot', 'LoadFirst', 'OptionalDep', 'AllowLoad:' }) do
      if line:find(tok, 1, true) and not shown[tok] then shown[tok] = true print('SYNTAX[' .. tok .. ']', a, line) end
    end
  end
end
