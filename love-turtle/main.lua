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
    y = 56, -- moved down to accommodate zoom display
    w = 220,
    h = 12,
    min = 0.1,
    max = 5.0,
    dragging = false,
}
-- animation UI state
local anim_button = { x = 560, y = 8, w = 120, h = 28 }

-- view transformation state
local view = {
    zoom = 1.0,
    pan_x = 0,
    pan_y = 0,
    dragging = false,
    drag_start_x = 0,
    drag_start_y = 0,
    drag_start_pan_x = 0,
    drag_start_pan_y = 0,
    min_zoom = 0.1,
    max_zoom = 10.0
}

-- text input / REPL state
local text_input = {
    text = "",
    cursor_pos = 0,
    active = false,
    mode = "repl", -- "repl" or "editor"
    x = 8,
    y = 480,       -- moved up further from 500 to 480
    w = 784,
    h = 112,       -- increased from 92 to 112 for better fit
    history = {},
    history_index = 0,
    output = {},
    output_scroll = 0, -- scroll offset for output
    multiline_code = "",
    blink_timer = 0,
    -- resize handle state
    resize_handle = {
        height = 6,        -- handle height
        dragging = false,  -- is currently being dragged
        hover = false,     -- mouse is hovering over handle
        drag_start_y = 0,  -- y position where drag started
        start_height = 0,  -- text input height when drag started (not used with new logic)
        start_y = 0,       -- text input y position when drag started
        min_y = 80,        -- minimum Y position (leaves space for UI)
        max_y = 540        -- maximum Y position (ensures minimum console height)
    },
    show_cursor = true,
    ignore_next_text_input = false -- flag to ignore activation character
}

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
    local demo = require 'demo0'
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

    -- update text input cursor blink
    text_input.blink_timer = text_input.blink_timer + dt
    if text_input.blink_timer >= 1.0 then
        text_input.blink_timer = 0
        text_input.show_cursor = not text_input.show_cursor
    end
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
local mono_font = love.graphics.newFont(11) -- use default font as fallback

-- Calculate maximum lines that can fit in the output area
local function calculate_max_lines()
    local ti = text_input
    local line_height = mono_font:getHeight()
    local input_line_height = ti.mode == "editor" and 28 or 22  -- space for input text
    local available_height = ti.h - input_line_height - 16      -- subtract margins and padding
    local max_lines = math.max(1, math.floor(available_height / line_height))
    return max_lines
end

