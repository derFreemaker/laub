const std = @import("std");

const Command = struct {
    const Self = @This();
    
    name: []const u8,
    
    pub fn init(name: []const u8) Self {
        return Self{
            .name = name,
        };
    }
};

const Laub = struct {
    const Self = @This();
    
    commands: std.ArrayList(Command),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .commands = std.ArrayList(Command).init(allocator)
        };
    }
    
    pub fn deinit(self: Self) void {
        self.commands.deinit();
    }
};

pub fn foo(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    var foo2 = Laub.init(allocator);
    defer _ = foo2.deinit();
    
    const command = try foo2.commands.addOne();
    command.* = Command.init("test");
    
    return foo2.commands.items[0].name;
}
