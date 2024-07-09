const std = @import("std");
const testing = std.testing;

pub const Cowsay = struct {
    w: std.io.AnyWriter,

    maxLineLength: u32 = 0,
    offset: u32 = 0,
    cowBuffer: [1000]u8 = undefined,
    cowLength: usize = 0,
    eyes: [2]u8 = [2]u8{ 'o', 'o' },

    const defaultCow =
        \\^__^
        \\(oo)\_______
        \\(__)\       )\/\
        \\    ||----w |
        \\    ||     ||
    ;

    pub fn say(self: *Cowsay, comptime fmt: []const u8, comptime args: anytype) !void {
        var buffer = std.ArrayList(u8).init(std.heap.page_allocator);
        defer buffer.deinit();
        const fmtWriter = buffer.writer();
        try std.fmt.format(fmtWriter, fmt, args);
        self.findMax(buffer.items);

        try self.printHLine();
        try self.printContent(buffer.items);
        try self.printHLine();
        try self.printCow();
    }

    pub fn printHLine(self: *Cowsay) !void {
        try self.w.writeByte('+');
        try self.w.writeByteNTimes('-', self.maxLineLength + 2);
        try self.w.writeAll("+\n");
    }

    pub fn printContent(self: *Cowsay, s: []const u8) !void {
        var line_len: u32 = 0;
        for (s) |c| {
            if (line_len == 0) {
                try self.w.writeAll("| ");
            }
            if (c == '\n') {
                try self.w.writeByteNTimes(' ', self.maxLineLength - line_len);
                try self.w.writeAll(" |");
                line_len = 0;
            } else {
                line_len += 1;
            }
            try self.w.writeByte(c);
        }
        if (line_len != 0) {
            try self.w.writeByteNTimes(' ', self.maxLineLength - line_len);
            try self.w.writeAll(" |\n");
        }
    }

    pub fn printCow(self: *Cowsay) !void {
        if (self.cowLength == 0) {
            self.cowLength = defaultCow.len;
            for (defaultCow, 0..) |c, i| {
                self.cowBuffer[i] = c;
            }
        }
        try self.w.writeByteNTimes(' ', self.offset);
        try self.w.writeAll("\\ ");
        var line: u32 = 0;
        var eyeIndex: u8 = 0;
        for (0..self.cowLength) |i| {
            const c = self.cowBuffer[i];
            if (c == 'o' and eyeIndex < 2) {
                try self.w.writeByte(self.eyes[eyeIndex]);
                eyeIndex += 1;
            } else try self.w.writeByte(c);
            if (c == '\n' and i != self.cowLength - 1) {
                line += 1;
                try self.w.writeByteNTimes(' ', self.offset);
                if (line == 1) {
                    try self.w.writeAll(" \\");
                } else {
                    try self.w.writeAll("  ");
                }
            }
        }
        if (self.cowBuffer[self.cowLength - 1] != '\n') {
            try self.w.writeByte('\n');
        }
    }

    pub fn findMax(self: *Cowsay, s: []const u8) void {
        self.maxLineLength = 0;
        var count: u32 = 0;
        for (s) |c| {
            if (c == '\n') {
                if (count > self.maxLineLength) {
                    self.maxLineLength = count;
                }
                count = 0;
            } else {
                count += 1;
            }
        }
        if (count > self.maxLineLength) {
            self.maxLineLength = count;
        }
        self.offset = (self.maxLineLength + 4) / 2;
    }

    pub fn useCowFile(self: *Cowsay, filename: []const u8) !void {
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();
        self.cowLength = try file.readAll(&self.cowBuffer);
    }

    pub fn useCowString(self: *Cowsay, s: []const u8) void {
        for (s, 0..) |c, i| {
            if (i >= 1000) {
                return;
            }
            self.cowBuffer[i] = c;
            self.cowLength += 1;
        }
        std.debug.print("COW LENGTH = {}\n", .{self.cowLength});
    }
};

test "test findMax" {
    const s = "";
    var cow = Cowsay{ .w = undefined };
    cow.findMax(s);
    try testing.expectEqual(0, cow.maxLineLength);
    const s1 = "abc";
    cow.findMax(s1);
    try testing.expectEqual(3, cow.maxLineLength);
    const s2 = "abc\n1234\n123";
    cow.findMax(s2);
    try testing.expectEqual(4, cow.maxLineLength);
}
test "test printHLine" {
    const alloc = testing.allocator;
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();
    const w = buffer.writer().any();
    var cow = Cowsay{ .w = w };
    cow.findMax("");
    try cow.printHLine();
    try testing.expectEqualStrings("+--+\n", buffer.items);
    buffer.clearRetainingCapacity();
    cow.findMax("12345");
    try cow.printHLine();
    try testing.expectEqualStrings("+-------+\n", buffer.items);
}

test "test printContent" {
    const alloc = testing.allocator;
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();
    const w = buffer.writer().any();
    var cow = Cowsay{ .w = w };
    try cow.printContent("");
    try testing.expectEqualStrings("", buffer.items);
    buffer.clearRetainingCapacity();
    const s = "abc";
    cow.findMax(s);
    try cow.printContent(s);
    try testing.expectEqualStrings("| abc |\n", buffer.items);
    buffer.clearRetainingCapacity();
    const s1 = "abc\n1234";
    cow.findMax(s1);
    try cow.printContent(s1);
    try testing.expectEqualStrings("| abc  |\n| 1234 |\n", buffer.items);
    buffer.clearRetainingCapacity();
    const s2 = "abc\n1234\n";
    cow.findMax(s2);
    try cow.printContent(s2);
    try testing.expectEqualStrings("| abc  |\n| 1234 |\n", buffer.items);
}

test "cow" {
    const alloc = testing.allocator;
    var buffer = std.ArrayList(u8).init(alloc);
    defer buffer.deinit();
    const w = buffer.writer().any();
    var cow = Cowsay{ .w = w };
    //cow.useCowString("  |  \n () ");

    try cow.say("Hello World!", .{});
}