local function draw_text_input()
    local ti = text_input

    -- background
    love.graphics.setColor(ti.active and { 0.95, 0.95, 1 } or { 0.9, 0.9, 0.9 })
    love.graphics.rectangle('fill', ti.x, ti.y, ti.w, ti.h, 4, 4)

    -- border
    love.graphics.setColor(ti.active and { 0.2, 0.2, 0.8 } or { 0.5, 0.5, 0.5 })
    love.graphics.setLineWidth(ti.active and 2 or 1)
    love.graphics.rectangle('line', ti.x, ti.y, ti.w, ti.h, 4, 4)

    -- input text (handle multiline) - positioned at top-left of console
    love.graphics.setFont(mono_font)
    local display_text = ti.text
    local text_x = ti.x + 8 -- start closer to left edge
    local text_y = ti.y + 8 -- start closer to top edge
    local line_height = mono_font:getHeight()

    if ti.mode == "editor" then
        -- multi-line display for editor mode
        local lines = {}
        local current_line = ""
        for i = 1, #display_text do
            local char = string.sub(display_text, i, i)
            if char == '\n' then
                table.insert(lines, current_line)
                current_line = ""
            else
                current_line = current_line .. char
            end
        end
        table.insert(lines, current_line)

        for i, line in ipairs(lines) do
            love.graphics.print(line, text_x, text_y + (i - 1) * line_height)
        end

        -- cursor for multiline
        if ti.active and ti.show_cursor then
            local cursor_line = 1
            local cursor_col = ti.cursor_pos
            local char_count = 0
            for i = 1, #display_text do
                if char_count >= ti.cursor_pos then break end
                if string.sub(display_text, i, i) == '\n' then
                    cursor_line = cursor_line + 1
                    cursor_col = ti.cursor_pos - char_count - 1
                end
                char_count = char_count + 1
            end
            local cursor_x = text_x + mono_font:getWidth(string.sub(lines[cursor_line] or "", 1, cursor_col))
            local cursor_y = text_y + (cursor_line - 1) * line_height
            love.graphics.setColor(0, 0, 0)
            love.graphics.line(cursor_x, cursor_y, cursor_x, cursor_y + line_height)
        end
    else
        -- single line display for REPL mode
        love.graphics.print(display_text, text_x, text_y)

        -- cursor
        if ti.active and ti.show_cursor then
            local cursor_x = text_x + mono_font:getWidth(string.sub(display_text, 1, ti.cursor_pos))
            love.graphics.setColor(0, 0, 0)
            love.graphics.line(cursor_x, text_y, cursor_x, text_y + line_height)
        end
    end

    -- output area (recent commands/results)
    if #ti.output > 0 and ti.active then
        love.graphics.setFont(mono_font)
        love.graphics.setColor(0.3, 0.3, 0.3)
        local output_y = ti.y + (ti.mode == "editor" and 28 or 22) -- positioned below input text
        local max_lines = calculate_max_lines()                   -- dynamic based on console height

        -- calculate visible range with scroll offset
        local total_lines = #ti.output
        local start_idx = math.max(1, total_lines - max_lines + 1 - ti.output_scroll)
        local end_idx = math.min(total_lines, start_idx + max_lines - 1)

        -- draw visible output lines
        local line_count = 0
        for i = start_idx, end_idx do
            if line_count >= max_lines then break end
            local line = ti.output[i]
            -- truncate long lines to fit
            if mono_font:getWidth(line) > ti.w - 100 then -- more space for scroll indicator
                line = string.sub(line, 1, math.floor((ti.w - 100) / mono_font:getWidth("M"))) .. "..."
            end
            love.graphics.print(line, text_x, output_y)
            output_y = output_y + mono_font:getHeight()
            line_count = line_count + 1
        end

        -- draw scroll indicator if there's more content
        if total_lines > max_lines then
            local scroll_x = ti.x + ti.w - 20
            local scroll_y = ti.y + (ti.mode == "editor" and 28 or 22) -- match output_y
            local scroll_h = max_lines * mono_font:getHeight()

            -- scroll track
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.rectangle('fill', scroll_x, scroll_y, 8, scroll_h)

            -- scroll thumb
            local thumb_height = math.max(10, scroll_h * max_lines / total_lines)
            local thumb_pos = scroll_y +
                (scroll_h - thumb_height) * ti.output_scroll / math.max(1, total_lines - max_lines)
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.rectangle('fill', scroll_x, thumb_pos, 8, thumb_height)

            -- scroll info - positioned above the scrollbar
            love.graphics.setFont(font)
            love.graphics.setColor(0.5, 0.5, 0.5)
            local info_text = string.format("%d/%d", math.min(end_idx, total_lines), total_lines)
            local text_width = font:getWidth(info_text)
            local info_x = ti.x + ti.w - text_width - 4 -- right-aligned with 4px margin from right border  
            local info_y = scroll_y - font:getHeight() - 2 -- above scrollbar with 2px gap
            love.graphics.print(info_text, info_x, info_y)
        end
    end

    -- help text
    if not ti.active and ti.text == "" then
        love.graphics.setFont(font)
        love.graphics.setColor(0.6, 0.6, 0.6)
        if ti.mode == "repl" then
            love.graphics.print(
                "Click here or press 'i' for REPL: fd(100), rt(90), pu(), pd(), etc. Type 'help' for commands", ti.x + 8,
                ti.y + 8)
        else
            love.graphics.print("Click here or press 'i' for CODE mode: Enter multi-line code, Ctrl+Enter to execute",
                ti.x + 8, ti.y + 8)
        end
        love.graphics.print("Tab to switch modes, Esc to exit, Up/Down for history, PgUp/PgDn/wheel to scroll", ti.x + 8,
            ti.y + 22)
        love.graphics.print("Ctrl+C/V/X for copy/paste/cut, Ctrl+A to select all", ti.x + 8, ti.y + 36)
    end
    
    -- resize handle
    local handle = ti.resize_handle
    local handle_y = ti.y - handle.height
    local handle_color = handle.hover and { 0.6, 0.6, 0.8 } or { 0.7, 0.7, 0.7 }
    if handle.dragging then
        handle_color = { 0.4, 0.4, 0.9 }
    end
    
    love.graphics.setColor(handle_color)
    love.graphics.rectangle('fill', ti.x, handle_y, ti.w, handle.height, 2, 2)
    
    -- resize handle grip lines
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setLineWidth(1)
    local grip_y = handle_y + handle.height / 2
    for i = 0, 2 do
        local grip_x = ti.x + ti.w / 2 - 10 + i * 8
        love.graphics.line(grip_x, grip_y - 1, grip_x, grip_y + 1)
    end
