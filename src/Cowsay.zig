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
cow: []const u8,

pub fn init(allocator: std.mem.Allocator, writer: std.io.AnyWriter) Self {
    return .{ .allocator = allocator, .writer = writer, .cow = default_cow };
}

pub fn deinit(self: *Self) void {
    self.freeCowMemory();
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
    const widths, const max_width = try self.findWidth(buffer.items);
    defer widths.deinit();
    try self.printHLine(max_width);
    try self.printMessage(buffer.items, widths.items, max_width);
    try self.printHLine(max_width);
    try self.printCow(thinking, (max_width + 4) / 2);
}

fn printHLine(self: *Self, line_width: usize) !void {
    try self.writer.writeByte('+');
    try self.writer.writeByteNTimes('-', line_width + 2);
    try self.writer.writeAll("+\n");
}

fn printMessage(self: *Self, s: []const u8, widths: []const usize, max_width: usize) !void {
    var lines = std.mem.splitScalar(u8, s, '\n');
    var line_index: usize = 0;
    while (lines.next()) |line| : (line_index += 1) {
        try self.writer.writeAll("| ");
        try self.writer.writeAll(line);
        try self.writer.writeByteNTimes(' ', max_width - widths[line_index]);
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

fn findWidth(self: *Self, s: []const u8) !struct { std.ArrayList(usize), usize } {
    const dwd = try DisplayWidth.DisplayWidthData.init(self.allocator);
    defer dwd.deinit();
    var widths = std.ArrayList(usize).init(self.allocator);
    var max_width: usize = 0;
    // The `DisplayWidth` structure takes a pointer to the data.
    const dw = DisplayWidth{ .data = &dwd };
    var lines = std.mem.splitScalar(u8, s, '\n');
    while (lines.next()) |line| {
        const line_len = dw.strWidth(line);
        if (line_len > max_width) {
            max_width = line_len;
        }
        try widths.append(line_len);
    }
    return .{ widths, max_width };
}

/// Use a ascii text cow file. file is relative to current working folder.
pub fn useCowFile(self: *Self, filename: []const u8) !void {
    self.freeCowMemory();
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    self.cow = try file.readToEndAlloc(self.allocator, 1000);
}
/// Use the default cow
pub fn useDefaultCow(self: *Self) void {
    self.freeCowMemory();
    self.cow = default_cow;
}

fn freeCowMemory(self: *Self) void {
    if (self.cow.len > 0 and self.cow.ptr != default_cow) {
        self.allocator.free(self.cow);
    }
}
test findWidth {
    const testcases = [4]struct {
        s: []const u8,
        want_max_width: usize,
        want_widths: []const usize,
    }{
        .{ .s = "", .want_max_width = 0, .want_widths = &.{0} },
        .{ .s = "abc", .want_max_width = 3, .want_widths = &.{3} },
        .{ .s = "abc\n1234\n123", .want_max_width = 4, .want_widths = &.{ 3, 4, 3 } },
        .{ .s = "🐮", .want_max_width = 2, .want_widths = &.{2} },
    };
    for (testcases) |testcase| {
        const allocator = testing.allocator;
        var cow = init(allocator, undefined);
        defer cow.deinit();

        const widths, const max_width = try cow.findWidth(testcase.s);
        defer widths.deinit();

        try testing.expectEqualSlices(usize, testcase.want_widths, widths.items);
        try testing.expectEqual(testcase.want_max_width, max_width);
    }
}

test printHLine {
    const testcases = [2]struct { width: usize, want: []const u8 }{
        .{ .width = 0, .want = "+--+\n" },
        .{ .width = 3, .want = "+-----+\n" },
    };
    for (testcases) |testcase| {
        const allocator = testing.allocator;
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const writer = buffer.writer().any();
        var cow = init(allocator, writer);
        defer cow.deinit();
        try cow.printHLine(testcase.width);
        try testing.expectEqualStrings(testcase.want, buffer.items);
    }
}

test printMessage {
    const testcases = [4]struct { s: []const u8, want: []const u8 }{
        .{ .s = "", .want = "|  |\n" },
        .{ .s = "abc", .want = "| abc |\n" },
        .{ .s = "abc\n1234\n123", .want = "| abc  |\n| 1234 |\n| 123  |\n" },
        .{ .s = "🐮", .want = "| 🐮 |\n" },
    };
    for (testcases) |testcase| {
        const allocator = testing.allocator;
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const writer = buffer.writer().any();
        var cow = init(allocator, writer);
        defer cow.deinit();

        const widths, const max_width = try cow.findWidth(testcase.s);
        defer widths.deinit();

        try cow.printMessage(testcase.s, widths.items, max_width);
        try testing.expectEqualStrings(testcase.want, buffer.items);
    }
}

test say {
    const testcases = [4]struct { s: []const u8 = "", want: []const u8 }{
        .{ .s = "", .want = 
        \\+--+
        \\|  |
        \\+--+
        \\  \  ^__^
        \\   \ (oo)\_______
        \\     (__)\       )\/\
        \\         ||----w |
        \\         ||     ||
        \\
        },
        .{ .s = "abc", .want = 
        \\+-----+
        \\| abc |
        \\+-----+
        \\   \  ^__^
        \\    \ (oo)\_______
        \\      (__)\       )\/\
        \\          ||----w |
        \\          ||     ||
        \\
        },
        .{ .s = "abc\n1234\n123", .want = 
        \\+------+
        \\| abc  |
        \\| 1234 |
        \\| 123  |
        \\+------+
        \\    \  ^__^
        \\     \ (oo)\_______
        \\       (__)\       )\/\
        \\           ||----w |
        \\           ||     ||
        \\
        },
        .{ .s = "🐮", .want = 
        \\+----+
        \\| 🐮 |
        \\+----+
        \\   \  ^__^
        \\    \ (oo)\_______
        \\      (__)\       )\/\
        \\          ||----w |
        \\          ||     ||
        \\
        },
    };
    inline for (testcases) |testcase| {
        const allocator = testing.allocator;
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const writer = buffer.writer().any();
        var cow = init(allocator, writer);
        defer cow.deinit();
        try cow.say(testcase.s, .{});
        try testing.expectEqualStrings(testcase.want, buffer.items);
    }
}

