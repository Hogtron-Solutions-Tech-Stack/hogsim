-- Spike probe (2026-10-30): what does the WoW: Forever (wowf) build actually ship?
-- Opens the CASC build exactly like tools/fetch.lua, then reports which per-flavor
-- TOC names exist and what ManifestInterfaceTOCData lists. Read-only; writes nothing.
local product = arg[1] or 'wowf'
local build = require('wowapi.yaml').parseFile('data/products/' .. product .. '/build.yaml')
local path = require('path')
path.mkdir('cache')
local keys = {}
for line in require('pl.file').read('vendor/tactkeys/WoW.txt'):gmatch('[^\r\n]+') do
  local k, v = line:match('^([0-9A-F]+) ([0-9A-F]+)')
  if k then keys[k:lower()] = v:lower() end
end
local casc = require('casc')
local _, cdn, ckey = casc.cdnbuild('http://us.patch.battle.net:1119/' .. product, 'us')
print('cdn=', cdn, 'ckey=', ckey)
local handle, err = casc.open({
  bkey = build.hash, cache = 'cache', cacheFiles = true, cdn = cdn, ckey = ckey,
  keys = keys, locale = casc.locale.US, zerofillEncryptedChunks = true,
})
if not handle then print('OPEN FAILED: ' .. tostring(err)) os.exit(1) end
print('opened build ' .. build.hash)

local function try(fn)
  local c = handle:readFile(fn)
  return c ~= nil, c and #c or 0
end
local suffixes = { '', '_Mainline', '_Vanilla', '_Classic', '_TBC', '_BCC', '_Wrath', '_WOTLKC', '_Cata', '_Mists', '_Forever', '_Standard', '_Beta' }
local probes = { 'Interface/AddOns/Blizzard_UIParent/Blizzard_UIParent', 'Interface/AddOns/Blizzard_ActionBar/Blizzard_ActionBar',
  'Interface/AddOns/Blizzard_UnitFrame/Blizzard_UnitFrame', 'Interface/FrameXML/FrameXML' }
for _, base in ipairs(probes) do
  for _, s in ipairs(suffixes) do
    local ok, n = try(base .. s .. '.toc')
    if ok then print('TOC EXISTS', base .. s .. '.toc', n .. ' bytes') end
  end
end
for _, d in ipairs({ 'Interface', 'Interface_Vanilla', 'Interface_Mainline', 'Interface_Forever', 'Interface_Classic' }) do
  local ok, n = try(d .. '/FrameXML/Bindings.xml')
  if ok then print('BINDINGS EXISTS', d .. '/FrameXML/Bindings.xml', n .. ' bytes') end
end

local tocdata = handle:readFile(1267335)
if not tocdata then print('ManifestInterfaceTOCData (fdid 1267335) NOT readable') os.exit(2) end
print('ManifestInterfaceTOCData bytes=' .. #tocdata .. ' header=' .. tocdata:sub(1, 4))
local count, shown = 0, 0
for _, filepath in require('dbc').rows(tocdata, 's') do
  count = count + 1
  if shown < 12 then print('  manifest:', filepath) shown = shown + 1 end
end
print('manifest rows=' .. count)
local gs = handle:readFile('DBFilesClient/GlobalStrings.db2')
print('GlobalStrings.db2', gs and (#gs .. ' bytes header=' .. gs:sub(1, 4)) or 'NOT FOUND by name')