end

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
    -- zoom indicator
    love.graphics.print(string.format('Zoom: %.2fx Pan: (%.0f,%.0f)', view.zoom, view.pan_x, view.pan_y), 8, 68)

    -- slider label
    love.graphics.print('Interval:', 8, 80)
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

    -- Apply view transformation for turtle drawing
    love.graphics.push()
    love.graphics.translate(400 + view.pan_x, 300 + view.pan_y) -- center of screen + pan offset
    love.graphics.scale(view.zoom, view.zoom)
    love.graphics.translate(-400, -300)                         -- translate back
    turtle.draw()
    love.graphics.pop()

    draw_ui()
    draw_text_input()
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

    -- Mode toggle button
    local mode_button = { x = 692, y = 8, w = 100, h = 28 }
    love.graphics.setColor(text_input.mode == "repl" and { 0.7, 0.9, 0.7 } or { 0.9, 0.7, 0.9 })
    love.graphics.rectangle('fill', mode_button.x, mode_button.y, mode_button.w, mode_button.h, 4, 4)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', mode_button.x, mode_button.y, mode_button.w, mode_button.h, 4, 4)
    love.graphics.print(string.format('%s (tab)', text_input.mode:upper()), mode_button.x + 8, mode_button.y + 6)
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
    -- Mode toggle click area
    local mode_button = { x = 692, y = 8, w = 100, h = 28 }
    if x >= mode_button.x and x <= mode_button.x + mode_button.w and y >= mode_button.y and y <= mode_button.y + mode_button.h then
        text_input.mode = text_input.mode == "repl" and "editor" or "repl"
        table.insert(text_input.output, "Mode: " .. text_input.mode)
        print('[info] Mode ->', text_input.mode)
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
    -- resize handle click area
    local ti = text_input
    local handle = ti.resize_handle
    local handle_y = ti.y - handle.height
    if x >= ti.x and x <= ti.x + ti.w and y >= handle_y and y <= handle_y + handle.height then
        handle.dragging = true
        handle.drag_start_y = y
        handle.start_height = ti.h
        handle.start_y = ti.y
        if DEBUG then print('[debug] resize handle drag started at y=', y) end
        return
    end
    -- text input click area
    if x >= ti.x and x <= ti.x + ti.w and y >= ti.y and y <= ti.y + ti.h then
        ti.active = true
        -- position cursor based on click
        local text_x = ti.x + 60
        local click_x = x - text_x
        local char_pos = 0
        for i = 1, #ti.text do
            local char_width = mono_font:getWidth(string.sub(ti.text, i, i))
            if click_x < mono_font:getWidth(string.sub(ti.text, 1, i)) - char_width / 2 then
                break
            end
            char_pos = i
        end
        ti.cursor_pos = char_pos
        if DEBUG then print('[debug] text input activated, cursor at', char_pos) end
        return
    else
        ti.active = false
    end

    -- check for view panning (right mouse button or middle mouse button)
    if button == 2 or button == 3 then -- right or middle mouse button
        view.dragging = true
        view.drag_start_x = x
        view.drag_start_y = y
        view.drag_start_pan_x = view.pan_x
        view.drag_start_pan_y = view.pan_y
        if DEBUG then print('[debug] starting pan drag') end
        return
    end

    -- otherwise resume input-wait
    if DEBUG then print('[debug] mousepressed outside UI: resume input') end
    turtle._resumeInput()
