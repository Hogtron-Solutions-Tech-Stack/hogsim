-- Spike probe 3: db2 by FDID + WDC5 parse test + TOC directive survey. Read-only.
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
local dbc = require('dbc')
for _, id in ipairs({ 1394440, 1375801, 1267336 }) do
  local c = handle:readFile(id)
  if not c then print('FDID', id, 'MISSING') else
    print('FDID', id, #c .. ' bytes magic=' .. c:sub(1, 4))
    local ok, err = pcall(function()
      local n, sample = 0, {}
      for _, a, b in dbc.rows(c, 's?') do
        n = n + 1
        if n <= 3 then sample[#sample + 1] = tostring(a):sub(1, 60) end
      end
      print('  rows=' .. n, 'sample:', table.concat(sample, ' | '))
    end)
    if not ok then print('  dbc.rows FAILED:', tostring(err):sub(1, 200)) end
    local ok2, hdr = pcall(dbc.header, c)
    if ok2 and type(hdr) == 'table' then
      local t = {}
      for k, v in pairs(hdr) do if type(v) ~= 'table' then t[#t + 1] = k .. '=' .. tostring(v) end end
      table.sort(t); print('  header:', table.concat(t, ' '):sub(1, 300))
    end
  end
end
local tokens, deps = {}, {}
for _, a in ipairs({ 'Blizzard_ActionBar', 'Blizzard_UnitFrame', 'Blizzard_FrameXML', 'Blizzard_UIPanels_Game', 'Blizzard_NamePlates', 'Blizzard_PlayerSpells', 'Blizzard_SharedXML', 'Blizzard_APIDocumentationGenerated' }) do
  local c = handle:readFile('Interface/AddOns/' .. a .. '/' .. a .. '.toc')
  if c then
    for line in c:gmatch('[^\r\n]+') do
      local key = line:match('^## ([%w_]+):')
      if key then deps[key] = (deps[key] or 0) + 1 end
      for tok in line:gmatch('%[([^%]]+)%]') do tokens[tok] = (tokens[tok] or 0) + 1 end
    end
  end
end
local function dump(label, t) local o = {} for k, v in pairs(t) do o[#o + 1] = k .. '=' .. v end table.sort(o) print(label, table.concat(o, ', ')) end
dump('TOC KEYS', deps); dump('BRACKET TOKENS', tokens)
local api = handle:readFile('Interface/AddOns/Blizzard_APIDocumentationGenerated/Blizzard_APIDocumentationGenerated.toc')
if api then local n = 0 for _ in api:gmatch('[^\r\n]+') do n = n + 1 end print('APIDoc toc lines=' .. n); print((api:sub(1, 600):gsub('\r', ''))) end
