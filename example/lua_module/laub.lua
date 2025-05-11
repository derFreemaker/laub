local module = laub.action({
    name = "lua module"
})

module.steps.build:async_on(function()
    print("building module")
end)

local native_tests = laub.action({
    name = "native tests"
})
native_tests:after(module)
native_tests.steps.test:async_on(function()
    laub.execute()
end)

local lua_tests = laub.action({
    name = "lua tests"
})
native_tests:after(module)

lua_tests.steps.test:async_on(function()
    print("running lua tests")
end)
