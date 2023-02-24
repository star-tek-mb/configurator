# Overview

Configurator is a template generator

# Purpose

Make my life easier to deploy my apps with nginx

# Build

Tested with Zig `0.11.0-dev.1711+dc1f50e50`

```
zig build
```

Run with

```
zig build run
```

# How to add new config

To add new config look into `main.zig` for example of predefined configurations.

For example your new config will look like:

```zig
pub const NewConfig = struct {
    pub const Template = @embedFile("config.template");

    var1: []const u8 = "default",
    var2: []const u8 = "value",
    var3: []const u8 = "or example",
};
```

Then create and place your `config.template` in `src` directory:
```
var1 = {{var1}}
var2 = {{var2}}
var3 = {{var3}}
```

Don't forget to include your `NewConfig` to list of `Configs` in `main.zig`:

```
pub const Configs = .{ NewConfig, Laravel, Django, Proxy };
```
