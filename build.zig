const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    {
        const exe = b.addExecutable(.{
            .name = "zig-blake3",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe.linkLibC();
        b.installArtifact(exe);

        const options = b.addOptions();
        options.addOption(bool, "c", false);
        options.addOption(bool, "std", false);

        exe.root_module.addOptions("config", options);
    }

    {
        const exe = b.addExecutable(.{
            .name = "zig-std-blake3",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe.linkLibC();
        b.installArtifact(exe);

        const options = b.addOptions();
        options.addOption(bool, "c", false);
        options.addOption(bool, "std", true);

        exe.root_module.addOptions("config", options);
    }

    const c_path = b.path("BLAKE3/c");

    {
        const exe = b.addExecutable(.{
            .name = "c-asm-blake3",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        exe.addSystemIncludePath(c_path);
        exe.addCSourceFiles(.{
            .root = c_path,
            .files = &.{
                "blake3.c",
                "blake3_dispatch.c",
                "blake3_portable.c",
                "blake3_sse2_x86-64_unix.S",
                "blake3_sse41_x86-64_unix.S",
                "blake3_avx2_x86-64_unix.S",
            },
            .flags = &.{"-DBLAKE3_NO_AVX512"},
        });
        exe.linkLibC();

        b.installArtifact(exe);

        const options = b.addOptions();
        options.addOption(bool, "c", true);
        options.addOption(bool, "std", false);

        exe.root_module.addOptions("config", options);
    }

    {
        const exe = b.addExecutable(.{
            .name = "c-blake3",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        exe.addSystemIncludePath(c_path);
        exe.addCSourceFiles(.{
            .root = c_path,
            .files = &.{
                "blake3.c",
                "blake3_dispatch.c",
                "blake3_portable.c",
                "blake3_sse2.c",
                "blake3_sse41.c",
                "blake3_avx2.c",
            },
            .flags = &.{"-DBLAKE3_NO_AVX512"},
        });
        exe.linkLibC();

        b.installArtifact(exe);

        const options = b.addOptions();
        options.addOption(bool, "c", true);
        options.addOption(bool, "std", false);

        exe.root_module.addOptions("config", options);
    }

    const tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
