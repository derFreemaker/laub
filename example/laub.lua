local foo_action = laub.action({
    name = "foo",
})

local example_action = laub.action({
    name = "example",
})

example_action.steps.build:on(function()
    print("executing build command")
end)

-- no realation to foo_action other than it needs to be done before example_action
example_action:after(foo_action)

-- samething just reversed
example_action:before(foo_action) -- -> foo_action:after(example_action)

example_action.steps.build:before("before example", function()
    print("doing somehting before building " .. example_action.name)
end)

example_action.steps.build:after("after example", function()
    print("doing somehting after " .. example_action.name .. " has been built")
end)
