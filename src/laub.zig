const std = @import("std");
const zlua = @import("zlua");

pub fn foo() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var lua = try zlua.Lua.init(allocator);
    defer lua.deinit();
    lua.openLibs();

    const success = lua.doFile("test.lua");
    if (success) |_| {} else |_| {
        std.debug.print("Error: {s}\n", .{try lua.toString(-1)});
        lua.pop(1);
    }
}
