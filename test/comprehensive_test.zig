//! Comprehensive tests for zig-yaml covering recent bug fixes,
//! edge cases, YAML 1.2 compliance, and Ethereum config parsing.

const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const Allocator = mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const Yaml = @import("yaml").Yaml;
const Value = Yaml.Value;
const stringify = @import("yaml").stringify;

const gpa = testing.allocator;

// ============================================================
// 1. Double-quoted escape sequences
// ============================================================

test "escape: backslash" {
    const source =
        \\- "\\"
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [1][]const u8);
    try testing.expectEqualStrings("\\", arr[0]);
}

test "escape: double quote" {
    const source =
        \\- "\""
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [1][]const u8);
    try testing.expectEqualStrings("\"", arr[0]);
}

test "escape: newline and tab" {
    const source =
        \\- "line1\nline2"
        \\- "col1\tcol2"
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [2][]const u8);
    try testing.expectEqualStrings("line1\nline2", arr[0]);
    try testing.expectEqualStrings("col1\tcol2", arr[1]);
}

test "escape: hex \\x41 = A" {
    const source =
        \\- "\x41"
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [1][]const u8);
    try testing.expectEqualStrings("A", arr[0]);
}

test "escape: unicode \\u0041 = A" {
    const source =
        \\- "\u0041"
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [1][]const u8);
    try testing.expectEqualStrings("A", arr[0]);
}

test "escape: unicode \\U00000041 = A" {
    const source =
        \\- "\U00000041"
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [1][]const u8);
    try testing.expectEqualStrings("A", arr[0]);
}

test "escape: backslash at end of string" {
    // Regression: "\\" should be a single backslash
    const source =
        \\- "hello\\"
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [1][]const u8);
    try testing.expectEqualStrings("hello\\", arr[0]);
}

test "escape: multiple backslashes in path" {
    const source =
        \\- "C:\\Users\\test\\file"
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [1][]const u8);
    try testing.expectEqualStrings("C:\\Users\\test\\file", arr[0]);
}

test "escape: null bell backspace escape formfeed return vtab space" {
    const source =
        \\- "\0"
        \\- "\a"
        \\- "\b"
        \\- "\e"
        \\- "\f"
        \\- "\r"
        \\- "\v"
        \\- "\ "
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [8][]const u8);
    try testing.expectEqualStrings("\x00", arr[0]);
    try testing.expectEqualStrings("\x07", arr[1]);
    try testing.expectEqualStrings("\x08", arr[2]);
    try testing.expectEqualStrings("\x1b", arr[3]);
    try testing.expectEqualStrings("\x0c", arr[4]);
    try testing.expectEqualStrings("\r", arr[5]);
    try testing.expectEqualStrings("\x0b", arr[6]);
    try testing.expectEqualStrings(" ", arr[7]);
}

test "escape: slash" {
    const source =
        \\- "\/"
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [1][]const u8);
    try testing.expectEqualStrings("/", arr[0]);
}

// ============================================================
// 2. Flow mappings
// ============================================================

test "flow mapping: simple" {
    const source =
        \\{a: 1, b: 2}
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expectEqualStrings("1", (try map.get("a").?.asScalar()));
    try testing.expectEqualStrings("2", (try map.get("b").?.asScalar()));
}

test "flow mapping: nested" {
    const source =
        \\{a: {b: 1}}
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const outer = yaml.docs.items[0].map;
    const inner = outer.get("a").?.map;
    try testing.expectEqualStrings("1", (try inner.get("b").?.asScalar()));
}

test "flow mapping: empty" {
    const source =
        \\data: {}
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    const inner = map.get("data").?;
    // Empty {} parses as empty map
    try testing.expectEqual(@as(usize, 0), inner.map.count());
}

test "flow mapping: with unquoted string values" {
    const source =
        \\{key1: val1, key2: val2}
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expectEqualStrings("val1", (try map.get("key1").?.asScalar()));
    try testing.expectEqualStrings("val2", (try map.get("key2").?.asScalar()));
}

