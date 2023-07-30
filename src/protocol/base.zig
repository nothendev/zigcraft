const h = @import("helpers.zig");
const s = @import("std");

pub const State = enum { status, login, disconnected };

pub const ProtocolError = error{
    VarIntTooBig,
};
