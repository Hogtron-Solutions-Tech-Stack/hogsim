-- tools/fetch_db2.lua <product> <Table> [...]: fetch single client database files into extracts/<product>/db2
-- without re-running the whole fetch (which deletes the extract first). Uses the same CASC setup as tools/fetch.lua.
local product = assert(arg[1], 'usage: lua tools/fetch_db2.lua <product> <Table>...')
assert(arg[2], 'usage: lua tools/fetch_db2.lua <product> <Table>...')
local build = require('wowapi.yaml').parseFile('data/products/' .. product .. '/build.yaml')
local fdids = require('build.listfile')
local path = require('path')
local keys = {}
for line in require('pl.file').read('vendor/tactkeys/WoW.txt'):gmatch('[^\r\n]+') do
  local k, v = line:match('^([0-9A-F]+) ([0-9A-F]+)')
  if k then keys[k:lower()] = v:lower() end
end
local casc = require('casc')
local _, cdn, ckey = casc.cdnbuild('http://us.patch.battle.net:1119/' .. product, 'us')
local handle = assert(casc.open({ bkey = build.hash, cache = 'cache', cacheFiles = true, cdn = cdn, ckey = ckey,
  keys = keys, locale = casc.locale.US, zerofillEncryptedChunks = true }))
for i = 2, #arg do
  local db = arg[i]
  local fdid = fdids[db:lower()]
  local content = fdid and handle:readFile(fdid)
  if content then
    local out = path.join('extracts', product, 'db2', db .. '.db2')
    path.mkdir(path.dirname(out))
    require('pl.file').write(out, content)
    print(('fetched %s (fdid %d, %d bytes)'):format(db, fdid, #content))
  else
    print(('MISSING %s (fdid %s)'):format(db, tostring(fdid)))
  end
end
