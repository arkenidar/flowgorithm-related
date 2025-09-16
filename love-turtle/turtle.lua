-- Minimal Love2D-compatible turtle (LOGO-like) library
-- Exposes global functions similar to original `turtle` module used by the user
-- Designed to be required by demos as `require 'turtle'`.

local M = {}

-- internal state
local turtles = {}
local current = 1
local showTurtles = false

local function newTurtle()
    local t = {
        x = 0,
        y = 0,
        angle = 0, -- degrees
        down = true,
        color = { 0, 0, 0, 1 },
        size = 2,
    }
    table.insert(turtles, t)
    current = #turtles
    return t
end

newTurtle()

local function each(fn)
    for i, t in ipairs(turtles) do
        fn(t)
    end
end

-- drawing commands will record segments into a list for rendering
local segments = {}

-- Verbose logging (per-frame/per-segment). Default off to avoid flooding terminal.
local VERBOSE = false

local function pushSegment(x1, y1, x2, y2, color, size)
    table.insert(segments, { x1, y1, x2, y2, color, size })
    if DEBUG and VERBOSE then
        print(string.format('[debug] pushSegment: (%.1f,%.1f)->(%.1f,%.1f) size=%.1f', x1, y1, x2, y2, size or 0))
    end
end

-- wait/animation state (declare early so functions above can see these locals)
local wait_co = nil
local wait_timer = nil

-- animation state for smooth moves
local animate_moves = true
local seconds_per_pixel = 0.005 -- duration per pixel moved (halved again -> 4x original speed)
local anim_active = false
local anim_from_x, anim_from_y = 0, 0
local anim_to_x, anim_to_y = 0, 0
local anim_total = 0
local anim_elapsed = 0
local anim_prev_x, anim_prev_y = 0, 0
local anim_pen_down = false
local anim_wait_co = nil
-- animation state for smooth rotation (turn)
local anim_turn_active = false
local anim_from_angle = 0
local anim_to_angle = 0
local anim_turn_total = 0
local anim_turn_elapsed = 0
local anim_prev_angle = 0

-- seconds per degree for rotation; default scales from seconds_per_pixel
local seconds_per_degree = seconds_per_pixel * 0.5

local function maybe_yield_for_anim()
    -- If running inside a coroutine, register it to be resumed when animations finish
    if coroutine.running() then
        if not anim_wait_co then
            anim_wait_co = coroutine.running()
            return coroutine.yield()
        else
            -- already someone waiting for animation; yield to let animation proceed
            return coroutine.yield()
        end
    end
end

function M.move(dist, dy)
    if not dist then return end
    local t = turtles[current]
    if dy then -- treat as vector
        local nx = t.x + dist
        local ny = t.y + dy
        local d = math.sqrt((nx - t.x) ^ 2 + (ny - t.y) ^ 2)
        if DEBUG then
            local in_co = (coroutine.running() ~= nil)
            print(string.format('[debug] move(vector) decision: animate_moves=%s anim_active=%s d=%.3f in_co=%s',
                tostring(animate_moves), tostring(anim_active), d, tostring(in_co)))
        end
        -- only animate if there's a non-zero distance to travel
        if animate_moves and not anim_active and d > 0 then
            anim_from_x, anim_from_y = t.x, t.y
            anim_to_x, anim_to_y = nx, ny
            anim_pen_down = t.down
            anim_prev_x, anim_prev_y = anim_from_x, anim_from_y
            anim_total = seconds_per_pixel * d
            anim_elapsed = 0
            anim_active = true
            if DEBUG then
                print(string.format('[debug] move (anim vector): to (%.1f, %.1f) down=%s dur=%.3f', nx, ny,
                    tostring(t.down), anim_total))
            end
            if coroutine.running() then
                anim_wait_co = coroutine.running()
                return coroutine.yield()
            end
            return
        end
        if t.down then pushSegment(t.x, t.y, nx, ny, t.color, t.size) end
        if DEBUG then print(string.format('[debug] move (vector): to (%.1f, %.1f) down=%s', nx, ny, tostring(t.down))) end
        t.x, t.y = nx, ny
        return
    end
    local draw_angle = (anim_turn_active and anim_prev_angle) or t.angle
    local rad = math.rad(draw_angle)
    local dx = dist * math.cos(rad)
    local dy2 = dist * math.sin(rad)
    local nx = t.x + dx
    local ny = t.y + dy2
    -- if animation is enabled and we're in Love2D main loop, animate the move
    local d = math.sqrt((nx - t.x) ^ 2 + (ny - t.y) ^ 2)
    if DEBUG then
        local in_co = (coroutine.running() ~= nil)
        print(string.format('[debug] move(scalar) decision: animate_moves=%s anim_active=%s d=%.3f in_co=%s',
            tostring(animate_moves), tostring(anim_active), d, tostring(in_co)))
    end
    if animate_moves and not anim_active and d > 0 then
        anim_from_x, anim_from_y = t.x, t.y
        anim_to_x, anim_to_y = nx, ny
        anim_pen_down = t.down
        anim_prev_x, anim_prev_y = anim_from_x, anim_from_y
        anim_total = seconds_per_pixel * d
        anim_elapsed = 0
        anim_active = true
        if DEBUG then
            print(string.format('[debug] move (anim): to (%.1f, %.1f) down=%s dur=%.3f', nx, ny,
                tostring(t.down), anim_total))
        end
        -- don't immediately set t.x/t.y; they'll be updated by _tick()
        -- if called inside a demo coroutine, suspend it until the animation completes
        if coroutine.running() then
            anim_wait_co = coroutine.running()
            return coroutine.yield()
        end
        return
    end
    if t.down then pushSegment(t.x, t.y, nx, ny, t.color, t.size) end
    if DEBUG then print(string.format('[debug] move: to (%.1f, %.1f) down=%s', nx, ny, tostring(t.down))) end
    t.x, t.y = nx, ny
