const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlua = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
        
        .lang = .lua54,
    });
    
    const laub = b.addModule("laub", .{
        .target = target,
        .optimize = optimize,

        .root_source_file = b.path("src/laub.zig"),
    });
    laub.addImport("zlua", zlua.module("zlua"));

    const laub_driver = b.addModule("laub_driver", .{
        .target = target,
        .optimize = optimize,
        
        .root_source_file = b.path("src/driver/main.zig"),
    });
    laub_driver.addImport("laub", laub);

    b.installArtifact(b.addExecutable(.{
        .name = "laub_driver",
        .root_module = laub_driver,
    }));
}
