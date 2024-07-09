# Cowsay

A simple library generates an ascii cow says a message.

## Basic usage

```zig
const stdout = std.io.getStdOut().writer();
var cow = cowsay.Cowsay{ .w = stdout.any() };
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

## Eyes

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

## Load file

```zig
try cow.useFile("cat");
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
