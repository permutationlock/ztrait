const std = @import("std");
const Builder = std.build.Builder;

const Example = struct { name: []const u8, path: []const u8 };
const paths = [_]Example{
    .{ .name = "count", .path = "examples/count.zig" },
    .{ .name = "slices", .path = "examples/slices.zig" },
    .{ .name = "mytrait", .path = "examples/use_mytrait.zig" },
    .{ .name = "count_ifc", .path = "examples/count_ifc.zig" },
    .{ .name = "count_ifc_params", .path = "examples/count_ifc_params.zig" },
};

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ztrait = b.addModule("ztrait", .{
        .source_file = .{ .path = "src/ztrait.zig" },
    });

    const run_step = b.step("run", &.{});

    inline for (paths) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_source_file = .{ .path = example.path },
            .target = target,
            .optimize = optimize,
        });
        exe.addModule("ztrait", ztrait);
        run_step.dependOn(&b.addRunArtifact(exe).step);
    }
}
