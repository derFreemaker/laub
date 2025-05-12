const std = @import("std");
const laub = @import("laub");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var instance = laub.Laub.init(allocator)
        catch @panic("unable to initialize laub");
    defer instance.deinit();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    try instance.execute(args);
}
