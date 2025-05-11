-- ---@meta

-- ---@class laub.option
-- ---@field name string
-- ---@field description string?
-- ---@field default any?
-- ---@field optional boolean?
-- ---@field placeholder string? is irgnored for non value options and only displayed on help

-- ---@class laub.option_with_short : laub.option
-- ---@field short string?

-- ---@class laub.option.select : laub.option_with_short
-- ---@field values string[]

-- ---@class laub.option.positional : laub.option
-- ---@field index integer

-- ---@class laub.options
-- local options = {}

-- ---@param option laub.option_with_short
-- function options.option(option)
-- end

-- ---@param option laub.option_with_short
-- function options.select(option)
-- end

-- --- A flag is a option which can only be false or true
-- ---@param option laub.option_with_short
-- function options.flag(option)
-- end

-- --- A flag is a option which can only be false or true
-- ---@param option laub.option.positional
-- function options.positional(option)
-- end

-- ---@class laub.command.options
-- ---@field [string] string | boolean
