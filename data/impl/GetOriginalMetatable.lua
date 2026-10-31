local api, obj = ...
local ud = api.UserData(obj)
local ty = ud and ud.type
return ty and api.uiobjectTypes[ty] and api.uiobjectTypes[ty].metatable or api.uiobjectTypes.frame.metatable
