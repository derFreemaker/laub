const std = @import("std");
const zlua = @import("zlua");

fn structIndex(comptime T: type) zlua.CFn {
    return zlua.wrap(struct {
        fn indexFn(lua: *zlua.Lua) i32 {
            const ptr_wrapper = lua.checkUserdata(LuaAccessableStruct, 1, @typeName(T));

            const struct_ptr = @as(*T, @alignCast(@ptrCast(ptr_wrapper.ptr)));
            const field_name = lua.toString(2) catch return 0;

            const type_info = @typeInfo(T);
            inline for (type_info.@"struct".fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    try pushValue(lua, @field(struct_ptr.*, field.name));
                    return 1;
                }
            }

            // field not found
            return 0;
        }
    }.indexFn);
}

fn structNewIndex(comptime T: type) zlua.CFn {
    return zlua.wrap(struct {
        fn newIndexFn(lua: *zlua.Lua) i32 {
            const ptr_wrapper = lua.checkUserdata(LuaAccessableStruct, 1, @typeName(T));

            const struct_ptr = @as(*T, @alignCast(@ptrCast(ptr_wrapper.ptr)));
            const field_name = lua.checkString(2);

            const type_info = @typeInfo(T);
            inline for (type_info.@"struct".fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    if (getValue(field.type, lua, 3)) |value| {
                        @field(struct_ptr.*, field.name) = value;
                    }
                    return 0;
                }
            }

            // field not found
            return 0;
        }
    }.newIndexFn);
}

fn structToString(comptime T: type) zlua.CFn {
    return zlua.wrap(struct {
        fn toStringFn(lua: *zlua.Lua) i32 {
            const ptr_wrapper = lua.checkUserdata(LuaAccessableStruct, 1, @typeName(LuaAccessableStruct));

            const struct_ptr = @as(*T, @alignCast(@ptrCast(ptr_wrapper.ptr)));

            // Create a string representation
            var buf: [1024]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&buf);
            const writer = fbs.writer();

            writer.print("{s} {{", .{@typeName(T)}) catch return 0;

            const type_info = @typeInfo(T);
            inline for (type_info.@"struct".fields, 0..) |field, i| {
                if (i > 0) {
                    writer.print(", ", .{}) catch return 0;
                }
                writer.print("{s}: ", .{field.name}) catch return 0;

                // Print field value based on its type
                printValue(writer, field.type, @field(struct_ptr.*, field.name)) catch return 0;
            }

            writer.print("}}", .{}) catch return 0;

            // Push the resulting string
            _ = lua.pushString(buf[0..fbs.pos]);
            return 1;
        }
    }.toStringFn);
}

fn structGC(comptime T: type) zlua.CFn {
    return zlua.wrap(struct {
        fn structGCFn(lua: *zlua.Lua) i32 {
            const ptr_wrapper = lua.checkUserdata(LuaAccessableStruct, 1, @typeName(LuaAccessableStruct));
            if (ptr_wrapper.owned) {
                ptr_wrapper.allocator.?.destroy(@as(*T, @alignCast(@ptrCast(ptr_wrapper.ptr))));
            }
            return 0;
        }
    }.structGCFn);
}