end

function M.jump(dist)
    local t = turtles[current]
    t.down = false
    M.move(dist)
    t.down = true
end

-- turn is defined later; keep single definition

function M.pndn() turtles[current].down = true end

function M.pnup() turtles[current].down = false end

function M.pnsz(s)
    if s then turtles[current].size = s end
    return turtles[current].size
end

function M.show()
    showTurtles = true
end

function M.hide()
    showTurtles = false
end

function M.pncl(r, g, b, a)
    if not r then return turtles[current].color end
    local c
    if type(r) == 'table' then
        c = r
    elseif g and b then
        c = { r / 255, g / 255, b / 255, (a or 255) / 255 }
    else
        c = { r, g or 0, b or 0, a or 1 }
    end
    turtles[current].color = c
    return c
end

function M.turn(angle)
    if not angle or angle == 0 then return end
    local t = turtles[current]
    -- compute target angle and shortest signed delta
    local from = t.angle % 360
    local to = (from + angle) % 360
    -- compute signed shortest difference in range (-180,180]
    local raw = ((to - from + 540) % 360) - 180
    local delta = raw
    local d = math.abs(delta)
    if d == 0 then
        t.angle = to
        return
    end
    -- start rotation animation
    anim_from_angle = from
    anim_to_angle = to
    anim_prev_angle = anim_from_angle
    anim_turn_total = seconds_per_degree * d
    anim_turn_elapsed = 0
    anim_turn_active = true
    if DEBUG then print(string.format('[debug] turn (anim): to %.1f delta %.1f deg dur=%.3f', to, delta, anim_turn_total)) end
    -- if called in a coroutine, yield until rotation finishes (registered via helper)
    return maybe_yield_for_anim()
end

-- wait(seconds) will yield the demo coroutine if seconds provided, or
-- if nil it waits for mouse/key (signalled via resumeInput)
function M.wait(seconds)
    if not coroutine.running() then
        -- if not running in coroutine (e.g., interactive), just sleep
        if seconds then
            local t0 = love.timer.getTime()
            while love.timer.getTime() - t0 < seconds do end
        end
        return
    end

    wait_co = coroutine.running()
    if not seconds then
        -- wait for input: set timer to nil and yield
        wait_timer = nil
        return coroutine.yield()
    else
        wait_timer = seconds
        return coroutine.yield()
    end
end