test "flow mapping: as struct value" {
    const source =
        \\config: {host: localhost, port: 8080}
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct {
        config: struct {
            host: []const u8,
            port: u16,
        },
    });
    try testing.expectEqualStrings("localhost", result.config.host);
    try testing.expectEqual(@as(u16, 8080), result.config.port);
}

// ============================================================
// 3. Quoted string non-coercion
// ============================================================

test "quoted strings: not coerced to bool" {
    const source =
        \\a: "true"
        \\b: 'false'
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expectEqualStrings("true", (try map.get("a").?.asScalar()));
    try testing.expectEqualStrings("false", (try map.get("b").?.asScalar()));
}

test "quoted strings: not coerced to int" {
    const source =
        \\a: "123"
        \\b: '456'
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expectEqualStrings("123", (try map.get("a").?.asScalar()));
    try testing.expectEqualStrings("456", (try map.get("b").?.asScalar()));
}

test "quoted strings: not coerced to null" {
    const source =
        \\a: "null"
        \\b: 'null'
        \\c: "~"
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expectEqualStrings("null", (try map.get("a").?.asScalar()));
    try testing.expectEqualStrings("null", (try map.get("b").?.asScalar()));
    try testing.expectEqualStrings("~", (try map.get("c").?.asScalar()));
}

test "quoted strings: not coerced to float" {
    const source =
        \\a: "1.5"
        \\b: '0x10'
        \\c: ".inf"
        \\d: ".nan"
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expectEqualStrings("1.5", (try map.get("a").?.asScalar()));
    try testing.expectEqualStrings("0x10", (try map.get("b").?.asScalar()));
    try testing.expectEqualStrings(".inf", (try map.get("c").?.asScalar()));
    try testing.expectEqualStrings(".nan", (try map.get("d").?.asScalar()));
}

// ============================================================
// 4. Null/empty values
// ============================================================

test "null: explicit null keyword" {
    const source =
        \\a: null
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expectEqualStrings("null", (try map.get("a").?.asScalar()));
}

test "null: tilde" {
    const source =
        \\a: ~
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expectEqualStrings("~", (try map.get("a").?.asScalar()));
}

test "null: NULL uppercase" {
    const source =
        \\a: NULL
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expectEqualStrings("NULL", (try map.get("a").?.asScalar()));
}

test "null: empty value in explicit document" {
    const source =
        \\---
        \\a:
        \\...
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    // a: with no value in explicit doc should be .empty
    try testing.expect(map.get("a").? == .empty);
}

test "null: typed optional gets null for ~, null, NULL, Null" {
    const source =
        \\f: present
        \\b: ~
        \\c: null
        \\d: NULL
        \\e: Null
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct {
        b: ?[]const u8,
        c: ?[]const u8,
        d: ?[]const u8,
        e: ?[]const u8,
        f: ?[]const u8,
    });
    try testing.expect(result.b == null);
    try testing.expect(result.c == null);
    try testing.expect(result.d == null);
    try testing.expect(result.e == null);
    try testing.expectEqualStrings("present", result.f.?);
}

// ============================================================
// 5. Special floats
// ============================================================

test "special float: .inf" {
    const source =
        \\val: .inf
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct { val: f64 });
    try testing.expect(std.math.isPositiveInf(result.val));
}

test "special float: -.inf" {
    const source =
        \\val: -.inf
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct { val: f64 });
    try testing.expect(std.math.isNegativeInf(result.val));
}

test "special float: .nan" {
    const source =
        \\val: .nan
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct { val: f64 });
    try testing.expect(std.math.isNan(result.val));
}

test "special float: case variations .Inf .NaN .INF .NAN" {
    const source =
        \\a: .Inf
        \\b: -.Inf
        \\c: .NaN
        \\d: .INF
        \\e: -.INF
        \\f: .NAN
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct { a: f64, b: f64, c: f64, d: f64, e: f64, f: f64 });
    try testing.expect(std.math.isPositiveInf(result.a));
    try testing.expect(std.math.isNegativeInf(result.b));
    try testing.expect(std.math.isNan(result.c));
    try testing.expect(std.math.isPositiveInf(result.d));
    try testing.expect(std.math.isNegativeInf(result.e));
    try testing.expect(std.math.isNan(result.f));
}

