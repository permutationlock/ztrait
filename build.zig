const std = @import("std");
const Builder = std.build.Builder;

const paths = .{ "main.zig", "where.zig" };

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    inline for (paths) |path| {
        const exe = b.addExecutable(.{
            .name = "this_will_not_build",
            .root_source_file = .{ .path = path },
            .target = target,
            .optimize = optimize
        });
        b.installArtifact(exe);
    }
}
