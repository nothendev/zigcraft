const s = @import("std");
const ev = s.event;

pub const Server = struct { players: ev.RwLocked(s.AutoArrayHashMap(s.net.Address, NetPlayer)) };
pub const NetPlayer = struct { name: []const u8, addr: s.net.Address };
