//! # JSON Data Serializer and Deserializer
//! - See documentation at - https://bitlaabjsonic.web.app/

const parser = @import("./core/parser.zig");

pub const free = parser.free;
pub const StaticJSON = parser.Static;
pub const DynamicJSON = parser.Dynamic;
