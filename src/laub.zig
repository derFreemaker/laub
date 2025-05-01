const std = @import("std");

pub fn foo(str: []const u8) void {
    std.debug.print("{s}\n", .{ str });
}
