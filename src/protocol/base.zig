const h = @import("helpers.zig");
const s = @import("std");
const vi = @import("varint.zig");
const toArrayList = @import("ser.zig").toArrayList;

pub const State = enum { status, login, disconnected };

pub const ProtocolError = error{
    VarIntTooBig,
};

pub const Buffer = s.ArrayList(u8);
pub const Allocator = s.mem.Allocator;

pub const SerializedPacket = struct {
    pub const Uncompressed = struct {
        length: vi.VarI32,
        packet_id: vi.VarI32,
        data: []const u8,

        const Self = @This();

        pub fn zcSerialize(self: Self, allocator: Allocator) ![]u8 {
            const length = try self.length.serialize(allocator);
            const packet_id = try self.packet_id.serialize(allocator);
            const data = self.data;
            defer allocator.free(length);
            defer allocator.free(packet_id);

            return try s.mem.concat(allocator, u8, &[_][]const u8{ length, packet_id, data });
        }
        pub fn zcDeserialize(bytes: []const u8, allocator: Allocator) !Self {
            _ = allocator;
            const length = try vi.VarI32.deserialize(bytes);
            const packet_id = try vi.VarI32.deserialize(bytes[length.len .. length.len + 1]);
            const data = bytes[packet_id.len..];
            return .{ .length = length, .packet_id = packet_id, .data = data };
        }

        pub fn fromPacket(comptime T: type, packet: T, allocator: Allocator) !Self {
            if (!@hasDecl(T, "packet_id")) @compileError("invalid packet type - no packet ID");
            const packet_id: vi.VarI32 = T.packet_id;
            if (!@hasDecl(T, "zcSerialize")) @compileError("invalid packet type - no serializer");
            const data: Buffer = try toArrayList(try packet.zcSerialize(allocator), allocator);
            return .{ .length = vi.VarI32.init(@intCast(i32, packet_id.len + data.items.len)), .packet_id = packet_id, .data = data.items };
        }

        pub fn deinitialize(self: Self, allocator: Allocator) void {
            allocator.free(self.data);
        }
    };
};
