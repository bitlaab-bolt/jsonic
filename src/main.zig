const std = @import("std");

const jsonic = @import("jsonic");

pub fn main() !void {
    std.debug.print("Hello, World!\n", .{});

    // Let's start from here...

    var gpa_mem = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    {
        const User = struct { name: []const u8, age: u8 };

        const static_str = "{ \"name\": \"John Doe\", \"age\": 40 }";
        const src = try heap.alloc(u8, static_str.len);
        defer heap.free(src);
        std.mem.copyForwards(u8, src, static_str);

        const data = try jsonic.StaticJson.parse(User, heap, src);
        std.debug.print(
            "Structure Data - name: {s} age: {d}\n", .{data.name, data.age}
        );

        const json_str = try jsonic.StaticJson.stringify(heap, data);
        defer heap.free(json_str);

        std.debug.print("Stringify Data - {s}\n", .{json_str});
        try jsonic.free(heap, data);
    }

    {
        const static_str = "[\"John Doe\", 40]";
        const src = try heap.alloc(u8, static_str.len);
        defer heap.free(src);
        std.mem.copyForwards(u8, src, static_str);

        var dyn_json = try jsonic.DynamicJson.init(heap, src, .{});
        defer dyn_json.deinit();

        const json_data = dyn_json.data().array;
        const item_1 = json_data.items[0].string;
        const item_2 = json_data.items[1].integer;
        std.debug.print("Array Item - Name: {s} Age: {}\n", .{item_1, item_2});
    }

    {
        const SliceType = []const []const u8;
        const static_str = "[\"John Doe\", \"Jane Doe\"]";
        const src = try heap.alloc(u8, static_str.len);
        defer heap.free(src);
        std.mem.copyForwards(u8, src, static_str);

        var dyn_json = try jsonic.DynamicJson.init(heap, src, .{});
        defer dyn_json.deinit();

        const value = dyn_json.data();
        const result = try jsonic.DynamicJson.parseInto(SliceType, heap, value, .{});
        const str = try jsonic.StaticJson.stringify(heap, result);
        defer heap.free(str);

        std.debug.print("Stringify Result:\n{s}\n", .{str});
        try jsonic.free(heap, result);
    }

    {
        const static_str =
        \\ {
        \\      "name": "Jane Doe",
        \\      "age": 30,
        \\      "hobby": ["reading", "fishing"],
        \\      "feelings": {
        \\          "fear": 75,
        \\          "joy": 25
        \\      }
        \\ }
        ;

        const static_input = try heap.alloc(u8, static_str.len);
        std.mem.copyForwards(u8, static_input, static_str);
        defer heap.free(static_input);

        var json_value = try jsonic.DynamicJson.init(heap, static_input, .{});
        defer json_value.deinit();

        const value = json_value.data().object;
        const joy = value.get("feelings").?.object.get("joy").?.integer;
        std.debug.print("Joy: {d}\t", .{joy});

        const hobby = value.get("hobby").?.array.items[1].string;
        std.debug.print("Hobby: {s}\n\n", .{hobby});
    }

    {
        const Feelings = struct { fear: f64, joy: i32 };
        const Foo = enum {Bar, Baz};
        const User = struct {
            name: []const u8,
            age: u8,
            hobby: []const[]const u8,
            feelings: Feelings,
            foo: Foo,
        };

        const static_str =
        \\ {
        \\      "name": "Jane Doe",
        \\      "age": 30,
        \\      "hobby": ["reading", "fishing"],
        \\      "feelings": {
        \\          "fear": 75.9,
        \\          "joy": -25
        \\      },
        \\      "foo": "Baz"
        \\ }
        ;

        const static_input = try heap.alloc(u8, static_str.len);
        std.mem.copyForwards(u8, static_input, static_str);
        defer heap.free(static_input);

        var json_value = try jsonic.DynamicJson.init(heap, static_input, .{});
        defer json_value.deinit();

        const src = json_value.data();

        const result = try jsonic.DynamicJson.parseInto(User, heap, src, .{});
        std.debug.print("result {any}\n", .{result});
        const str = try jsonic.StaticJson.stringify(heap, result);
        defer heap.free(str);

        std.debug.print("Stringify Result:\n{s}\n", .{str});
        try jsonic.free(heap, result);
    }
}
