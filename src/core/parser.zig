const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const StructField = std.builtin.Type.StructField;


pub const Static = struct {
    /// # Parses JSON String into a Given Structure
    /// **WARNING:** You must call `free()` on parsed result
    pub fn parse(comptime T: type, heap: Allocator, data: []const u8) !T {
        const parsed = try json.parseFromSlice(T, heap, data, .{});
        defer parsed.deinit();

        return try deepCopy(heap, parsed.value);
    }

    /// # Stringifies a Given Structure into JSON String
    /// **WARNING:** Return value must be deallocated by the caller
    pub fn stringify(heap: Allocator, value: anytype) ![]u8 {
        const out = try json.stringifyAlloc(
            heap, value, .{.whitespace = .minified}
        );

        return out;
    }
};

pub const Dynamic = struct {
    parsed: json.Parsed(json.Value),

    const Option = json.ParseOptions;

    /// # Initializes Dynamic JSON Value Instance
    pub fn init(heap: Allocator, src: []const u8, option: Option) !Dynamic {
        const parsed = try json.parseFromSlice(json.Value, heap, src, option);
        return .{.parsed = parsed};
    }

    /// # Destroys Dynamic JSON Value Instance
    pub fn deinit(self: *Dynamic) void { self.parsed.deinit(); }

    /// # Returns Parsed JSON Value
    pub fn data(self: *Dynamic) json.Value {
        return self.parsed.value;
    }

    /// # Parses Dynamic JSON Value into a Given Structure
    /// **WARNING:** You must call `free()` on parsed result
    pub fn parseInto(comptime T: type, heap: Allocator, src: json.Value) !T {
        const parsed = try json.parseFromValue(T, heap, src, .{});
        defer parsed.deinit();

        return try deepCopy(heap, parsed.value);
    }
};

/// # Releases underlying heap allocated memories
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
        .pointer => |p| {
            if (p.is_const and p.size == .slice) {
                const slice = try heap.alloc(p.child, src.len);

                var i: usize = 0;
                while (i < src.len) : (i += 1) {
                    const value = src[i];
                    slice[i] = try copyFieldValue(heap, @TypeOf(value), value);
                }

                dest = slice;
            } else @compileError("Only Use `[]const T` Instead");
        },
        else => @compileError("Unsupported Type")
    }

    return dest;
}

fn copyFieldValue(heap: Allocator, comptime T: type, value: T) !T {
    switch (@typeInfo(T)) {
        .bool => return value,
        .int => |n| {
            if (n.signedness == .unsigned and n.bits == 8) return value 
            else if (n.signedness == .signed and n.bits == 64) return value
            else @compileError("Only Use `u8` or `i64` Instead");
        },
        .float => |f| {
            if (f.bits == 64) return value
            else @compileError("Only Use `f64` Instead");
        },
        .@"struct" => return try deepCopy(heap, value),
        .pointer => return try deepCopy(heap, value),
        .optional => |o| {
            if (value == null) return value
            else return try copyFieldValue(heap, o.child, value.?);
        },
        else => @compileError("Unsupported Field Type")
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
        .@"struct" => return try deepFree(heap, value),
        .pointer => return try deepFree(heap, value),
        .optional => |o| {
            if (value != null) try freeFieldValue(heap, o.child, value.?);
        },
        else => {} // NOP
    }
}
