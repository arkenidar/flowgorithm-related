-- Demo copied from user's example
require 'turtle'

local function pattern(n, inner, sign)
    for _ = 1, n do
        for _ = 1, inner do
            move(50 / inner * 4)
            turn(180 / inner * sign)
        end
        turn(360 / n)
    end
end

return function()
    show()

    local sides = 4
    pnsz(2)

    -- arrange the four patterns in a 2x2 grid
    local spacing = 300 -- distance between pattern centers
    local half = spacing / 2

    -- start at top-left cell
    pnup()
    move(-half, -half)
    pndn()

    -- top-left: small quick pattern
    shape(function()
        pncl_ranc()
        pattern(sides, 3, 1)
        wait(0.2)
    end)

    -- move to top-right cell
    pnup()
    move(spacing, 0)
    pndn()

    -- top-right: larger detailed pattern
    shape(function()
        pncl_ranc()
        pattern(sides, 30, 1)
        wait(0.2)
    end)

    -- move to bottom-left cell
    pnup()
    move(-spacing, spacing)
    pndn()

    -- bottom-left: mirrored detailed pattern
    shape(function()
        pncl_ranc()
        pattern(sides, 30, -1)
        wait(0.2)
    end)

    -- move to bottom-right cell
    pnup()
    move(spacing, 0)
    pndn()

    -- bottom-right: small mirrored pattern
    shape(function()
        pncl_ranc()
        pattern(sides, 3, -1)
    end)

    -- final randomize pen and wait for input
    shape(function()
        pncl_ranc()
        wait()
    end)
end
