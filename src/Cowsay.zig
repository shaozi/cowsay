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
    try self.print(false, fmt, args);
}

/// Print the cow thinking the message. Same as `say` but uses `o` as the tail of the bubble.
pub fn think(self: *Self, comptime fmt: []const u8, comptime args: anytype) !void {
    try self.print(true, fmt, args);
}

fn print(self: *Self, thinking: bool, comptime fmt: []const u8, comptime args: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    const fmt_writer = buffer.writer();
    try std.fmt.format(fmt_writer, fmt, args);

    const line_widths, const max_line_width = try self.findWidth(buffer.items);
    defer line_widths.deinit();

    try self.printHLine(max_line_width);
    try self.printMessage(buffer.items, line_widths.items, max_line_width);
    try self.printHLine(max_line_width);

    const offset = (max_line_width + 4) / 2;
    try self.printCow(thinking, offset);
}

fn printHLine(self: *Self, width: usize) !void {
    try self.writer.writeByte('+');
    try self.writer.writeByteNTimes('-', width + 2);
    try self.writer.writeAll("+\n");
}

fn printMessage(
    self: *Self,
    s: []const u8,
    line_widths: []const usize,
    max_line_width: usize,
) !void {
    //var pw = DisplayWidth{ .data = pdwd };
    var lines = std.mem.splitScalar(u8, s, '\n');
    var line_index: usize = 0;
    while (lines.next()) |line| : (line_index += 1) {
        if (line_widths[line_index] == 0) {
            continue;
        }
        try self.writer.writeAll("| ");
        try self.writer.writeAll(line);
        //const line_len = pw.strWidth(line);
        try self.writer.writeByteNTimes(
            ' ',
            max_line_width - line_widths[line_index],
        );
        try self.writer.writeAll(" |\n");
    }
}

fn printCow(self: *Self, thinking: bool, offset: usize) !void {
    if (self.cow.len == 0) {
        self.useDefaultCow();
    }
    const bubble_tail: u8 = if (thinking) 'o' else '\\';
    var cow_lines = std.mem.splitScalar(u8, self.cow, '\n');
    var line_index: usize = 0;
    var eye_index: u8 = 0;
    while (cow_lines.next()) |line| : (line_index += 1) {
        try self.writer.writeByteNTimes(' ', offset);
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

fn findWidth(self: *Self, s: []const u8) !struct {
    std.ArrayList(usize),
    usize,
} {
    const dwd = try DisplayWidth.DisplayWidthData.init(self.allocator);
    defer dwd.deinit();
    var max_line_width: usize = 0;
    // The `DisplayWidth` structure takes a pointer to the data.
    const dw = DisplayWidth{ .data = &dwd };
    var line_widths = std.ArrayList(usize).init(self.allocator);
    var lines = std.mem.splitScalar(u8, s, '\n');
    while (lines.next()) |line| {
        const line_len = dw.strWidth(line);
        if (line_len > max_line_width) {
            max_line_width = line_len;
        }
        try line_widths.append(line_len);
    }
    return .{ line_widths, max_line_width };
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

test findWidth {
    const s = "";
    var cow = try Self.init(testing.allocator, undefined, null);
    defer cow.deinit();
    const widths, const max_width = try cow.findWidth(s);
    defer widths.deinit();

    try testing.expectEqualSlices(usize, &[_]usize{0}, widths.items);
    try testing.expectEqual(0, max_width);
    const s1 = "abc";
    const widths1, const max_width1 = try cow.findWidth(s1);
    defer widths1.deinit();

    try testing.expectEqualSlices(usize, &[_]usize{3}, widths1.items);
    try testing.expectEqual(3, max_width1);
    const s2 = "abc\n1234\n123";
    const widths2, const max_width2 = try cow.findWidth(s2);
    defer widths2.deinit();

    try testing.expectEqualSlices(usize, &[_]usize{ 3, 4, 3 }, widths2.items);
    try testing.expectEqual(4, max_width2);
    // unicode
    const s3 = "🐮";
    const widths3, const max_width3 = try cow.findWidth(s3);
    defer widths3.deinit();

    try testing.expectEqualSlices(usize, &[_]usize{2}, widths3.items);
    try testing.expectEqual(2, max_width3);
}

test printHLine {
    const alloc = testing.allocator;
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();
    const w = buffer.writer().any();
    var cow = try Self.init(alloc, w, null);
    defer cow.deinit();
    const widths, const max_width = try cow.findWidth("");
    defer widths.deinit();

    try testing.expectEqual(0, max_width);
    try testing.expectEqualSlices(usize, &[_]usize{0}, widths.items);
    try cow.printHLine(max_width);
    try testing.expectEqualStrings("+--+\n", buffer.items);
    buffer.clearRetainingCapacity();
    const widths1, const max_width1 = try cow.findWidth("12345");
    defer widths1.deinit();

    try testing.expectEqualSlices(usize, &[_]usize{5}, widths1.items);
    try cow.printHLine(max_width1);
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
    const widths, const max_width = try cow.findWidth(s);
    defer widths.deinit();
    try cow.printMessage(s, widths.items, max_width);
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
    const widths, const max_width = try cow.findWidth(s);
    defer widths.deinit();
    try cow.printMessage(s, widths.items, max_width);
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
    const widths, const max_width = try cow.findWidth(s);
    defer widths.deinit();
    try cow.printMessage(s, widths.items, max_width);
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
    const widths, const max_width = try cow.findWidth(s);
    defer widths.deinit();
    try cow.printMessage(s, widths.items, max_width);
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
