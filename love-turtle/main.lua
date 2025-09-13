-- Love2D runner for the turtle demo
-- enable stdout debug messages
_G.DEBUG = true
local turtle = require 'turtle'

local demo_co
local demo_status = 'not started'
local step_requested = false
local auto_enabled = false
local auto_interval = 1.5 -- seconds between automatic steps
local auto_acc = 0
local step_all = true
local step_all_acc = 0
local slider = {
    x = 100,
    y = 44,
    w = 220,
    h = 12,
    min = 0.1,
    max = 5.0,
    dragging = false,
}
-- animation UI state
local anim_button = { x = 560, y = 8, w = 120, h = 28 }

local function start_demo()
    -- If there's an existing demo coroutine, behave sensibly:
    --  - if it's suspended, resume it (Run acts like resume)
    --  - if it's running, ignore the request
    --  - if it's dead or nil, create a fresh coroutine and start it
    if demo_co then
        local st = coroutine.status(demo_co)
        if st == 'suspended' then
            if DEBUG then print('[debug] start_demo: resuming existing suspended demo') end
            local ok, err = coroutine.resume(demo_co)
            demo_status = coroutine.status(demo_co)
            if not ok then
                demo_status = 'error: ' .. tostring(err)
                print('[error] demo coroutine error (resume existing):', err)
                if debug and debug.traceback then print(debug.traceback()) end
            end
            return
        elseif st == 'running' then
            if DEBUG then print('[debug] start_demo: demo already running; ignoring') end
            return
        end
        -- if dead, fall through to create a fresh one
    end

    -- start a new demo coroutine
    local demo = require 'demo2'
    demo_co = coroutine.create(demo)
    demo_status = 'running'
    if DEBUG then print('[debug] starting demo coroutine') end
    local ok, err
    if coroutine.status(demo_co) == 'suspended' then
        ok, err = coroutine.resume(demo_co)
    end
    demo_status = coroutine.status(demo_co)
    if DEBUG then print('[debug] demo status after start:', demo_status) end
    if not ok then
        demo_status = 'error: ' .. tostring(err)
        print('[error] demo coroutine error (start):', err)
        if debug and debug.traceback then print(debug.traceback()) end
    end
end

function love.load()
    love.window.setTitle('Love Turtle LOGO Demo')
    love.window.setMode(800, 600)
    start_demo()
end

function love.update(dt)
    turtle._tick(dt)
    -- auto-step mode: accumulate time and request a step when interval reached
    if auto_enabled and demo_co and coroutine.status(demo_co) == 'suspended' then
        -- don't schedule the next automatic step while an animation is still running
        local ws = turtle._getWaitState and turtle._getWaitState() or { anim_wait = false }
        if not ws.anim_wait then
            auto_acc = auto_acc + dt
            if auto_acc >= auto_interval then
                auto_acc = 0
                step_requested = true
            end
        else
            -- pause accumulator while animating
            auto_acc = 0
        end
    end
    -- if coroutine is suspended waiting and not dead, resume as appropriate is done by turtle
    if step_requested and demo_co and coroutine.status(demo_co) == 'suspended' then
        step_requested = false
        if DEBUG then print('[debug] stepping coroutine (single step)') end
        if DEBUG then
            print('[debug] demo_co before step status:', coroutine.status(demo_co))
            if turtle and turtle._getWaitState then
                local ws = turtle._getWaitState()
                print('[debug] turtle wait state before step:', ws.wait_co, ws.wait_timer)
            end
        end
        local ok, err
        if coroutine.status(demo_co) == 'suspended' then
            ok, err = coroutine.resume(demo_co)
        end
        demo_status = coroutine.status(demo_co)
        if DEBUG then print('[debug] demo status after step:', demo_status) end
        if not ok then
            demo_status = 'error: ' .. tostring(err)
            print('[error] demo coroutine error (step):', err)
            if debug and debug.traceback then print(debug.traceback()) end
        end
    end
    -- if step_all requested, keep resuming until coroutine is dead
    if step_all and demo_co and coroutine.status(demo_co) == 'suspended' then
        -- animate step_all: resume one shape every auto_interval seconds
        local ws = turtle._getWaitState and turtle._getWaitState() or { anim_wait = false }
        if not ws.anim_wait then
            step_all_acc = step_all_acc + dt
            if step_all_acc >= auto_interval then
                step_all_acc = 0
                if DEBUG then print('[debug] step_all: resume one shape') end
                local ok, err
                if coroutine.status(demo_co) == 'suspended' then
                    ok, err = coroutine.resume(demo_co)
                end
                demo_status = coroutine.status(demo_co)
                if not ok then
                    demo_status = 'error: ' .. tostring(err)
                    print('[error] demo coroutine error (step_all):', err)
                    step_all = false
                end
                -- stop when coroutine finishes
                if coroutine.status(demo_co) == 'dead' then
                    if DEBUG then print('[debug] step_all completed, status:', demo_status) end
                    step_all = false
                end
            end
        else
            -- pause accumulator while animating
            step_all_acc = 0
        end
    end
end

