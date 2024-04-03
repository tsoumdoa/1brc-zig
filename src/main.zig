const std = @import("std");
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const Allocator = std.mem.Allocator;

const SharedData = struct {
    mutex: Mutex,
    value: i32,
    map: std.StringHashMap(Data),
    keyArray: std.ArrayList([]u8),

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
            entry.value_ptr.high = @max(val, entry.value_ptr.high);
            entry.value_ptr.sum += val;
            entry.value_ptr.count += 1;
        } else {
            entry.value_ptr.low = val;
            entry.value_ptr.high = val;
            entry.value_ptr.sum = val;
            entry.value_ptr.count = 1;
            try self.keyArray.append(name);
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

    var key_array = std.ArrayList([]u8).init(allocator);
    defer key_array.deinit();

    var shared_data = SharedData{
        .mutex = Mutex{},
        .value = 0,
        .map = map,
        .keyArray = key_array,
    };
    try foldRow(ptr[0..(length - 1)], &shared_data);

    // try stdout.print("shared_data: {d}\n", .{shared_data.value});
    std.mem.sort([]const u8, shared_data.keyArray.items, {}, (struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }).lessThan);

    for (shared_data.keyArray.items) |name| {
        const entry = shared_data.map.get(name).?;
        try stdout.print("{s}={d:.1}/{d:.1}/{d:.1}\n", .{ name, entry.low, entry.sum / entry.count, entry.high });
    }
    //
    // var iterator = shared_data.map.iterator();
    // while (iterator.next()) |entry| {
    //     try stdout.print("{s}={d:.1}/{d:.1}/{d:.1}\n", .{ entry.key_ptr.*, entry.value_ptr.low, entry.value_ptr.sum / entry.value_ptr.count, entry.value_ptr.high });
    // }
}

fn foldRow(ptr: []u8, shared_data: *SharedData) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    _ = allocator;
    // const max_chunk_size = 1_024_000_000;
    // const max_chunk_size = 512_000_000;
    // const max_chunk_size = 256_000_000;
    // const max_chunk_size = 128_000_000;
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
                const name = ptr[prev_line..prev_delimiter];
                const val = ptr[prev_delimiter + 1 .. indx];
                const cast_val = try std.fmt.parseFloat(f16, val);
                try shared_data.addMap(name, cast_val);
                prev_line = indx + 1;
                // shared_data.incrementCount();
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
