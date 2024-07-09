const std = @import("std");
const cowsay = @import("cowsay.zig");

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
    var cs = cowsay.Cowsay{ .w = stdout.any() };
    cs.eyes = [_]u8{ '*', '*' };
    try cs.say("{s}", .{message});
    cs.eyes = [_]u8{ '$', '$' };
    try cs.say("This is a number: {d}", .{100});
    cs.eyes = [_]u8{ '^', '^' };

    try cs.say("something", .{});
    //try cs.useCowFile("bigcow");
    cs.eyes = [_]u8{ 'e', 'e' };
    try cs.say("Hello {s}!\n", .{"world"});

    cs.eyes = [_]u8{ 'z', 'z' };
    try cs.say("Hello {s}!\n", .{"world"});
    try cs.useCowFile("cows/cat");
    try cs.say("Hello {s}!\n", .{"meow"});
    try cs.useCowFile("cows/tux");
    cs.eyes = [_]u8{ 'o', 'o' };
    try cs.say("Hello {s}!\n", .{"Linux"});
}
