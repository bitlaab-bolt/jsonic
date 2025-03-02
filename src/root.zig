//! # JSON Data Parser and Stringifier
//! - See documentation at - https://bitlaabjsonic.web.app/

const parser = @import("./core/parser.zig");

pub const free = parser.free;
pub const StaticJson = parser.Static;
pub const DynamicJson = parser.Dynamic;