test "special float: f32" {
    const source =
        \\val: .inf
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct { val: f32 });
    try testing.expect(std.math.isPositiveInf(result.val));
}

// ============================================================
// 6. Stringify roundtrips
// ============================================================

fn testStringify(expected: []const u8, input: anytype) !void {
    var aw: std.Io.Writer.Allocating = .init(gpa);
    try stringify(gpa, input, &aw.writer);
    var output = aw.toArrayList();
    defer output.deinit(gpa);
    try testing.expectEqualStrings(expected, output.items);
}

test "stringify: integers" {
    try testStringify("42", @as(i32, 42));
    try testStringify("-7", @as(i32, -7));
    try testStringify("0", @as(u32, 0));
}

test "stringify: floats" {
    try testStringify("3.14", @as(f64, 3.14));
    try testStringify("0", @as(f64, 0.0));
}

test "stringify: strings" {
    try testStringify("hello", "hello");
    try testStringify("hello world", "hello world");
}

test "stringify: struct with nested" {
    try testStringify(
        \\name: test
        \\value: 42
    , struct { name: []const u8, value: i32 }{ .name = "test", .value = 42 });
}

test "stringify: list" {
    try testStringify("[ 1, 2, 3 ]", @as([]const i32, &.{ 1, 2, 3 }));
}

test "stringify: optional present" {
    try testStringify(
        \\a: 1
    , struct { a: ?i32 }{ .a = 1 });
}

test "stringify: optional null" {
    try testStringify("", struct { a: ?i32 }{ .a = null });
}

// ============================================================
// 7. Comments
// ============================================================

test "comments: inline after value" {
    const source =
        \\key: value # this is a comment
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expectEqualStrings("value", (try map.get("key").?.asScalar()));
}

test "comments: standalone line" {
    const source =
        \\# comment at top
        \\key: value
        \\# comment at bottom
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expectEqualStrings("value", (try map.get("key").?.asScalar()));
}

test "comments: between mapping entries" {
    const source =
        \\a: 1
        \\# separator
        \\b: 2
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expectEqualStrings("1", (try map.get("a").?.asScalar()));
    try testing.expectEqualStrings("2", (try map.get("b").?.asScalar()));
}

// ============================================================
// 8. Empty and multi-document
// ============================================================

test "empty document" {
    const source = "";
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    try testing.expectEqual(@as(usize, 0), yaml.docs.items.len);
}

test "multi-document with --- markers" {
    const source =
        \\---
        \\a: 1
        \\---
        \\b: 2
        \\...
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    try testing.expectEqual(@as(usize, 2), yaml.docs.items.len);
}

test "document end marker" {
    const source =
        \\a: 1
        \\...
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    try testing.expectEqual(@as(usize, 1), yaml.docs.items.len);
}

// ============================================================
// 9. Boolean edge cases (YAML 1.2 core schema)
// ============================================================

test "boolean: true and false are bool" {
    const source =
        \\a: true
        \\b: false
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct { a: bool, b: bool });
    try testing.expect(result.a == true);
    try testing.expect(result.b == false);
}

test "boolean: yes/no/on/off are also recognized (YAML 1.1 compat)" {
    // Note: YAML 1.2 strict only has true/false, but this parser supports 1.1 compat
    const source =
        \\a: yes
        \\b: no
        \\c: on
        \\d: off
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct { a: bool, b: bool, c: bool, d: bool });
    try testing.expect(result.a == true);
    try testing.expect(result.b == false);
    try testing.expect(result.c == true);
    try testing.expect(result.d == false);
}

test "boolean: case insensitive" {
    const source =
        \\a: True
        \\b: FALSE
        \\c: YES
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct { a: bool, b: bool, c: bool });
    try testing.expect(result.a == true);
    try testing.expect(result.b == false);
    try testing.expect(result.c == true);
}

