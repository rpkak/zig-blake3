const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const valgrind = b.option(bool, "valgrind", "valgrind") orelse false;

    {
        const exe = b.addExecutable(.{
            .name = "zig-blake3",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        b.getInstallStep().dependOn(&b.addInstallFile(exe.getEmittedLlvmIr(), "root.ll").step);
        b.getInstallStep().dependOn(&b.addInstallFile(exe.getEmittedAsm(), "root.S").step);
        exe.root_module.valgrind = valgrind;
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
        exe.root_module.valgrind = valgrind;
        exe.linkLibC();
        b.installArtifact(exe);

        const options = b.addOptions();
        options.addOption(bool, "c", false);
        options.addOption(bool, "std", true);

        exe.root_module.addOptions("config", options);
    }

    const c_path = b.dependency("blake3", .{}).path("c");

    if (target.result.cpu.arch == .x86_64) {
        const exe = b.addExecutable(.{
            .name = "c-asm-blake3",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        exe.addSystemIncludePath(c_path);

        var files: std.ArrayList([]const u8) = .init(b.allocator);
        defer files.deinit();
        var flags: std.ArrayList([]const u8) = .init(b.allocator);
        defer flags.deinit();

        try files.appendSlice(&.{ "blake3.c", "blake3_dispatch.c", "blake3_portable.c" });

        if (std.Target.x86.featureSetHas(target.result.cpu.features, .sse2)) {
            if (target.result.os.tag == .windows) {
                try files.append("blake3_sse2_x86-64_windows_gnu.S");
            } else {
                try files.append("blake3_sse2_x86-64_unix.S");
            }
        } else {
            try flags.append("-DBLAKE3_NO_SSE2");
        }

        if (std.Target.x86.featureSetHas(target.result.cpu.features, .sse4_1)) {
            if (target.result.os.tag == .windows) {
                try files.append("blake3_sse41_x86-64_windows_gnu.S");
            } else {
                try files.append("blake3_sse41_x86-64_unix.S");
            }
        } else {
            try flags.append("-DBLAKE3_NO_SSE41");
        }

        if (std.Target.x86.featureSetHas(target.result.cpu.features, .avx2)) {
            if (target.result.os.tag == .windows) {
                try files.append("blake3_avx2_x86-64_windows_gnu.S");
            } else {
                try files.append("blake3_avx2_x86-64_unix.S");
            }
        } else {
            try flags.append("-DBLAKE3_NO_AVX2");
        }

        if (std.Target.x86.featureSetHasAll(target.result.cpu.features, .{ .avx512f, .avx512vl })) {
            if (target.result.os.tag == .windows) {
                try files.append("blake3_avx512_x86-64_windows_gnu.S");
            } else {
                try files.append("blake3_avx512_x86-64_unix.S");
            }
        } else {
            try flags.append("-DBLAKE3_NO_AVX512");
        }

        exe.addCSourceFiles(.{
            .root = c_path,
            .files = files.items,
            .flags = flags.items,
        });
        exe.root_module.valgrind = valgrind;
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

        var files: std.ArrayList([]const u8) = .init(b.allocator);
        defer files.deinit();
        var flags: std.ArrayList([]const u8) = .init(b.allocator);
        defer flags.deinit();

        try files.appendSlice(&.{ "blake3.c", "blake3_dispatch.c", "blake3_portable.c" });

        if (target.result.cpu.arch == .x86_64) {
            if (std.Target.x86.featureSetHas(target.result.cpu.features, .sse2)) {
                try files.append("blake3_sse2.c");
            } else {
                try flags.append("-DBLAKE3_NO_SSE2");
            }

            if (std.Target.x86.featureSetHas(target.result.cpu.features, .sse4_1)) {
                try files.append("blake3_sse41.c");
            } else {
                try flags.append("-DBLAKE3_NO_SSE41");
            }

            if (std.Target.x86.featureSetHas(target.result.cpu.features, .avx2)) {
                try files.append("blake3_avx2.c");
            } else {
                try flags.append("-DBLAKE3_NO_AVX2");
            }

            if (std.Target.x86.featureSetHasAll(target.result.cpu.features, .{ .avx512f, .avx512vl })) {
                try files.append("blake3_avx512.c");
            } else {
                try flags.append("-DBLAKE3_NO_AVX512");
            }
        } else if (target.result.cpu.arch == .aarch64) {
            if (std.Target.aarch64.featureSetHas(target.result.cpu.features, .neon)) {
                try files.append("blake3_neon.c");
                try flags.append("-DBLAKE3_USE_NEON=1");
            } else {
                try flags.append("-DBLAKE3_USE_NEON=0");
            }
        }

        exe.addCSourceFiles(.{
            .root = c_path,
            .files = files.items,
            .flags = flags.items,
        });
        exe.root_module.valgrind = valgrind;
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