-- signal resume from input or timer
function M._resumeInput()
    if wait_co then
        local co = wait_co
        wait_co = nil
        -- if input forces a resume while a timer was set, clear the timer too
        wait_timer = nil
        -- if an animation is running, snap it to the end and finish drawing
        if anim_active or anim_turn_active then
            -- finish move animation
            if anim_active then
                if anim_pen_down then
                    pushSegment(anim_prev_x, anim_prev_y, anim_to_x, anim_to_y, turtles[current].color,
                        turtles[current].size)
                end
                turtles[current].x = anim_to_x
                turtles[current].y = anim_to_y
                anim_active = false
            end
            -- finish rotation animation
            if anim_turn_active then
                turtles[current].angle = anim_to_angle % 360
                anim_turn_active = false
            end
            -- resume any coroutine that yielded waiting for animation
            if anim_wait_co then
                if coroutine.status(anim_wait_co) == 'suspended' then
                    local co2 = anim_wait_co
                    anim_wait_co = nil
                    local ok, err = coroutine.resume(co2)
                    if not ok then print('[error] demo coroutine error (anim resume input):', err) end
                else
                    anim_wait_co = nil
                end
            end
        end
        -- only attempt resume if coroutine is suspended
        if coroutine.status(co) ~= 'suspended' then
            return false
        end
        local ok, err = coroutine.resume(co)
        if not ok then
            print('[error] demo coroutine error (resume input):', err)
            if debug and debug.traceback then
                print(debug.traceback(co, err))
            end
        end
        return true
    end
    return false
end

function M._tick(dt)
    -- advance any active animation first
    if anim_active then
        anim_elapsed = anim_elapsed + dt
        local t = anim_total > 0 and math.min(1, anim_elapsed / anim_total) or 1
        local curx = anim_from_x + (anim_to_x - anim_from_x) * t
        local cury = anim_from_y + (anim_to_y - anim_from_y) * t
        if anim_pen_down then
            pushSegment(anim_prev_x, anim_prev_y, curx, cury, turtles[current].color, turtles[current].size)
        end
        anim_prev_x, anim_prev_y = curx, cury
        turtles[current].x, turtles[current].y = curx, cury
        if anim_elapsed >= anim_total then
            anim_active = false
            -- if rotation also finished, resume waiting coroutine; otherwise wait for rotation
            if not anim_turn_active and anim_wait_co then
                if coroutine.status(anim_wait_co) == 'suspended' then
                    local co = anim_wait_co
                    anim_wait_co = nil
                    local ok, err = coroutine.resume(co)
                    if not ok then print('[error] demo coroutine error (anim complete):', err) end
                else
                    anim_wait_co = nil
                end
            end
        end
    end

    -- advance rotation animation
    if anim_turn_active then
        anim_turn_elapsed = anim_turn_elapsed + dt
        local t2 = anim_turn_total > 0 and math.min(1, anim_turn_elapsed / anim_turn_total) or 1
        -- shortest signed delta
        local from = anim_from_angle
        local to = anim_to_angle
        local signed = ((to - from + 540) % 360) - 180
        local curang = from + signed * t2
        -- normalize
        curang = (curang % 360 + 360) % 360
        anim_prev_angle = curang
        turtles[current].angle = curang
        if anim_turn_elapsed >= anim_turn_total then
            anim_turn_active = false
            -- if move also finished, resume waiting coroutine
            if not anim_active and anim_wait_co then
                if coroutine.status(anim_wait_co) == 'suspended' then
                    local co = anim_wait_co
                    anim_wait_co = nil
                    local ok, err = coroutine.resume(co)
                    if not ok then print('[error] demo coroutine error (anim turn complete):', err) end
                else
                    anim_wait_co = nil
                end
            end
        end
    end

    if wait_timer then
        wait_timer = wait_timer - dt
        if wait_timer <= 0 and wait_co then
            local co = wait_co
            wait_co = nil
            wait_timer = nil
            local ok, err = coroutine.resume(co)
            if not ok then
                print('[error] demo coroutine error (timer):', err)
                if debug and debug.traceback then
                    print(debug.traceback(co, err))
                end
            end
        end
    end
end

function M.wipe()
    segments = {}
end

-- reset turtles and canvas: wipe segments and recreate initial turtle
function M.reset()
    segments = {}
    turtles = {}
    current = 1
    newTurtle()
    -- clear any pending wait targets so reset returns to a clean state
    wait_co = nil
    wait_timer = nil
    -- clear any animation wait state
    anim_active = false
    anim_wait_co = nil
    -- clear rotation animation state
    anim_turn_active = false
    anim_prev_angle = 0
end

