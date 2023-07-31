const h = @import("helpers.zig");
const s = @import("std");

pub const State = enum { status, login, disconnected };

pub const ProtocolError = error{
    VarIntTooBig,
};

pub const Buffer = s.ArrayList(u8);
pub const Allocator = s.mem.Allocator;
