/// The protocol version of the client that is trying to connect.
protocol_version: VarI32,
/// The next state that the client is trying to achieve
next_state: NextState,

const Self = @This();

pub const packet_id: VarI32 = VarI32.init(0x00);

pub fn zcSerialize(self: Self, allocator: base.Allocator) ![]u8 {
    const protocol_version: []const u8 = try self.protocol_version.serialize(allocator);
    // why
    defer allocator.free(protocol_version);

    return mem.concat(allocator, u8, &[_][]const u8{ protocol_version, &[_]u8{@intFromEnum(self.next_state)} });
}

pub fn zcDeserialize(data: []const u8, _allocator: base.Allocator) !Self {
    _ = _allocator;
    const protocol_version = try VarI32.deserialize(data);
    const next_state: NextState = @enumFromInt(@as(*const u2, @ptrCast(data[protocol_version.len .. protocol_version.len + 1])).*);
    return Self{ .protocol_version = protocol_version, .next_state = next_state };
}

const mem = @import("std").mem;
const base = @import("../base.zig");
const VarI32 = @import("../varint.zig").VarI32;

pub const NextState = enum(u2) {
    status = 1,
    login = 2,

    pub fn toState(self: @This()) base.State {
        return switch (self) {
            .status => .status,
            .login => .login,
        };
    }

    pub fn fromState(base_state: base.State) ?@This() {
        return switch (base_state) {
            .status => .status,
            .login => .login,
            else => null,
        };
    }
};