test think {
    const testcases = [4]struct { s: []const u8 = "", want: []const u8 }{
        .{ .s = "", .want = 
        \\+--+
        \\|  |
        \\+--+
        \\  o  ^__^
        \\   o (oo)\_______
        \\     (__)\       )\/\
        \\         ||----w |
        \\         ||     ||
        \\
        },
        .{ .s = "abc", .want = 
        \\+-----+
        \\| abc |
        \\+-----+
        \\   o  ^__^
        \\    o (oo)\_______
        \\      (__)\       )\/\
        \\          ||----w |
        \\          ||     ||
        \\
        },
        .{ .s = "abc\n1234\n123", .want = 
        \\+------+
        \\| abc  |
        \\| 1234 |
        \\| 123  |
        \\+------+
        \\    o  ^__^
        \\     o (oo)\_______
        \\       (__)\       )\/\
        \\           ||----w |
        \\           ||     ||
        \\
        },
        .{ .s = "🐮", .want = 
        \\+----+
        \\| 🐮 |
        \\+----+
        \\   o  ^__^
        \\    o (oo)\_______
        \\      (__)\       )\/\
        \\          ||----w |
        \\          ||     ||
        \\
        },
    };
    inline for (testcases) |testcase| {
        const allocator = testing.allocator;
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const writer = buffer.writer().any();
        var cow = init(allocator, writer);
        defer cow.deinit();
        try cow.think(testcase.s, .{});
        try testing.expectEqualStrings(testcase.want, buffer.items);
    }
}

test useCowFile {
    const allocator = testing.allocator;
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    const writer = buffer.writer().any();
    var cow = init(allocator, writer);
    defer cow.deinit();

    try cow.useCowFile("cows/cat");
    try cow.say("Hello meow!", .{});
    try testing.expectEqualStrings(
        \\+-------------+
        \\| Hello meow! |
        \\+-------------+
        \\       \   /\___/\
        \\        \ (= ^.^ =)
        \\           (") (")__/
        \\
    , buffer.items);
    cow.useDefaultCow();
    buffer.clearRetainingCapacity();

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
}
