local fn = ...
local container = { fn = fn, cancelled = false }
function container:Invoke(...) if not self.cancelled and self.fn then return self.fn(...) end end
function container:Cancel() self.cancelled = true end
function container:IsCancelled() return self.cancelled end
return container