// ============================================================
// 10. Integer formats (YAML 1.2 core schema)
// ============================================================

test "integer: decimal" {
    const source =
        \\- 0
        \\- 42
        \\- -17
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [3]i32);
    try testing.expectEqual(@as(i32, 0), arr[0]);
    try testing.expectEqual(@as(i32, 42), arr[1]);
    try testing.expectEqual(@as(i32, -17), arr[2]);
}

test "integer: hex 0x1A" {
    const source =
        \\val: 0x1A
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct { val: i32 });
    try testing.expectEqual(@as(i32, 26), result.val);
}

test "integer: octal 0o17" {
    const source =
        \\val: 0o17
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct { val: i32 });
    try testing.expectEqual(@as(i32, 15), result.val);
}

test "integer: large values" {
    const source =
        \\val: 1606824000
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct { val: u64 });
    try testing.expectEqual(@as(u64, 1606824000), result.val);
}

// ============================================================
// 11. Deeply nested structures
// ============================================================

test "deeply nested: 4 levels of maps" {
    const source =
        \\level1:
        \\  level2:
        \\    level3:
        \\      level4: deep_value
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct {
        level1: struct {
            level2: struct {
                level3: struct {
                    level4: []const u8,
                },
            },
        },
    });
    try testing.expectEqualStrings("deep_value", result.level1.level2.level3.level4);
}

test "deeply nested: mixed lists and maps" {
    const source =
        \\items:
        \\  - name: first
        \\    sub:
        \\      - nested1
        \\      - nested2
        \\  - name: second
        \\    sub:
        \\      - nested3
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct {
        items: []const struct {
            name: []const u8,
            sub: []const []const u8,
        },
    });
    try testing.expectEqual(@as(usize, 2), result.items.len);
    try testing.expectEqualStrings("first", result.items[0].name);
    try testing.expectEqual(@as(usize, 2), result.items[0].sub.len);
    try testing.expectEqualStrings("nested1", result.items[0].sub[0]);
    try testing.expectEqualStrings("nested2", result.items[0].sub[1]);
    try testing.expectEqualStrings("second", result.items[1].name);
    try testing.expectEqual(@as(usize, 1), result.items[1].sub.len);
    try testing.expectEqualStrings("nested3", result.items[1].sub[0]);
}

// ============================================================
// 12. Mixed flow and block styles
// ============================================================

test "mixed: flow list in block mapping" {
    const source =
        \\name: test
        \\tags: [a, b, c]
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct {
        name: []const u8,
        tags: []const []const u8,
    });
    try testing.expectEqualStrings("test", result.name);
    try testing.expectEqual(@as(usize, 3), result.tags.len);
    try testing.expectEqualStrings("a", result.tags[0]);
    try testing.expectEqualStrings("b", result.tags[1]);
    try testing.expectEqualStrings("c", result.tags[2]);
}

test "mixed: flow map in block mapping" {
    const source =
        \\outer: {inner: value}
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct {
        outer: struct { inner: []const u8 },
    });
    try testing.expectEqualStrings("value", result.outer.inner);
}

// ============================================================
// 13. Ethereum config-specific tests
// ============================================================

test "ethereum: mainnet config values" {
    const source =
        \\PRESET_BASE: mainnet
        \\MIN_GENESIS_TIME: 1606824000
        \\GENESIS_DELAY: 604800
        \\MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: 16384
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();

    const Config = struct {
        PRESET_BASE: []const u8,
        MIN_GENESIS_TIME: u64,
        GENESIS_DELAY: u64,
        MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: u64,
    };

    const result = try yaml.parse(arena.allocator(), Config);
    try testing.expectEqualStrings("mainnet", result.PRESET_BASE);
    try testing.expectEqual(@as(u64, 1606824000), result.MIN_GENESIS_TIME);
    try testing.expectEqual(@as(u64, 604800), result.GENESIS_DELAY);
    try testing.expectEqual(@as(u64, 16384), result.MIN_GENESIS_ACTIVE_VALIDATOR_COUNT);
}