function M.save(path)
    -- save current canvas as PNG using love.graphics.newCanvas
    local canvas = love.graphics.newCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(1, 1, 1, 1)
    for _, s in ipairs(segments) do
        love.graphics.setColor(s[5])
        love.graphics.setLineWidth(s[6])
        love.graphics.line(s[1], s[2], s[3], s[4])
    end
    love.graphics.setCanvas()
    local image = canvas:newImageData()
    image:encode('png', path .. '.png')
end

-- testing helpers
function M._getSegmentsCount()
    return #segments
end

function M._getTurtleState()
    local t = turtles[current]
    return { x = t.x, y = t.y, angle = t.angle, down = t.down, color = t.color, size = t.size }
end

-- expose wait state for debugging
function M._getWaitState()
    return { wait_co = (wait_co ~= nil), wait_timer = wait_timer, anim_wait = (anim_wait_co ~= nil) }
end

-- Animation controls
function M.setAnimation(enabled)
    animate_moves = not not enabled
end

-- Verbose logging controls (per-segment debug output)
function M.setVerboseLogging(v)
    VERBOSE = not not v
end

function M.getVerboseLogging()
    return VERBOSE
end

function M.getAnimation()
    return animate_moves
end

function M.setSecondsPerPixel(s)
    if type(s) == 'number' and s >= 0 then
        seconds_per_pixel = s
        -- keep rotation speed proportional to movement speed unless explicitly changed
        seconds_per_degree = seconds_per_pixel * 0.5
    end
end

function M.getSecondsPerPixel()
    return seconds_per_pixel
end

-- return random color table (r, g, b, a) with channels in 0..1
function M.ranc()
    local r = math.random(0, 255)
    local g = math.random(0, 255)
    local b = math.random(0, 255)
    return { r / 255, g / 255, b / 255, 1 }
end

-- convenience: set pen to random color
function M.pncl_ranc()
    local c = M.ranc()
    return M.pncl(c)
end

-- shape(fn): call fn() to draw a logical shape, then pause (wait for input) so
-- the UI step/resume will advance one shape at a time. If fn yields itself
-- (calls wait), we don't override that behavior.
function M.shape(fn)
    if type(fn) ~= 'function' then return end
    if not coroutine.running() then
        -- not running inside a coroutine (interactive), just draw
        fn()
        return
    end
    -- call the drawing function; if it yields (via wait) it will return later
    fn()
    -- if the function already yielded and set wait_co, don't override
    if wait_co then return end
    -- otherwise set current coroutine to wait for input and yield
    wait_co = coroutine.running()
    wait_timer = nil
    return coroutine.yield()
end

-- expose globals for compatibility
for k, v in pairs(M) do _G[k] = v end

