---@diagnostic disable: undefined-global
require "turtle"

jump(-100)

local n = 6

for iteration = 1, n do
  turn(360 / n)
  move(100)

  turn(-360 / n)
  move(20)

  for n2 = 1, n - 2 do
    turn(360 / n)
    move(40)
  end

  turn(360 / n)
  move(20)
end

wait()
