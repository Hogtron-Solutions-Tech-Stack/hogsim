local args = (function()
  local parser = require('argparse')()
  parser:argument('product', 'product to fetch')
  parser:flag('-v --verbose', 'verbose')
  return parser:parse()
end)()
local product = args.product

local log = args.verbose and print or function() end

local build = require('wowapi.yaml').parseFile('data/products/' .. product .. '/build.yaml')

local fdids = require('build.listfile')

-- forever-sim: per-product TOC conventions. WoW: Forever (wowf) ships one plain TOC per Blizzard addon;
-- its lines carry [Family]/[Game] path prefixes and trailing [AllowLoadGameType ...]-style conditions.
local tocFamily = build.family or 'Mainline'
local tocGame = build.game or 'Mainline'
local function tocFilePath(line)
  local cleaned = line
  while true do
    local before = cleaned:match('^(.-)%s*%[[^%]]*%]%s*$')
    if not before or before == '' then
      break
    end
    cleaned = before
  end
  cleaned = cleaned:gsub('^%[Family%]', tocFamily):gsub('^%[Game%]', tocGame)
  return cleaned
end
-- Files whose names lost their lookup hash in modern builds; read by FDID instead.
local knownFdids = {
  ['Interface/FrameXML/Bindings.xml'] = 804550,
}

local path = require('path')
path.mkdir('cache')

local encryptionKeys = (function()
  local wowtxt = require('pl.file').read('vendor/tactkeys/WoW.txt')
  local ret = {}
  for line in wowtxt:gmatch('[^\r\n]+') do
    local k, v = line:match('^([0-9A-F]+) ([0-9A-F]+)')
    ret[k:lower()] = v:lower()
  end
  return ret
end)()

local handle = (function()
  local casc = require('casc')
  local _, cdn, ckey = casc.cdnbuild('http://us.patch.battle.net:1119/' .. product, 'us')
  local handle, err = casc.open({
    bkey = build.hash,
    cache = 'cache',
    cacheFiles = true,
    cdn = cdn,
    ckey = ckey,
    keys = encryptionKeys,
    locale = casc.locale.US,
    log = log,
    zerofillEncryptedChunks = true,
  })
  if not handle then
    print('unable to open ' .. build.hash .. ': ' .. err)
    os.exit(1)
  end
  return handle
end)()

local function normalizePath(p)
  -- path.normalize does not normalize x/../y to y.
  -- Unfortunately, we need exactly that behavior for Interface_Vanilla etc.
  -- links in per-product TOCs. We hack around it here by adding an extra dir.
  return path.normalize('a/' .. p):sub(3)
end

local function joinRelative(relativeTo, suffix)
  return normalizePath(path.join(path.dirname(relativeTo), suffix))
end

local outdir = path.join('extracts', product)
if path.isdir(outdir) then
  require('pl.dir').rmtree(outdir)
end

local function save(fn, content)
  log('writing', fn)
  path.mkdir(path.dirname(path.join(outdir, fn)))
  require('pl.file').write(path.join(outdir, fn), content)
end

local processFile = (function()
  local lxp = require('lxp')
  local function doProcessFile(fn)
    local content = handle:readFile(fn)
    if content then
      save(fn, content)
      if fn:sub(-4) == '.xml' then
        local parser = lxp.new({
          StartElement = function(_, name, attrs)
            local lname = string.lower(name)
            if (lname == 'include' or lname == 'script') and attrs.file then
              doProcessFile(joinRelative(fn, attrs.file))
            end
          end,
        })
        parser:parse(content)
        parser:close()
      end
    end
  end
  return doProcessFile
end)()

local function processTocDir(dir)
  local addonName = path.basename(dir)
  local tocName = path.join(dir, addonName .. '_' .. build.flavor .. '.toc')
  local tocContent = handle:readFile(tocName)
  if not tocContent then
    tocName = path.join(dir, addonName .. '.toc')
    tocContent = handle:readFile(tocName)
  end
  if tocContent then
    save(tocName, tocContent)
    for line in tocContent:gmatch('[^\r\n]+') do
      if line:sub(1, 1) ~= '#' then
        local fp = tocFilePath((line:gsub('%s*$', '')))
        if fp ~= '' then
          processFile(joinRelative(tocName, fp))
        end
      end
    end
  end
  local bindingsName = path.join(dir, 'Bindings.xml')
  local bindingsContent = handle:readFile(bindingsName)
  if not bindingsContent then
    bindingsName = bindingsName:gsub('^Interface/', 'Interface_' .. build.flavor .. '/')
    bindingsContent = handle:readFile(bindingsName)
  end
  if not bindingsContent and knownFdids[path.join(dir, 'Bindings.xml')] then
    bindingsName = path.join(dir, 'Bindings.xml')
    bindingsContent = handle:readFile(knownFdids[bindingsName])
  end
  if bindingsContent then
    save(bindingsName, bindingsContent)
  end
  return tocContent ~= nil
end

for _, db in ipairs(require('build.products.' .. product .. '.dblist')) do
  local fdid = fdids[db:lower()]
  local content = fdid and handle:readFile(fdid)
  if content then
    save(path.join('db2', db .. '.db2'), content)
  else
    print('WARN: db2 ' .. db .. ' is not in this build (fdid ' .. tostring(fdid) .. '); table will be empty')
  end
end

processTocDir('Interface/FrameXML')
do
  local manifest = {}
  -- Yes, ManifestInterfaceTOCData fdid and sig are hardcoded.
  local tocdata = handle:readFile(1267335)
  if tocdata then
    for id, filepath in require('dbc').rows(tocdata, 's') do
      local dir = normalizePath(filepath)
      if processTocDir(dir) then
        manifest[#manifest + 1] = { path = dir, fdid = tonumber(id) or 0 }
      end
    end
  else
    -- forever-sim: builds without ManifestInterfaceTOCData (WoW: Forever). Enumerate Blizzard addons from
    -- the community listfile: every Interface/AddOns/Blizzard_X/Blizzard_X.toc (plain toc only), proper case.
    print('no ManifestInterfaceTOCData in this build; enumerating Blizzard addons from the listfile')
    local seen = {}
    for line in io.lines('vendor/listfile/community-listfile-withcapitals.csv') do
      local id, p = line:match('^(%d+);([^;\r]+)')
      if p and p:lower():match('^interface/addons/[%w_]+/[%w_]+%.toc$') then
        local dir, name = p:match('^(.-)/([^/]+)%.toc$')
        if dir and path.basename(dir):lower() == name:lower() and not seen[dir:lower()] then
          seen[dir:lower()] = true
          dir = dir:gsub('^[Ii][Nn][Tt][Ee][Rr][Ff][Aa][Cc][Ee]/[Aa][Dd][Dd][Oo][Nn][Ss]/', 'Interface/AddOns/')
          if processTocDir(dir) then
            manifest[#manifest + 1] = { path = dir, fdid = tonumber(id) }
          end
        end
      end
    end
  end
  table.sort(manifest, function(a, b)
    return a.fdid < b.fdid
  end)
  local out = { 'return {' }
  for _, m in ipairs(manifest) do
    out[#out + 1] = ('  { path = %q, fdid = %d },'):format(m.path, m.fdid)
  end
  out[#out + 1] = '}'
  require('pl.file').write(path.join(outdir, 'manifest.lua'), table.concat(out, string.char(10)) .. string.char(10))
  print(('manifest: %d Blizzard addons'):format(#manifest))
  processTocDir('Interface/AddOns/Blizzard_APIDocumentationGenerated')
end
