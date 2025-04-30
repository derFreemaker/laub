const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "laub",
        .root_source_file = b.path("src/main.zig"),
        .target = b.graph.host,
    });

    const ziglua = b.dependency("ziglua", .{});
    exe.root_module.addImport("zlua", ziglua.module("ziglua"));
    
    b.installArtifact(exe);
}
