const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;


pub const Static = struct {
    pub fn parse(comptime T: type, heap: Allocator, data: []const u8) !T {
        const parsed = try json.parseFromSlice(T, heap, data, .{});
        defer parsed.deinit();
        return parsed.value;
    }

    /// **WARNING:** Return value must be deallocated!
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