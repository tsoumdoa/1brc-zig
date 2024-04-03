const std = @import("std");
const Data = struct {
    low: f16,
    high: f16,
    sum: f16,
    count: f16,
};

pub fn main() !void {
    if (.windows == @import("builtin").os.tag) {
        std.debug.print("MMap is not supported in Windows\n", .{});
        return;
    }
    const stdout = std.io.getStdOut().writer();
    const stdo = std.io.getStdOut();
    var bufout = std.io.bufferedWriter(stdo.writer());
    _ = bufout;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    _ = allocator;

    var file = try std.fs.cwd().openFile("./data/measurements.txt", .{});
    defer file.close();

    const file_size = (try file.stat()).size;
    const length = @as(u64, @intCast(file_size));

    const ptr = try std.os.mmap(
        null,
        length,
        std.os.PROT.READ | std.os.PROT.WRITE,
        std.os.MAP.PRIVATE,
        file.handle,
        0,
    );

    defer std.os.munmap(ptr);

    try stdout.print("ptr: {s}\n", .{ptr[0..length]});

    // var buffered = std.io.bufferedReader(file.reader());
    // var reader = buffered.reader();
    //
    // var line = std.ArrayList(u8).init(allocator);
    // var buffered_line_writer = std.io.bufferedWriter(line.writer());
    // _ = buffered_line_writer;
    // defer line.deinit();
    //
    // var line_count: usize = 0;
    //
    // var map = std.StringHashMap(Data).init(allocator);
    // defer map.deinit();

    // while (true) : (line.clearRetainingCapacity()) {
    //     reader.streamUntilDelimiter(line.writer(), '\n', null) catch |err| switch (err) {
    //         error.EndOfStream => break,
    //         else => return err,
    //     };
    //     line_count += 1;
    // if (line_count % 10000000 == 0) {
    // try bufout.writer().print("line: {}\n", .{line_count});
    // }

    // try bufout.writer().print("line: {s}\n", .{line.items});
    // var line_buffer = allocator.dupe(u8, line.items) catch |err| return err;
    // _ = line_buffer;

    // var iter = std.mem.split(u8, line_buffer, ";");
    //
    // const name = iter.next().?;
    // const val = try std.fmt.parseFloat(f16, iter.next().?);
    //
    // const entry = try map.getOrPut(name);
    //
    // if (entry.found_existing) {
    //     if (val < entry.value_ptr.low) {
    //         entry.value_ptr.low = val;
    //     } else if (val > entry.value_ptr.high) {
    //         entry.value_ptr.high = val;
    //     }
    //     entry.value_ptr.sum += val;
    //     entry.value_ptr.count += 1;
    // } else {
    //     entry.value_ptr.low = val;
    //     entry.value_ptr.high = val;
    //     entry.value_ptr.sum = val;
    //     entry.value_ptr.count = 1;
    // }
    // try bufout.writer().print("line: {}\n", .{line_count});
    // }

    // try bufout.writer().print("Hey", .{});
    // var iterator = map.iterator();
    // while (iterator.next()) |entry| {
    //     try stdout.print("{s}={d:.1}/{d:.1}/{d:.1}\n", .{ entry.key_ptr.*, entry.value_ptr.low, entry.value_ptr.sum / entry.value_ptr.count, entry.value_ptr.high });
    // }
    // try stdout.print("line: {d:}\n", .{line_count});
}
