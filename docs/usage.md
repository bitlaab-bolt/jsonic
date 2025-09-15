# How to use

First, import Jsonic into your Zig source file.

```zig
const jsonic = @import("jsonic");
const StaticJSON = jsonic.StaticJSON;
const DynamicJSON = jsonic.DynamicJSON;
```

Now, add following code into your `main` function.

```zig
var gpa_mem = std.heap.DebugAllocator(.{}).init;
defer std.debug.assert(gpa_mem.deinit() == .ok);
const heap = gpa_mem.allocator();
```

## Supported Data Type

Zig's `std.json` supports variety of data types. But keep in mind though, JavaScript numbers are **IEEE 754** double-precision floating-point values, which means they use **64 bits** for representation. However, only **53 bits** are used for the integer part. The largest integer that can be represented without loss of precision is: `2^53 - 1 = 9,007,199,254,740,991`. At `2^53 + 1`, the number exceeds the 53-bit precision, causing rounding errors.

**CAUTION:** Please be mindful when handling JSON input from external sources.

## Static JSON

```zig
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

const json_str = try StaticJSON.stringify(heap, data);
defer heap.free(json_str);

std.debug.print(
    "Stringified JSON from Zig Structure - {s}\n", .{json_str}
);
try jsonic.free(heap, data);
```

## Dynamic JSON

### Array

```zig
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
```

### Convert Array Value Into a Slice Type

**NOTE:** `jsonic` only supports array with the same type (e.g., `[]const ?T`).

```zig
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
```

### Object

```zig
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
```

### Convert Object Value Into a Struct

```zig
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
```
