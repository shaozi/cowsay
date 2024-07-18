const std = @import("std");
const Cowsay = @import("Cowsay.zig");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    //try bw.flush(); // don't forget to flush!

    const message =
        \\try stdout.print("Run `zig build test` to run the tests.\n", .{});
        \\
        \\try bw.flush(); // don't forget to flush!
        \\const a = root.add(2, 3);
        \\try stdout.print("{}", .{a});
        \\try bw.flush();
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) @panic("TEST FAIL");
    }
    var cow = Cowsay{ .writer = stdout.any(), .allocator = gpa.allocator() };
    cow.eyes = [_]u8{ '*', '*' };
    try cow.say("{s}", .{message});
    cow.eyes = [_]u8{ '$', '$' };
    try cow.say("This is a number: {d}", .{100});
    cow.eyes = [_]u8{ '^', '^' };

    try cow.say("something", .{});
    //try cs.useCowFile("bigcow");
    cow.eyes = [_]u8{ 'e', 'e' };
    try cow.say("Hello {s}!\n", .{"world"});

    cow.eyes = [_]u8{ 'z', 'z' };
    try cow.say("Hello {s}!\n", .{"world"});
    cow.useCowFile("cows/cat");
    try cow.say("Hello {s}!\n", .{"meow"});
    cow.useCowFile("cows/tux");
    cow.eyes = [_]u8{ 'o', 'o' };
    try cow.say("Hello {s}!\n", .{"Linux"});
    // use default cow
    cow.useCowFile("");
    try cow.think("Hmm... Hello ... world ...\n", .{});
    cow.useDefaultCow();
    try cow.say("Hello wörld! 你好！", .{});
    cow.useCowFile("cows/cow-utf8");
    try cow.say("Hello world! 🐷", .{});
}
