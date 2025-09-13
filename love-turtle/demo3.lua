-- Demo 3: spaced, axis-aligned patterns (grid of crosses)
require 'turtle'

return function()
    show()
    pnup()
    pnsz(3)

    local cols, rows = 6, 4
    local cell = 50
    local spacing = 30

    -- top-left start relative to center
    local startx = -((cols - 1) * (cell + spacing)) / 2
    local starty = -((rows - 1) * (cell + spacing)) / 2

    -- move to starting position
    move(startx, starty) -- vector move (pen up)

    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            shape(function()
                -- set random color per cell
                pncl_ranc()

                -- draw centered axis-aligned cross of total length = cell
                -- we are currently at cell center
                pnup()
                -- horizontal: move left, draw to right, return center
                move(-cell / 2, 0)
                pndn()
                move(cell, 0)
                pnup()
                move(-cell / 2, 0)

                -- vertical: move up, draw down, return center
                move(0, -cell / 2)
                pndn()
                move(0, cell)
                pnup()
                move(0, -cell / 2)

                -- advance to next column
                move(cell + spacing, 0)
            end)
        end
        -- move back to first column of next row
        move(-(cols) * (cell + spacing), cell + spacing)
    end

    wait()
end
