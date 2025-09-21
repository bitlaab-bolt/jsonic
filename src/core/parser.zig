const std = @import("std");
const fmt = std.fmt;
const json = std.json;
const Parsed = json.Parsed;
const Allocator = std.mem.Allocator;


const Str = []const u8;

pub const Static = struct {
    /// # Parses JSON String into a Given Structure
    /// **WARNING:** You must call `jsonic.free()` on parsed result.
    pub fn parse(comptime T: type, heap: Allocator, data: Str) !T {
        const parsed: Parsed(T) = try json.parseFromSlice(T, heap, data, .{});
        defer parsed.deinit();

        return try deepCopy(heap, parsed.value);
    }

    /// # Stringifies a Given Structure into JSON String
    /// **WARNING:** Return value must be freed by the caller.
    pub fn stringify(heap: Allocator, value: anytype) ![]u8 {
        var out = std.Io.Writer.Allocating.init(heap);
        errdefer out.deinit();

        var stringify_json = json.Stringify {
            .writer = &out.writer, .options = .{.whitespace = .minified}
        };

        try stringify_json.write(value);
        return try out.toOwnedSlice();
    }
};

pub const Dynamic = struct {
    const Value = json.Value;
    const Option = json.ParseOptions;

    parsed: json.Parsed(Value),

    /// # Initializes Dynamic JSON Data from a Given Source
    pub fn init(heap: Allocator, src: Str, opt: Option) !Dynamic {
        const parsed = try json.parseFromSlice(Value, heap, src, opt);
        return .{.parsed = parsed};
    }

    /// # Destroys Dynamic JSON Data
    pub fn deinit(self: *Dynamic) void { self.parsed.deinit(); }

    /// # Returns Parsed JSON `Value`
    pub fn data(self: *const Dynamic) Value { return self.parsed.value; }

    /// # Parses Dynamic JSON Value into a Given Structure
    /// **WARNING:** You must call `jsonic.free()` on parsed result.
    pub fn parseInto(
        comptime T: type,
        heap: Allocator,
        src: Value,
        opt: Option
    ) !T {
        const parsed = try json.parseFromValue(T, heap, src, opt);
        defer parsed.deinit();

        return try deepCopy(heap, parsed.value);
    }
};

/// # Frees the Parsed Result
/// - `result` - Return value of the `parse()` and `parseInto()`.
pub fn free(heap: Allocator, result: anytype) !void {
    try deepFree(heap, result);
}

fn deepCopy(heap: Allocator, src: anytype) !@TypeOf(src) {
    var dest: @TypeOf(src) = undefined;

    switch (@typeInfo(@TypeOf(src))) {
        .@"struct" => |s| {
            inline for (s.fields) |field| {
                const value = @field(src, field.name);
                const v = try copyFieldValue(heap, @TypeOf(value), value);
                @field(dest, field.name) = v;
            }
        },
        .@"union" => {
            const active_tag = std.meta.activeTag(src);
            switch (active_tag) {
                inline else => |tag| {
                    const value = @field(src, @tagName(tag));
                    const v = try copyFieldValue(heap, @TypeOf(value), value);
                    dest = @unionInit(@TypeOf(src), @tagName(tag), v);
                },
            }
        },
        .pointer => |p| {
            if (p.is_const and p.size == .slice) {
                const slice = try heap.alloc(p.child, src.len);

                var i: usize = 0;
                while (i < src.len) : (i += 1) {
                    const value = src[i];
                    slice[i] = try copyFieldValue(heap, @TypeOf(value), value);
                }

                dest = slice;
            } else {
                const t_name = @typeName(p.child);
                const err_str = "jsonic: Use `[]const {s}` Instead";
                @compileError(fmt.comptimePrint(err_str, .{t_name}));
            }
        },
        else => {
            const t_name = @typeName(@TypeOf(src));
            const err_str = "Jsonic: Unsupported Type `{s}`";
            @compileError(fmt.comptimePrint(err_str, .{t_name}));
        }
    }

    return dest;
}

fn copyFieldValue(heap: Allocator, comptime T: type, value: T) !T {
    switch (@typeInfo(T)) {
        .bool, .@"enum" => return value,
        .int => |n| {
            if (n.bits <= 53) return value
            else {
                const err_str = "jsonic: Unsupported Type `{s}`. Exceeds IEEE 754 double-precision floating-point boundary!";
                @compileError(fmt.comptimePrint(err_str, .{@typeName(T)}));
            }
        },
        .float => |f| {
            if (f.bits == 64) return value
            else @compileError("jsonic: Use only `f64` Instead");
        },
        .@"struct", .@"union" => return try deepCopy(heap, value),
        .pointer => return try deepCopy(heap, value),
        .optional => |o| {
            if (value == null) return value
            else return try copyFieldValue(heap, o.child, value.?);
        },
        else => {
            const err_str = "jsonic: Unsupported Field Type `{s}`";
            @compileError(fmt.comptimePrint(err_str, .{@typeName(T)}));
        }
    }
}

fn deepFree(heap: Allocator, src: anytype) !void {
    switch (@typeInfo(@TypeOf(src))) {
        .@"struct" => |s| {
            inline for (s.fields) |field| {
                const value = @field(src, field.name);
                try freeFieldValue(heap, @TypeOf(value), value);
            }
        },
        .@"union" => {
            const active_tag = std.meta.activeTag(src);
            switch (active_tag) {
                inline else => |tag| {
                    const value = @field(src, @tagName(tag));
                    try freeFieldValue(heap, @TypeOf(value), value);
                }
            }
        },
        .pointer => {
            var i: usize = 0;
            while (i < src.len) : (i += 1) {
                const value = src[i];
                try freeFieldValue(heap, @TypeOf(value), value);
            }

            heap.free(src);
        },
        else => {} // NOP
    }
}

fn freeFieldValue(heap: Allocator, comptime T: type, value: T) !void {
    switch (@typeInfo(T)) {
        .@"struct", .@"union" => return try deepFree(heap, value),
        .pointer => return try deepFree(heap, value),
        .optional => |o| {
            if (value != null) try freeFieldValue(heap, o.child, value.?);
        },
        else => {} // NOP
    }
}
