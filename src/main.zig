const std = @import("std");
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const Allocator = std.mem.Allocator;

const SharedData = struct {
    mutex: Mutex,
    value: i32,
    map: std.StringHashMap(Data),

    pub fn incrementCount(self: *SharedData) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.value += 1;
    }

    pub fn addMap(self: *SharedData, name: []u8, val: f16) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const entry = try self.map.getOrPut(name);
        if (entry.found_existing) {
            entry.value_ptr.low = @min(val, entry.value_ptr.low);
            entry.value_ptr.high = @min(val, entry.value_ptr.high);
            entry.value_ptr.sum += val;
            entry.value_ptr.count += 1;
        } else {
            entry.value_ptr.low = val;
            entry.value_ptr.high = val;
            entry.value_ptr.sum = val;
            entry.value_ptr.count = 1;
        }
    }
};

const Data = struct { low: f16, high: f16, sum: f16, count: f16 };

pub fn main() !void {
    if (.windows == @import("builtin").os.tag) {
        std.debug.print("MMap is not supported in Windows\n", .{});
        return;
    }
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

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
    var map = std.StringHashMap(Data).init(allocator);
    defer map.deinit();
    var shared_data = SharedData{
        .mutex = Mutex{},
        .value = 0,
        .map = map,
    };
    try foldRow(ptr[0..(length - 1)], &shared_data);
    shared_data.value += 1;

    try stdout.print("shared_data: {d}\n", .{shared_data.value});

    var iterator = shared_data.map.iterator();
    while (iterator.next()) |entry| {
        try stdout.print("{s}={d:.1}/{d:.1}/{d:.1}\n", .{ entry.key_ptr.*, entry.value_ptr.low, entry.value_ptr.sum / entry.value_ptr.count, entry.value_ptr.high });
    }
}

fn foldRow(ptr: []u8, shared_data: *SharedData) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // const max_chunk_size = 256_000_000;
    const max_chunk_size = 64_000_000;
    // const max_chunk_size = 32_000_000;
    // const max_chunk_size = 16_000_000;
    const stdout = std.io.getStdOut().writer();
    _ = stdout;

    var prev_line: usize = 0;
    var prev_delimiter: usize = 0;
    if (ptr.len < max_chunk_size) {
        for (ptr, 0..) |c, indx| {
            if (c == ';') {
                prev_delimiter = indx;
            }
            if (c == '\n') {
                // const name = ptr[prev_line..prev_delimiter];
                // var name = allocator.dupe(u8, ptr[prev_line..prev_delimiter]) catch |err| return err;
                // _ = name;
                // var val = allocator.dupe(u8, ptr[prev_delimiter + 1 .. indx]) catch |err| return err;
                var line = allocator.dupe(u8, ptr[prev_line..indx]) catch |err| return err;
                // defer allocator.free(line);
                // try stdout.print("line: {}\n", .{line.len});

                var iter = std.mem.split(u8, line, ";");
                const name = iter.next().?;
                _ = name;
                const val = try std.fmt.parseFloat(f16, iter.next().?);
                //
                // try stdout.print("name: {s}\n", .{name});
                // var val = ptr.ptr[prev_delimiter + 1 .. indx];
                // const cast_val = try std.fmt.parseFloat(f16, val);
                // _ = cast_val;
                try shared_data.addMap(ptr[prev_line..prev_delimiter], val);
                prev_line = indx + 1;
                shared_data.incrementCount();
            }
        }
        return;
    }

    var mid = ptr.len / 2;

    while (ptr[mid] != '\n') : (mid += 1) {}

    {
        const t1 = try std.Thread.spawn(.{}, foldRow, .{ ptr[0..mid], shared_data });
        defer t1.join();
        const t2 = try std.Thread.spawn(.{}, foldRow, .{ ptr[mid + 1 ..], shared_data });
        defer t2.join();
    }
}
