local env, quality = ...
-- Blizzard's default item quality colours (poor .. wowtoken), indexed by Enum.ItemQuality
local q = {
  [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
  [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 }, [6] = { 0.9, 0.8, 0.5 }, [7] = { 0, 0.8, 1 }, [8] = { 0, 0.8, 1 },
}
local c = q[tonumber(quality) or 1] or q[1]
if env.CreateColor then
  return env.CreateColor(c[1], c[2], c[3], 1)
end
return { r = c[1], g = c[2], b = c[3], a = 1 }
