local module = laub.action({
    name = "lua module",
})
module().build:async_on(function()
    print("building module")
end)

local native_tests = laub.action({
    name = "native tests",
    after = { module }
})
native_tests().test:async_on(function()
    laub.execute("asd")
end)

local lua_tests = laub.action({
    name = "lua tests",
    after = { module },
})
lua_tests().test:async_on(function()
    print("running lua tests")
end)
