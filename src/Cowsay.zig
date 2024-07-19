const std = @import("std");
const DisplayWidth = @import("DisplayWidth");

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
/// allocator is used for formatting.
allocator: std.mem.Allocator,

/// the eyes. will substitute the first two `o` of the cow
eyes: ?[2]u8 = null,

/// private variables
thinking: bool = false,
max_line_length: usize = 0,
offset: usize = 0,
cow: []const u8,

/// Initialize a Cowsay struct.
pub fn init(
    allocator: std.mem.Allocator,
    writer: std.io.AnyWriter,
    cow_file: ?[]const u8,
) !Self {
    var result: Self = .{
        .allocator = allocator,
        .writer = writer,
        .cow = default_cow,
    };
    if (cow_file) |file| {
        const f = try std.fs.cwd().openFile(file, .{});
        defer f.close();
        result.cow = try f.readToEndAlloc(allocator, 1000);
    }
    return result;
}

pub fn deinit(self: *Self) void {
    // Check that internal cow slice does not point to static text addresses.
    if (self.cow.len > 0 and self.cow.ptr != default_cow) {
        self.allocator.free(self.cow);
    }
    self.* = undefined;
}

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
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    const fmt_writer = buffer.writer();
    try std.fmt.format(fmt_writer, fmt, args);

    var line_width_list = try self.findWidth(buffer.items, allocator);
    defer line_width_list.deinit();

    try self.printHLine();
    try self.printMessage(buffer.items, line_width_list.items);
    try self.printHLine();
    try self.printCow();
}

fn printHLine(self: *Self) !void {
    try self.writer.writeByte('+');
    try self.writer.writeByteNTimes('-', self.max_line_length + 2);
    try self.writer.writeAll("+\n");
}

fn printMessage(self: *Self, s: []const u8, sizes: []usize) !void {
    //var pw = DisplayWidth{ .data = pdwd };
    var lines = std.mem.splitScalar(u8, s, '\n');
    var line_index: usize = 0;
    while (lines.next()) |line| : (line_index += 1) {
        if (sizes[line_index] == 0) {
            continue;
        }
        try self.writer.writeAll("| ");
        try self.writer.writeAll(line);
        //const line_len = pw.strWidth(line);
        try self.writer.writeByteNTimes(' ', self.max_line_length - sizes[line_index]);
        try self.writer.writeAll(" |\n");
    }
}

fn printCow(self: *Self) !void {
    if (self.cow.len == 0) {
        self.useDefaultCow();
    }
    const bubble_tail: u8 = if (self.thinking) 'o' else '\\';
    var cow_lines = std.mem.splitScalar(u8, self.cow, '\n');
    var line_index: usize = 0;
    var eye_index: u8 = 0;
    while (cow_lines.next()) |line| : (line_index += 1) {
        try self.writer.writeByteNTimes(' ', self.offset);
        if (line_index == 0) {
            try self.writer.writeByte(bubble_tail);
            try self.writer.writeAll("  ");
        } else if (line_index == 1) {
            try self.writer.writeByte(' ');
            try self.writer.writeByte(bubble_tail);
            try self.writer.writeByte(' ');
        } else {
            try self.writer.writeAll("   ");
        }
        if (self.eyes) |eyes| {
            if (eye_index < 2) {
                // replace eyes
                for (line) |c| {
                    if (eye_index < 2 and c == 'o') {
                        try self.writer.writeByte(eyes[eye_index]);
                        eye_index += 1;
                    } else {
                        try self.writer.writeByte(c);
                    }
                }
            } else {
                try self.writer.writeAll(line);
            }
        } else {
            try self.writer.writeAll(line);
        }
        try self.writer.writeByte('\n');
    }
}

fn findWidth(self: *Self, s: []const u8, allocator: std.mem.Allocator) !std.ArrayList(usize) {
    const dwd = try DisplayWidth.DisplayWidthData.init(allocator);
    defer dwd.deinit();
    self.max_line_length = 0;
    // The `DisplayWidth` structure takes a pointer to the data.
    const dw = DisplayWidth{ .data = &dwd };
    var line_width = std.ArrayList(usize).init(allocator);
    var lines = std.mem.splitScalar(u8, s, '\n');
    while (lines.next()) |line| {
        const line_len = dw.strWidth(line);
        if (line_len > self.max_line_length) {
            self.max_line_length = line_len;
        }
        try line_width.append(line_len);
    }
    self.offset = (self.max_line_length + 4) / 2;
    return line_width;
}
// Use a ascii text cow file. file is relative to current working folder.
// If file open or read error, use the default cow.
pub fn useCowFile(self: *Self, filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    if (self.cow.len > 0 and self.cow.ptr != default_cow) {
        self.allocator.free(self.cow);
    }
    self.cow = try file.readToEndAlloc(self.allocator, 1000);
}
/// Use the default cow
pub fn useDefaultCow(self: *Self) void {
    if (self.cow.len > 0 and self.cow.ptr != default_cow) {
        self.allocator.free(self.cow);
    }
    self.cow = default_cow;
}

