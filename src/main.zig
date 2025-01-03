const std = @import("std");
const config = @import("config");
const blake3 = @import("./root.zig");
const cblake3 = @import("c-blake3");

fn run() !void {
    const stdout = std.io.getStdOut();
    if (std.os.argv.len != 2) {
        return error.OneArgRequired;
    }
    const fd = try std.posix.openZ(std.os.argv[1], .{}, undefined);
    defer std.posix.close(fd);

    const stat = try std.posix.fstat(fd);

    const area = try std.posix.mmap(null, @intCast(stat.size), 1, .{ .TYPE = .PRIVATE }, fd, 0);
    defer std.posix.munmap(area);

    var out: [32]u8 = undefined;

    std.valgrind.callgrind.startInstrumentation();
    if (config.c) {
        var hasher: cblake3.blake3_hasher = undefined;
        cblake3.blake3_hasher_init(&hasher);
        cblake3.blake3_hasher_update(&hasher, area.ptr, area.len);
        cblake3.blake3_hasher_finalize(&hasher, &out, out.len);
    } else if (config.std) {
        std.crypto.hash.Blake3.hash(area, &out, .{});
    } else {
        blake3.Blake3(.{}).hash(area, &out, .{});
    }
    std.valgrind.callgrind.stopInstrumentation();

    try stdout.writer().print("{s}\n", .{std.fmt.bytesToHex(out, .lower)});
}

pub fn main() u8 {
    const stderr = std.io.getStdErr();
    run() catch |err| {
        stderr.writer().print("Error: {}\n", .{err}) catch unreachable;
        return 1;
    };
    return 0;
}
