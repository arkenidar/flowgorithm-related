-- Demo copied from user's example
require 'turtle'

return function()
    jump(-100)

    local n = 6

    for _ = 1, n do
        turn(360 / n)
        move(100)

        turn(-360 / n)
        move(20)

        for _ = 1, n - 2 do
            turn(360 / n)
            move(40)
        end

        turn(360 / n)
        move(20)
    end

    wait()
end
