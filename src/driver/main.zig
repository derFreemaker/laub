const std = @import("std");
const laub = @import("laub");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const foo2 = try laub.foo(allocator);
    std.debug.print("{s}\n", .{ foo2 });
}
