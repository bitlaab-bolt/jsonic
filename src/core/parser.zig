const std = @import("std");
const json = std.json;
const builtin = std.builtin;
const Allocator = std.mem.Allocator;
const StructField = builtin.Type.StructField;


const Error = std.mem.Allocator.Error;


pub const Static = struct {
    pub fn parse(comptime T: type, heap: Allocator, data: []const u8) !T {
        const parsed = try json.parseFromSlice(T, heap, data, .{});
        defer parsed.deinit();

        return try deepCopy(heap, parsed.value);
    }

    // pub fn free(heap: Allocator, result: anytype) !void {
    //     try deepFree(heap, result);
    // }

    /// **WARNING:** Return value must be deallocated!
    pub fn stringify(heap: Allocator, value: anytype) ![]u8 {
        const out = try json.stringifyAlloc(
            heap, value, .{.whitespace = .minified}
        );

        return out;
    }
};

// fn deepFree(heap: Allocator, src: anytype) !void {
//     switch (@typeInfo(@TypeOf(src))) {
//         .@"struct" => |s| {
//             inline for (s.fields) |field| {
//                 try freeFieldValue(heap, src, field.type, field.name);
//             }
//         },
//         else => @compileError("Unsupported Type")
//     }
// }

// fn freeFieldValue(
//     heap: Allocator,
//     src: anytype,
//     comptime T: type,
//     comptime tag: []const u8
// ) !void {
//     const value = @field(src, tag);

//     switch (@typeInfo(T)) {
//         .@"struct" => |_| {
//             deepFree(heap, value);
//         },
//         .pointer => |_| {
//             heap.free(value);
//         },
//         .optional => |o| {
//             if (value != null) freeFieldValue(heap, src, o.child, tag);
//         },
//         else => {} // NOP
//     }
// }

fn deepCopy(heap: Allocator, src: anytype) Error!@TypeOf(src) {
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

fn copyFieldValue(heap: Allocator, comptime T: type, value: T) Error!T {
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