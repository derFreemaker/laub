const std = @import("std");
const zlua = @import("zlua");

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
    
    pub fn execute(_: *Laub, args: [][:0]u8) void {
        for (args, 0..) |arg, i| {
            std.log.info("<{d}> {s}", .{ i, arg });
        }
    }
};
