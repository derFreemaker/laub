const std = @import("std");
const zlua = @import("zlua");
const yazap = @import("yazap");

const utils = @import("lua/utils.zig");

const CommandParserCommandConfigurator = struct {
    _command: yazap.Command,
    _default: ?utils.LuaAny = null,
    _optional: bool = true,

    pub fn __index(lua: *zlua.Lua) i32 {
        return utils.defaultLuaStructIndex(CommandParserCommandConfigurator, "_")(lua);
    }

    pub fn option(state: utils.ThisLuaState, self: *CommandParserCommandConfigurator, options: utils.LuaTable) !void {
        const name: [:0]const u8 = switch (try options.getField("name")) {
            .string => |str| str.data,
            else => {
                state.lua.raiseErrorStr("expected field 'name' to be a 'string'", .{});
            },
        };

        const description: ?[:0]const u8 = switch (try options.getField("description")) {
            .nil => null,
            .string => |str| str.data,
            else => {
                state.lua.raiseErrorStr("expected field 'name' to be a 'string' or 'nil'", .{});
            },
        };

        const arg = yazap.Arg.init(name, description);

        self._default = try options.getField("default");
        self._optional = switch (try options.getField("optional")) {
            .boolean => |boolean| boolean.value,
            else => {
                state.lua.raiseErrorStr("expected field 'optional' to be a 'boolean'", .{});
            },
        };
        
        switch (try options.getField("placeholder")) {
            .nil => {},
            .string => |str| {
                arg.setValuePlaceholder(str.data);
            },
            else => {
                state.lua.raiseErrorStr("expected field 'placeholder' to be a 'string'", .{});
            },
        }

        try self._command.addArg(arg);
    }
};

const CommandParserConfigurator = struct {
    _parser: yazap.App,
    _commands: std.ArrayList(*CommandParserCommandConfigurator),

    pub fn _init(allocator: std.mem.Allocator) CommandParserConfigurator {
        return .{
            ._parser = yazap.App.init(allocator, "laub", "Laub is a project managing tool. Which takes care of actions steps to do specified things."),
            ._commands = std.ArrayList(*CommandParserCommandConfigurator).init(allocator),
        };
    }

    pub fn __index(lua: *zlua.Lua) i32 {
        return utils.defaultLuaStructIndex(CommandParserConfigurator, "_")(lua);
    }

    pub fn command(state: utils.ThisLuaState, self: *CommandParserConfigurator, name: [:0]const u8, description: ?[:0]const u8) !*CommandParserCommandConfigurator {
        var command_configurator = try state.lua.allocator().create(CommandParserCommandConfigurator);
        command_configurator._command = self._parser.createCommand(name, description);
        try self._commands.append(command_configurator);
        return command_configurator;
    }
};

pub fn configureCommandLineArgs(lua: *zlua.Lua, project_root: [:0]const u8) !void {
    var parser = CommandParserConfigurator._init(lua.allocator());
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
        std.debug.print("{s}\n", .{try lua.toString(-1)});
        lua.pop(1);
    };
}
