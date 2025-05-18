const std = @import("std");
const zlua = @import("zlua");

const utils = @This();

pub const LuaFunc = fn (lua: *zlua.Lua) i32;

pub const LuaValue = union(enum) {
    none,
    nil,
    boolean: bool,
    integer: i64,
    number: f64,
    string: StringRef,
    table: TableRef,
    function: FunctionRef,
    lightuserdata: *anyopaque,
    userdata: UserdataRef,
    thread: ThreadRef,

    pub const StringRef = struct {
        ref_index: i32,
        data: [:0]const u8,
    };

    pub const TableRef = struct {
        ref_index: i32,
    };

    pub const FunctionRef = struct {
        ref_index: i32,
    };

    pub const UserdataRef = struct {
        ref_index: i32,
        ptr: *anyopaque,
    };

    pub const ThreadRef = struct {
        ref_index: i32,
        thread: *zlua.Lua,
    };

    fn createRef(lua: *zlua.Lua, index: i32) i32 {
        lua.pushValue(index);
        return lua.ref(zlua.registry_index) catch unreachable;
    }

    fn releaseRef(lua: *zlua.Lua, ref_index: i32) void {
        lua.unref(zlua.registry_index, ref_index);
    }

    pub fn get(lua: *zlua.Lua, index: i32) LuaValue {
        const lua_type = lua.typeOf(index);

        switch (lua_type) {
            .none => {
                return LuaValue{ .none = {} };
            },
            .nil => {
                return LuaValue{ .nil = {} };
            },
            .boolean => {
                return LuaValue{ .boolean = lua.toBoolean(index) };
            },
            .number => {
                return LuaValue{ .number = lua.toNumber(index) catch unreachable };
            },
            .string => {
                return LuaValue{ .string = .{ .ref_index = createRef(lua, index), .data = lua.toString(index) catch unreachable } };
            },
            .table => {
                return LuaValue{ .table = .{ .ref_index = createRef(lua, index) } };
            },
            .function => {
                return LuaValue{ .function = .{ .ref_index = createRef(lua, index) } };
            },
            .light_userdata => {
                return LuaValue{ .lightuserdata = lua.toUserdata(anyopaque, index) catch unreachable };
            },
            .userdata => {
                return LuaValue{ .userdata = .{ .ref_index = createRef(lua, index), .ptr = lua.toUserdata(anyopaque, index) catch unreachable } };
            },
            .thread => {
                return LuaValue{ .thread = .{ .ref_index = createRef(lua, index), .thread = lua.toThread(index) catch unreachable } };
            },
        }
    }

    pub fn push(self: *LuaValue, lua: *zlua.Lua) void {
        switch (self.*) {
            .none => {},
            .nil => lua.pushNil(),
            .boolean => |b| lua.pushBoolean(b),
            .integer => |i| lua.pushInteger(i),
            .number => |n| lua.pushNumber(n),
            .string => |s| _ = lua.pushString(s.data),
            .table => |t| lua.rawGetIndex(zlua.registry_index, t.ref_index),
            .function => |f| lua.rawGetIndex(zlua.registry_index, f.ref_index),
            .lightuserdata => |p| lua.pushLightUserdata(p),
            .userdata => |u| lua.rawGetIndex(zlua.registry_index, u.ref_index),
            .thread => |t| lua.rawGetIndex(zlua.registry_index, t.ref_index),
        }
    }

    pub fn deinit(self: *LuaValue, lua: *zlua.Lua) void {
        switch (self.*) {
            .table => |t| {
                releaseRef(lua, t.ref_index);
            },
            .function => |f| {
                releaseRef(lua, f.ref_index);
            },
            .userdata => |u| {
                releaseRef(lua, u.ref_index);
            },
            .thread => |t| {
                releaseRef(lua, t.ref_index);
            },
            else => {},
        }
    }

    pub fn typeName(self: *const LuaValue) [:0]const u8 {
        return switch (self.*) {
            .none => "none",
            .nil => "nil",
            .boolean => "boolean",
            .integer => "integer",
            .number => "number",
            .string => "string",
            .table => "table",
            .function => "function",
            .lightuserdata => "lightuserdata",
            .userdata => "userdata",
            .thread => "thread",
        };
    }
};

const ManyValuesTag = struct {};

pub fn ManyValues(comptime T: type) type {
    return struct {
        tag: ManyValuesTag = .{},

        values: []T,

        pub fn get(lua: *zlua.Lua, index: i32) ManyValues(T) {
            while (is(lua, T, index)) {}
        }

        pub fn push(self: *ManyValues(T), lua: *zlua.Lua) !void {
            for (self.values) |value| {
                try utils.push(lua, value);
            }
        }
    };
}