test "ethereum: hex fork version strings stay as strings" {
    const source =
        \\GENESIS_FORK_VERSION: 0x00000000
        \\ALTAIR_FORK_VERSION: 0x01000000
        \\BELLATRIX_FORK_VERSION: 0x02000000
        \\CAPELLA_FORK_VERSION: 0x03000000
        \\DENEB_FORK_VERSION: 0x04000000
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();

    // When parsed as strings, hex values are preserved as-is
    const Config = struct {
        GENESIS_FORK_VERSION: []const u8,
        ALTAIR_FORK_VERSION: []const u8,
        BELLATRIX_FORK_VERSION: []const u8,
        CAPELLA_FORK_VERSION: []const u8,
        DENEB_FORK_VERSION: []const u8,
    };

    const result = try yaml.parse(arena.allocator(), Config);
    try testing.expectEqualStrings("0x00000000", result.GENESIS_FORK_VERSION);
    try testing.expectEqualStrings("0x01000000", result.ALTAIR_FORK_VERSION);
    try testing.expectEqualStrings("0x02000000", result.BELLATRIX_FORK_VERSION);
    try testing.expectEqualStrings("0x03000000", result.CAPELLA_FORK_VERSION);
    try testing.expectEqualStrings("0x04000000", result.DENEB_FORK_VERSION);
}

test "ethereum: full mainnet config snippet" {
    const source =
        \\# Mainnet config
        \\
        \\PRESET_BASE: mainnet
        \\CONFIG_NAME: mainnet
        \\
        \\# Genesis
        \\MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: 16384
        \\MIN_GENESIS_TIME: 1606824000
        \\GENESIS_FORK_VERSION: 0x00000000
        \\GENESIS_DELAY: 604800
        \\
        \\# Forking
        \\ALTAIR_FORK_VERSION: 0x01000000
        \\ALTAIR_FORK_EPOCH: 74240
        \\BELLATRIX_FORK_VERSION: 0x02000000
        \\BELLATRIX_FORK_EPOCH: 144896
        \\CAPELLA_FORK_VERSION: 0x03000000
        \\CAPELLA_FORK_EPOCH: 194048
        \\DENEB_FORK_VERSION: 0x04000000
        \\DENEB_FORK_EPOCH: 269568
        \\
        \\# Time parameters
        \\SECONDS_PER_SLOT: 12
        \\SECONDS_PER_ETH1_BLOCK: 14
        \\MIN_VALIDATOR_WITHDRAWABILITY_DELAY: 256
        \\SHARD_COMMITTEE_PERIOD: 256
        \\ETH1_FOLLOW_DISTANCE: 2048
        \\
        \\# Deposit contract
        \\DEPOSIT_CHAIN_ID: 1
        \\DEPOSIT_NETWORK_ID: 1
        \\DEPOSIT_CONTRACT_ADDRESS: 0x00000000219ab540356cBB839Cbe05303d7705Fa
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();

    const Config = struct {
        PRESET_BASE: []const u8,
        CONFIG_NAME: []const u8,
        MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: u64,
        MIN_GENESIS_TIME: u64,
        GENESIS_FORK_VERSION: []const u8,
        GENESIS_DELAY: u64,
        ALTAIR_FORK_VERSION: []const u8,
        ALTAIR_FORK_EPOCH: u64,
        BELLATRIX_FORK_VERSION: []const u8,
        BELLATRIX_FORK_EPOCH: u64,
        CAPELLA_FORK_VERSION: []const u8,
        CAPELLA_FORK_EPOCH: u64,
        DENEB_FORK_VERSION: []const u8,
        DENEB_FORK_EPOCH: u64,
        SECONDS_PER_SLOT: u64,
        SECONDS_PER_ETH1_BLOCK: u64,
        MIN_VALIDATOR_WITHDRAWABILITY_DELAY: u64,
        SHARD_COMMITTEE_PERIOD: u64,
        ETH1_FOLLOW_DISTANCE: u64,
        DEPOSIT_CHAIN_ID: u64,
        DEPOSIT_NETWORK_ID: u64,
        DEPOSIT_CONTRACT_ADDRESS: []const u8,
    };

    const cfg = try yaml.parse(arena.allocator(), Config);
    try testing.expectEqualStrings("mainnet", cfg.PRESET_BASE);
    try testing.expectEqualStrings("mainnet", cfg.CONFIG_NAME);
    try testing.expectEqual(@as(u64, 16384), cfg.MIN_GENESIS_ACTIVE_VALIDATOR_COUNT);
    try testing.expectEqual(@as(u64, 1606824000), cfg.MIN_GENESIS_TIME);
    try testing.expectEqualStrings("0x00000000", cfg.GENESIS_FORK_VERSION);
    try testing.expectEqual(@as(u64, 604800), cfg.GENESIS_DELAY);
    try testing.expectEqualStrings("0x01000000", cfg.ALTAIR_FORK_VERSION);
    try testing.expectEqual(@as(u64, 74240), cfg.ALTAIR_FORK_EPOCH);
    try testing.expectEqual(@as(u64, 12), cfg.SECONDS_PER_SLOT);
    try testing.expectEqual(@as(u64, 1), cfg.DEPOSIT_CHAIN_ID);
    try testing.expectEqualStrings("0x00000000219ab540356cBB839Cbe05303d7705Fa", cfg.DEPOSIT_CONTRACT_ADDRESS);
}

