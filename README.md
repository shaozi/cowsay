# Cowsay

This is a simple zig library that mimic the ascii art [**cowsay**](https://en.wikipedia.org/wiki/Cowsay) .

## Install

1. Use the `zig fetch` command to fetch and save the library: 
   - Fetch the latest: `zig fetch --save git+https://github.com/shaozi/cowsay`
   - or, fetch a specific version: `zig fetch --save https://github.com/shaozi/cowsay/archive/refs/tags/v0.0.1.tar.gz`
1. Add the module to you own `build.zig` file:
   - Add these lines right before the line `b.installArtifact(exe);`:
     ```zig
     const cowsay = b.dependency("cowsay", .{});
     exe.root_module.addImport("cowsay", cowsay.module("cowsay"));
     ```
1. Import it in your zig file:
   ```zig
   const Cowsay = @import("cowsay").Cowsay;
   ```

## Usage

### Basic usage

```zig
const stdout = std.io.getStdOut().writer();
var cow = Cowsay{ .w = stdout.any() };
try cow.say("Hello {s}", .{"world"});
```

Output:

```text
+--------------+
| Hello world! |
+--------------+
        \ ^__^
         \(oo)\_______
          (__)\       )\/\
              ||----w |
              ||     ||
```

> [!NOTE]
>
> Cowsay takes type `std.io.AnyWriter`. Therefore, you must use the `.any()` to
> convert a writer before pass it in. This allows you to use an ArrayList(u8) to
> let cowsay write output to a string.

### Eyes

```zig
cow.eyes = [_]u8{ '$', '$' };
```

Output:

```text
+--------------+
| Hello world! |
+--------------+
        \ ^__^
         \($$)\_______
          (__)\       )\/\
              ||----w |
              ||     ||
```
> [!NOTE]
>
> The first two `o` in the file are eyes.

### Load an ASCII cow file

```zig
cow.useFile("cat");
```

Output

```text
+-------------+
| Hello meow! |
+-------------+
       \  /\___/\
        \(= ^.^ =)
          (") (")__/
```

If the file read failed, it will revert back to the default cow.
You can use `.useFile("")` or `.useDefaultCow()` to reset the cow.

> [!NOTE]
> - Cow file is simple text file of the ascii image, without the `\` bubble pointer.
> - Max length of the file is 1000 bytes.

### Cow think

```zig
try cow.think("Hmm... Hello ... world ...", .{});
```

Output

```text
+----------------------------+
| Hmm... Hello ... world ... |
+----------------------------+
               o  ^__^
                o (oo)\_______
                  (__)\       )\/\
                      ||----w |
                      ||     ||
```

### Write to an `ArrayList`, out as a string

```zig
var buffer = std.ArrayList(u8).init(std.heap.page_allocator);
defer buffer.deinit();
const w = buffer.writer().any();
var cow = Cowsay{ .w = w };
try cow.say("Hello world!", .{});
try stdout.print("{s}", buffer.items);
```