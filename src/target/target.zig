const std = @import("std");

pub const Target = struct {
    name: []const u8,
    dependencies: std.ArrayList(Target),
};
