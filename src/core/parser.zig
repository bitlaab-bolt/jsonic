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

        return try copyValue(heap, T, parsed.value);
    }

    /// # Parses JSON String for Identifying Syntactic Error
    /// **WARNING:** Return value must be freed by the caller.
    pub fn diagnose(comptime T: type, heap: Allocator, data: Str) !?Str {
        var diag = json.Diagnostics{};
        var scanner = json.Scanner.initCompleteInput(heap, data);
        defer scanner.deinit();
        scanner.enableDiagnostics(&diag);

        const tok_source = json.parseFromTokenSource(T, heap, &scanner, .{});
        const parsed = tok_source catch |err| {
            if (err == error.OutOfMemory) return err;

            const byte_offset = @min(diag.getByteOffset(), data.len);
            var start = if (byte_offset > 40) byte_offset - 40 else 0;
            var end = @min(byte_offset + 40, data.len);

            // Never split a UTF-8 sequence (skip continuation bytes).
            while (start < end and isContinuation(data[start])) start += 1;
            while (end < data.len and isContinuation(data[end])) end += 1;

            const ctx = data[start..end];
            const fmt_str = "JSON error context: {s} - {s}";
            return try fmt.allocPrint(heap, fmt_str, .{ctx, @errorName(err)});
        };

        parsed.deinit();
        return null;
    }

    fn isContinuation(byte: u8) bool { return byte & 0xC0 == 0x80; }

    /// # Stringifies a Given Structure into JSON String
    /// **WARNING:** Return value must be freed by the caller.
    pub fn stringify(heap: Allocator, value: anytype) !Str {
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
    /// **Remarks:** Value is owned by `self` and dangles after `deinit()`.
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

        return try copyValue(heap, T, parsed.value);
    }
};

/// # Frees the Parsed Result
/// **Remarks:** NO-OP when `result` is *null**. 
///
/// - `result` - Return value of the `parse()` and `parseInto()`.
pub fn free(heap: Allocator, result: anytype) void {
    const T = @TypeOf(result);
    switch (@typeInfo(T)) {
        .null => return,
        .optional, .array, .pointer, .@"struct", .@"union" => freeValue(heap, T, result),
        else => {
            const err_str = "@jsonic: `{s}` owns no heap memory; do not pass it to `free()`";
            @compileError(fmt.comptimePrint(err_str, .{@typeName(T)}));
        },
    }
}

fn isScalar(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .bool, .int, .float, .@"enum" => true, else => false
    };
}

/// Integers are limited to 53 bits and floats to `f64`, so every value
/// is exactly representable as an IEEE 754 double (JSON number model).
fn checkScalar(comptime T: type) void {
    switch (@typeInfo(T)) {
        .int => |n| {
            if (n.bits > 53) {
                const err_str = "@jsonic: Unsupported type `{s}`. Exceeds IEEE 754 double-precision floating-point boundary!";
                @compileError(fmt.comptimePrint(err_str, .{@typeName(T)}));
            }
        },
        .float => |f| {
            if (f.bits != 64) @compileError("@jsonic: Use only `f64` instead!");
        },
        else => {} // NO-OP
    }
}

