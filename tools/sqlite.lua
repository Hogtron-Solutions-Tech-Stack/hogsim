local lsqlite3 = require('lsqlite3')

local quote = (function()
  local moo = require('luasql.sqlite3').sqlite3():connect('')
  return function(s)
    return '\'' .. moo:escape(s) .. '\''
  end
end)()

local function factory(theProduct)
  local defs = (function()
    local build = require('wowapi.yaml').parseFile('data/products/' .. theProduct .. '/build.yaml')
    local bv = build.version .. '.' .. build.build
    local t = {}
    for _, db in ipairs(require('build.products.' .. theProduct .. '.dblist')) do
      local okdb, errdb = pcall(function()
      local content = assert(require('pl.file').read('vendor/dbdefs/definitions/' .. db .. '.dbd'))
      local dbd = assert(require('luadbd.parser').dbd(content))
      local v = (function()
        -- forever-sim: accept build ranges, and when the exact build is unknown to wowdbdefs
        -- (a client newer than the definitions) fall back to the nearest build of the same
        -- major.minor.patch. Layouts rarely change inside a patch line; the warning says when we guessed.
        local wmaj, wmin, wpat, wbld = bv:match('^(%d+)%.(%d+)%.(%d+)%.(%d+)$')
        wbld = tonumber(wbld)
        local function same(t)
          return tostring(t[1]) == wmaj and tostring(t[2]) == wmin and tostring(t[3]) == wpat
        end
        local best, bestDist
        for _, version in ipairs(dbd.versions) do
          for _, vb in ipairs(version.builds) do
            local lo, hi = vb[1], vb[#vb]
            if same(lo) and same(hi) then
              local lob, hib = tonumber(lo[4]), tonumber(hi[4])
              if wbld >= lob and wbld <= hib then
                return version
              end
              local dist = wbld > hib and (wbld - hib) or (lob - wbld)
              if not bestDist or dist < bestDist then
                best, bestDist = version, dist
              end
            end
          end
        end
        if best then
          io.stderr:write('WARN ' .. db .. ': no dbd layout lists build ' .. bv .. '; using nearest '
            .. wmaj .. '.' .. wmin .. '.' .. wpat .. ' layout (build distance ' .. bestDist .. ')' .. string.char(10))
          return best
        end
        error('cannot find ' .. bv .. ' in dbd ' .. db)
      end)()
      local sig, field2index = require('luadbd.sig')(dbd, v)
      t[db] = {
        field2index = field2index,
        orderedfields = (function()
          local list = {}
          for k in pairs(field2index) do
            table.insert(list, k)
          end
          table.sort(list, function(a, b)
            return field2index[a] < field2index[b]
          end)
          return list
        end)(),
        sig = sig,
      }
      end)
      if not okdb then
        io.stderr:write('WARN: skipping table ' .. db .. ': ' .. tostring(errdb) .. string.char(10))
      end
    end
    return t
  end)()

  local function create(filename)
    local dbinit = { 'BEGIN' }
    for k, v in pairs(defs) do
      table.insert(dbinit, ('CREATE TABLE %s (%s)'):format(k, table.concat(v.orderedfields, ',')))
    end
    table.insert(dbinit, 'COMMIT')
    table.insert(dbinit, '')
    local db = filename and lsqlite3.open(filename) or lsqlite3.open_memory()
    if db:exec(table.concat(dbinit, ';\n')) ~= lsqlite3.OK then
      error('sqlite failure: ' .. db:errmsg())
    end
    return db
  end

  local function populate(db)
    local dbinit = { 'BEGIN' }
    for k, v in pairs(defs) do
      local success, msg = pcall(function()
        local data = require('pl.file').read(('extracts/%s/db2/%s.db2'):format(theProduct, k))
        if not data then
          io.stderr:write('WARN: no db2 extracted for ' .. k .. '; table left empty' .. string.char(10))
          return
        end
        for row in require('dbc').rows(data, '{' .. v.sig:gsub('%.', '%?') .. '}') do
          local values = {}
          for _, field in ipairs(v.orderedfields) do
            local value = row[v.field2index[field]]
            local ty = type(value)
            if ty == 'table' then
              value = value[1]
              ty = type(value)
            end
            if ty == 'nil' then
              value = 'NULL'
            elseif ty == 'string' then
              value = quote(value)
            elseif ty == 'number' then
              value = tostring(value)
            else
              error('unexpected value of type ' .. ty .. ' on field ' .. field .. ' of table ' .. k)
            end
            table.insert(values, value)
          end
          table.insert(dbinit, ('INSERT INTO %s VALUES (%s)'):format(k, table.concat(values, ',')))
        end
      end)
      if not success then
        error('failed to populate ' .. k .. ': ' .. msg)
      end
    end
    table.insert(dbinit, 'COMMIT')
    table.insert(dbinit, '')
    assert(db:exec(table.concat(dbinit, ';\n')) == lsqlite3.OK)
  end

  return create, populate
end

local args = (function()
  local parser = require('argparse')()
  parser:argument('product', 'product to fetch')
  parser:flag('-f --full', 'also include data')
  return parser:parse()
end)()
local filebase = args.full and 'data' or 'schema'
local filename = ('build/products/%s/%s.db'):format(args.product, filebase)
require('pl.file').delete(filename)
local create, populate = factory(args.product)
local db = create(filename)
if args.full then
  populate(db)
end
db:close()
