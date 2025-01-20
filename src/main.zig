const std = @import("std");
const debug = std.debug;

const parser = @import("./core/parser.zig");


pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    defer debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    // Static JSON
    const static_input = "{ \"name\": \"John Doe\", \"age\": 40 }";
    const User = struct { name: []const u8, age: u8 };

    const data = try parser.Static.parse(User, heap, static_input);
    debug.print(
        "Static Data [ name: {s}, age: {d} ]\n", .{data.name, data.age}
    );

    const out = try parser.Static.stringify(heap, data);
    defer heap.free(out);

    debug.print("{s}\n", .{out});

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