fn copyValue(heap: Allocator, comptime T: type, value: T) Allocator.Error!T {
    switch (@typeInfo(T)) {
        .void, .null, .bool, .@"enum" => return value,
        .int, .float => {
            checkScalar(T);
            return value;
        },
        .optional => |o| {
            if (value) |v| return try copyValue(heap, o.child, v)
            else return null;
        },
        .array => |a| {
            var dest: T = undefined;
            for (value, 0..) |item, i| {
                dest[i] = copyValue(heap, a.child, item) catch |err| {
                    for (dest[0..i]) |d| freeValue(heap, a.child, d);
                    return err;
                };
            }

            return dest;
        },
        .pointer => |p| {
            if (!p.attrs.@"const") {
                const err_str = "@jsonic: Use `const` ptr for `{s}` instead";
                @compileError(fmt.comptimePrint(err_str, .{@typeName(T)}));
            }

            if (p.sentinel() != null) {
                const err_str = "@jsonic: Sentinel terminated `{s}` is unsupported";
                @compileError(fmt.comptimePrint(err_str, .{@typeName(T)}));
            }

            switch (p.size) {
                .slice => {
                    if (comptime isScalar(p.child)) {
                        comptime checkScalar(p.child);
                        return try heap.dupe(p.child, value);
                    }

                    const slice = try heap.alloc(p.child, value.len);
                    for (value, 0..) |item, i| {
                        slice[i] = copyValue(heap, p.child, item) catch |err| {
                            for (slice[0..i]) |d| freeValue(heap, p.child, d);
                            heap.free(slice);
                            return err;
                        };
                    }

                    return slice;
                },
                .one => {
                    const dest = try heap.create(p.child);
                    dest.* = copyValue(heap, p.child, value.*) catch |err| {
                        heap.destroy(dest);
                        return err;
                    };

                    return dest;
                },
                else => {
                    const err_str = "@jsonic: Unsupported pointer type `{s}`";
                    @compileError(fmt.comptimePrint(err_str, .{@typeName(T)}));
                }
            }
        },
        .@"struct" => |s| {
            var dest: T = undefined;
            inline for (s.field_names, s.field_types, 0..) |name, FT, i| {
                if (comptime s.field_attrs[i].@"comptime") continue;

                const v = @field(value, name);
                if (isDefault(T, i, v)) {
                    @field(dest, name) = v;
                } else {
                    @field(dest, name) = copyValue(heap, FT, v) catch |err| {
                        freeFields(heap, T, &dest, i);
                        return err;
                    };
                }
            }

            return dest;
        },
        .@"union" => {
            switch (value) {
                inline else => |payload, tag| {
                    const v = try copyValue(heap, @TypeOf(payload), payload);
                    return @unionInit(T, @tagName(tag), v);
                }
            }
        },
        else => {
            const err_str = "jsonic: Unsupported type `{s}`";
            @compileError(fmt.comptimePrint(err_str, .{@typeName(T)}));
        }
    }
}

/// Frees only the first `n` fields of a partially initialized struct.
fn freeFields(
    heap: Allocator,
    comptime T: type,
    dest: *const T,
    n: usize
) void {
    const s = @typeInfo(T).@"struct";
    inline for (s.field_names, s.field_types, 0..) |name, FT, i| {
        if (comptime s.field_attrs[i].@"comptime") continue;
        if (i < n) {
            const v = @field(dest.*, name);
            if (!isDefault(T, i, v)) freeValue(heap, FT, v);
        }
    }
}

fn isDefault(comptime T: type, comptime i: usize, value: anytype) bool {
    const s = @typeInfo(T).@"struct";
    const FT = s.field_types[i];
    if (comptime s.field_attrs[i].defaultValue(FT)) |d| {
        return aliasesDefault(FT, value, d);
    }

    return false;
}

fn aliasesDefault(comptime T: type, value: T, comptime default: T) bool {
    switch (@typeInfo(T)) {
        .pointer => |p| switch (p.size) {
            .slice => return value.ptr == default.ptr and value.len == default.len,
            .one => return value == default,
            else => return false
        },
        .optional => |o| {
            const d = default orelse return false;
            const v = value orelse return false;
            return aliasesDefault(o.child, v, d);
        },
        else => return false
    }
}

fn freeValue(heap: Allocator, comptime T: type, value: T) void {
    switch (@typeInfo(T)) {
        .optional => |o| {
            if (value) |v| freeValue(heap, o.child, v);
        },
        .array => |a| {
            if (comptime isScalar(a.child)) return;
            for (value) |item| freeValue(heap, a.child, item);
        },
        .pointer => |p| {
            switch (p.size) {
                .slice => {
                    if (comptime !isScalar(p.child)) {
                        for (value) |item| freeValue(heap, p.child, item);
                    }

                    heap.free(value);
                },
                .one => {
                    freeValue(heap, p.child, value.*);
                    heap.destroy(value);
                },
                else => {}
            }
        },
        .@"struct" => |s| {
            inline for (s.field_names, s.field_types, 0..) |name, FT, i| {
                if (comptime s.field_attrs[i].@"comptime") continue;

                const v = @field(value, name);
                if (!isDefault(T, i, v)) freeValue(heap, FT, v);
            }
        },
        .@"union" => {
            switch (value) {
                inline else => |payload| freeValue(heap, @TypeOf(payload), payload)
            }
        },
        else => {} // NO-OP
    }
}
