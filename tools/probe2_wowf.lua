-- Spike probe 2: contents of key TOCs, manifest/db2 discovery, FrameXML location. Read-only.
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
local function rf(x) return handle:readFile(x) end
local function show(label, x, n)
  local c = rf(x)
  if c then print(label, x, #c .. ' bytes'); print((c:sub(1, n or 400):gsub('\r', ''))) else print(label, x, 'MISSING') end
end
show('TOC', 'Interface/AddOns/Blizzard_UIParent/Blizzard_UIParent.toc', 400)
show('TOC', 'Interface/AddOns/Blizzard_ActionBar/Blizzard_ActionBar.toc', 500)
for _, a in ipairs({ 'Blizzard_FrameXML', 'Blizzard_FrameXMLBase', 'Blizzard_FrameXMLUtil', 'Blizzard_SharedXML', 'Blizzard_SharedXMLBase', 'Blizzard_APIDocumentationGenerated', 'Blizzard_UIPanels_Game', 'Blizzard_PlayerSpells', 'Blizzard_TalentUI', 'Blizzard_ClassTalentUI', 'Blizzard_UnitFrame', 'Blizzard_NamePlates', 'Blizzard_DamageMeter', 'Blizzard_CompactRaidFrames', 'Blizzard_Settings_Shared', 'Blizzard_GameMenu' }) do
  local c = rf('Interface/AddOns/' .. a .. '/' .. a .. '.toc')
  print('ADDON', a, c and (#c .. ' bytes') or 'MISSING')
end
print('FrameXML/FrameXML.toc', rf('Interface/FrameXML/FrameXML.toc') and 'EXISTS' or 'MISSING')
print('FrameXML/Bindings.xml', rf('Interface/FrameXML/Bindings.xml') and 'EXISTS' or 'MISSING')
print('AddOns/Blizzard_FrameXML/Bindings.xml', rf('Interface/AddOns/Blizzard_FrameXML/Bindings.xml') and 'EXISTS' or 'MISSING')
for _, db in ipairs({ 'ManifestInterfaceTOCData', 'GlobalStrings', 'ManifestInterfaceData', 'UiTextureAtlas', 'UiTextureAtlasMember' }) do
  local c = rf('DBFilesClient/' .. db .. '.db2')
  print('DB2', db, c and (#c .. ' bytes magic=' .. c:sub(1, 4)) or 'MISSING by name')
end
for _, id in ipairs({ 1267335, 1375801, 1267336 }) do
  local c = rf(id)
  print('FDID', id, c and (#c .. ' bytes magic=' .. c:sub(1, 4)) or 'MISSING')
end
local c = rf('DBFilesClient/ManifestInterfaceTOCData.db2')
if c then
  local n, shown = 0, 0
  for _, filepath in require('dbc').rows(c, 's') do
    n = n + 1
    if shown < 10 then print('  manifest:', filepath) shown = shown + 1 end
  end
  print('manifest rows=' .. n)
end
