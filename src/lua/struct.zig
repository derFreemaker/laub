const zlua = @import("zlua");
const utils = @import("utils.zig");

pub const LuaStructMetatable = struct {
    
};

pub const LuaStruct = struct {
    ptr: *anyopaque,
    type_name: [:0]const u8,
    
    pub fn init(lua: *zlua.Lua, comptime T: type, data: *T) LuaStruct {
        lua.newUserdata(LuaStruct, 0);
        
        return .{
            .ptr = data,
            .type_name = @typeName(T),
        };
    }
};
