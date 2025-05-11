---@meta _

---@class laub.action.options
---@field name string

---@class laub.action
---@field name string
---
---@field steps laub.steps
local _action = {}

---@param action laub.action
function _action:before(action)
    action:after(self)
end

---@param action laub.action
function _action:after(action)
end
