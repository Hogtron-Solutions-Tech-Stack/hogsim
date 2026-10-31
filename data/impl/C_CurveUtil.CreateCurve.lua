-- minimal curve object: points are kept sorted; Evaluate returns the value of the last point at or before x
local curve = { points = {}, curveType = 0 }
function curve:SetType(t) self.curveType = t end
function curve:GetType() return self.curveType end
function curve:AddPoint(x, y)
  self.points[#self.points + 1] = { x = x, y = y }
  table.sort(self.points, function(a, b) return a.x < b.x end)
end
function curve:ClearPoints() self.points = {} end
function curve:GetPoints() return self.points end
function curve:Evaluate(x)
  local best
  for _, p in ipairs(self.points) do
    if p.x <= x then best = p end
  end
  best = best or self.points[1]
  return best and best.y
end
curve.EvaluateColor = curve.Evaluate
return curve