-- also expose draw function for love main
function M.draw()
    love.graphics.push()
    -- compute bounding box of content (segments + turtle positions)
    local minx, miny = math.huge, math.huge
    local maxx, maxy = -math.huge, -math.huge
    for _, s in ipairs(segments) do
        local x1, y1, x2, y2 = s[1], s[2], s[3], s[4]
        minx = math.min(minx, x1, x2)
        miny = math.min(miny, y1, y2)
        maxx = math.max(maxx, x1, x2)
        maxy = math.max(maxy, y1, y2)
    end
    -- include all turtles' current positions
    for _, t in ipairs(turtles) do
        minx = math.min(minx, t.x)
        miny = math.min(miny, t.y)
        maxx = math.max(maxx, t.x)
        maxy = math.max(maxy, t.y)
    end

    -- fallback: if nothing drawn yet, center around origin
    if minx == math.huge then minx, miny, maxx, maxy = -1, -1, 1, 1 end

    local content_w = maxx - minx
    local content_h = maxy - miny
    if content_w <= 0 then content_w = 1 end
    if content_h <= 0 then content_h = 1 end

    local win_w, win_h = love.graphics.getDimensions()
    -- leave some padding (10% each side)
    local pad = 0.9
    local sx = (win_w * pad) / content_w
    local sy = (win_h * pad) / content_h
    -- scale to fit window with padding; allow upscaling for small content
    local scale = math.min(sx, sy)

    -- translate to screen center, scale, then translate content center to origin
    local cx = (minx + maxx) / 2
    local cy = (miny + maxy) / 2
    love.graphics.translate(win_w / 2, win_h / 2)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-cx, -cy)

    -- draw segments
    for _, s in ipairs(segments) do
        love.graphics.setColor(s[5])
        love.graphics.setLineWidth(s[6])
        love.graphics.line(s[1], s[2], s[3], s[4])
    end

    -- draw turtle as triangle (use animated pos when animating)
    local t = turtles[current]
    local draw_x = anim_active and anim_prev_x or t.x
    local draw_y = anim_active and anim_prev_y or t.y
    love.graphics.setColor(0, 0, 0)
    local rad = math.rad(t.angle)
    local dist = 10
    local x1 = draw_x + dist * math.cos(rad)
    local y1 = draw_y + dist * math.sin(rad)
    local x2 = draw_x + dist * math.cos(rad + 2 * math.pi / 3)
    local y2 = draw_y + dist * math.sin(rad + 2 * math.pi / 3)
    local x3 = draw_x + dist * math.cos(rad - 2 * math.pi / 3)
    local y3 = draw_y + dist * math.sin(rad - 2 * math.pi / 3)
    love.graphics.polygon('line', x1, y1, x2, y2, x3, y3)
    love.graphics.pop()
    -- debug overlay in screen space
    if DEBUG then
        local win_w, win_h = love.graphics.getDimensions()
        love.graphics.setColor(0, 0, 0)
        local segs = #segments
        -- always-on animated marker: big yellow dot/triangle at current animated position
        if DEBUG and (anim_active or anim_wait_co) then
            local win_w, win_h = love.graphics.getDimensions()
            local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
            for _, s in ipairs(segments) do
                minx = math.min(minx, s[1], s[3])
                miny = math.min(miny, s[2], s[4])
                maxx = math.max(maxx, s[1], s[3])
                maxy = math.max(maxy, s[2], s[4])
            end
            for _, tt in ipairs(turtles) do
                minx = math.min(minx, tt.x)
                miny = math.min(miny, tt.y)
                maxx = math.max(maxx, tt.x)
                maxy = math.max(maxy, tt.y)
            end
            if minx == math.huge then minx, miny, maxx, maxy = -1, -1, 1, 1 end
            local content_w = maxx - minx
            local content_h = maxy - miny
            if content_w <= 0 then content_w = 1 end
            if content_h <= 0 then content_h = 1 end
            local pad = 0.9
            local sx = (win_w * pad) / content_w
            local sy = (win_h * pad) / content_h
            local scale = math.min(sx, sy)
            local cx = (minx + maxx) / 2
            local cy = (miny + maxy) / 2
            -- compute animated position (use anim_prev if active, otherwise turtle coords)
            local ax = anim_active and anim_prev_x or turtles[current].x
            local ay = anim_active and anim_prev_y or turtles[current].y
            local sxp = win_w / 2 + (ax - cx) * scale
            local syp = win_h / 2 + (ay - cy) * scale
            love.graphics.push()
            love.graphics.setColor(1, 0.85, 0, 1)
            love.graphics.circle('fill', sxp, syp, 12)
            -- draw a simple filled triangle pointing in turtle angle for clarity
            local ang = math.rad(turtles[current].angle)
            local dist = 18
            local x1 = sxp + dist * math.cos(ang)
            local y1 = syp + dist * math.sin(ang)
            local x2 = sxp + dist * math.cos(ang + 2 * math.pi / 3)
            local y2 = syp + dist * math.sin(ang + 2 * math.pi / 3)
            local x3 = sxp + dist * math.cos(ang - 2 * math.pi / 3)
            local y3 = syp + dist * math.sin(ang - 2 * math.pi / 3)
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.polygon('fill', x1, y1, x2, y2, x3, y3)
            love.graphics.pop()
        end
        local ws = M._getWaitState()
        local lines = {
            string.format('segments: %d', segs),
            string.format('anim_active: %s', tostring(anim_active)),
            string.format('anim_wait: %s', tostring(ws.anim_wait)),
            string.format('wait_timer: %s', tostring(ws.wait_timer)),
        }
        for i, l in ipairs(lines) do
            love.graphics.print(l, 8, 80 + (i - 1) * 14)
        end

        -- draw content center cross (should map to screen center)
        love.graphics.setColor(1, 0, 0)
        love.graphics.setLineWidth(2)
        love.graphics.line(win_w / 2 - 10, win_h / 2, win_w / 2 + 10, win_h / 2)
        love.graphics.line(win_w / 2, win_h / 2 - 10, win_w / 2, win_h / 2 + 10)

        -- stronger debug rendering: draw transformed segments and filled turtle
        if DEBUG then
            local win_w, win_h = love.graphics.getDimensions()
            -- recompute content bbox/scale (same math as above)
            local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
            for _, s in ipairs(segments) do
                minx = math.min(minx, s[1], s[3])
                miny = math.min(miny, s[2], s[4])
                maxx = math.max(maxx, s[1], s[3])
                maxy = math.max(maxy, s[2], s[4])
            end
            for _, tt in ipairs(turtles) do
                minx = math.min(minx, tt.x)
                miny = math.min(miny, tt.y)
                maxx = math.max(maxx, tt.x)
                maxy = math.max(maxy, tt.y)
            end
            if minx == math.huge then minx, miny, maxx, maxy = -1, -1, 1, 1 end
            local content_w = maxx - minx
            local content_h = maxy - miny
            if content_w <= 0 then content_w = 1 end
            if content_h <= 0 then content_h = 1 end
            local pad = 0.9
            local sx = (win_w * pad) / content_w
            local sy = (win_h * pad) / content_h
            local scale = math.min(sx, sy)
            local cx = (minx + maxx) / 2
            local cy = (miny + maxy) / 2

            -- draw transformed segments in bright red, thicker
            love.graphics.push()
            love.graphics.setColor(1, 0, 0, 0.85)
            love.graphics.setLineWidth(3)
            for _, s in ipairs(segments) do
                local x1 = win_w / 2 + (s[1] - cx) * scale
                local y1 = win_h / 2 + (s[2] - cy) * scale
                local x2 = win_w / 2 + (s[3] - cx) * scale
                local y2 = win_h / 2 + (s[4] - cy) * scale
                love.graphics.line(x1, y1, x2, y2)
            end
            -- draw filled turtle marker in distinct color
            local t = turtles[current]
            local tx = win_w / 2 + (t.x - cx) * scale
            local ty = win_h / 2 + (t.y - cy) * scale
            love.graphics.setColor(0, 0.6, 1, 1)
            love.graphics.circle('fill', tx, ty, 8)
            love.graphics.pop()
        end
        local t = turtles[current]
        -- compute screen-space coords using same transform as above
        local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
        for _, s in ipairs(segments) do
            minx = math.min(minx, s[1], s[3])
            miny = math.min(miny, s[2], s[4])
            maxx = math.max(maxx, s[1], s[3])
            maxy = math.max(maxy, s[2], s[4])
        end
        for _, tt in ipairs(turtles) do
            minx = math.min(minx, tt.x)
            miny = math.min(miny, tt.y)
            maxx = math.max(maxx, tt.x)
            maxy = math.max(maxy, tt.y)
        end
        if minx == math.huge then minx, miny, maxx, maxy = -1, -1, 1, 1 end
        local content_w = maxx - minx
        local content_h = maxy - miny
        if content_w <= 0 then content_w = 1 end
        if content_h <= 0 then content_h = 1 end
        local pad = 0.9
        local sx = (win_w * pad) / content_w
        local sy = (win_h * pad) / content_h
        local scale = math.min(sx, sy)
        local cx = (minx + maxx) / 2
        local cy = (miny + maxy) / 2
        local screen_tx = win_w / 2 + (t.x - cx) * scale
        local screen_ty = win_h / 2 + (t.y - cy) * scale
        love.graphics.setColor(0, 1, 0)
        love.graphics.circle('fill', screen_tx, screen_ty, 6)

        -- also draw animation preview points
        if anim_active then
            local from_sx = win_w / 2 + (anim_from_x - cx) * scale
            local from_sy = win_h / 2 + (anim_from_y - cy) * scale
            local to_sx = win_w / 2 + (anim_to_x - cx) * scale
            local to_sy = win_h / 2 + (anim_to_y - cy) * scale
            love.graphics.setColor(0, 0, 1)
            love.graphics.circle('line', from_sx, from_sy, 6)
            love.graphics.circle('line', to_sx, to_sy, 6)
            love.graphics.setColor(0, 0, 1, 0.6)
            love.graphics.line(from_sx, from_sy, to_sx, to_sy)
        end
    end
end

return M