pub const LuaAccessableStruct = struct {
    ptr: *anyopaque,
    type_name: [:0]const u8,

    /// Flag to indicate if the struct should be freed on garbage collection from lua
    owned: bool,
    allocator: ?*std.mem.Allocator,

    pub fn init(lua: *zlua.Lua, comptime T: type, data: *T) !void {
        const userdata = lua.newUserdata(LuaAccessableStruct, 0);

        userdata.* = LuaAccessableStruct{
            .ptr = @ptrCast(data),
            .type_name = @typeName(T),
            .owned = false,
            .allocator = null,
        };

        if (lua.getMetatableRegistry(@typeName(T)) == .nil) {
            lua.pop(1);
            try lua.newMetatable(@typeName(T));

            lua.pushFunction(structIndex(T));
            lua.setField(-2, "__index");

            lua.pushFunction(structNewIndex(T));
            lua.setField(-2, "__newindex");

            lua.pushFunction(structToString(T));
            lua.setField(-2, "__tostring");

            lua.pushFunction(structGC(T));
            lua.setField(-2, "__gc");

            // If a metatable name is provided, set the metable for the userdata
            lua.setMetatableRegistry(@typeName(T));
        }

        lua.setMetatable(-2);
    }

    pub fn init_owned(comptime T: type, lua: *zlua.Lua, data: *T, allocator: *std.mem.Allocator) !void {
        const userdata = lua.newUserdata(LuaAccessableStruct);

        userdata.* = LuaAccessableStruct{
            .ptr = @ptrCast(data),
            .type_name = @typeName(T),
            .owned = true,
            .allocator = allocator,
        };

        if (lua.getMetatableRegistry(@typeName(T)) == .nil) {
            lua.newTable();

            try lua.pushFunction(zlua.wrap(structGC));
            lua.setField(-2, "__gc");

            try lua.pushFunction(zlua.wrap(structGC));
            lua.setField(-2, "__gc");

            // If a metatable name is provided, set the metable for the userdata
            lua.setMetatableRegistry(@typeName(T));
        }
    }
};

pub fn pushValue(lua: *zlua.Lua, value: anytype) !void {
    const T = @TypeOf(value);

    switch (@typeInfo(T)) {
        .int => lua.pushInteger(@intCast(value)),
        .float => lua.pushNumber(value),
        .bool => lua.pushBoolean(value),
        .pointer => |ptr_info| {
            if (ptr_info.size == .Slice and ptr_info.child == u8) {
                // String slice
                lua.pushString(value);
            } else if (ptr_info.size == .One) {
                // Handle pointers to other types
                // This is simplified - in a real implementation you'd want to handle more cases
                LuaAccessableStruct.init(@TypeOf(value.*), &lua, value) catch {
                    lua.pushNil();
                };
            } else {
                lua.pushNil();
            }
        },
        .optional => {
            if (value) |v| {
                pushValue(lua, v);
            } else {
                lua.pushNil();
            }
        },
        else => return error.UnsupportedValue,
    }
}

pub fn getValue(comptime T: type, lua: *zlua.Lua, index: i32) !?T {
    switch (@typeInfo(T)) {
        .int => {
            if (lua.isInteger(index)) {
                return @intCast(lua.toInteger(index) catch {
                    
                });
            }
        },
        .float => {
            if (lua.isNumber(index)) {
                return @floatCast(try lua.toNumber(index));
            }
        },
        .bool => {
            return lua.toBoolean(index);
        },
        .pointer => {
            return lua.toUserdata(T, index);
        },
        .optional => |opt| {
            if (lua.isNil(index)) {
                return null;
            } else {
                return getValue(opt.child, lua, index);
            }
        },
        .@"struct" => {
            if (lua.isUserdata(index)) {
                if (lua.toUserdata(LuaAccessableStruct, index)) |ptr_wrapper| {
                    if (std.mem.eql(u8, ptr_wrapper.type_name, @typeName(T))) {
                        return @as(*T, @ptrCast(@alignCast(ptr_wrapper.ptr))).*;
                    }
                } else |_| {
                    return lua.toUserdata(T, index) catch return null;
                }
            }
        },
        else => {},
    }

    return null;
}

fn printValue(writer: anytype, comptime T: type, value: T) !void {
    switch (@typeInfo(T)) {
        .int => try writer.print("{}", .{value}),
        .float => try writer.print("{d}", .{value}),
        .bool => try writer.print("{}", .{value}),
        .pointer => |ptr_info| {
            if (ptr_info.size == .Slice and ptr_info.child == u8) {
                try writer.print("\"{s}\"", .{value});
            } else {
                try writer.print("*{s}", .{@typeName(ptr_info.child)});
            }
        },
        .optional => {
            if (value) |v| {
                try printValue(writer, @TypeOf(v), v);
            } else {
                try writer.print("null", .{});
            }
        },
        .@"struct" => try writer.print("{s}{{...}}", .{@typeName(T)}),
        else => try writer.print("?", .{}),
    }
}
