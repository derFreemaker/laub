const std = @import("std");
const laub = @import("laub");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arenaAllocator = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arenaAllocator.deinit();
    const allocator = arenaAllocator.allocator();

    var instance = laub.Laub.init(allocator)
        catch @panic("unable to initialize laub");
    defer instance.deinit();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try instance.execute(args);
}
