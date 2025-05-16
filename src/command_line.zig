const std = @import("std");
const zlua = @import("zlua");
const yazap = @import("yazap");

const utils = @import("lua/utils.zig");

pub const CommandParserConfigurator = struct {
    pub fn option(_: *CommandParserConfigurator, str: ?[:0]const u8) !void {
        std.debug.print("{s}\n", .{str orelse "NONE"});
    }
};

pub fn configure_command_line_args(lua: *zlua.Lua, project_root: [:0]const u8) !void {
    var parser = CommandParserConfigurator{
        
    };
    try utils.push(lua, &parser);
    lua.setGlobal("laub_parser");
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const raw_path = try std.fs.path.join(allocator, &[_][]const u8{ project_root, "laub_parse.lua" });
    defer allocator.free(raw_path);
    const path = try allocator.dupeZ(u8, raw_path);
    defer allocator.free(path);

    lua.doFile(path) catch {
        std.debug.print("{s}", .{try lua.toString(-1)});
        lua.pop(1);
    };
}
