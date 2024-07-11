const std = @import("std");
const testing = std.testing;

const Self = @This();

const default_cow =
    \\^__^
    \\(oo)\_______
    \\(__)\       )\/\
    \\    ||----w |
    \\    ||     ||
;

/// writer for output. must be an AnyWriter. Use `.any()` to convert to AnyWriter before passing in.
writer: std.io.AnyWriter,
/// the eyes. will substitute the first two `o` of the cow
eyes: [2]u8 = [2]u8{ 'o', 'o' },

/// private variables
thinking: bool = false,
max_line_length: u32 = 0,
offset: u32 = 0,
cow_buffer: [1000]u8 = undefined,
cow_buffer_length: usize = 0,

/// Print the cow saying the message. format is same as `std.fmt`
pub fn say(self: *Self, comptime fmt: []const u8, comptime args: anytype) !void {
    self.thinking = false;
    try self.print(fmt, args);
}

/// Print the cow thinking the message. Same as `say` but uses `o` as the tail of the bubble.
pub fn think(self: *Self, comptime fmt: []const u8, comptime args: anytype) !void {
    self.thinking = true;
    try self.print(fmt, args);
}

fn print(self: *Self, comptime fmt: []const u8, comptime args: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const fmtWriter = buffer.writer();
    try std.fmt.format(fmtWriter, fmt, args);
    self.findWidth(buffer.items);

    try self.printHLine();
    try self.printMessage(buffer.items);
    try self.printHLine();
    try self.printCow();
}

fn printHLine(self: *Self) !void {
    try self.writer.writeByte('+');
    try self.writer.writeByteNTimes('-', self.max_line_length + 2);
    try self.writer.writeAll("+\n");
}

fn printMessage(self: Self, s: []const u8) !void {
    var line_len: u32 = 0;
    for (s) |c| {
        if (line_len == 0) {
            try self.writer.writeAll("| ");
        }
        if (c == '\n') {
            try self.writer.writeByteNTimes(' ', self.max_line_length - line_len);
            try self.writer.writeAll(" |");
            line_len = 0;
        } else {
            line_len += 1;
        }
        try self.writer.writeByte(c);
    }
    if (line_len != 0) {
        try self.writer.writeByteNTimes(' ', self.max_line_length - line_len);
        try self.writer.writeAll(" |\n");
    }
}

fn printCow(self: *Self) !void {
    if (self.cow_buffer_length == 0) {
        self.useDefaultCow();
    }
    try self.writer.writeByteNTimes(' ', self.offset);
    var bubblePointer: u8 = '\\';
    if (self.thinking) {
        bubblePointer = 'o';
    }
    try self.writer.writeByte(bubblePointer);
    try self.writer.writeAll("  ");

    var line: u32 = 0;
    var eyeIndex: u8 = 0;
    for (0..self.cow_buffer_length) |i| {
        const c = self.cow_buffer[i];
        if (c == 'o' and eyeIndex < 2) {
            try self.writer.writeByte(self.eyes[eyeIndex]);
            eyeIndex += 1;
        } else try self.writer.writeByte(c);
        if (c == '\n' and i != self.cow_buffer_length - 1) {
            line += 1;
            try self.writer.writeByteNTimes(' ', self.offset);
            if (line == 1) {
                try self.writer.writeByte(' ');
                try self.writer.writeByte(bubblePointer);
                try self.writer.writeByte(' ');
            } else {
                try self.writer.writeAll("   ");
            }
        }
    }
    if (self.cow_buffer[self.cow_buffer_length - 1] != '\n') {
        try self.writer.writeByte('\n');
    }
}

fn findWidth(self: *Self, s: []const u8) void {
    self.max_line_length = 0;
    var count: u32 = 0;
    for (s) |c| {
        if (c == '\n') {
            if (count > self.max_line_length) {
                self.max_line_length = count;
            }
            count = 0;
        } else {
            count += 1;
        }
    }
    if (count > self.max_line_length) {
        self.max_line_length = count;
    }
    self.offset = (self.max_line_length + 4) / 2;
}
// Use a ascii text cow file. file is relative to current working folder.
// If file open or read error, use the default cow.
pub fn useCowFile(self: *Self, filename: []const u8) void {
    const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
        // use default
        self.useDefaultCow();
        _ = err catch {};
        return;
    };
    defer file.close();
    const n_read = file.readAll(&self.cow_buffer) catch |err| {
        // use default
        self.useDefaultCow();
        _ = err catch {};
        return;
    };
    self.cow_buffer_length = n_read;
}
/// Use the default cow
pub fn useDefaultCow(self: *Self) void {
    self.cow_buffer_length = default_cow.len;
    for (default_cow, 0..) |c, i| {
        self.cow_buffer[i] = c;
    }
}

test "test findMax" {
    const s = "";
    var cow = Self{ .writer = undefined };
    cow.findWidth(s);
    try testing.expectEqual(0, cow.max_line_length);
    const s1 = "abc";
    cow.findWidth(s1);
    try testing.expectEqual(3, cow.max_line_length);
    const s2 = "abc\n1234\n123";
    cow.findWidth(s2);
    try testing.expectEqual(4, cow.max_line_length);
}
test "test printHLine" {
    const alloc = testing.allocator;
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();
    const w = buffer.writer().any();
    var cow = Self{ .writer = w };
    cow.findWidth("");
    try cow.printHLine();
    try testing.expectEqualStrings("+--+\n", buffer.items);
    buffer.clearRetainingCapacity();
    cow.findWidth("12345");
    try cow.printHLine();
    try testing.expectEqualStrings("+-------+\n", buffer.items);
}

test "test printContent" {
    const alloc = testing.allocator;
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();
    const w = buffer.writer().any();
    var cow = Self{ .writer = w };
    try cow.printMessage("");
    try testing.expectEqualStrings("", buffer.items);
    buffer.clearRetainingCapacity();
    const s = "abc";
    cow.findWidth(s);
    try cow.printMessage(s);
    try testing.expectEqualStrings("| abc |\n", buffer.items);
    buffer.clearRetainingCapacity();
    const s1 = "abc\n1234";
    cow.findWidth(s1);
    try cow.printMessage(s1);
    try testing.expectEqualStrings("| abc  |\n| 1234 |\n", buffer.items);
    buffer.clearRetainingCapacity();
    const s2 = "abc\n1234\n";
    cow.findWidth(s2);
    try cow.printMessage(s2);
    try testing.expectEqualStrings("| abc  |\n| 1234 |\n", buffer.items);
}

test "cow" {
    const alloc = testing.allocator;
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();
    const w = buffer.writer().any();
    var cow = Self{ .writer = w };
    try cow.say("Hello world!", .{});
    try testing.expectEqualStrings(
        \\+--------------+
        \\| Hello world! |
        \\+--------------+
        \\        \  ^__^
        \\         \ (oo)\_______
        \\           (__)\       )\/\
        \\               ||----w |
        \\               ||     ||
        \\
    , buffer.items);
    buffer.clearRetainingCapacity();
    try cow.think("Hello world!", .{});
    try testing.expectEqualStrings(
        \\+--------------+
        \\| Hello world! |
        \\+--------------+
        \\        o  ^__^
        \\         o (oo)\_______
        \\           (__)\       )\/\
        \\               ||----w |
        \\               ||     ||
        \\
    , buffer.items);
}
