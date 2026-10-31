-- tools/apidoc2yaml.lua: Blizzard_APIDocumentationGenerated -> wowless data for a product.
-- Usage: lua tools/apidoc2yaml.lua <product>
-- Reads extracts/<product>/Interface/AddOns/Blizzard_APIDocumentationGenerated/*.lua (shipped inside the
-- client build) and writes, merged over what is already there:
--   data/products/<product>/apis.yaml      every documented C_Namespace.Function and global function
--   data/products/<product>/events.yaml    every documented event with its typed payload
--   data/products/<product>/globals.yaml   Enum.* (+ *Meta) and Constants.* tables
--   data/api/<name>.yaml                   an "unimplemented" stub (typed inputs/outputs) where none exists
--   data/structures/<Name>.yaml            documented structures that wowless does not know yet
local product = assert(arg[1], 'usage: lua tools/apidoc2yaml.lua <product>')
local yaml = require('wowapi.yaml')
local pldir, plfile, plpath = require('pl.dir'), require('pl.file'), require('pl.path')
local docdir = ('extracts/%s/Interface/AddOns/Blizzard_APIDocumentationGenerated'):format(product)
assert(plpath.isdir(docdir), 'no API documentation extracted at ' .. docdir)

local docs = {}
local env = setmetatable({
  APIDocumentation = { AddDocumentationTable = function(_, t) docs[#docs + 1] = t end },
}, { __index = _G })
for _, f in ipairs(pldir.getfiles(docdir, '*.lua')) do
  local fn = assert(loadfile(f))
  setfenv(fn, env)
  fn()
end

local enums, structs, consts = {}, {}, {}
for _, d in ipairs(docs) do
  for _, t in ipairs(d.Tables or {}) do
    if t.Type == 'Enumeration' then enums[t.Name] = t
    elseif t.Type == 'Structure' then structs[t.Name] = t
    elseif t.Type == 'Constants' then consts[t.Name] = t end
  end
end
local knownStructs = {}
for _, f in ipairs(pldir.getfiles('data/structures', '*.yaml')) do
  knownStructs[(plpath.basename(f):gsub('%.yaml$', ''))] = true
end

local prim = {
  bool = 'boolean', boolean = 'boolean', number = 'number', luaIndex = 'number', fileID = 'number',
  time_t = 'number', size = 'number', uiUnit = 'number', BigInteger = 'number', BigUInteger = 'number',
  WOWMONEY = 'number', cstring = 'string', string = 'string', stringView = 'string', WOWGUID = 'string',
  textureKit = 'string', textureAtlas = 'string', uiAddon = 'string', luaFunction = 'function', table = 'table',
}
-- ctx: input | output | field (structure fields and event payloads)
local function maptype(ty, ctx)
  if prim[ty] then
    if prim[ty] == 'function' and ctx == 'field' then return 'unknown' end
    return prim[ty]
  end
  if enums[ty] then return 'number' end
  if structs[ty] or knownStructs[ty] then return ty end
  if ty == 'UnitToken' or ty == 'UnitTokenType' then return ctx == 'input' and 'unit' or 'string' end
  if ty:match('I[Dd]$') then return 'number' end
  return 'unknown'
end
local function rec(x, ctx)
  local r = { type = maptype(x.Type, ctx) }
  if x.Name and ctx ~= 'input' then r.name = x.Name end
  if x.Nilable then r.nilable = true end
  if x.Type == 'table' and x.InnerType then r.innerType = maptype(x.InnerType, 'field') end
  if ctx == 'input' and x.Default ~= nil and type(x.Default) ~= 'table' then r.default = x.Default end
  return r
end
local function readyaml(path, default)
  return plpath.exists(path) and yaml.parseFile(path) or default
end
local function writeyaml(path, t)
  plfile.write(path, yaml.pprint(t))
end

local stats = { structures = 0, apis = 0, stubs = 0, events = 0, enums = 0, constants = 0 }

-- 1. structures first: stubs reference them by name and prep.lua needs their defaults
for name, st in pairs(structs) do
  if not knownStructs[name] then
    local fields = {}
    for _, f in ipairs(st.Fields or {}) do fields[#fields + 1] = rec(f, 'field') end
    writeyaml('data/structures/' .. name .. '.yaml', { name = name, fields = fields })
    knownStructs[name] = true
    stats.structures = stats.structures + 1
  end
end

-- 2. functions -> apis.yaml + data/api stubs
local apisfile = ('data/products/%s/apis.yaml'):format(product)
local apis = readyaml(apisfile, {})
for _, d in ipairs(docs) do
  for _, fn in ipairs(d.Functions or {}) do
    local name = (d.Namespace and (d.Namespace .. '.') or '') .. fn.Name
    apis[name] = name
    stats.apis = stats.apis + 1
    local path = 'data/api/' .. name .. '.yaml'
    if not plpath.exists(path) then
      local api = { name = name, status = 'unimplemented' }
      if fn.Arguments and #fn.Arguments > 0 then
        local sig = {}
        for _, a in ipairs(fn.Arguments) do sig[#sig + 1] = rec(a, 'input') end
        api.inputs = { sig }
      end
      if fn.Returns and #fn.Returns > 0 then
        local outs = {}
        for _, r in ipairs(fn.Returns) do outs[#outs + 1] = rec(r, 'output') end
        api.outputs = outs
      end
      writeyaml(path, api)
      stats.stubs = stats.stubs + 1
    end
  end
end
writeyaml(apisfile, apis)

-- 3. events -> events.yaml (documented payloads win over the seed)
local eventsfile = ('data/products/%s/events.yaml'):format(product)
local events = readyaml(eventsfile, {})
for _, d in ipairs(docs) do
  for _, ev in ipairs(d.Events or {}) do
    local e = {}
    if ev.Payload and #ev.Payload > 0 then
      e.payload = {}
      for _, p in ipairs(ev.Payload) do e.payload[#e.payload + 1] = rec(p, 'field') end
    end
    events[ev.LiteralName] = e
    stats.events = stats.events + 1
  end
end
writeyaml(eventsfile, events)

-- 4. enums + constants -> globals.yaml
local globalsfile = ('data/products/%s/globals.yaml'):format(product)
local globals = readyaml(globalsfile, {})
globals.Enum = globals.Enum or {}
globals.Constants = globals.Constants or {}
for name, t in pairs(enums) do
  local e = {}
  for _, f in ipairs(t.Fields or {}) do e[f.Name] = f.EnumValue end
  globals.Enum[name] = e
  globals.Enum[name .. 'Meta'] = { MinValue = t.MinValue, MaxValue = t.MaxValue, NumValues = t.NumValues }
  stats.enums = stats.enums + 1
end
for name, t in pairs(consts) do
  local c = {}
  for _, v in ipairs(t.Values or {}) do
    if type(v.Value) ~= 'table' then c[v.Name] = v.Value end
  end
  globals.Constants[name] = c
  stats.constants = stats.constants + 1
end
writeyaml(globalsfile, globals)

print(('apidoc2yaml %s: %d doc tables; structures +%d, apis %d (stubs +%d), events %d, enums %d, constants %d'):format(
  product, #docs, stats.structures, stats.apis, stats.stubs, stats.events, stats.enums, stats.constants))
