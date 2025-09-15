-- for wxLua-based Turtle Graphics

-- Draw two triangles, one clockwise and one counter-clockwise
require("turtle")

local function triangle(side, angle)
  move(side)
  turn(angle)
  move(side)
  turn(angle)
  move(side)
  turn(angle)
end

triangle(100, 120)
triangle(100, -120)

wait()
