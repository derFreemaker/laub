const std = @import("std");
const zlua = @import("zlua");

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
        },
        .optional => |opt| {
            if (lua.isNil(index)) {
                return null;
            }
            return get(lua, opt.child, index);
        },
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
    }

    return error.UnsupportedType;
}
