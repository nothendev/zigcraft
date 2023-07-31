pub const Handshake = packed struct {
    /// The protocol version of the client that is trying to connect.
    protocol_version: VarI32,
    /// The next state that the client is trying to achieve
    next_state: NextState,

    pub fn zcSerialize(self: @This(), allocator: base.Allocator) ![]u8 {
        var result: []u8 = try allocator.alloc(u8, self.protocol_version.calculateLength() + @sizeOf(NextState));
        const protocol_version: *[VarI32.length]u8 = (try self.protocol_version.serialize(allocator)).items[0..VarI32.length];
        mem.copy(u8, result[0..protocol_version.len], protocol_version);
        mem.copy(u8, result[protocol_version.len .. protocol_version.len + @sizeOf(NextState)], &[1]u8{@enumToInt(self.next_state)});

        return result;
    }

    pub fn zcDeserialize(data: []const u8) !@This() {
        const protocol_version = try VarI32.deserialize(data);
        const next_state = @intToEnum(NextState, @bitCast(u2, data[protocol_version.len .. protocol_version.len + 2]));
    }
};

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
