const std = @import("std");

const jsonic = @import("jsonic");
const StaticJSON = jsonic.StaticJSON;
const DynamicJSON = jsonic.DynamicJSON;


pub fn main() !void {
    std.debug.print("↓ CODE COVERAGE EXAMPLES\n", .{});

    var gpa_mem = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    // Static JSON - Basic Struct
    {
        const User = struct { name: []const u8, age: u8 };

        const src = try slice(heap, "{ \"name\": \"John Doe\", \"age\": 40 }");
        defer heap.free(src);

        const data = try StaticJSON.parse(User, heap, src);
        defer jsonic.free(heap, data);

        std.debug.print(
            "Static JSON Parsed Output - name: {s}, age: {d}\n",
            .{data.name, data.age},
        );

        const json_str = try StaticJSON.stringify(heap, data);
        defer heap.free(json_str);

        std.debug.print(
            "Stringified JSON from Zig Structure - {s}\n",
            .{json_str}
        );
    }

    // Static JSON - Diagnose Syntax Error (missing closing quote)
    {
        const User = struct { name: []const u8, age: u8 };

        const fmt_str = "{\"name\": \"John Doe, \"age\": 40}";
        const err_src = try slice(heap, fmt_str);
        defer heap.free(err_src);

        const diag = try StaticJSON.diagnose(User, heap, err_src);
        if (diag) |ctx| {
            defer heap.free(ctx);
            std.debug.print("Diagnosed - {s}\n", .{ctx});
        } else {
            std.debug.print("Found 0 Error!\n", .{});
        }
    }

    // Static JSON - Diagnose Trailing Comma
    {
        const User = struct { name: []const u8, age: u8 };

        const fmt_str = "{\"name\": \"John Doe\", \"age\": 40,}";
        const err_src = try slice(heap, fmt_str);
        defer heap.free(err_src);

        const diag = try StaticJSON.diagnose(User, heap, err_src);
        if (diag) |ctx| {
            defer heap.free(ctx);
            std.debug.print("Diagnosed Trailing Comma - {s}\n", .{ctx});
        } else {
            std.debug.print("Found 0 Error!\n", .{});
        }
    }

    // Static JSON - Diagnose Type Mismatch (string given for `age: u8`)
    {
        const User = struct { name: []const u8, age: u8 };

        const fmt_str = "{\"name\": \"John Doe\", \"age\": \"forty\"}";
        const err_src = try slice(heap, fmt_str);
        defer heap.free(err_src);

        const diag = try StaticJSON.diagnose(User, heap, err_src);
        if (diag) |ctx| {
            defer heap.free(ctx);
            std.debug.print("Diagnosed Type Mismatch - {s}\n", .{ctx});
        } else {
            std.debug.print("Found 0 Error!\n", .{});
        }
    }

    // Static JSON - Diagnose Missing Field (no "age" key)
    {
        const User = struct { name: []const u8, age: u8 };

        const err_src = try slice(heap, "{ \"name\": \"John Doe\" }");
        defer heap.free(err_src);

        const diag = try StaticJSON.diagnose(User, heap, err_src);
        if (diag) |ctx| {
            defer heap.free(ctx);
            std.debug.print("Diagnosed Missing Field - {s}\n", .{ctx});
        } else {
            std.debug.print("Found 0 Error!\n", .{});
        }
    }

    // Static JSON - Diagnose No Error (well-formed JSON)
    {
        const User = struct { name: []const u8, age: u8 };

        const src = try slice(heap, "{ \"name\": \"John Doe\", \"age\": 40 }");
        defer heap.free(src);

        const diag = try StaticJSON.diagnose(User, heap, src);
        if (diag) |ctx| {
            defer heap.free(ctx);
            std.debug.print("Diagnosed Unexpected - {s}\n", .{ctx});
        } else {
            std.debug.print("Diagnose - Found 0 Error!\n", .{});
        }
    }

    // Static JSON - Scalars, Optional, Enum, Float
    {
        const Level = enum { low, medium, high };
        const Record = struct {
            id: u32,
            score: f64,
            active: bool,
            level: Level,
            nickname: ?[]const u8, // `null` or absent JSON field
        };

        const src = try slice(heap,
            \\ {
            \\    "id": 123456,
            \\    "score": 99.5,
            \\    "active": true,
            \\    "level": "high",
            \\    "nickname": null
            \\ }
        );
        defer heap.free(src);

        const record = try StaticJSON.parse(Record, heap, src);
        defer jsonic.free(heap, record);

        const fmt_str = "Scalars - id: {d}, score: {d}, active: {}, level: {s}, nickname: {?s}\n";

        std.debug.print(fmt_str, .{
            record.id, record.score, record.active, @tagName(record.level), record.nickname
        });

        const json_str = try StaticJSON.stringify(heap, record);
        defer heap.free(json_str);
        std.debug.print("Stringified Scalars - {s}\n", .{json_str});
    }

    // Static JSON - Nested Struct & Slice of Structs
    {
        const Point = struct { x: i32, y: i32 };
        const Shape = struct {
            label: []const u8,
            origin: Point,
            vertices: []const Point,
        };

        const src = try slice(heap,
            \\ {
            \\    "label": "triangle",
            \\    "origin": {"x": 0, "y": 0},
            \\    "vertices": [
            \\          {"x": 1, "y": 1}, {"x": 4, "y": 1}, {"x": 1, "y": 4}
            \\    ]
            \\ }
        );
        defer heap.free(src);

        const shape = try StaticJSON.parse(Shape, heap, src);
        defer jsonic.free(heap, shape);

        const fmt_str = "Nested - label: {s}, origin: ({d}, {d}), vertices[1].x: {d}\n";

        std.debug.print(fmt_str, .{
            shape.label, shape.origin.x, shape.origin.y, shape.vertices[1].x
        });

        const json_str = try StaticJSON.stringify(heap, shape);
        defer heap.free(json_str);
        std.debug.print("Stringified Nested - {s}\n", .{json_str});
    }

    // Static JSON - Tagged Union (age variant)
    {
        const User = struct { name: []const u8, level: u8 };
        const Data = union(enum) { age: u8, user: User };

        const age_input = try slice(heap,
            \\ { "age": 29 }
        );
        defer heap.free(age_input);

        const age = try StaticJSON.parse(Data, heap, age_input);
        defer jsonic.free(heap, age);

        std.debug.print("Tagged Age: {any}\n", .{age});
    }

    // Static JSON - Tagged Union (user variant with nested struct)
    {
        const User = struct { name: []const u8, level: u8 };
        const Data = union(enum) { age: u8, user: User };

        const user_input = try slice(heap,
            \\ { "user": {"name": "Jane Doe", "level": 5} }
        );
        defer heap.free(user_input);

        const user = try StaticJSON.parse(Data, heap, user_input);
        defer jsonic.free(heap, user);

        std.debug.print("Tagged User: {any}\n", .{user});
    }

    // Static JSON - Optional Slice & Empty Containers
    {
        const Holder = struct {
            tags: ?[]const []const u8,
            empty: []const []const u8, // empty JSON array -> empty slice
        };

        const src = try slice(heap,
            \\ { "tags": ["alpha", "beta"], "empty": [] }
        );
        defer heap.free(src);

        const holder = try StaticJSON.parse(Holder, heap, src);
        defer jsonic.free(heap, holder);

        std.debug.print(
            "Optional Slice - tags: {d}, first: {s}, empty len: {d}\n",
            .{holder.tags.?.len, holder.tags.?[0], holder.empty.len},
        );

        const json_str = try StaticJSON.stringify(heap, holder);
        defer heap.free(json_str);
        std.debug.print("Stringified Optional Slice - {s}\n", .{json_str});
    }

    // Dynamic JSON - Array
    {
        const src = try slice(heap, "[\"John Doe\", 40]");
        defer heap.free(src);

        var dyn_json = try DynamicJSON.init(heap, src, .{});
        defer dyn_json.deinit();

        const json_data = dyn_json.data().array;
        const item_1 = json_data.items[0].string;
        const item_2 = json_data.items[1].integer;
        std.debug.print(
            "JSON Array Items - Name: {s}, Age: {}\n",
            .{item_1, item_2},
        );
    }

    // Dynamic JSON - String Array
    {
        const Str = []const u8;
        const StrArray = []const Str;

        const src = try slice(heap, "[\"John Doe\", \"Jane Doe\"]");
        defer heap.free(src);

        var dyn_json = try DynamicJSON.init(heap, src, .{});
        defer dyn_json.deinit();

        const value = dyn_json.data();
        const result = try DynamicJSON.parseInto(StrArray, heap, value, .{});
        defer jsonic.free(heap, result);

        const str = try StaticJSON.stringify(heap, result);
        defer heap.free(str);

        std.debug.print("Stringified Array Items:\n{s}\n", .{str});
    }

    // Dynamic JSON - Object
    {
        const static_input = try slice(heap,
            \\ {
            \\      "name": "Jane Doe",
            \\      "age": 30,
            \\      "hobby": ["reading", "fishing"],
            \\      "feelings": {
            \\          "fear": 75,
            \\          "joy": 25
            \\      }
            \\ }
        );
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

        const age_input = try slice(heap,
            \\ { "age": 29 }
        );
        defer heap.free(age_input);

        const age = try StaticJSON.parse(Data, heap, age_input);
        defer jsonic.free(heap, age);

        std.debug.print("Tagged Age: {any}\n", .{age});

        const user_input = try slice(heap,
            \\ { "user": { "name": "Jane Doe", "level": 5 } }
        );
        defer heap.free(user_input);

        const user = try StaticJSON.parse(Data, heap, user_input);
        defer jsonic.free(heap, user);

        std.debug.print("Tagged User: {any}\n", .{user});
    }

    // Dynamic JSON - Mixed (Object -> Struct)
    {
        const Feelings = struct { fear: f64, joy: i32 };
        const Foo = enum { Bar, Baz };
        const User = struct {
            name: []const u8,
            age: u8,
            hobby: []const []const u8,
            feelings: Feelings,
            foo: Foo,
        };

        const static_input = try slice(heap,
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
        );
        defer heap.free(static_input);

        var json_value = try DynamicJSON.init(heap, static_input, .{});
        defer json_value.deinit();

        const src = json_value.data();

        const result = try DynamicJSON.parseInto(User, heap, src, .{});
        defer jsonic.free(heap, result);

        std.debug.print("Mixed JSON Result {any}\n", .{result});
        const str = try StaticJSON.stringify(heap, result);
        defer heap.free(str);

        std.debug.print("Stringified JSON Result {s}\n", .{str});
    }

    // Dynamic JSON - Null Parsing (JSON `null` -> `null` Value)
    {
        const src = try slice(heap, "null");
        defer heap.free(src);

        var dyn_json = try DynamicJSON.init(heap, src, .{});
        defer dyn_json.deinit();

        std.debug.print(
            "Dynamic Null - is_null: {}\n",
            .{dyn_json.data() == .null}
        );
    }
}

/// Allocates a mutable copy of a comptime string literal.
fn slice(heap: std.mem.Allocator, comptime src: []const u8) ![]u8 {
    const dest = try heap.alloc(u8, src.len);
    @memcpy(dest, src);
    return dest;
}
