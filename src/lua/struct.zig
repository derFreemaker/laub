const std = @import("std");
const zlua = @import("zlua");

const utils = @import("utils.zig");

pub const LuaStruct = struct {
    ptr: *anyopaque,
    type_name: [:0]const u8,

    pub fn push(lua: *zlua.Lua, comptime T: type, data: *T) LuaStruct {
        lua.newUserdata(LuaStruct, 0);
        
        if (lua.getMetatableRegistry(@typeName(T)) == .nil) {
                    }
    }
};