test "test findWidth" {
    const s = "";
    var cow = try Self.init(testing.allocator, undefined, null);
    defer cow.deinit();
    const widths = try cow.findWidth(s, testing.allocator);
    defer widths.deinit();

    try testing.expectEqualSlices(usize, &[_]usize{0}, widths.items);
    try testing.expectEqual(0, cow.max_line_length);
    const s1 = "abc";
    const widths1 = try cow.findWidth(s1, testing.allocator);
    defer widths1.deinit();

    try testing.expectEqualSlices(usize, &[_]usize{3}, widths1.items);
    try testing.expectEqual(3, cow.max_line_length);
    const s2 = "abc\n1234\n123";
    const widths2 = try cow.findWidth(s2, testing.allocator);
    defer widths2.deinit();

    try testing.expectEqualSlices(usize, &[_]usize{ 3, 4, 3 }, widths2.items);
    try testing.expectEqual(4, cow.max_line_length);
    // unicode
    const s3 = "🐮";
    const widths3 = try cow.findWidth(s3, testing.allocator);
    defer widths3.deinit();

    try testing.expectEqualSlices(usize, &[_]usize{2}, widths3.items);
    try testing.expectEqual(2, cow.max_line_length);
}
test "test printHLine" {
    const alloc = testing.allocator;
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();
    const w = buffer.writer().any();
    var cow = try Self.init(alloc, w, null);
    defer cow.deinit();
    const widths = try cow.findWidth("", testing.allocator);
    defer widths.deinit();

    try testing.expectEqual(0, cow.max_line_length);
    try testing.expectEqualSlices(usize, &[_]usize{0}, widths.items);
    try cow.printHLine();
    try testing.expectEqualStrings("+--+\n", buffer.items);
    buffer.clearRetainingCapacity();
    const widths1 = try cow.findWidth("12345", testing.allocator);
    defer widths1.deinit();

    try testing.expectEqualSlices(usize, &[_]usize{5}, widths1.items);
    try cow.printHLine();
    try testing.expectEqualStrings("+-------+\n", buffer.items);
}

test "test printMessage 1" {
    const alloc = testing.allocator;
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();
    const w = buffer.writer().any();
    var cow = try Self.init(alloc, w, null);
    defer cow.deinit();
    const s = "";
    const widths = try cow.findWidth(s, testing.allocator);
    defer widths.deinit();
    try cow.printMessage(s, widths.items);
    try testing.expectEqualStrings("", buffer.items);
}

test "test printMessage 2" {
    const alloc = testing.allocator;
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();
    const w = buffer.writer().any();
    var cow = try Self.init(alloc, w, null);
    defer cow.deinit();
    const s = "abc";
    const widths = try cow.findWidth(s, testing.allocator);
    defer widths.deinit();
    try cow.printMessage(s, widths.items);
    try testing.expectEqualStrings("| abc |\n", buffer.items);
}

test "test printMessage 3" {
    const alloc = testing.allocator;
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();
    const w = buffer.writer().any();
    var cow = try Self.init(alloc, w, null);
    defer cow.deinit();
    const s = "abc\n1234";
    const widths = try cow.findWidth(s, testing.allocator);
    defer widths.deinit();
    try cow.printMessage(s, widths.items);
    try testing.expectEqualStrings("| abc  |\n| 1234 |\n", buffer.items);
}

test "test printMessage 4" {
    const alloc = testing.allocator;
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();
    const w = buffer.writer().any();
    var cow = try Self.init(alloc, w, null);
    defer cow.deinit();
    const s = "abc\n1234\n";
    const widths = try cow.findWidth(s, testing.allocator);
    defer widths.deinit();
    try cow.printMessage(s, widths.items);
    try testing.expectEqualStrings("| abc  |\n| 1234 |\n", buffer.items);
}

test "cow" {
    const alloc = testing.allocator;
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();
    const w = buffer.writer().any();
    var cow = try Self.init(alloc, w, null);
    defer cow.deinit();
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
