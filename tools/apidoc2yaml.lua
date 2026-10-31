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
local currentFile
-- The doc tables reference Enum.X.Y and Constants.X.Y while being built; any lookup must succeed.
local function autoviv()
  return setmetatable({}, { __index = function(t, k)
    local v = setmetatable({}, { __index = function() return 0 end })
    rawset(t, k, v)
    return v
  end })
end
-- Constants tables say e.g. "Value = NUM_BAG_SLOTS": engine globals the docs do not define. Known values come
-- from the table below; anything else resolves to 0 and is recorded so the product's synthesized.txt lists it.
local knownEngine = {
  NUM_BAG_SLOTS = 4, NUM_REAGENTBAG_SLOTS = 1, NUM_BANKBAGSLOTS = 7, NUM_BAG_FRAMES = 4, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5,
  MAX_WATCHED_TOKENS = 20, NUM_CHARACTERBANK_SLOTS = 28, NUM_ACCOUNTBANK_SLOTS = 98, MAX_ACCOUNT_MACROS = 120,
  MAX_CHARACTER_MACROS = 30, NUM_ACTIONBAR_BUTTONS = 12, NUM_ACTIONBAR_PAGES = 6, MAX_SPELLS = 1024, MAX_SKILLLINE_TABS = 8,
}
local engineRefs = {}
local env = setmetatable({
  APIDocumentation = { AddDocumentationTable = function(_, t)
    t.__file = currentFile
    docs[#docs + 1] = t
  end },
  Enum = autoviv(),
  Constants = autoviv(),
}, { __index = function(_, k)
  local v = _G[k]
  if v ~= nil then return v end
  if type(k) == 'string' and k:match('^[A-Z][A-Z0-9_]+$') then
    engineRefs[k] = true
    return knownEngine[k] or 0
  end
end })
for _, f in ipairs(pldir.getfiles(docdir, '*.lua')) do
  currentFile = (plpath.basename(f):gsub('Documentation%.lua$', ''))
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
-- 4b. engine constants the docs referenced by name become plain globals too (Blizzard Lua uses them directly)
stats.engine = 0
local engineList = {}
for name in pairs(engineRefs) do
  if globals[name] == nil then
    globals[name] = knownEngine[name] or 0
    stats.engine = stats.engine + 1
  end
  engineList[#engineList + 1] = name .. ' = ' .. tostring(knownEngine[name] or 0) .. (knownEngine[name] and '' or ' (unknown, 0)')
end
table.sort(engineList)
plfile.write(('data/products/%s/engine-constants.txt'):format(product),
  'Engine constants referenced by the API docs (Value = NAME). Curated values where known, 0 otherwise.'
  .. string.char(10) .. table.concat(engineList, string.char(10)) .. string.char(10))
writeyaml(globalsfile, globals)

print(('apidoc2yaml %s: %d doc tables; structures +%d, apis %d (stubs +%d), events %d, enums %d, constants %d'):format(
  product, #docs, stats.structures, stats.apis, stats.stubs, stats.events, stats.enums, stats.constants))

-- 5. script-object methods -> data/uiobjects/<Type>/<Type>.yaml, declared "unimplemented" where missing so a
--    call returns nothing instead of "attempt to call method ... (a nil value)". The engine flattens the
--    inheritance graph and refuses a method declared twice along any path, so a method is only added to a
--    type when no ancestor, no descendant and no other ancestor of a descendant already declares it.
local typemap = {
  SimpleAnimAPI = 'Animation', SimpleAnimAlphaAPI = 'Alpha', SimpleAnimGroupAPI = 'AnimationGroup',
  SimpleAnimPathAPI = 'Path', SimpleAnimRotationAPI = 'Rotation', SimpleAnimScaleAPI = 'Scale',
  SimpleAnimScaleLineAPI = 'LineScale', SimpleAnimTextureCoordTranslationAPI = 'TextureCoordTranslation',
  SimpleAnimTranslationAPI = 'Translation', SimpleAnimTranslationLineAPI = 'LineTranslation',
  SimpleBrowserAPI = 'Browser', SimpleButtonAPI = 'Button', SimpleCheckboxAPI = 'CheckButton',
  SimpleColorSelectAPI = 'ColorSelect', SimpleControlPointAPI = 'ControlPoint', SimpleEditBoxAPI = 'EditBox',
  SimpleFontAPI = 'Font', SimpleFontStringAPI = 'FontString', SimpleFrameAPI = 'Frame',
  SimpleFrameScriptObjectAPI = 'ScriptObject', SimpleHTMLAPI = 'SimpleHTML', SimpleLineAPI = 'Line',
  SimpleMaskTextureAPI = 'MaskTexture', SimpleMessageFrameAPI = 'MessageFrame', SimpleModelAPI = 'Model',
  SimpleMovieAPI = 'MovieFrame', SimpleObjectAPI = 'UIObject', SimpleOffScreenFrameAPI = 'OffScreenFrame',
  SimpleRegionAPI = 'Region', SimpleScriptRegionAPI = 'Region', SimpleScriptRegionResizingAPI = 'Region',
  SimpleScrollFrameAPI = 'ScrollFrame', SimpleSliderAPI = 'Slider', SimpleStatusBarAPI = 'StatusBar',
  SimpleTextureAPI = 'Texture', SimpleTextureBaseAPI = 'Texture',
  FrameAPIModelSceneFrame = 'ModelScene', FrameAPIModelSceneFrameShared = 'ModelScene',
  FrameAPIModelSceneFrameActor = 'Actor', FrameAPIModelSceneFrameActorBase = 'Actor',
  FrameAPITooltip = 'GameTooltip', FrameAPICooldown = 'Cooldown', FrameAPIDressUpModel = 'DressUpModel',
  FrameAPITabardModel = 'TabardModel', FrameAPITabardModelBase = 'TabardModel',
  FrameAPICinematicModel = 'CinematicModel', FrameAPICharacterModelBase = 'PlayerModel',
  FrameAPIFogOfWarFrame = 'FogOfWarFrame', FrameAPIQuestPOI = 'QuestPOIFrame',
  FrameAPIScenarioPOI = 'ScenarioPOIFrame', FrameAPISimpleCheckout = 'Checkout',
  FrameAPIUnitPositionFrame = 'UnitPositionFrame',
}
local types, parents = {}, {}
for _, d in ipairs(pldir.getdirectories('data/uiobjects')) do
  local t = plpath.basename(d)
  local y = ('data/uiobjects/%s/%s.yaml'):format(t, t)
  if plpath.exists(y) then
    types[t] = yaml.parseFile(y)
    parents[t] = {}
    for p in pairs(types[t].inherits or {}) do parents[t][#parents[t] + 1] = p end
  end
end
local function closure(t, seen)
  for _, p in ipairs(parents[t] or {}) do
    if not seen[p] then
      seen[p] = true
      closure(p, seen)
    end
  end
  return seen
end
local anc = {}
for t in pairs(types) do anc[t] = closure(t, {}) end
local function declared(t, m) return types[t] and types[t].methods and types[t].methods[m] ~= nil end
local function conflicts(t, m)
  if declared(t, m) then return true end
  for a in pairs(anc[t]) do if declared(a, m) then return true end end
  for d, cl in pairs(anc) do
    if cl[t] then
      if declared(d, m) then return true end
      for x in pairs(cl) do if x ~= t and declared(x, m) then return true end end
    end
  end
  return false
end
stats.methods, stats.skipped = 0, 0
local touched = {}
for _, d in ipairs(docs) do
  local ty = d.__file and typemap[d.__file]
  if ty and types[ty] then
    types[ty].methods = types[ty].methods or {}
    for _, fn in ipairs(d.Functions or {}) do
      if conflicts(ty, fn.Name) then
        stats.skipped = stats.skipped + 1
      else
        types[ty].methods[fn.Name] = { status = 'unimplemented' }
        stats.methods = stats.methods + 1
        touched[ty] = true
      end
    end
  end
end
local ntypes = 0
for ty in pairs(touched) do
  ntypes = ntypes + 1
  writeyaml(('data/uiobjects/%s/%s.yaml'):format(ty, ty), types[ty])
end
print(('apidoc2yaml %s: uiobject methods +%d across %d types (%d already provided along the inheritance graph)'):format(
  product, stats.methods, ntypes, stats.skipped))
