const std = @import("std");
const zlua = @import("zlua");

const utils = @This();

pub const LuaFunc = fn (lua: *zlua.Lua) i32;

pub fn DefaultLuaStructIndex(comptime T: type) zlua.CFn {
    return zlua.wrap(struct {
        pub fn indexFn(lua: *zlua.Lua) i32 {
            const struct_ptr = check(lua, T, 1);

            const field_name = lua.toString(2) catch {
                lua.pushNil();
                return 1;
            };

            if (field_name[0] == '_') {
                lua.pushNil();
                return 1;
            }

            const type_info = @typeInfo(T);
            inline for (type_info.@"struct".fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    try utils.push(lua, @field(struct_ptr.*.*, field.name));
                    return 1;
                }
            }

            inline for (@typeInfo(T).@"struct".decls) |decl| {
                const field = @field(T, decl.name);
                if (@typeInfo(@TypeOf(field)) == .@"fn") {
                    lua.pushFunction(wrap(field));
                } else {
                    @compileError("struct doesn't support any other declaration than functions: " ++ decl.name);
                }

                return 1;
            }

            lua.pushNil();
            return 1;
        }
    }.indexFn);
}

fn pushLuaStruct(lua: *zlua.Lua, comptime T: type, data: *T) !void {
    const pointer_type = *T;
    
    const userdata = lua.newUserdata(pointer_type, 0);
    userdata.* = data;

    if (lua.getMetatableRegistry(@typeName(pointer_type)) == .nil) {
        lua.pop(1);

        try lua.newMetatable(@typeName(pointer_type));

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
            }
            if (lua.isLightUserdata(index)) {
                return true;
            }
        },
        .optional => |opt| {
            if (lua.isNil(index)) {
                return true;
            }
            return is(lua, opt.child, index);
        },
        .@"struct" => {
            _ = lua.testUserdata(T, index, @typeName(T)) catch return false;
            return true;
        },
        else => {},
    }

    return false;
}

fn PointerIfStruct(comptime T: type) type {
    if (@typeInfo(T) == .@"struct") {
        return *T;
    }

    return T;
}

pub fn get(lua: *zlua.Lua, comptime T: type, index: i32) !PointerIfStruct(T) {
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
            return lua.toUserdata(ptr_info.child, index);
        },
        .optional => |opt| {
            if (lua.isNil(index)) {
                return null;
            }
            return get(lua, opt.child, index);
        },
        .@"struct" => {
            return lua.toUserdata(T, index);
        },
        else => {},
    }

    // when we encounter this error means that is(...) and get(...) are out of sync
    return error.UnsupportedType;
}

pub fn check(lua: *zlua.Lua, comptime T: type, index: i32) PointerIfStruct(T) {
    std.debug.print("{s}\n", .{@typeName(T)});
    std.debug.dumpCurrentStackTrace(null);
    
    switch (@typeInfo(T)) {
        .int, .comptime_int => {
            return @intCast(lua.checkInteger(index));
        },
        .float, .comptime_float => {
            return @floatCast(lua.checkNumber(index));
        },
        .bool => {
            return lua.toBoolean(index);
        },
        .pointer => |ptr_info| {
            if (ptr_info.size == .slice and ptr_info.child == u8) {
                return lua.checkString(index);
            }
            return lua.checkUserdata(ptr_info.child, index, @typeName(T));
        },
        .optional => |opt| {
            if (lua.isNil(index) or lua.getTop() < index) {
                return null;
            }
            return check(lua, opt.child, index);
        },
        .@"struct" => {
            return lua.checkUserdata(T, index, @typeName(*T));
        },
        else => {},
    }
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
        // .@"struct" => |struct_info| {
        //     if (struct_info.is_tuple) {
        //         @compileError("implement custom handling of tuples");
        //     }
        // },
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

pub fn wrap(comptime func: anytype) zlua.CFn {
    const func_type = @TypeOf(func);
    if (@typeInfo(func_type) != .@"fn") {
        @compileError("Wrap only accepts functions");
    }
    if (func_type == LuaFunc) {
        return zlua.wrap(func);
    } else if (func_type == zlua.CFn) {
        return func;
    }

    const func_info = @typeInfo(func_type).@"fn";
    const params = func_info.params;
    const has_error_union = @typeInfo(func_info.return_type.?) == .error_union;

    return zlua.wrap(struct {
        pub fn call(lua: *zlua.Lua) i32 {
            var args: createArgsType(func_info) = undefined;
            var lua_arg_index: i32 = 0;
            inline for (params, 0..) |param, i| {
                lua_arg_index += 1;

                const param_type = param.type orelse @compileError("parameter type required");
                args[i] = check(lua, param_type, lua_arg_index);
            }
            lua.pop(lua.getTop()); // clear function stack

            const result = if (has_error_union)
                @call(.always_inline, func, args) catch |err| {
                    lua.raiseErrorStr(@errorName(err), .{});
                    unreachable; // Needed because raiseErrorStr never returns
                }
            else
                @call(.always_inline, func, args);

            if (@TypeOf(result) == void) {
                return 0;
            }
            push(lua, result) catch |err| {
                lua.raiseErrorStr("push(%s): %s", .{ @typeName(@TypeOf(result)).ptr, @errorName(err).ptr });
            };
            return 1;
        }
    }.call);
}

fn createArgsType(comptime fn_type: std.builtin.Type.Fn) type {
    return std.meta.Tuple(&compileHelperParams(fn_type.params));
}

fn compileHelperParams(comptime params: []const std.builtin.Type.Fn.Param) [params.len]type {
    var result: [params.len]type = undefined;
    for (params, 0..) |param, i| {
        result[i] = param.type.?;
    }
    return result;
}