pub fn isManyValues(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .@"struct" => |s| {
            for (s.fields) |field| {
                if (std.mem.eql(u8, field.name, "tag") and field.type == ManyValuesTag) {
                    return true;
                }
            }
        },
        else => {},
    }
    return false;
}

pub fn DefaultLuaStructIndex(comptime T: type) LuaFunc {
    return struct {
        pub fn indexFn(lua: *zlua.Lua) i32 {
            const struct_ptr = check(lua, T, 1);
            const field_name = lua.toString(2) catch {
                lua.pushNil();
                return 1;
            };
            lua.pop(2);

            if (std.mem.startsWith(u8, field_name, "_")) {
                lua.pushNil();
                return 1;
            }

            const type_info = @typeInfo(T);
            inline for (type_info.@"struct".fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    try push(lua, @field(struct_ptr.*.*, field.name));
                    return 1;
                }
            }

            inline for (@typeInfo(T).@"struct".decls) |decl| {
                if (std.mem.eql(u8, decl.name, field_name)) {
                    const field = @field(T, decl.name);
                    if (@typeInfo(@TypeOf(field)) == .@"fn") {
                        try push(lua, field);
                    } else {
                        @compileError("struct doesn't support any other declaration than functions: " ++ decl.name);
                    }
                    return 1;
                }
            }

            lua.pushNil();
            return 1;
        }
    }.indexFn;
}

fn createMetatable(lua: *zlua.Lua, comptime T: type, comptime meta: type) !void {
    try lua.newMetatable(@typeName(T));

    if (@hasDecl(meta, "__index")) {
        lua.pushFunction(wrap(meta.__index));
        lua.setField(-2, "__index");
    }

    if (@hasDecl(meta, "__newindex")) {
        lua.pushFunction(wrap(meta.__newindex));
        lua.setField(-2, "__newindex");
    }

    if (@hasDecl(meta, "__gc")) {
        lua.pushFunction(wrap(meta.__gc));
        lua.setField(-2, "__gc");
    }

    //TODO: implement more metamethods
}

fn getOrCreateMetatable(lua: *zlua.Lua, comptime T: type, comptime meta: type) !void {
    if (lua.getMetatableRegistry(@typeName(T)) == .nil) {
        lua.pop(1);
        try createMetatable(lua, T, meta);
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
    if (T == LuaValue) {
        return LuaValue;
    }

    if (isManyValues(T)) {
        return T;
    }

    if (@typeInfo(T) == .@"struct") {
        return *T;
    }

    return T;
}

pub fn getUnchecked(lua: *zlua.Lua, comptime T: type, index: i32) !PointerIfStruct(T) {
    if (T == LuaValue) {
        return LuaValue.get(lua, index);
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

pub fn get(lua: *zlua.Lua, comptime T: type, index: i32) !PointerIfStruct(T) {
    if (T == LuaValue) {
        return LuaValue.get(lua, index);
    }

    if (!is(lua, T, index)) {
        return error.TypeMismatch;
    }

    return getUnchecked(lua, T, index);
}

pub fn check(lua: *zlua.Lua, comptime T: type, index: i32) PointerIfStruct(T) {
    if (T == LuaValue) {
        return LuaValue.get(lua, index);
    }

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

            if (lua.isLightUserdata(index)) {
                return lua.toUserdata(ptr_info.child, index) catch unreachable;
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
        .@"fn" => {
            return lua.autoPushFunction(index);
        },
        else => {},
    }
}

pub fn push(lua: *zlua.Lua, value: anytype) !void {
    const T = @TypeOf(value);

    if (T == LuaValue) {
        value.push(lua);
    }

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
                const userdata = lua.newUserdata(T, 0);
                userdata.* = value;
                try getOrCreateMetatable(lua, T, ptr_info.child);
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
        .@"struct" => |struct_info| {
            if (struct_info.is_tuple) {
                @compileError("implement custom handling of tuples");
            }

            const userdata = lua.newUserdata(T, 0);
            userdata.* = value;
            try getOrCreateMetatable(lua, T, T);
            return;
        },
        .@"fn" => {
            lua.pushFunction(wrap(value));
            return;
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
            var args: std.meta.ArgsTuple(func_type) = undefined;
            var lua_arg_index: i32 = 0;
            inline for (params, 0..) |param, i| {
                if (param.type == *zlua.Lua) {
                    args[0] = lua;
                    continue;
                }
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

fn compileParams(comptime params: []const std.builtin.Type.Fn.Param) [params.len]type {
    var result: [params.len]type = undefined;
    for (params, 0..) |param, i| {
        result[i] = param.type.?;
    }
    return result;
}
