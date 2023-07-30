const base = @import("../base.zig");
const helpers = @import("../helpers.zig");

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

pub const Handshake = helpers.Packet(struct { protocol_version: base.VarI32, next_state: NextState });
