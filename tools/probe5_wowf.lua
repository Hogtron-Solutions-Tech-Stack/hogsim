-- Spike probe 5: [Family]/[Game] folder mapping for Forever, Bindings.xml home, 12.x toc reads. Read-only.
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
local function ex(p) return handle:readFile(p) ~= nil end
local dirs = { 'Camelot', 'Forever', 'Classic', 'Mainline', 'Standard', 'Vanilla', 'TBC', 'Wrath', 'Cata', 'Mists', 'Shared', 'Base', 'Game', 'Family' }
print('== [Game] prefix: Blizzard_ActionBar/<dir>/ActionButtonOverrides.lua')
for _, d in ipairs(dirs) do if ex('Interface/AddOns/Blizzard_ActionBar/' .. d .. '/ActionButtonOverrides.lua') then print('  EXISTS', d) end end
print('== [Family] prefix: Blizzard_ActionBar/<dir>/ActionButtonUtilOverrides.lua')
for _, d in ipairs(dirs) do if ex('Interface/AddOns/Blizzard_ActionBar/' .. d .. '/ActionButtonUtilOverrides.lua') then print('  EXISTS', d) end end
print('== [Family] MainMenuBarEndCaps.xml (excluded for camelot, so maybe absent)')
for _, d in ipairs(dirs) do if ex('Interface/AddOns/Blizzard_ActionBar/' .. d .. '/MainMenuBarEndCaps.xml') then print('  EXISTS', d) end end
print('== Bindings.xml candidates')
for _, p in ipairs({ 'Interface/AddOns/Blizzard_FrameXMLBase/Bindings.xml', 'Interface/AddOns/Blizzard_FrameXMLUtil/Bindings.xml', 'Interface/AddOns/Blizzard_SharedXMLBase/Bindings.xml', 'Interface/AddOns/Blizzard_UIParent/Bindings.xml', 'Interface/AddOns/Blizzard_KeyBindings/Bindings.xml', 'Interface/AddOns/Blizzard_Bindings/Bindings.xml', 'Interface/FrameXML/Bindings.xml', 'Interface/Bindings.xml', 'Interface/AddOns/Blizzard_FrameXML/Camelot/Bindings.xml', 'Interface/AddOns/Blizzard_FrameXML/Classic/Bindings.xml', 'Interface/AddOns/Blizzard_FrameXML/Mainline/Bindings.xml' }) do
  print('  ' .. (ex(p) and 'EXISTS ' or 'missing') .. '  ' .. p)
end
print('== 12.x-era tocs by name')
for _, a in ipairs({ 'Blizzard_DamageMeter', 'Blizzard_CooldownViewer', 'Blizzard_Secrets', 'Blizzard_HousingDashboard', 'Blizzard_EditMode', 'Blizzard_Settings_Shared', 'Blizzard_Menu', 'Blizzard_Colors', 'Blizzard_Flyout', 'Blizzard_TextStatusBar', 'Blizzard_Minimap', 'Blizzard_HelpPlate', 'Blizzard_QuickKeybind', 'Blizzard_StoreUI' }) do
  local c = handle:readFile('Interface/AddOns/' .. a .. '/' .. a .. '.toc')
  print('  ' .. (c and ('EXISTS ' .. #c) or 'missing') .. '  ' .. a)
end
local c = handle:readFile('Interface/AddOns/Blizzard_DamageMeter/Blizzard_DamageMeter.toc')
if c then print('-- Blizzard_DamageMeter.toc:'); print((c:gsub('\r', ''))) end
local f = handle:readFile('Interface/AddOns/Blizzard_FrameXML/Blizzard_FrameXML.toc')
if f then print('-- Blizzard_FrameXML.toc first 40 lines:'); local n = 0 for line in f:gmatch('[^\r\n]+') do n = n + 1 if n <= 40 then print(line) end end end