test "ethereum: config with optional fields" {
    const source =
        \\PRESET_BASE: minimal
        \\CONFIG_NAME: minimal
        \\TERMINAL_TOTAL_DIFFICULTY: 115792089237316195423570985008687907853269984665640564039457584007913129639936
        \\TERMINAL_BLOCK_HASH: 0x0000000000000000000000000000000000000000000000000000000000000000
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();

    const Config = struct {
        PRESET_BASE: []const u8,
        CONFIG_NAME: []const u8,
        TERMINAL_TOTAL_DIFFICULTY: []const u8, // Too large for u256, keep as string
        TERMINAL_BLOCK_HASH: []const u8,
    };

    const cfg = try yaml.parse(arena.allocator(), Config);
    try testing.expectEqualStrings("minimal", cfg.PRESET_BASE);
    try testing.expectEqualStrings("115792089237316195423570985008687907853269984665640564039457584007913129639936", cfg.TERMINAL_TOTAL_DIFFICULTY);
    try testing.expectEqualStrings("0x0000000000000000000000000000000000000000000000000000000000000000", cfg.TERMINAL_BLOCK_HASH);
}

// ============================================================
// 14. Single-quoted strings
// ============================================================

test "single quoted: basic" {
    const source =
        \\- 'hello'
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [1][]const u8);
    try testing.expectEqualStrings("hello", arr[0]);
}

test "single quoted: escaped quote (doubled)" {
    const source =
        \\- 'it''s'
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [1][]const u8);
    try testing.expectEqualStrings("it's", arr[0]);
}

test "single quoted: backslash is literal" {
    const source =
        \\- 'no\nescapes'
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [1][]const u8);
    try testing.expectEqualStrings("no\\nescapes", arr[0]);
}

// ============================================================
// 15. Lists edge cases
// ============================================================

test "empty list" {
    const source =
        \\items: []
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct { items: []const []const u8 });
    try testing.expectEqual(@as(usize, 0), result.items.len);
}

test "single element list" {
    const source =
        \\- only
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [1][]const u8);
    try testing.expectEqualStrings("only", arr[0]);
}

test "flow list with spaces" {
    const source =
        \\[ a , b , c ]
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const arr = try yaml.parse(arena.allocator(), [3][]const u8);
    try testing.expectEqualStrings("a", arr[0]);
    try testing.expectEqualStrings("b", arr[1]);
    try testing.expectEqualStrings("c", arr[2]);
}

// ============================================================
// 16. Map edge cases
// ============================================================