end

function love.mousereleased(x, y, button)
    if slider.dragging then slider.dragging = false end
    if text_input.resize_handle.dragging then 
        text_input.resize_handle.dragging = false
        if DEBUG then print('[debug] stopped resize handle drag') end
    end
    if view.dragging then
        view.dragging = false
        if DEBUG then print('[debug] stopped pan drag') end
    end
end

function love.mousemoved(x, y, dx, dy)
    local ti = text_input
    local handle = ti.resize_handle
    
    -- check hover state for resize handle
    local handle_y = ti.y - handle.height
    handle.hover = (x >= ti.x and x <= ti.x + ti.w and y >= handle_y and y <= handle_y + handle.height)
    
    if handle.dragging then
        -- resize the text input - always extend to bottom of window
        local delta_y = y - handle.drag_start_y
        local new_y = math.max(80, math.min(540, handle.start_y + delta_y)) -- constrain Y position
        local window_bottom = 600 - 8 -- leave 8px margin from window bottom
        
        ti.y = new_y
        ti.h = window_bottom - ti.y -- always fill to bottom of window
        
        if DEBUG then print('[debug] resizing to y=', ti.y, 'height=', ti.h, 'extends to=', ti.y + ti.h) end
    elseif slider.dragging then
        local t = (x - slider.x) / slider.w
        t = math.max(0, math.min(1, t))
        auto_interval = slider.min + t * (slider.max - slider.min)
        if DEBUG then print('[debug] slider dragging ->', auto_interval) end
    elseif view.dragging then
        -- update pan based on mouse movement
        view.pan_x = view.drag_start_pan_x + (x - view.drag_start_x)
        view.pan_y = view.drag_start_pan_y + (y - view.drag_start_y)
    end
end

-- Help system
local help_commands = {
    ["help"] = "Show this help message",
    ["move(n)"] = "Move forward n pixels (use fd(n) as shortcut)",
    ["fd(n)"] = "Forward n pixels",
    ["bk(n)"] = "Backward n pixels",
    ["turn(angle)"] = "Turn by angle degrees (positive=right, negative=left)",
    ["rt(angle)"] = "Right turn by angle degrees (default 90)",
    ["lt(angle)"] = "Left turn by angle degrees (default 90)",
    ["jump(n)"] = "Jump forward n pixels without drawing",
    ["pu()"] = "Pen up (stop drawing)",
    ["pd()"] = "Pen down (start drawing)",
    ["pnsz(size)"] = "Set pen size",
    ["pncl(r,g,b,a)"] = "Set pen color (values 0-1)",
    ["wait(seconds)"] = "Wait for specified seconds",
    ["show()"] = "Show turtle",
    ["hide()"] = "Hide turtle",
    ["print(...)"] = "Print values to output",
    ["clear()"] = "Clear output history",
    ["reset()"] = "Reset turtle to origin",
    ["square(size)"] = "Draw a square (default size 50)",
    ["triangle(size,angle)"] = "Draw a triangle (default size 50, angle 120)",
    ["circle(radius)"] = "Draw a circle (default radius 50)",
}

