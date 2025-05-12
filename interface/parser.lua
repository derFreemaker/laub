---@meta _

---@class laub.parser.option
---@field name string
---@field description string?
---@field default any?
---@field optional boolean?
---@field placeholder string? is irgnored for non value options and only displayed on help

---@class laub.parser.option_with_short : laub.parser.option
---@field short string?

---@class laub.parser.option.select : laub.parser.option_with_short
---@field values string[]

---@class laub.parser.option.positional : laub.parser.option
---@field index integer

---@class laub.parser.parsed_options
---@field [string] string | boolean

---@class laub.parser
local _parser = {}

---@param option laub.parser.option_with_short
function _parser.option(option)
end

---@param option laub.parser.option_with_short
function _parser.select(option)
end

--- A flag is a option which can only be false or true
---@param option laub.parser.option_with_short
function _parser.flag(option)
end

---@param option laub.parser.option.positional
function _parser.positional(option)
end

---@param func fun(laub.parser.parsed_options) : nil
function _parser.parse(func)
end

laub_parser = _parser
