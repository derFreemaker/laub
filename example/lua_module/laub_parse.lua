-- laub_parser.flag({
--     name = "lol",
--     short = "l",
--     description = "lol desc",
-- })
-- 
-- laub_parser.option({
--     name = "test",
--     short = "t",
--     description = "test desc",
--     placeholder = "test placeholder",
--     default = "laub",
-- })
-- 
-- laub_parser.parse(function(args)
--     for index, value in ipairs(args) do
--         print(index, value)
--     end
-- end)

local test = laub_parser:command("test")
test:option({ name = "opt" })