local function show_help()
    local ti = text_input
    if DEBUG then print('[debug] show_help() called') end
    table.insert(ti.output, "=== TURTLE COMMANDS ===")
    local commands = {}
    for cmd, desc in pairs(help_commands) do
        table.insert(commands, cmd)
    end
    table.sort(commands)

    for _, cmd in ipairs(commands) do
        table.insert(ti.output, cmd .. " - " .. help_commands[cmd])
    end
    table.insert(ti.output, "=== SCROLLING ===")
    table.insert(ti.output, "PgUp/PgDn - Scroll output up/down")
    table.insert(ti.output, "Mouse wheel - Scroll output")
    table.insert(ti.output, "Ctrl+Home - Scroll to top")
    table.insert(ti.output, "Ctrl+End - Scroll to bottom")
    table.insert(ti.output, "=== CLIPBOARD ===")
    table.insert(ti.output, "Ctrl+C - Copy text to clipboard")
    table.insert(ti.output, "Ctrl+V - Paste text from clipboard")
    table.insert(ti.output, "Ctrl+X - Cut text to clipboard")
    table.insert(ti.output, "Ctrl+A - Select all (move cursor to end)")
    table.insert(ti.output, "=== VIEW CONTROLS ===")
    table.insert(ti.output, "Mouse wheel - Zoom in/out at cursor")
    table.insert(ti.output, "Right-click drag - Pan the view")
    table.insert(ti.output, "Ctrl++ - Zoom in")
    table.insert(ti.output, "Ctrl+- - Zoom out")
    table.insert(ti.output, "Arrow keys - Pan view")
    table.insert(ti.output, "Home - Reset zoom and pan")
    table.insert(ti.output, "=== ANIMATION SPEED ===")
    table.insert(ti.output, "Shift++ - Faster auto-step (decrease interval)")
    table.insert(ti.output, "Shift+- - Slower auto-step (increase interval)")
    table.insert(ti.output, "=== EXAMPLES ===")
    table.insert(ti.output, "fd(100)  -- move forward 100 pixels")
    table.insert(ti.output, "rt(90)   -- turn right 90 degrees")
    table.insert(ti.output, "square(80)  -- draw 80px square")
    table.insert(ti.output, "pncl(1,0,0,1); circle(60)  -- red circle")
    table.insert(ti.output, "for i=1,6 do fd(50); rt(60) end  -- hexagon")

    -- auto-scroll to bottom to show the help
    local max_lines = calculate_max_lines()
    ti.output_scroll = math.max(0, #ti.output - max_lines)
end

local function handle_text_input(key)
    local ti = text_input

    if key == 'return' then
        -- execute command in REPL mode or add newline in editor mode
        if ti.mode == "repl" then
            if ti.text ~= "" then
                table.insert(ti.history, ti.text)
                ti.history_index = #ti.history + 1
                execute_turtle_command(ti.text)
                ti.text = ""
                ti.cursor_pos = 0
            end
        else
            -- editor mode: add newline
            ti.text = string.sub(ti.text, 1, ti.cursor_pos) .. '\n' .. string.sub(ti.text, ti.cursor_pos + 1)
            ti.cursor_pos = ti.cursor_pos + 1
        end
        return true
    elseif key == 'backspace' then
        if ti.cursor_pos > 0 then
            ti.text = string.sub(ti.text, 1, ti.cursor_pos - 1) .. string.sub(ti.text, ti.cursor_pos + 1)
            ti.cursor_pos = ti.cursor_pos - 1
        end
        return true
    elseif key == 'left' then
        ti.cursor_pos = math.max(0, ti.cursor_pos - 1)
        return true
    elseif key == 'right' then
        ti.cursor_pos = math.min(#ti.text, ti.cursor_pos + 1)
        return true
    elseif key == 'up' and ti.mode == "repl" then
        -- history navigation
        if ti.history_index > 1 then
            ti.history_index = ti.history_index - 1
            ti.text = ti.history[ti.history_index] or ""
            ti.cursor_pos = #ti.text
        end
        return true
    elseif key == 'down' and ti.mode == "repl" then
        -- history navigation
        if ti.history_index <= #ti.history then
            ti.history_index = ti.history_index + 1
            ti.text = ti.history[ti.history_index] or ""
            ti.cursor_pos = #ti.text
        end
        return true
    elseif key == 'tab' then
        -- toggle mode
        ti.mode = ti.mode == "repl" and "editor" or "repl"
        table.insert(ti.output, "Mode: " .. ti.mode)
        return true
    elseif key == 'pageup' then
        -- scroll output up
        ti.output_scroll = math.max(0, ti.output_scroll - 5)
        return true
    elseif key == 'pagedown' then
        -- scroll output down
        local max_lines = calculate_max_lines()
        local max_scroll = math.max(0, #ti.output - max_lines)
        ti.output_scroll = math.min(max_scroll, ti.output_scroll + 5)
        return true
    elseif key == 'home' and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) then
        -- scroll to top
        ti.output_scroll = 0
        return true
    elseif key == 'end' and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) then
        -- scroll to bottom
        local max_lines = calculate_max_lines()
        ti.output_scroll = math.max(0, #ti.output - max_lines)
        return true
    elseif key == 'c' and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) then
        -- copy selected text or all text to clipboard
        if ti.text ~= "" then
            love.system.setClipboardText(ti.text)
            table.insert(ti.output, "Text copied to clipboard")
        end
        return true
    elseif key == 'v' and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) then
        -- paste from clipboard
        local clipboard_text = love.system.getClipboardText()
        if clipboard_text and clipboard_text ~= "" then
            ti.text = string.sub(ti.text, 1, ti.cursor_pos) .. clipboard_text .. string.sub(ti.text, ti.cursor_pos + 1)
            ti.cursor_pos = ti.cursor_pos + #clipboard_text
            table.insert(ti.output, "Text pasted from clipboard")
        end
        return true
    elseif key == 'x' and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) then
        -- cut text to clipboard
        if ti.text ~= "" then
            love.system.setClipboardText(ti.text)
            ti.text = ""
            ti.cursor_pos = 0
            table.insert(ti.output, "Text cut to clipboard")
        end
        return true
    elseif key == 'a' and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) then
        -- select all (move cursor to end)
        ti.cursor_pos = #ti.text
        return true
    elseif key == 'escape' then
        ti.active = false
        return true
    elseif key == 'f1' then
        -- show help
        show_help()
        return true
    end

    return false
