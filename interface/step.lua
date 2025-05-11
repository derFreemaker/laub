---@meta _

---@class laub.step
local step = {}

---@param func function
function step:on(func)
end

---@param desc string
---@param func function
function step:before(desc, func)
end

---@param desc string
---@param func function
function step:after(desc, func)
end

---@param func function
function step:async_on(func)
end

---@param desc string
---@param func function
function step:async_before(desc, func)
end

---@param desc string
---@param func function
function step:async_after(desc, func)
end

---@class laub.steps
---@field [string] laub.step
local steps = {}
