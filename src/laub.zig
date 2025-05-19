const std = @import("std");
const zlua = @import("zlua");

const CommandLine = @import("command_line.zig");

pub const Laub = struct {
    lua: *zlua.Lua,

    pub fn init(allocator: std.mem.Allocator) !Laub {
        return .{
            .lua = try zlua.Lua.init(allocator),
        };
    }

    pub fn deinit(self: *Laub) void {
        self.lua.deinit();
    }
    
    pub fn execute(self: *Laub, _: [][:0]u8) !void {
        self.lua.openLibs();
        try CommandLine.configureCommandLineArgs(self.lua, "F:/Coding/zig/laub/example/lua_module/");
    }
};
