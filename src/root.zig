//! # JSON data parser
//! - See documentation at https://bitlaabjsonic.web.app/

const parser = @import("./core/parser.zig");


pub const StaticJson = parser.Static;
pub const DynamicJson = parser.Dynamic;
