const std = @import("std");

const jsonic = @import("jsonic");
const StaticJSON = jsonic.StaticJSON;
const DynamicJSON = jsonic.DynamicJSON;


pub fn main() !void {
    std.debug.print("Code coverage examples - \n", .{});

    // Let's start from here...

    var gpa_mem = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    // Static JSON
    {
        const User = struct { name: []const u8, age: u8 };

        const static_str = "{ \"name\": \"John Doe\", \"age\": 40 }";
        const src = try heap.alloc(u8, static_str.len);
        defer heap.free(src);
        std.mem.copyForwards(u8, src, static_str);

        const data = try StaticJSON.parse(User, heap, src);
        std.debug.print(
            "Static JSON Parsed Output - name: {s}, age: {d}\n",
            .{data.name, data.age}
        );

        const err_src = "{ \"name\": \"John Doe, \"age\": 40 }";
        const diag = try StaticJSON.diagnose(User, heap, err_src);
        if (diag) |ctx| {
            std.debug.print("{s}\n", .{ctx});
            heap.free(ctx);
        } else {
            std.debug.print("Found 0 Error!\n", .{});
        }

        const json_str = try StaticJSON.stringify(heap, data);
        defer heap.free(json_str);

        std.debug.print(
            "Stringified JSON from Zig Structure - {s}\n", .{json_str}
        );
        try jsonic.free(heap, data);
    }

    // Dynamic JSON - Array
    {
        const static_str = "[\"John Doe\", 40]";
        const src = try heap.alloc(u8, static_str.len);
        defer heap.free(src);
        std.mem.copyForwards(u8, src, static_str);

        var dyn_json = try DynamicJSON.init(heap, src, .{});
        defer dyn_json.deinit();

        const json_data = dyn_json.data().array;
        const item_1 = json_data.items[0].string;
        const item_2 = json_data.items[1].integer;
        std.debug.print(
            "JSON Array Items - Name: {s}, Age: {}\n",
            .{item_1, item_2}
        );
    }

    // Dynamic JSON - String Array
    {
        const Str = []const u8;
        const StrArray = []const Str;
        const static_str = "[\"John Doe\", \"Jane Doe\"]";
        const src = try heap.alloc(u8, static_str.len);
        defer heap.free(src);
        std.mem.copyForwards(u8, src, static_str);

        var dyn_json = try DynamicJSON.init(heap, src, .{});
        defer dyn_json.deinit();

        const value = dyn_json.data();
        const result = try DynamicJSON.parseInto(StrArray, heap, value, .{});
        const str = try StaticJSON.stringify(heap, result);
        defer heap.free(str);

        std.debug.print("Stringified Array Items:\n{s}\n", .{str});
        try jsonic.free(heap, result);
    }

    // Dynamic JSON - Object
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

        var json_value = try DynamicJSON.init(heap, static_input, .{});
        defer json_value.deinit();

        const value = json_value.data().object;
        const joy = value.get("feelings").?.object.get("joy").?.integer;
        std.debug.print("JSON Object - Joy: {d}\t", .{joy});

        const hobby = value.get("hobby").?.array.items[1].string;
        std.debug.print("JSON Object - Hobby: {s}\n", .{hobby});
    }

    // Dynamic JSON - Tagged Union
    {
        const User = struct { name: []const u8, level: u8 };
        const Data = union(enum) { age: u8, user: User };

        const age_str =
        \\ {
        \\      "age": 29
        \\ }
        ;
        const age_input = try heap.alloc(u8, age_str.len);
        std.mem.copyForwards(u8, age_input, age_str);
        defer heap.free(age_input);

        const age = try StaticJSON.parse(Data, heap, age_input);
        defer jsonic.free(heap, age) catch unreachable;

        std.debug.print("Tagged Age: {any}\n", .{age});

        const user_str =
        \\ {
        \\      "user": { "name": "Jane Doe", "level": 5 }
        \\ }
        ;
        const user_input = try heap.alloc(u8, user_str.len);
        std.mem.copyForwards(u8, user_input, user_str);
        defer heap.free(user_input);

        const user = try StaticJSON.parse(Data, heap, user_input);
        defer jsonic.free(heap, user) catch unreachable;

        std.debug.print("Tagged User: {any}\n", .{user});
    }

    // Dynamic JSON - Mixed
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

        var json_value = try DynamicJSON.init(heap, static_input, .{});
        defer json_value.deinit();

        const src = json_value.data();

        const result = try DynamicJSON.parseInto(User, heap, src, .{});
        std.debug.print("Mixed JSON Result {any}\n", .{result});
        const str = try StaticJSON.stringify(heap, result);
        defer heap.free(str);

        std.debug.print("Stringified JSON Result {s}\n", .{str});
        try jsonic.free(heap, result);
    }
}
