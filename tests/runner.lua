-- Minimal busted-compatible test runner for headless Love2D mode.
-- Provides describe / it / assert globals, then requires all test files passed in.

local results = { pass = 0, fail = 0, errors = {} }
local _current_suite = ""

function describe(name, fn)
    _current_suite = name
    fn()
    _current_suite = ""
end

function it(name, fn)
    local label = _current_suite ~= "" and (_current_suite .. " > " .. name) or name
    local ok, err = pcall(fn)
    if ok then
        results.pass = results.pass + 1
        print("  PASS  " .. label)
    else
        results.fail = results.fail + 1
        table.insert(results.errors, { label = label, msg = tostring(err) })
        print("  FAIL  " .. label)
        print("        " .. tostring(err))
    end
end

local _native_assert = assert
assert = setmetatable({
    are     = {},
    are_not = {},
    is      = {},
    is_not  = {},
}, {
    __call  = function(_, v, msg) return _native_assert(v, msg) end,
    __index = function(_, k) error("assert." .. k .. " not found", 2) end,
})

function assert.are.equal(expected, actual, msg)
    if expected ~= actual then
        error((msg or "expected " .. tostring(expected) .. " but got " .. tostring(actual)), 2)
    end
end

function assert.are_not.equal(unexpected, actual, msg)
    if unexpected == actual then
        error((msg or "expected value to differ from " .. tostring(unexpected)), 2)
    end
end

function assert.is_true(v, msg)
    if v ~= true then
        error((msg or "expected true but got " .. tostring(v)), 2)
    end
end

function assert.is_false(v, msg)
    if v ~= false then
        error((msg or "expected false but got " .. tostring(v)), 2)
    end
end

function assert.is_nil(v, msg)
    if v ~= nil then
        error((msg or "expected nil but got " .. tostring(v)), 2)
    end
end

function assert.is_not_nil(v, msg)
    if v == nil then
        error(msg or "expected non-nil value", 2)
    end
end

-- Run a list of test module paths synchronously (headless mode).
local function run(test_files)
    print("\n=== NIGHTFALL headless tests ===\n")
    for _, path in ipairs(test_files) do
        print("-- " .. path)
        local ok, err = pcall(require, path)
        if not ok then
            results.fail = results.fail + 1
            table.insert(results.errors, { label = path .. " (load)", msg = tostring(err) })
            print("  ERROR loading file: " .. tostring(err))
        end
    end

    print(string.format("\n%d passed, %d failed\n", results.pass, results.fail))

    os.exit(results.fail > 0 and 1 or 0)
end

-- Collect tests as {name, fn} pairs without running them (watch mode).
local function collect(test_files)
    local tests  = {}
    local _suite = ""

    local orig_describe = describe
    local orig_it       = it

    function describe(name, fn)
        _suite = name
        fn()
        _suite = ""
    end

    function it(name, fn)
        local label = _suite ~= "" and (_suite .. " > " .. name) or name
        table.insert(tests, { name = label, fn = fn })
    end

    for _, path in ipairs(test_files) do
        local ok, err = pcall(require, path)
        if not ok then
            local msg = tostring(err)
            table.insert(tests, { name = path .. " (load error)", fn = function() error(msg) end })
        end
    end

    describe = orig_describe
    it       = orig_it

    return tests
end

return { run = run, collect = collect }
