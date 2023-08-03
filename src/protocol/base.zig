const h = @import("helpers.zig");
const s = @import("std");
const vi = @import("varint.zig");
const toArrayList = @import("ser.zig").toArrayList;

pub const State = enum { handshaking, status, login, disconnected };

pub const ProtocolError = error{ VarIntTooBig, InvalidPacketId };

pub const Buffer = s.ArrayList(u8);
pub const Allocator = s.mem.Allocator;
