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

## Supported Data Types

Zig's `std.json` supports variety of data types. But keep in mind though, JavaScript numbers are **IEEE 754** double-precision floating-point values, which means they use **64 bits** for representation. However, only **53 bits** are used for the integer part. The largest integer that can be represented without loss of precision is: `2^53 - 1 = 9,007,199,254,740,991`. At `2^53 + 1`, the number exceeds the 53-bit precision, causing rounding errors.

Rules enforced at compile time by `jsonic`:

- Integers wider than **53 bits** are rejected (`@compileError`).
- Floats other than **`f64`** are rejected (`@compileError`).
- Pointers must be **`const`**; sentinel-terminated pointers are unsupported.
- Only `.slice` and `.one` pointer sizes are supported.

**CAUTION:** Please be mindful when handling JSON input from external sources.

## Memory Management

- `StaticJSON.parse()` and `DynamicJSON.parseInto()` return heap allocated results. Always release them with `jsonic.free()`. `StaticJSON.stringify()` return heap allocated slice, Always release them with `heap.free()`.
- `jsonic.free()` is a NO-OP for `null` result and raises `@compileError` for types owning no heap memory (e.g. plain integers).
- `DynamicJSON` values are released by `deinit()`; values borrowed from them dangle afterwards.

## Static JSON

`StaticJSON` provides three operations: `parse()`, `diagnose()`, and `stringify()`.

### Parse a Struct

```zig
const User = struct { name: []const u8, age: u8 };

const static_str = "{ \"name\": \"John Doe\", \"age\": 40 }";
const src = try heap.alloc(u8, static_str.len);
defer heap.free(src);
std.mem.copyForwards(u8, src, static_str);

const data = try StaticJSON.parse(User, heap, src);
defer jsonic.free(heap, data);

std.debug.print(
    "Static JSON Parsed Output - name: {s}, age: {d}\n",
    .{data.name, data.age}
);
```

### Diagnose a Syntax Error

`diagnose()` returns `null` when the input is valid, otherwise an allocated
context string containing the error location and error name.

```zig
const err_src = "{ \"name\": \"John Doe, \"age\": 40 }";
const diag = try StaticJSON.diagnose(User, heap, err_src);
if (diag) |ctx| {
    defer heap.free(ctx);
    std.debug.print("{s}\n", .{ctx});
} else {
    std.debug.print("Found 0 Error!\n", .{});
}
```

It also reports semantic errors such as type mismatch and missing fields:

```zig
// `{ "name": "John Doe", "age": "forty" }` -> InvalidCharacter
// `{ "name": "John Doe" }` (no `age` field) -> MissingField
```

### Stringify

```zig
const json_str = try StaticJSON.stringify(heap, data);
defer heap.free(json_str);
std.debug.print("Stringified: {s}\n", .{json_str});
```

### Scalars, Optional Fields and Enums

JSON numbers map to `i32`/`u32`/`f64` etc. (max **53-bit** integers), JSON strings map to `enum` names, and `null` maps to optionals. A field typed `?T` may also be **absent** from the JSON object.

```zig
const Level = enum { low, medium, high };
const Record = struct {
    id: u32,
    score: f64,
    active: bool,
    level: Level,
    nickname: ?[]const u8, // `null` or absent in JSON
};

const src = try heap.alloc(u8, json_text.len);
std.mem.copyForwards(u8, src, json_text);

const record = try StaticJSON.parse(Record, heap, src);
defer jsonic.free(heap, record);
```

### Nested Structs and Slices of Structs

```zig
const Point = struct { x: i32, y: i32 };
const Shape = struct {
    label: []const u8,
    origin: Point,
    vertices: []const Point,
};
```

Parsed results are deep-copied, so freeing the top-level value releases
everything nested inside it.

### Tagged Union

```zig
const User = struct { name: []const u8, level: u8 };
const Data = union(enum) { age: u8, user: User };

const user = try StaticJSON.parse(Data, heap, user_src);
defer jsonic.free(heap, user);
// JSON `{ "user": { "name": "Jane Doe", "level": 5 } }` selects `.user`.
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

**NOTE:** `jsonic` only supports arrays with the same element type
(e.g., `[]const ?T`).

```zig
const Str = []const u8;
const StrArray = []const Str;

var dyn_json = try DynamicJSON.init(heap, src, .{});
defer dyn_json.deinit();

const value = dyn_json.data();
const result = try DynamicJSON.parseInto(StrArray, heap, value, .{});
defer jsonic.free(heap, result);
```

### Object

```zig
var json_value = try DynamicJSON.init(heap, static_input, .{});
defer json_value.deinit();

const value = json_value.data().object;
const joy = value.get("feelings").?.object.get("joy").?.integer;
const hobby = value.get("hobby").?.array.items[1].string;
```

### Convert Object Value Into a Struct

```zig
const Feelings = struct { fear: f64, joy: i32 };
const Foo = enum { Bar, Baz };
const User = struct {
    name: []const u8,
    age: u8,
    hobby: []const []const u8,
    feelings: Feelings,
    foo: Foo,
};

const src = json_value.data();
const result = try DynamicJSON.parseInto(User, heap, src, .{});
defer jsonic.free(heap, result);

std.debug.print("Mixed JSON Result {any}\n", .{result});
```

### `null` Values

A JSON document consisting of `null` parses into the `.null` tag:

```zig
var dyn_json = try DynamicJSON.init(heap, src, .{});
defer dyn_json.deinit();

const is_null = dyn_json.data() == .null;
```

## Known Quirks

- An **empty array of strings** (`"empty": []`) round-trips through
  `stringify()` as an empty string (`""`), because `[]const u8` slices are
  serialized as JSON strings rather than arrays.
- Tagged unions print with byte arrays in `{any}` debug output; use
  `stringify()` for human-readable output.
