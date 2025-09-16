-- for wxLua-based Turtle Graphics
require("turtle")
fd=move
rt=turn
for i=1,5 do fd(100); rt(180); fd(50); rt(180); rt(-360/5); end
--[[
for i=1,3 do
  fd(100)
  rt(180)
  fd(50)
  rt(180)
  rt(-120)
end
--]]

