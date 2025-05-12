---@meta _

---@class laub.step
local step = {}

---@param func function
function step:on(func)
end

---@param name string
---@param func function
function step:before(name, func)
end

---@param name string
---@param func function
function step:after(name, func)
end

---@param func function
function step:async_on(func)
end

---@param name string
---@param func function
function step:async_before(name, func)
end

---@param name string
---@param func function
function step:async_after(name, func)
end

---@class laub.steps
---@field [string] laub.step
local steps = {}
