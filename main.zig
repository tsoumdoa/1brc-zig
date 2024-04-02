const std = @import("std");
const Data = struct {
    low: f16,
    high: f16,
    sum: f16,
    count: f16,
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var file = try std.fs.cwd().openFile("./data/measurements.txt", .{});
    defer file.close();

    var buffered = std.io.bufferedReader(file.reader());
    var reader = buffered.reader();

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();

    var line_count: usize = 0;

    var map = std.StringHashMap(Data).init(allocator);
    defer map.deinit();

    while (true) {
        reader.streamUntilDelimiter(line.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        defer line.clearRetainingCapacity();
        line_count += 1;
        var line_buffer = allocator.dupe(u8, line.items) catch |err| return err;
        var iter = std.mem.split(u8, line_buffer, ";");

        const name = iter.next().?;
        const val = try std.fmt.parseFloat(f16, iter.next().?);

        const entry = try map.getOrPut(name);

        if (entry.found_existing) {
            if (val < entry.value_ptr.low) {
                entry.value_ptr.low = val;
            } else if (val > entry.value_ptr.high) {
                entry.value_ptr.high = val;
            }
            entry.value_ptr.sum += val;
            entry.value_ptr.count += 1;
        } else {
            entry.value_ptr.low = val;
            entry.value_ptr.high = val;
            entry.value_ptr.sum = val;
            entry.value_ptr.count = 1;
        }
    }

    var iterator = map.iterator();
    while (iterator.next()) |entry| {
        try stdout.print("{s}={d:.1}/{d:.1}/{d:.1}\n", .{ entry.key_ptr.*, entry.value_ptr.low, entry.value_ptr.sum / entry.value_ptr.count, entry.value_ptr.high });
    }
}
