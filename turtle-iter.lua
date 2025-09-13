require("turtle")

local function pattern(n, inner, sign)
  for _ = 1, n do
    for _ = 1, inner do
      move(50 / inner * 4)
      turn(180 / inner * sign)
    end
    turn(360 / n)
  end
end

show()

local sides = 4

pncl(ranc())
pattern(sides, 3, 1)

pncl(ranc())
pattern(sides, 30, 1)

pncl(ranc())
pattern(sides, 30, -1)

pncl(ranc())
pattern(sides, 3, -1)

wait()