end

function execute_turtle_command(cmd)
    local ti = text_input
    table.insert(ti.output, ">" .. cmd)
    -- auto-scroll to bottom when new content is added
    local max_lines = calculate_max_lines()
    ti.output_scroll = math.max(0, #ti.output - max_lines)

    -- handle special commands
    if cmd:lower() == "help" or cmd:lower() == "?" then
        show_help()
        return
    elseif cmd:lower() == "clear" then
        ti.output = {}
        table.insert(ti.output, "Output cleared")
        return
    elseif cmd:lower() == "reset" then
        turtle.reset()
        table.insert(ti.output, "Turtle reset to origin")
        return
    end

    -- create a safe environment for execution
    local safe_env = {
        -- turtle functions
        move = turtle.move,
        turn = turtle.turn,
        jump = turtle.jump,
        pndn = turtle.pndn,
        pnup = turtle.pnup,
        pnsz = turtle.pnsz,
        pncl = turtle.pncl,
        wait = turtle.wait,
        show = turtle.show,
        hide = turtle.hide,
        -- math functions
        math = math,
        -- basic functions
        print = function(...)
            local args = { ... }
            local output = ""
            for i, v in ipairs(args) do
                output = output .. tostring(v) .. (i < #args and "\t" or "")
            end
            table.insert(ti.output, output)
            -- auto-scroll to bottom when new content is added
            local max_lines = calculate_max_lines()
            ti.output_scroll = math.max(0, #ti.output - max_lines)
        end,
        -- shorthand functions
        fd = turtle.move,                                     -- forward
        bk = function(dist) turtle.move(-dist) end,           -- backward
        rt = function(angle) turtle.turn(angle or 90) end,    -- right turn
        lt = function(angle) turtle.turn(-(angle or 90)) end, -- left turn
        pu = turtle.pnup,                                     -- pen up
        pd = turtle.pndn,                                     -- pen down
        -- help functions
        help = show_help,
        -- utility functions
        clear = function()
            ti.output = {}
            table.insert(ti.output, "Output cleared")
        end,
        reset = function()
            turtle.reset()
            table.insert(ti.output, "Turtle reset")
        end,
        -- common drawing functions
        square = function(size)
            size = size or 50
            for i = 1, 4 do
                turtle.move(size)
                turtle.turn(90)
            end
        end,
        triangle = function(size, angle)
            size = size or 50
            angle = angle or 120 -- default interior angle for equilateral triangle
            for i = 1, 3 do
                turtle.move(size)
                turtle.turn(angle)
            end
        end,
        circle = function(radius)
            radius = radius or 50
            local steps = 36
            for i = 1, steps do
                turtle.move(2 * math.pi * radius / steps)
                turtle.turn(360 / steps)
            end
        end,
    }

    -- try to execute the command
    local success, result = pcall(function()
        local func, err = load("return " .. cmd, "repl", "t", safe_env)
        if not func then
            func, err = load(cmd, "repl", "t", safe_env)
        end
        if not func then
            error("Parse error: " .. err)
        end
        return func()
    end)

    if success then
        if result ~= nil then
            table.insert(ti.output, tostring(result))
        end
        table.insert(ti.output, "Command completed")
    else
        table.insert(ti.output, "Error: " .. tostring(result))
        if DEBUG then print('[debug] Command execution error:', result) end
    end

    -- auto-scroll to bottom when new content is added
    local max_lines = calculate_max_lines()
    ti.output_scroll = math.max(0, #ti.output - max_lines)

    -- limit output history
    while #ti.output > 50 do -- increased from 10 to 50 for better scrolling
        table.remove(ti.output, 1)
        -- adjust scroll offset when removing from beginning
        ti.output_scroll = math.max(0, ti.output_scroll - 1)
    end
end

function execute_editor_code()
    local ti = text_input
    if ti.text ~= "" then
        table.insert(ti.output, "Executing code block:")
        execute_turtle_command(ti.text)
    end
end

function love.keypressed(k, scancode, isrepeat)
    -- global F1 help - works anytime
    if k == 'f1' then
        if DEBUG then print('[debug] F1 key pressed - showing help') end
        show_help()
        -- activate text input to show the help output
        if not text_input.active then
            text_input.active = true
            if DEBUG then print('[debug] activated text input to show help') end
        end
        return
    end

    -- handle text input activation/deactivation first
    if k == 'i' and not text_input.active then
        text_input.active = true
        text_input.ignore_next_text_input = true -- ignore the 'i' character in textinput
        if DEBUG then print('[debug] text input activated') end
        return
    end

    -- handle text input if active
    if text_input.active then
        -- check for Ctrl+Enter to execute code in editor mode
        if k == 'return' and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) and text_input.mode == "editor" then
            execute_editor_code()
            return
        end
        if handle_text_input(k) then
            return
        end
    end

    -- only handle these keys when text input is not active
    if not text_input.active then
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
    end

    -- Handle Ctrl+zoom controls
    if (k == '+' or k == '=') and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) then
        -- Ctrl+Plus: zoom in
        view.zoom = math.min(view.max_zoom, view.zoom * 1.2)
        if DEBUG then print('[debug] Ctrl+zoom in ->', view.zoom) end
        return
    end
    if k == '-' and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) then
        -- Ctrl+Minus: zoom out
        view.zoom = math.max(view.min_zoom, view.zoom / 1.2)
        if DEBUG then print('[debug] Ctrl+zoom out ->', view.zoom) end
        return
    end

    -- Handle Shift+auto-interval controls
    if k == '+' and (love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift')) then
        -- Shift+Plus: decrease auto_interval (faster)
        auto_interval = math.max(0.05, auto_interval - 0.05)
        if DEBUG then print('[debug] Shift+auto_interval faster ->', auto_interval) end
        return
    end
    if k == '-' and (love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift')) then
        -- Shift+Minus: increase auto_interval (slower)
        auto_interval = auto_interval + 0.05
        if DEBUG then print('[debug] Shift+auto_interval slower ->', auto_interval) end
        return
    end
    -- only handle these keys when text input is not active
    if not text_input.active then
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

        -- View controls (zoom and pan)
        if k == 'kp+' or k == '=' then
            -- zoom in (supports keypad+ and =)
            view.zoom = math.min(view.max_zoom, view.zoom * 1.2)
            if DEBUG then print('[debug] zoom in ->', view.zoom) end
            return
        end
        if k == 'kp-' then
            -- zoom out (supports keypad-)
            view.zoom = math.max(view.min_zoom, view.zoom / 1.2)
            if DEBUG then print('[debug] zoom out ->', view.zoom) end
            return
        end
        if k == 'up' then
            -- pan up
            view.pan_y = view.pan_y - 20
            return
        end
        if k == 'down' then
            -- pan down
            view.pan_y = view.pan_y + 20
            return
        end
        if k == 'left' then
            -- pan left
            view.pan_x = view.pan_x - 20
            return
        end
        if k == 'right' then
            -- pan right
            view.pan_x = view.pan_x + 20
            return
        end
        if k == 'home' then
            -- reset view
            view.zoom = 1.0
            view.pan_x = 0
            view.pan_y = 0
            if DEBUG then print('[debug] view reset') end
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
end

function love.textinput(text)
    if text_input.active then
        -- check if we should ignore this text input (e.g., activation key 'i')
        if text_input.ignore_next_text_input then
            text_input.ignore_next_text_input = false
            return
        end

        -- insert text at cursor position
        local ti = text_input
        ti.text = string.sub(ti.text, 1, ti.cursor_pos) .. text .. string.sub(ti.text, ti.cursor_pos + 1)
        ti.cursor_pos = ti.cursor_pos + #text
        ti.blink_timer = 0 -- reset cursor blink
        ti.show_cursor = true
    end
end

function love.wheelmoved(x, y)
    local ti = text_input
    local max_lines = calculate_max_lines()
    if ti.active and #ti.output > max_lines then
        -- scroll output with mouse wheel when text input is active
        if y > 0 then
            -- scroll up
            ti.output_scroll = math.max(0, ti.output_scroll - 2)
        elseif y < 0 then
            -- scroll down
            local max_scroll = math.max(0, #ti.output - max_lines)
            ti.output_scroll = math.min(max_scroll, ti.output_scroll + 2)
        end
    else
        -- zoom in/out with mouse wheel when text input is not active
        local mouse_x, mouse_y = love.mouse.getPosition()
        local old_zoom = view.zoom

        if y > 0 then
            -- zoom in
            view.zoom = math.min(view.max_zoom, view.zoom * 1.2)
        elseif y < 0 then
            -- zoom out
            view.zoom = math.max(view.min_zoom, view.zoom / 1.2)
        end

        -- zoom around mouse cursor
        if view.zoom ~= old_zoom then
            local zoom_factor = view.zoom / old_zoom
            local center_x, center_y = 400, 300
            view.pan_x = (view.pan_x + mouse_x - center_x) * zoom_factor - (mouse_x - center_x)
            view.pan_y = (view.pan_y + mouse_y - center_y) * zoom_factor - (mouse_y - center_y)
            if DEBUG then print('[debug] zoom:', view.zoom, 'pan:', view.pan_x, view.pan_y) end
        end
    end
end
