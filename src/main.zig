const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Laravel = struct {
    pub const Template = @embedFile("laravel.template");

    domain: []const u8 = "example.com",
    public_root: []const u8 = "/var/www/laravel/public",
    php_version: []const u8 = "8.1",
};

pub const Django = struct {
    pub const Template = @embedFile("django.template");

    domain: []const u8 = "example.com",
    address: []const u8 = "http://127.0.0.1:8080",
    root: []const u8 = "/path/to/django/root",
};

pub const Proxy = struct {
    pub const Template = @embedFile("proxy.template");

    domain: []const u8 = "example.com",
    address: []const u8 = "http://127.0.0.1:8080",
};

pub const Configs = .{ Laravel, Django, Proxy };

/// caller owns memory, free with `freeConfig`
pub fn promptConfig(allocator: Allocator, comptime T: type) !T {
    var config: T = undefined;
    inline for (@typeInfo(T).Struct.fields) |field| {
        const default = if (field.default_value == null) "" else @ptrCast(*align(1) const [:0]const u8, field.default_value.?).*;
        try std.io.getStdOut().writer().print("{s} ({s}): ", .{ field.name, default });
        @field(config, field.name) = try std.io.getStdIn().reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(u16));
        if (@field(config, field.name).len == 0) {
            @field(config, field.name) = try allocator.dupe(u8, default);
        }
    }
    return config;
}

pub fn freeConfig(allocator: Allocator, config: anytype) void {
    inline for (@typeInfo(@TypeOf(config)).Struct.fields) |field| {
        allocator.free(@field(config, field.name));
    }
}

/// caller owns memory, free with `allocator.free`
pub fn generateConfig(allocator: Allocator, config: anytype) ![]const u8 {
    var tmpl = try allocator.dupe(u8, @TypeOf(config).Template);
    defer allocator.free(tmpl);

    var buf = try std.ArrayListUnmanaged(u8).initCapacity(allocator, tmpl.len);

    var last_index: usize = 0;
    while (true) {
        const template_begin = (std.mem.indexOf(u8, tmpl[last_index..], "{{") orelse break) + last_index;
        const template_end = (std.mem.indexOf(u8, tmpl[template_begin..], "}}") orelse return error.TemplateNotClosed) + template_begin;
        const template_var = tmpl[template_begin + 2 .. template_end];

        try buf.appendSlice(allocator, tmpl[last_index..template_begin]);
        inline for (@typeInfo(@TypeOf(config)).Struct.fields) |field| {
            if (std.mem.eql(u8, template_var, field.name)) {
                try buf.appendSlice(allocator, @field(config, field.name));
            }
        }
        last_index = template_end + 2;
    }
    try buf.appendSlice(allocator, tmpl[last_index..]);

    return buf.toOwnedSlice(allocator);
}

pub fn main() !void {
    inline for (Configs, 1..) |config, i| {
        const compileName = @typeName(config);
        const last = (std.mem.lastIndexOfScalar(u8, compileName, '.') orelse return error.InternalError) + 1;
        try std.io.getStdOut().writer().print("{d}: {s}\n", .{ i, compileName[last..] });
    }
    try std.io.getStdOut().writer().print("Choose config: ", .{});
    var read_buf: [10]u8 = undefined;
    var read_str = try std.io.getStdIn().reader().readUntilDelimiter(&read_buf, '\n');
    var read_int = try std.fmt.parseInt(u32, read_str, 10);
    if (read_int <= 0 or read_int > Configs.len) {
        try std.io.getStdOut().writer().print("Invalid config\n", .{});
        return;
    }

    inline for (Configs, 1..) |config, i| {
        if (i == read_int) {
            var conf = try promptConfig(std.heap.page_allocator, config);
            defer freeConfig(std.heap.page_allocator, conf);
            var out = try generateConfig(std.heap.page_allocator, conf);
            defer std.heap.page_allocator.free(out);
            try std.io.getStdOut().writer().print("\x1B[2J\x1B[2J{s}\n", .{out});
        }
    }
}
