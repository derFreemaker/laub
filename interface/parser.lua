---@meta _

---@class laub.parser.command.option
---@field name string
---@field description string?
---@field default any?
---@field optional boolean?
---@field placeholder string? is irgnored for non value options and only displayed on help

---@class laub.parser.command.option_with_short : laub.parser.command.option
---@field short string?

---@class laub.parser.command.option.select : laub.parser.command.option_with_short
---@field values string[]

---@class laub.parser.command.option.positional : laub.parser.command.option
---@field index integer

---@class laub.parser.command
---@field name string
---@field description string?
local _command = {}

---@param options laub.parser.command.option_with_short
function _command.option(options)
end

---@param options laub.parser.command.option_with_short
function _command.select(options)
end

--- A flag is a option which can only be false or true
---@param option laub.parser.command.option_with_short
function _command.flag(option)
end

---@param option laub.parser.command.option.positional
function _command.positional(option)
end

---@class laub.parser.parsed_options
---@field [string] string | string[] | boolean | nil

---@class laub.parser
local _parser = {}

---@param name string
---@param description string?
---@return laub.parser.command
function _parser.command(name, description)
end

---@param func fun(options: laub.parser.parsed_options) : nil
function _parser.parse(func)
end

laub_parser = _parser
