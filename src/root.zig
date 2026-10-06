//! # JSON Data Serializer and Deserializer
//! - See documentation at - https://bitlaab.com/api-doc?pkg=jsonic

const parser = @import("./core/parser.zig");

pub const free = parser.free;
pub const StaticJSON = parser.Static;
pub const DynamicJSON = parser.Dynamic;
