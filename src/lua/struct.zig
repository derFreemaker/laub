const utils = @import("utils.zig");

pub const LuaStruct = struct {
    ptr: *anyopaque,
    type_name: [:0]const u8,
};
