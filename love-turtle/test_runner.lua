-- Test runner to validate turtle logic without Love2D
local turtle = require('turtle') -- load module so require() inside demo.lua returns same instance
-- load demo as a chunk
local demoChunk, err = loadfile('demo.lua')
if not demoChunk then
    print('Failed to load demo.lua:', err)
    os.exit(1)
end

-- run demo in coroutine to exercise wait behavior
local co = coroutine.create(function()
    -- demo.lua expects globals like move, turn, etc. They were set by turtle.lua
    return demoChunk()
end)

local ok, res = coroutine.resume(co)
if not ok then
    print('Demo error:', res)
    os.exit(1)
end

-- after initial resume, coroutine likely yielded on wait(); simulate resume
if coroutine.status(co) == 'suspended' then
    print('Coroutine yielded on wait(); resuming (simulated input)')
    -- call the module helper to resume (turtle.wait yields and stores co), but in this test environment
    -- turtle.lua stores wait_co as coroutine.running() when called by the demo. We need to trigger resume.
    -- The simplest approach: call turtle._resumeInput() which resumes the stored coroutine.
    turtle._resumeInput()
end

-- if coroutine resumed and finished, check segments
if coroutine.status(co) ~= 'dead' then
    -- resume until dead
    while coroutine.status(co) ~= 'dead' do
        local ok, err
        if coroutine.status(co) == 'suspended' then
            ok, err = coroutine.resume(co)
        end
        if ok == false then
            print('Error resuming coroutine:', err); break
        end
        -- if we couldn't resume because coroutine not suspended, break to avoid infinite loop
        if coroutine.status(co) ~= 'suspended' and coroutine.status(co) ~= 'dead' then break end
    end
end

local segs = turtle._getSegmentsCount()
print('Segments drawn:', segs)
if segs > 0 then
    print('Basic functional test PASSED')
    os.exit(0)
else
    print('Basic functional test FAILED: no segments drawn')
    os.exit(2)
end