test "map: hyphenated keys" {
    const source =
        \\my-key: my-value
        \\another-key: another-value
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expectEqualStrings("my-value", (try map.get("my-key").?.asScalar()));
    try testing.expectEqualStrings("another-value", (try map.get("another-key").?.asScalar()));
}

test "map: underscored keys map to struct fields" {
    // zig-yaml maps underscore in field names to hyphens in YAML keys
    const source =
        \\my-key: hello
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const result = try yaml.parse(arena.allocator(), struct { my_key: []const u8 });
    try testing.expectEqualStrings("hello", result.my_key);
}

// ============================================================
// 17. Parse-then-stringify roundtrip
// ============================================================

test "roundtrip: simple map" {
    const source =
        \\a: 1
        \\b: 2
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);

    var aw: std.Io.Writer.Allocating = .init(gpa);
    try yaml.stringify(&aw.writer);
    var output = aw.toArrayList();
    defer output.deinit(gpa);

    // Stringify adds --- and ... markers
    try testing.expect(std.mem.startsWith(u8, output.items, "---\n"));
    try testing.expect(std.mem.endsWith(u8, output.items, "...\n"));
    // Contains the key-value pairs
    try testing.expect(std.mem.indexOf(u8, output.items, "a: 1") != null);
    try testing.expect(std.mem.indexOf(u8, output.items, "b: 2") != null);
}

test "roundtrip: list" {
    const source =
        \\- x
        \\- y
        \\- z
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);

    var aw: std.Io.Writer.Allocating = .init(gpa);
    try yaml.stringify(&aw.writer);
    var output = aw.toArrayList();
    defer output.deinit(gpa);

    try testing.expect(std.mem.indexOf(u8, output.items, "[ x, y, z ]") != null);
}

// ============================================================
// 18. Error cases
// ============================================================

test "error: type mismatch int as string" {
    const source =
        \\val: hello
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    try testing.expectError(error.InvalidCharacter, yaml.parse(arena.allocator(), struct { val: i32 }));
}

test "error: missing struct field" {
    const source =
        \\a: 1
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    var arena = Arena.init(gpa);
    defer arena.deinit();
    try testing.expectError(error.StructFieldMissing, yaml.parse(arena.allocator(), struct { a: i32, b: i32 }));
}

test "error: duplicate map keys" {
    const source =
        \\a: 1
        \\a: 2
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try testing.expectError(error.DuplicateMapKey, yaml.load(gpa));
}

// ============================================================
// 19. Untyped value access
// ============================================================

test "untyped: map contains check" {
    const source =
        \\present: yes
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("present"));
    try testing.expect(!map.contains("absent"));
}

test "untyped: list indexing" {
    const source =
        \\- first
        \\- second
        \\- third
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(gpa);
    try yaml.load(gpa);
    const list = yaml.docs.items[0].list;
    try testing.expectEqual(@as(usize, 3), list.len);
    try testing.expectEqualStrings("first", list[0].scalar);
    try testing.expectEqualStrings("second", list[1].scalar);
    try testing.expectEqualStrings("third", list[2].scalar);
}

// ============================================================
// 20. Value.encode and stringify integration
// ============================================================

test "encode: struct to Value and back" {
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const input = struct { name: []const u8, count: u32 }{ .name = "test", .count = 42 };
    const value = try Value.encode(arena.allocator(), input);
    try testing.expect(value != null);
    const map = value.?.map;
    try testing.expectEqualStrings("test", (try map.get("name").?.asScalar()));
    try testing.expectEqualStrings("42", (try map.get("count").?.asScalar()));
}

test "encode: list to Value" {
    var arena = Arena.init(gpa);
    defer arena.deinit();
    const input = @as([]const i32, &.{ 1, 2, 3 });
    const value = try Value.encode(arena.allocator(), input);
    try testing.expect(value != null);
    const list = value.?.list;
    try testing.expectEqual(@as(usize, 3), list.len);
    try testing.expectEqualStrings("1", list[0].scalar);
    try testing.expectEqualStrings("2", list[1].scalar);
    try testing.expectEqualStrings("3", list[2].scalar);
}