-- draw UI (step button and status)
local font = love.graphics.newFont(12)
local function draw_ui()
    love.graphics.setFont(font)
    -- button background
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle('fill', 8, 8, 80, 28, 4, 4)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', 8, 8, 80, 28, 4, 4)
    love.graphics.print('Step (s)', 18, 14)

    -- Step All button
    love.graphics.setColor(step_all and { 0.7, 0.95, 0.7 } or { 0.9, 0.9, 0.9 })
    love.graphics.rectangle('fill', 232, 8, 84, 28, 4, 4)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', 232, 8, 84, 28, 4, 4)
    love.graphics.print('Step All (r)', 242, 14)

    -- auto toggle button
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle('fill', 100, 8, 120, 28, 4, 4)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', 100, 8, 120, 28, 4, 4)
    love.graphics.print('Auto: ' .. (auto_enabled and 'ON' or 'OFF'), 110, 14)
    love.graphics.print(string.format('%.2fs', auto_interval), 170, 14)

    love.graphics.setColor(0, 0, 0)
    love.graphics.print('Demo: ' .. tostring(demo_status), 8, 44)
    -- debug indicator
    love.graphics.print('Debug: ' .. (DEBUG and 'ON' or 'OFF'), 8, 56)

    -- slider label
    love.graphics.print('Interval:', 8, 68)
    -- slider background
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle('fill', slider.x, slider.y, slider.w, slider.h, 4, 4)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', slider.x, slider.y, slider.w, slider.h, 4, 4)
    -- knob position
    local t = (auto_interval - slider.min) / (slider.max - slider.min)
    t = math.max(0, math.min(1, t))
    local kx = slider.x + t * slider.w
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.circle('fill', kx, slider.y + slider.h / 2, slider.h)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(string.format('%.2fs', auto_interval), slider.x + slider.w + 8, slider.y - 2)
end

-- combined draw: turtle content + UI
function love.draw()
    love.graphics.clear(1, 1, 1, 1)
    turtle.draw()
    draw_ui()
    -- Reset button
    love.graphics.setColor(0.9, 0.7, 0.7)
    love.graphics.rectangle('fill', 328, 8, 64, 28, 4, 4)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', 328, 8, 64, 28, 4, 4)
    love.graphics.print('Reset (z)', 336, 14)
    -- Run button
    love.graphics.setColor(0.7, 0.9, 0.9)
    love.graphics.rectangle('fill', 400, 8, 64, 28, 4, 4)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', 400, 8, 64, 28, 4, 4)
    love.graphics.print('Run (p)', 408, 14)
    -- Debug toggle button
    love.graphics.setColor(DEBUG and { 0.7, 0.95, 0.7 } or { 0.9, 0.9, 0.9 })
    love.graphics.rectangle('fill', 472, 8, 84, 28, 4, 4)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', 472, 8, 84, 28, 4, 4)
    love.graphics.print('Debug (d)', 480, 14)
    -- Animation controls
    love.graphics.setColor(turtle.getAnimation() and { 0.7, 0.95, 0.7 } or { 0.9, 0.9, 0.9 })
    love.graphics.rectangle('fill', anim_button.x, anim_button.y, anim_button.w, anim_button.h, 4, 4)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', anim_button.x, anim_button.y, anim_button.w, anim_button.h, 4, 4)
    love.graphics.print(string.format('Anim %s (m)', turtle.getAnimation() and 'ON' or 'OFF'), anim_button.x + 8,
        anim_button.y + 6)
    love.graphics.print(string.format('spd: %.4f', turtle.getSecondsPerPixel()), anim_button.x + 8, anim_button.y + 18)
end

