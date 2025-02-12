const std = @import("std");
const json = std.json;
const builtin = std.builtin;
const Allocator = std.mem.Allocator;
const StructField = builtin.Type.StructField;


pub const Static = struct {
    pub fn parse(comptime T: type, heap: Allocator, data: []const u8) !T {
        const parsed = try json.parseFromSlice(T, heap, data, .{});
        defer parsed.deinit();

        return try deepCopy(T, parsed.value, heap);
    }

    /// **WARNING:** Return value must be deallocated!
    pub fn stringify(heap: Allocator, value: anytype) ![]u8 {
        const out = try json.stringifyAlloc(
            heap, value, .{.whitespace = .minified}
        );

        return out;
    }
};

fn deepCopy(comptime T: type, src: T, heap: Allocator) !T {
    var dest: T = undefined;

    switch (@typeInfo(T)) {
        .@"struct" => |s| {
            inline for (s.fields) |field| {
                try copyFieldValue(src, &dest, field.type, field.name, heap);

            //     const value = @field(src, field.name);
            //     switch (@typeInfo(field.type)) {
            //         .bool => @field(dest, field.name) = value,
            //         .int => |n| {
            //             if (n.signedness == .signed and n.bits == 64) {
            //                 @field(dest, field.name) = value;
            //             } else {
            //                 @compileError("Only Use `i64` Instead");
            //             }
            //         },
            //         .float => |f| {
            //             if (f.bits == 64) @field(dest, field.name) = value
            //             else {
            //                 @compileError("Only Use `f64` Instead");
            //             }
            //         },
            //         .@"struct" => |_| {
            //             @field(dest, field.name) = deepCopy(
            //                 field.type, value, heap
            //             );
            //         },
            //         .pointer => |p| {
            //             if (p.is_const and p.size == .slice) {
            //                 const slice_data = try heap.dupe(p.child,value);
            //                 @field(dest, field.name) = slice_data;
            //             } else {
            //                 @compileError("Only Use `[]const T` Instead");
            //             }
            //         },
            //         .optional => |o| {
            //             if (value == null) @field(dest, field.name) = null;
            //             else @field(dest, field.name) = deepCopy()
            //         },
            //         else => @compileError("Unsupported Field Type")
            //     }
            }
        },
        else => @compileError("Unsupported Type")
    }

    return dest;
}

fn copyFieldValue(
    src: anytype,
    dest: anytype,
    T: type,
    comptime tag: []const u8,
    heap: Allocator
) !void {
    const value = @field(src, tag);
    switch (@typeInfo(T)) {
        .bool => @field(dest, tag) = value,
        .int => |n| {
            if (n.signedness == .signed and n.bits == 64) {
                @field(dest, tag) = value;
            } else {
                @compileError("Only Use `i64` Instead");
            }
        },
        .float => |f| {
            if (f.bits == 64) @field(dest, tag) = value
            else {
                @compileError("Only Use `f64` Instead");
            }
        },
        .@"struct" => |_| {
            @field(dest, tag) = deepCopy(T, value, heap);
        },
        .pointer => |p| {
            if (p.is_const and p.size == .slice) {
                const slice_data = try heap.dupe(p.child, value);
                @field(dest, tag) = slice_data;
            } else {
                @compileError("Only Use `[]const T` Instead");
            }
        },
        .optional => |o| {
            if (value == null) @field(dest, tag) = null
            else @field(dest, tag) = copyFieldValue(src, dest, o.child, tag, heap);
        },
        else => @compileError("Unsupported Field Type")
    }
}

pub const Dynamic = struct {
    parsed: json.Parsed(json.Value),

    const Option = json.ParseOptions;

    pub fn init(heap: Allocator, src: []const u8, option: Option) !Dynamic {
        const parsed = try json.parseFromSlice(json.Value, heap, src, option);
        return .{.parsed = parsed};
    }

    pub fn deinit(self: *Dynamic) void {
        self.parsed.deinit();
    }

    pub fn data(self: *Dynamic) json.Value {
        return self.parsed.value;
    }
};