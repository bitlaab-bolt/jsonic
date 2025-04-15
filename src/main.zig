const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const Allocator = mem.Allocator;

const jsonic = @import("jsonic");
const StaticJson = jsonic.StaticJson;
const DynamicJson = jsonic.DynamicJson;


pub fn main() !void {
    var gpa_mem = std.heap.DebugAllocator(.{}).init;
    defer debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    // Demo for Static JSON
    const out = try StaticJsonTest.staticJson(heap);
    const str = try StaticJson.stringify(heap, out);
    defer heap.free(str);

    debug.print("Stringify Result:\n{s}\n\n", .{str});
    try jsonic.free(heap, out);

    // Demo for Dynamic JSON
    try DynamicJsonTest.dynamicJson(heap);
}

const StaticJsonTest = struct {
    const User = struct {
        name: []const u8,
        age: i64,
        male: bool,
        balance: f64,
        score: []const i64,
        hobby: []const[]const u8,
        card_one: Card,
        card_two: ?Card,
        card_three: ?Card,
        wallet: []const ?Card
    };

    const Card = struct { name: []const u8, credit: i64 };

    fn staticJson(heap: Allocator) !User {
        std.debug.print("Showing Static JSON Demo:\n\n", .{});

        const static_str =
        \\ {
        \\      "name": "John Doe",
        \\      "age": 40,
        \\      "male": true,
        \\      "balance": 5000.78,
        \\      "score": [120, 240, 301],
        \\      "hobby": ["fishing", "reading"],
        \\      "card_one": {"name": "Green", "credit": 500},
        \\      "card_two": {"name": "yellow", "credit": 10},
        \\      "card_three": null,
        \\      "wallet": [
        \\          {"name": "Green", "credit": 500},
        \\          {"name": "yellow", "credit": 10},
        \\          null
        \\      ]
        \\ }
        ;

        const static_input = try heap.alloc(u8, static_str.len);
        mem.copyForwards(u8, static_input, static_str);
        defer heap.free(static_input);

        const data = try StaticJson.parse(User, heap, static_input);
        return data;
    }
};

const DynamicJsonTest = struct {
    const User = struct {
        name: []const u8,
        age: i64,
        hobby: []const[]const u8,
        feelings: Feelings,
    };

    const Feelings = struct { fear: i64, joy: i64 };

    fn dynamicJson(heap: Allocator) !void {
        std.debug.print("Showing Dynamic JSON Demo:\n\n", .{});

        const static_str =
        \\ [{
        \\      "name": "Jane Doe",
        \\      "age": 30,
        \\      "hobby": ["reading", "fishing"],
        \\      "feelings": {
        \\          "fear": 75,
        \\          "joy": 25
        \\      }
        \\ }]
        ;

        const static_input = try heap.alloc(u8, static_str.len);
        mem.copyForwards(u8, static_input, static_str);
        defer heap.free(static_input);

        var json_value = try DynamicJson.init(heap, static_input, .{});
        defer json_value.deinit();

        const value = json_value.data().array.items[0].object;
        const joy = value.get("feelings").?.object.get("joy").?.integer;
        std.debug.print("Joy: {d}\t", .{joy});

        const hobby = value.get("hobby").?.array.items[1].string;
        std.debug.print("Hobby: {s}\n\n", .{hobby});

        const src = json_value.data();
        const result = try DynamicJson.parseInto([]const User, heap, src);
        const str = try StaticJson.stringify(heap, result);
        defer heap.free(str);

        debug.print("Stringify Result:\n{s}\n", .{str});
        try jsonic.free(heap, result);
    }
};
