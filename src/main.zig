const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const Allocator = mem.Allocator;

const parser = @import("./core/parser.zig");


pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    // defer debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    // Static JSON
    const out = try staticJsonTest(heap);
    debug.print("Result: {any}\n", .{out});

    const str = try parser.Static.stringify(heap, out);
    defer heap.free(str);
    debug.print("{s}\n", .{str});
    // try parser.Static.free(heap, out);





    // Dynamic JSON with object data
    const input2 =
    \\ {
    \\      "name": "Jane Doe",
    \\      "age": 30,
    \\      "hobby": ["reading", "fishing"],
    \\      "score": {
    \\          "fear": 75,
    \\          "joy": 60
    \\      }
    \\ }
    ;

    var dyn_json = try parser.Dynamic.init(heap, input2, .{});
    defer dyn_json.deinit();

    const json_data = dyn_json.data().object;
    const joy = json_data.get("score").?.object.get("joy").?.integer;
    std.debug.print("Joy: {d}\n", .{joy});

    const hobby = json_data.get("hobby").?.array.items[1].string;
    std.debug.print("Hobby: {s}\n", .{hobby});

    // Dynamic JSON with array data
    const input3 = "[\"John Doe\", 40]";

    var dyn_json2 = try parser.Dynamic.init(heap, input3, .{});
    defer dyn_json2.deinit();

    const json_data2 = dyn_json2.data().array;
    const item = json_data2.items[0].string;
    std.debug.print("Array Item: {s}\n", .{item});
}

const User = struct {
    name: []const u8,
    age: i64,
    balance: f64,
    score: []const i64,
    hobby: []const[]const u8,
    card_one: Card,
    card_two: ?Card,
    card_three: ?Card,
    wallet: []const ?Card
};

const Card = struct { name: []const u8, credit: i64 };

fn staticJsonTest(heap: Allocator) !User {
    const static_str =
    \\ {
    \\      "name": "John Doe",
    \\      "age": 40,
    \\      "balance": 5000.78,
    \\      "score": [ 120, 240, 301 ],
    \\      "hobby": [ "fishing", "reading" ],
    \\      "card_one": { "name": "Green", "credit": 500 },
    \\      "card_two": { "name": "yellow", "credit": 10 },
    \\      "card_three": null,
    \\      "wallet": [
    \\          { "name": "Green", "credit": 500 },
    \\          { "name": "yellow", "credit": 10 },
    \\          null
    \\      ]
    \\ }
    ;

    const static_input = try heap.alloc(u8, static_str.len);
    mem.copyForwards(u8, static_input, static_str);
    defer heap.free(static_input);

    const data = try parser.Static.parse(User, heap, static_input);
    return data;
}