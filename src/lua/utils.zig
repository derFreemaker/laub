const std = @import("std");
const zlua = @import("zlua");

const utils = @This();

pub const LuaFunc = fn (lua: *zlua.Lua) i32;

pub fn DefaultLuaStructIndex(comptime T: type) zlua.CFn {
    return zlua.wrap(struct {
        pub fn indexFn(lua: *zlua.Lua) i32 {
            const struct_ptr = lua.checkUserdata(*T, 1, @typeName(T));

            const field_name = lua.toString(2) catch {
                lua.pushNil();
                return 1;
            };

            const type_info = @typeInfo(T);
            inline for (type_info.@"struct".fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    try utils.push(lua, @field(struct_ptr.*.*, field.name));
                    return 1;
                }
            }

            inline for (@typeInfo(T).@"struct".decls) |decl| {
                const field = @field(T, decl.name);
                if (@TypeOf(field) == LuaFunc) {
                    lua.pushFunction(zlua.wrap(field));
                } else if (@TypeOf(field) == zlua.CFn) {
                    lua.pushFunction(field);
                } else {
                    break;
                    // try utils.push(lua, field);
                }

                return 1;
            }

            lua.pushNil();
            return 1;
        }
    }.indexFn);
}

fn isLuaStruct(lua: *zlua.Lua, comptime T: type, index: i32) bool {
    _ = lua.testUserdata(T, index, @typeName(T)) catch return false;
    return true;
}

fn getLuaStruct(lua: *zlua.Lua, comptime T: type, index: i32) !*T {
    if (!isLuaStruct(lua, T, index)) {
        return error.TypeMissmatch;
    }

    return lua.toUserdata(T, index) catch unreachable;
}

fn pushLuaStruct(lua: *zlua.Lua, comptime T: type, data: *T) !void {
    const userdata = lua.newUserdata(*T, 0);
    userdata.* = data;

    if (lua.getMetatableRegistry(@typeName(T)) == .nil) {
        lua.pop(1);

        try lua.newMetatable(@typeName(T));

        {
            lua.pushFunction(DefaultLuaStructIndex(T));
            lua.setField(-2, "__index");
        }
    }

    lua.setMetatable(-2);
}

pub fn is(lua: *zlua.Lua, comptime T: type, index: i32) bool {
    switch (@typeInfo(T)) {
        .int, .comptime_int => {
            return lua.isInteger(index);
        },
        .float, .comptime_float => {
            return lua.isNumber(index);
        },
        .bool => {
            return lua.isBoolean(index);
        },
        .pointer => |ptr_info| {
            if (ptr_info.size == .slice and ptr_info.child == u8) {
                return lua.isString(index);
            } else if (isLuaStruct(lua, ptr_info.child, index)) {
                return true;
            } else {
                return lua.isLightUserdata(index);
            }
        },
        .optional => |opt| {
            if (lua.isNil(index)) {
                return true;
            }
            return is(lua, opt.child, index);
        },
        else => {},
    }

    return false;
}

pub fn get(lua: *zlua.Lua, comptime T: type, index: i32) !T {
    if (!is(lua, T, index)) {
        return error.TypeMismatch;
    }

    switch (@typeInfo(T)) {
        .int, .comptime_int => {
            return @intCast(lua.toInteger(index) catch unreachable);
        },
        .float, .comptime_float => {
            return @floatCast(lua.toNumber(index) catch unreachable);
        },
        .bool => {
            return lua.toBoolean(index);
        },
        .pointer => |ptr_info| {
            if (ptr_info.size == .slice and ptr_info.child == u8) {
                return lua.toString(index) catch unreachable;
            }
            if (isLuaStruct(lua, ptr_info.child, index)) {
                return getLuaStruct(lua, ptr_info.child, index);
            }
            if (ptr_info.size == .one) {
                return lua.toUserdata(ptr_info.child, index);
            }
        },
        .optional => |opt| {
            if (lua.isNil(index)) {
                return null;
            }
            return get(lua, opt.child, index);
        },
        else => {},
    }

    // when we encounter this error means that is(...) and get(...) are out of sync
    return error.UnsupportedType;
}

pub fn push(lua: *zlua.Lua, value: anytype) !void {
    const T = @TypeOf(value);

    switch (@typeInfo(T)) {
        .int, .comptime_int => {
            lua.pushInteger(@intCast(value));
            return;
        },
        .float, .comptime_float => {
            lua.pushNumber(value);
            return;
        },
        .bool => {
            lua.pushBoolean(value);
            return;
        },
        .pointer => |ptr_info| {
            if (ptr_info.size == .one and @typeInfo(ptr_info.child) == .array and @typeInfo(ptr_info.child).array.child == u8) {
                _ = lua.pushString(value);
                return;
            } else if (ptr_info.size == .one) {
                if (@typeInfo(ptr_info.child) == .@"struct") {
                    try pushLuaStruct(lua, ptr_info.child, value);
                    return;
                }

                lua.pushLightUserdata(value);
                return;
            }

            @compileError("unsupported pointer: " ++ @typeName(T));
        },
        .optional => {
            if (value) |v| {
                push(lua, v);
                return;
            } else {
                lua.pushNil();
                return;
            }
        },
        else => {},
    }

    return error.UnsupportedValue;
}

pub fn print(writer: anytype, value: anytype) !void {
    const T = @TypeOf(value);

    switch (@typeInfo(T)) {
        .int, .comptime_int => {
            try writer.print("{}", .{value});
        },
        .float, .comptime_float => {
            try writer.print("{d}", .{value});
        },
        .bool => {
            try writer.print("{}", .{value});
        },
        .pointer => |ptr_info| {
            if (ptr_info.size == .slice and ptr_info.child == u8) {
                try writer.print("\"{s}\"", .{value});
            } else {
                try writer.print("*{s}", .{@typeName(ptr_info.child)});
            }
        },
        .optional => {
            if (value) |v| {
                try print(writer, v);
            } else {
                try writer.print("null", .{});
            }
        },
        .@"struct" => {
            try writer.print("{s}{{...}}", .{@typeName(T)});
        },
        else => {},
    }

    return error.UnsupportedType;
}
