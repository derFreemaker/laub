const std = @import("std");
const zlua = @import("zlua");

const utils = @This();

pub fn dumpStack(lua: *zlua.Lua) void {
    std.debug.print("stack dump:{}:\n", .{lua.getTop()});
    for (1..@as(usize, @intCast(lua.getTop())) + 1) |i| {
        const index: i32 = @intCast(i);
        std.debug.print("  {}: {s} -> ", .{ i, lua.typeNameIndex(index) });

        switch (lua.typeOf(index)) {
            .none => {},
            .nil => {
                std.debug.print("nil", .{});
            },
            .boolean => {
                std.debug.print("'{}'", .{lua.toBoolean(index)});
            },
            .number => {
                if (lua.toNumber(index)) |value| {
                    std.debug.print("'{}'", .{value});
                } else |_| {
                    std.debug.print("<ERROR NUMBER>", .{});
                }
            },
            .string => {
                if (lua.toString(index)) |value| {
                    std.debug.print("'{s}'", .{value});
                } else |_| {
                    std.debug.print("<ERROR STRING>", .{});
                }
            },
            else => {
                std.debug.print("'{s}'", .{lua.toStringEx(index)});
                lua.pop(1);
            },
        }

        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
}

pub fn absoluteIndex(lua: *zlua.Lua, index: i32) i32 {
    if (index > 0) {
        return index;
    }
    return lua.getTop() + index + 1;
}

pub const LuaFunc = fn (lua: *zlua.Lua) i32;

pub const ThisLuaState = struct {
    lua: *zlua.Lua,
};

fn isTypeString(typeinfo: std.builtin.Type.Pointer) bool {
    const childinfo = @typeInfo(typeinfo.child);
    if (typeinfo.child == u8 and typeinfo.size != .one) {
        return true;
    } else if (typeinfo.size == .one and childinfo == .array and childinfo.array.child == u8) {
        return true;
    }
    return false;
}

fn isTypeArray(typeinfo: std.builtin.Type.Pointer) bool {
    return switch (typeinfo.size) {
        .slice, .many => true,
        else => false,
    };
}

// const ManyValuesTag = struct {};
//
// pub fn ManyValues(comptime T: type) type {
//     return struct {
//         tag: ManyValuesTag = .{},
//
//         values: []T,
//
//         pub fn get(lua: *zlua.Lua, index: i32) ManyValues(T) {
//             while (is(lua, T, index)) {}
//         }
//
//         pub fn push(self: *ManyValues(T), lua: *zlua.Lua) !void {
//             for (self.values) |value| {
//                 try utils.push(lua, value);
//             }
//         }
//     };
// }
//
// pub fn isManyValues(comptime T: type) bool {
//     switch (@typeInfo(T)) {
//         .@"struct" => |s| {
//             for (s.fields) |field| {
//                 if (std.mem.eql(u8, field.name, "tag") and field.type == ManyValuesTag) {
//                     return true;
//                 }
//             }
//         },
//         else => {},
//     }
//     return false;
// }

pub fn IndexCovered(comptime T: type) type {
    return struct {
        index_covered: i32,
        value: T,
    };
}

pub fn IndexCoveredOne(value: anytype) IndexCovered(@TypeOf(value)) {
    return .{
        .index_covered = 1,
        .value = value,
    };
}

pub fn IndexCoveredMany(value: anytype, covered: i32) IndexCovered(@TypeOf(value)) {
    return .{
        .index_covered = covered,
        .value = value,
    };
}

fn createRef(lua: *zlua.Lua, index: i32) i32 {
    lua.pushValue(index);
    return lua.ref(zlua.registry_index) catch unreachable;
}

fn releaseRef(lua: *zlua.Lua, ref_index: i32) void {
    lua.unref(zlua.registry_index, ref_index);
}

fn pushRef(lua: *zlua.Lua, ref_index: i32) void {
    _ = lua.rawGetIndex(zlua.registry_index, ref_index);
}

pub const LuaTable = struct {
    ref_index: i32,
    lua: *zlua.Lua,

    pub fn deinit(self: *LuaTable) void {
        releaseRef(self.lua, self.ref_index);
    }

    pub fn get(lua: *zlua.Lua, index: i32) !LuaTable {
        if (!lua.isTable(index)) {
            return error.NoTableAtIndex;
        }

        return LuaTable{
            .ref_index = createRef(lua, index),
            .lua = lua,
        };
    }

    pub fn check(lua: *zlua.Lua, index: i32) LuaTable {
        lua.checkType(index, .table);
        return LuaTable.get(lua, index) catch unreachable;
    }

    pub fn push(self: LuaTable) void {
        pushRef(self.lua, self.ref_index);
    }

    pub fn setField(self: LuaTable, index: anytype, value: anytype) !void {
        self.push();
        try utils.push(self.lua, index);
        try utils.push(self.lua, value);
        self.lua.setTable(-3);
        self.lua.pop(1);
    }

    pub fn getField(self: LuaTable, index: anytype) !LuaAny {
        self.push();
        try utils.push(self.lua, index);
        _ = self.lua.getTable(-2);

        const value = try utils.get(self.lua, LuaAny, -1);
        self.lua.pop(2);

        return value;
    }
};

pub const LuaAny = union(enum) {
    none,
    nil: Nil,
    boolean: Bool,
    integer: Integer,
    number: Number,
    string: StringRef,
    table: LuaTable,
    function: FunctionRef,
    lightuserdata: LightUserdata,
    userdata: UserdataRef,
    thread: ThreadRef,

    pub const Nil = struct {
        lua: *zlua.Lua,
    };

    pub const Bool = struct {
        lua: *zlua.Lua,
        value: bool,
    };

    pub const Integer = struct {
        lua: *zlua.Lua,
        value: i64,
    };

    pub const Number = struct {
        lua: *zlua.Lua,
        value: f64,
    };

    pub const StringRef = struct {
        lua: *zlua.Lua,
        ref_index: i32,
        data: [:0]const u8,
    };

    pub const FunctionRef = struct {
        lua: *zlua.Lua,
        ref_index: i32,
    };

    pub const LightUserdata = struct {
        lua: *zlua.Lua,
        ptr: *anyopaque,
    };

    pub const UserdataRef = struct {
        lua: *zlua.Lua,
        ref_index: i32,
        ptr: *anyopaque,
    };

    pub const ThreadRef = struct {
        lua: *zlua.Lua,
        ref_index: i32,
        thread: *zlua.Lua,
    };

    pub fn get(lua: *zlua.Lua, index: i32) LuaAny {
        const lua_type = lua.typeOf(index);

        switch (lua_type) {
            .none => {
                return LuaAny{ .none = {} };
            },
            .nil => {
                return LuaAny{ .nil = .{ .lua = lua } };
            },
            .boolean => {
                return LuaAny{ .boolean = .{ .lua = lua, .value = lua.toBoolean(index) } };
            },
            .number => {
                return LuaAny{ .number = .{ .lua = lua, .value = lua.toNumber(index) catch unreachable } };
            },
            .string => {
                return LuaAny{ .string = .{ .lua = lua, .ref_index = createRef(lua, index), .data = lua.toString(index) catch unreachable } };
            },
            .table => {
                return LuaAny{ .table = LuaTable.get(lua, index) catch unreachable };
            },
            .function => {
                return LuaAny{ .function = .{ .lua = lua, .ref_index = createRef(lua, index) } };
            },
            .light_userdata => {
                return LuaAny{ .lightuserdata = .{ .lua = lua, .ptr = lua.toUserdata(anyopaque, index) catch unreachable } };
            },
            .userdata => {
                return LuaAny{ .userdata = .{ .lua = lua, .ref_index = createRef(lua, index), .ptr = lua.toUserdata(anyopaque, index) catch unreachable } };
            },
            .thread => {
                return LuaAny{ .thread = .{ .lua = lua, .ref_index = createRef(lua, index), .thread = lua.toThread(index) catch unreachable } };
            },
        }
    }

    pub fn push(self: *LuaAny) void {
        switch (self.*) {
            .none => {},
            .nil => |n| n.lua.pushNil(),
            .boolean => |b| b.lua.pushBoolean(b.value),
            .integer => |i| i.lua.pushInteger(i.value),
            .number => |n| n.lua.pushNumber(n.value),
            .string => |s| _ = s.lua.pushString(s.data),
            .table => |t| t.push(),
            .function => |f| pushRef(f.lua, f.ref_index),
            .lightuserdata => |p| p.lua.pushLightUserdata(p.ptr),
            .userdata => |u| pushRef(u.lua, u.ref_index),
            .thread => |t| pushRef(t.lua, t.ref_index),
        }
    }

    pub fn deinit(self: *LuaAny) void {
        switch (self.*) {
            .table => |t| {
                t.deinit();
            },
            .function => |f| {
                releaseRef(f.lua, f.ref_index);
            },
            .userdata => |u| {
                releaseRef(u.lua, u.ref_index);
            },
            .thread => |t| {
                releaseRef(t.lua, t.ref_index);
            },
            else => {},
        }
    }

    pub fn typeName(self: *const LuaAny) [:0]const u8 {
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

fn isArray(lua: *zlua.Lua, comptime _: type, _index: i32) IndexCovered(bool) {
    const index = absoluteIndex(lua, _index);

    if (lua.typeOf(index) != .table) {
        return IndexCoveredOne(false);
    }

    @compileError("implement this");
}

fn toArray(lua: *zlua.Lua, comptime child: type, _index: i32, push_err_msg: bool) !IndexCovered([]child) {
    const index = absoluteIndex(lua, _index);

    if (lua.typeOf(index) != .table) {
        if (push_err_msg) {
            _ = lua.pushFString("expected array (%s[]) at index: %d", .{ typeName(child).ptr, index });
        }
        return error.TypeMismatch;
    }

    const child_info = @typeInfo(child);
    const child_is_tuple = child_info == .@"struct" and child_info.@"struct".is_tuple;

    var size = lua.rawLen(index);
    if (child_is_tuple) {
        const tuple_len = lenTuple(child);
        const over = size % tuple_len;
        if (over != 0) {
            //TODO: report back what exactly is wrong
            if (push_err_msg) {
                _ = lua.pushFString("bad pattern length in array -> pattern '%s' expected", .{typeName(child).ptr});
            }
            return error.TypeMismatch;
        }
        size = size / tuple_len;
    }
    var arr = lua.allocator().alloc(child, size) catch lua.raiseErrorStr("laub.toArray: out of memory", .{});

    if (child_is_tuple) {
        for (1..size + 1) |i| {
            const tuple_len = lenTuple(child);
            inline for (0..tuple_len) |j| {
                lua.pushInteger(@intCast(tuple_len * (i - 1) + j + 1));
                _ = lua.getTable(index);
            }

            const tuple = get(lua, child, -@as(i32, tuple_len)) catch |err| {
                //TODO: report back what exactly is wrong
                if (push_err_msg) {
                    _ = lua.pushFString("bad array index: %d -> pattern '%s' expected", .{ i, typeName(child).ptr });
                }
                return err;
            };
            lua.pop(@intCast(tuple_len));

            arr[i - 1] = tuple.value;
        }
    } else {
        for (1..size + 1) |i| {
            lua.pushInteger(@intCast(i));
            _ = lua.getTable(index);

            const result = get(lua, child, -1) catch |err| {
                if (push_err_msg) {
                    _ = lua.pushFString("bad array index '%d' -> only '%s' expected, got '%s'", .{ i, typeName(child).ptr, lua.typeNameIndex(-1).ptr });
                }
                return err;
            };
            lua.pop(1);

            arr[i - 1] = result.value;
        }
    }

    return IndexCoveredOne(arr);
}

fn isTuple(lua: *zlua.Lua, comptime info: std.builtin.Type.Struct, _index: i32) IndexCovered(bool) {
    const index = absoluteIndex(lua, _index);

    inline for (info.fields, 0..) |field, i| {
        if (!is(lua, field.type, index + @as(i32, i)).value) {
            return IndexCoveredMany(false, @intCast(i + 1));
        }
    }
    return IndexCoveredMany(true, info.fields.len);
}

fn lenTuple(comptime T: type) comptime_int {
    if (@typeInfo(T) != .@"struct" or !@typeInfo(T).@"struct".is_tuple) {
        @compileError("type in luaTuple(...) needs to be a tuple");
    }

    var length = 0;
    for (@typeInfo(T).@"struct".fields) |field| {
        const field_info = @typeInfo(field.type);
        if (field_info == .@"struct" and field_info.@"struct".is_tuple) {
            length += lenTuple(field.type);
            continue;
        }
        length += 1;
    }

    return length;
}

fn toTuple(lua: *zlua.Lua, comptime T: type, _index: i32) !IndexCovered(T) {
    const struct_info = @typeInfo(T).@"struct";
    const index = absoluteIndex(lua, _index);

    var tuple: T = undefined;

    var covered_index: i32 = 0;
    inline for (struct_info.fields, 0..) |field, i| {
        const result = try get(lua, field.type, @intCast(index + covered_index));
        covered_index += result.index_covered;
        tuple[i] = result.value;
    }

    return IndexCoveredMany(tuple, covered_index);
}

fn checkTuple(lua: *zlua.Lua, comptime T: type, _index: i32) IndexCovered(T) {
    const struct_info = @typeInfo(T);
    const index = absoluteIndex(lua, _index);

    var tuple: T = undefined;

    var covered_index: i32 = 0;
    inline for (struct_info.fields, 0..) |field, i| {
        const result = check(lua, field.type, @intCast(index + covered_index));
        covered_index += result.index_covered;
        tuple[i] = result.value;
    }

    return IndexCoveredMany(tuple, covered_index);
}

pub fn is(lua: *zlua.Lua, comptime T: type, index: i32) IndexCovered(bool) {
    if (lua.getTop() < @abs(index)) {
        return IndexCoveredOne(false);
    }

    if (T == LuaTable) {
        return IndexCoveredOne(lua.isTable(index));
    }

    switch (@typeInfo(T)) {
        .int, .comptime_int => {
            return IndexCoveredOne(lua.isInteger(index));
        },
        .float, .comptime_float => {
            return IndexCoveredOne(lua.isNumber(index));
        },
        .bool => {
            return IndexCoveredOne(lua.isBoolean(index));
        },
        .pointer => |ptr_info| {
            if (comptime isTypeString(ptr_info)) {
                return IndexCoveredOne(lua.isString(index));
            }
            if (comptime isTypeArray(ptr_info)) {
                return isArray(lua, ptr_info.child, index);
            }
            if (lua.isLightUserdata(index)) {
                return IndexCoveredOne(true);
            }
        },
        .optional => |opt| {
            if (lua.isNil(index)) {
                return IndexCoveredOne(true);
            }
            return is(lua, opt.child, index);
        },
        .@"struct" => |struct_info| {
            if (struct_info.is_tuple) {
                return isTuple(lua, struct_info, index);
            }

            _ = lua.testUserdata(T, index, @typeName(T)) catch return IndexCoveredOne(false);
            return IndexCoveredOne(true);
        },
        else => {},
    }

    return false;
}

fn PointerIfStruct(comptime T: type) type {
    if (T == LuaAny or T == LuaTable
        // or isManyValues(T)
    ) {
        return T;
    }

    if (@typeInfo(T) == .@"struct" and !@typeInfo(T).@"struct".is_tuple) {
        return *T;
    }

    return T;
}

pub fn getUnchecked(lua: *zlua.Lua, comptime T: type, index: i32) !IndexCovered(PointerIfStruct(T)) {
    if (T == LuaAny) {
        return IndexCoveredOne(LuaAny.get(lua, index));
    }

    switch (@typeInfo(T)) {
        .int, .comptime_int => {
            const value: T = @intCast(lua.toInteger(index) catch unreachable);
            return IndexCoveredOne(value);
        },
        .float, .comptime_float => {
            return IndexCoveredOne(@floatCast(lua.toNumber(index) catch unreachable));
        },
        .bool => {
            return IndexCoveredOne(lua.toBoolean(index));
        },
        .pointer => |ptr_info| {
            if (comptime isTypeString(ptr_info)) {
                return IndexCoveredOne(lua.toString(index) catch unreachable);
            }
            if (comptime isTypeArray(ptr_info)) {
                return toArray(lua, ptr_info.child, index, true) catch |err| {
                    lua.pop(1);
                    return err;
                };
            }

            return IndexCoveredOne(lua.toUserdata(ptr_info.child, index));
        },
        .optional => |opt| {
            if (lua.isNil(index)) {
                return IndexCoveredOne(null);
            }
            return get(lua, opt.child, index);
        },
        .@"struct" => |struct_info| {
            if (struct_info.is_tuple) {
                return try toTuple(lua, T, index);
            }

            return IndexCoveredOne(lua.toUserdata(T, index));
        },
        else => {},
    }

    // when we encounter this error through get(...) means that is(...) and getUnchecked(...) are out of sync
    @compileError("unsupported type: " ++ @typeName(T));
}

pub fn get(lua: *zlua.Lua, comptime T: type, index: i32) !IndexCovered(PointerIfStruct(T)) {
    if (T == LuaAny) {
        return IndexCoveredOne(LuaAny.get(lua, index));
    }

    if (T == LuaTable) {
        return IndexCoveredOne(try LuaTable.get(lua, index));
    }

    if (!is(lua, T, index).value) {
        return error.TypeMismatch;
    }

    return getUnchecked(lua, T, index);
}

pub fn check(lua: *zlua.Lua, comptime T: type, index: i32) IndexCovered(PointerIfStruct(T)) {
    if (T == LuaAny) {
        return IndexCoveredOne(LuaAny.get(lua, index));
    }

    if (T == LuaTable) {
        return IndexCoveredOne(LuaTable.check(lua, index));
    }

    switch (@typeInfo(T)) {
        .int, .comptime_int => {
            const value: T = @intCast(lua.checkInteger(index));
            return IndexCoveredOne(value);
        },
        .float, .comptime_float => {
            return IndexCoveredOne(@floatCast(lua.checkNumber(index)));
        },
        .bool => {
            return IndexCoveredOne(lua.toBoolean(index));
        },
        .pointer => |ptr_info| {
            if (comptime isTypeString(ptr_info)) {
                return IndexCoveredOne(lua.checkString(index));
            }

            if (comptime isTypeArray(ptr_info)) {
                if (lua.typeOf(index) != .table) {
                    const details = lua.pushFString("expected %s[], got %s", .{ typeName(ptr_info.child).ptr, lua.typeNameIndex(index).ptr });
                    lua.pop(1);
                    lua.argError(index, details);
                }
                return toArray(lua, ptr_info.child, index, true) catch {
                    const details = lua.toString(-1) catch unreachable;
                    lua.pop(1);
                    lua.argError(index, details);
                };
            }

            if (lua.isLightUserdata(index)) {
                return IndexCoveredOne(lua.toUserdata(ptr_info.child, index) catch unreachable);
            }

            return IndexCoveredOne(lua.checkUserdata(ptr_info.child, index, @typeName(T)));
        },
        .optional => |opt| {
            if (lua.isNil(index)) {
                return IndexCoveredOne(null);
            }
            return check(lua, opt.child, index);
        },
        .@"struct" => |struct_info| {
            if (struct_info.is_tuple) {
                return checkTuple(lua, T, index);
            }

            return IndexCoveredOne(lua.checkUserdata(T, index, @typeName(*T)));
        },
        else => {},
    }
}

pub fn push(lua: *zlua.Lua, value: anytype) !void {
    const T = @TypeOf(value);

    if (T == LuaAny) {
        value.push(lua);
        return;
    }

    if (T == LuaTable) {
        value.push(lua);
        return;
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
            if (comptime isTypeString(ptr_info)) {
                _ = lua.pushString(value);
                return;
            }

            if (comptime isTypeArray(ptr_info)) {
                lua.createTable(@intCast(value.len), 0);
                for (value, 0..) |x, i| {
                    lua.pushInteger(@intCast(i + 1));
                    try push(lua, x);
                    lua.setTable(-3);
                }
                return;
            }

            if (ptr_info.size == .one) {
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
                for (struct_info.fields) |field| {
                    try push(lua, @field(value, field.name));
                }
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

pub fn typeName(comptime T: type) [:0]const u8 {
    const signature = comptime blk: {
        if (T == LuaAny) {
            break :blk "any";
        }
        if (T == LuaTable) {
            break :blk "table";
        }

        switch (@typeInfo(T)) {
            .int, .comptime_int => break :blk "integer",
            .float, .comptime_float => break :blk "number",
            .bool => break :blk "boolean",
            .pointer => |info| {
                if (isTypeString(info)) {
                    break :blk "string";
                }
                if (isTypeArray(info)) {
                    break :blk typeName(info.child) ++ "[]";
                }
                break :blk "*" ++ typeName(info.child);
            },
            .optional => |info| {
                break :blk typeName(info.child) ++ "?";
            },
            .@"struct" => |info| {
                if (info.is_tuple) {
                    var signature: [:0]const u8 = "";
                    if (info.fields.len == 0) {
                        break :blk signature;
                    }

                    for (info.fields, 0..) |field, i| {
                        if (i > 0) {
                            signature = signature ++ ", ";
                        }
                        signature = signature ++ typeName(field.type);
                    }
                    break :blk signature;
                }

                break :blk @typeName(T);
            },
            .@"fn" => break :blk @typeName(T),
            else => break :blk "unknown",
        }
    };
    return signature;
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
                if (param.type == ThisLuaState) {
                    args[i] = ThisLuaState{ .lua = lua };
                    continue;
                }
                lua_arg_index += 1;

                const param_type = param.type orelse @compileError("parameter type required");
                const result = check(lua, param_type, lua_arg_index);
                lua_arg_index += result.index_covered - 1;
                args[i] = result.value;
            }
            defer {
                inline for (params, 0..) |param, i| {
                    const param_info = @typeInfo(param.type.?);
                    if (param_info == .pointer and comptime isTypeArray(param_info.pointer)) {
                        lua.allocator().free(args[i]);
                    }
                }
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