function love.mousepressed(x, y, button)
    -- if click inside the step button, request single-step resume
    if x >= 8 and x <= 88 and y >= 8 and y <= 36 then
        -- prefer resuming an input-waiting coroutine (shape-level wait)
        local resumed = false
        if turtle and turtle._resumeInput then
            resumed = turtle._resumeInput()
        end
        if not resumed then
            step_requested = true
        end
        return
    end
    -- auto toggle click area
    if x >= 100 and x <= 220 and y >= 8 and y <= 36 then
        auto_enabled = not auto_enabled
        auto_acc = 0
        if DEBUG then print('[debug] auto_enabled ->', auto_enabled) end
        return
    end
    -- Step All click area
    if x >= 232 and x <= 316 and y >= 8 and y <= 36 then
        step_all = not step_all
        step_all_acc = 0
        if DEBUG then print('[debug] step_all ->', step_all) end
        return
    end
    -- Reset click area
    if x >= 328 and x <= 392 and y >= 8 and y <= 36 then
        if DEBUG then print('[debug] reset requested') end
        -- perform reset only; stop any running demo coroutine so subsequent
        -- clicks reliably act on the fresh state.
        turtle.reset()
        if turtle and turtle._getWaitState then
            local ws = turtle._getWaitState()
            if DEBUG then print('[debug] turtle wait state after reset:', ws.wait_co, ws.wait_timer) end
        end
        demo_co = nil
        demo_status = 'not started'
        step_requested = false
        step_all = false
        auto_enabled = false
        auto_acc = 0
        step_all_acc = 0
        return
    end
    -- Run click area (start demo without resetting)
    if x >= 400 and x <= 464 and y >= 8 and y <= 36 then
        if DEBUG then print('[debug] run requested') end
        start_demo()
        if turtle and turtle._getWaitState then
            local ws = turtle._getWaitState()
            if DEBUG then print('[debug] turtle wait state after run:', ws.wait_co, ws.wait_timer) end
        end
        return
    end
    -- Debug click area
    if x >= 472 and x <= 556 and y >= 8 and y <= 36 then
        _G.DEBUG = not _G.DEBUG
        print('[info] Debug ->', _G.DEBUG)
        return
    end
    -- Animation click area
    if x >= anim_button.x and x <= anim_button.x + anim_button.w and y >= anim_button.y and y <= anim_button.y + anim_button.h then
        local newv = not turtle.getAnimation()
        turtle.setAnimation(newv)
        print('[info] Animation ->', newv)
        return
    end
    -- slider hit test (start drag)
    if x >= slider.x and x <= slider.x + slider.w and y >= slider.y - 8 and y <= slider.y + slider.h + 8 then
        slider.dragging = true
        -- set value according to position
        local t = (x - slider.x) / slider.w
        t = math.max(0, math.min(1, t))
        auto_interval = slider.min + t * (slider.max - slider.min)
        if DEBUG then print('[debug] slider set ->', auto_interval) end
        return
    end
    -- otherwise resume input-wait
    if DEBUG then print('[debug] mousepressed outside UI: resume input') end
    turtle._resumeInput()
end

function love.mousereleased(x, y, button)
    if slider.dragging then slider.dragging = false end
end

function love.mousemoved(x, y, dx, dy)
    if slider.dragging then
        local t = (x - slider.x) / slider.w
        t = math.max(0, math.min(1, t))
        auto_interval = slider.min + t * (slider.max - slider.min)
        if DEBUG then print('[debug] slider dragging ->', auto_interval) end
    end
end

function love.keypressed(k)
    if k == 's' then
        -- try to resume any input-waiting coroutine first; if none, request a step
        -- so the update loop will resume the demo coroutine if it's suspended
        local resumed = false
        if turtle and turtle._resumeInput then
            resumed = turtle._resumeInput()
        end
        if not resumed then
            step_requested = true
        end
        return
    end
    if k == 'a' then
        auto_enabled = not auto_enabled
        auto_acc = 0
        if DEBUG then print('[debug] auto_enabled ->', auto_enabled) end
        return
    end
    if k == '+' or k == '=' then
        auto_interval = math.max(0.05, auto_interval - 0.05)
        if DEBUG then print('[debug] auto_interval ->', auto_interval) end
        return
    end
    if k == '-' then
        auto_interval = auto_interval + 0.05
        if DEBUG then print('[debug] auto_interval ->', auto_interval) end
        return
    end
    if k == 'z' then
        if DEBUG then print('[debug] reset requested (key)') end
        -- reset only; do not start demo automatically
        turtle.reset()
        return
    end
    if k == 'p' then
        if DEBUG then print('[debug] run requested (key)') end
        start_demo()
        return
    end
    if k == 'r' then
        step_all = not step_all
        step_all_acc = 0
        if DEBUG then print('[debug] step_all ->', step_all) end
        return
    end
    if k == 'm' then
        local newv = not turtle.getAnimation()
        turtle.setAnimation(newv)
        if DEBUG then print('[debug] animation ->', newv) end
        return
    end
    if k == 't' then
        -- quick single-move animation test: reset and move forward visibly
        if DEBUG then print('[debug] single-move test (t)') end
        turtle.reset()
        turtle.setAnimation(true)
        turtle.setSecondsPerPixel(0.01)
        -- place turtle near center
        turtle.jump(0)
        -- run a small coroutine to animate a single move
        demo_co = coroutine.create(function()
            move(200)
            wait()
        end)
        demo_status = 'running'
        coroutine.resume(demo_co)
        demo_status = coroutine.status(demo_co)
        return
    end
    if k == ',' then
        -- decrease seconds_per_pixel (faster animation)
        local cur = turtle.getSecondsPerPixel()
        local nxt = math.max(0.0001, cur - 0.001)
        turtle.setSecondsPerPixel(nxt)
        if DEBUG then print('[debug] seconds_per_pixel ->', nxt) end
        return
    end
    if k == '.' then
        -- increase seconds_per_pixel (slower animation)
        local cur = turtle.getSecondsPerPixel()
        local nxt = cur + 0.001
        turtle.setSecondsPerPixel(nxt)
        if DEBUG then print('[debug] seconds_per_pixel ->', nxt) end
        return
    end
    if k == 'escape' or k == 'esc' then
        if DEBUG then print('[debug] escape pressed: quitting') end
        love.event.quit()
        return
    end
    if DEBUG then print('[debug] keypressed:', k, '-> resume input') end
    turtle._resumeInput()
end
