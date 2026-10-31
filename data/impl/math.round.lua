local value, numDecimalPlaces = ...
if numDecimalPlaces then
  local mult = 10 ^ numDecimalPlaces
  return math.floor(value * mult + 0.5) / mult
end
return math.floor(value + 0.5)
