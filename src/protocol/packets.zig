const vi = @import("varint.zig");
const b = @import("base.zig");
const s = @import("std");
const toArrayList = @import("ser.zig").toArrayList;
const AutoComptimeHashMap = @import("../util/comptime_hashmap.zig").AutoComptimeHashMap;

pub const Handshake = @import("packets/Handshake.zig");
pub const PacketServerbound = union(enum) {
    Handshake: Handshake,
};
pub const PacketClientbound = union(enum) {};

/// A "serialized"(-ish) representation of a Minecraft packet.
/// Higher level representations are available in the "packets" folder.
/// You can convert them to the serialized form with .initUncompressed or .initCompressed.
pub const SerializedPacket = union(enum) {
    uncompressed: Uncompressed,
    pub const max_size: u32 = 2097151;

    fn checkPacketType(comptime T: type) vi.VarI32 {
        if (!@hasDecl(T, "packet_id")) @compileError("invalid packet type - no packet ID");
        if (!@hasDecl(T, "zcSerialize")) @compileError("invalid packet type - no serializer");
        if (!@hasDecl(T, "zcDeserialize")) @compileError("invalid packet type - no deserializer");
        return @field(T, "packet_id");
    }

    pub fn zcSerialize(self: @This(), allocator: b.Allocator) ![]u8 {
        return switch (self) {
            .uncompressed => |uncompressed| try uncompressed.zcSerialize(allocator),
        };
    }

    pub fn initUncompressed(comptime T: type, packet: T, allocator: b.Allocator) !@This() {
        return .{ .uncompressed = try Uncompressed.fromPacket(T, packet, allocator) };
    }

    pub const Uncompressed = struct {
        length: vi.VarI32,
        packet_id: vi.VarI32,
        data: []const u8,

        const Self = @This();

        pub fn zcSerialize(self: Self, allocator: b.Allocator) ![]u8 {
            const length = try self.length.serialize(allocator);
            defer allocator.free(length);
            const packet_id = try self.packet_id.serialize(allocator);
            defer allocator.free(packet_id);
            const data = self.data;

            return try s.mem.concat(allocator, u8, &[_][]const u8{ length, packet_id, data });
        }
        pub fn zcDeserialize(bytes: []const u8, allocator: b.Allocator) !Self {
            const length = try vi.VarI32.deserialize(bytes);
            const packet_id = try vi.VarI32.deserialize(bytes[length.len..]);
            // reallocate so `bytes` could be freed without fear of segfault
            const data = try allocator.dupe(u8, bytes[length.len + packet_id.len .. @intCast(length.value + 1)]);
            return .{ .length = length, .packet_id = packet_id, .data = data };
        }

        pub fn fromPacket(comptime T: type, packet: T, allocator: b.Allocator) !Self {
            const packet_id = checkPacketType(T);
            const data: b.Buffer = try toArrayList(try packet.zcSerialize(allocator), allocator);
            return .{ .length = vi.VarI32.init(@intCast(packet_id.len + data.items.len)), .packet_id = packet_id, .data = data.items };
        }
        pub fn toPacket(self: Self, comptime T: type, allocator: b.Allocator) !T {
            const packet_id = checkPacketType(T);
            if (self.packet_id.value != packet_id.value) return b.ProtocolError.InvalidPacketId;
            return try T.zcDeserialize(self.data, allocator);
        }

        fn associate(comptime fields: []const s.builtin.Type.UnionField) []const struct { i32, type } {
            comptime var ub: [fields.len]struct { vi.VarI32, type } = undefined;
            for (fields, 0..) |field, index| {
                ub[index] = .{ @field(field.type, "packet_id").value, field.type };
            }
            return ub;
        }

        pub fn toPacketUnion(self: Self, comptime T: type, allocator: b.Allocator) !T {
            const ids = AutoComptimeHashMap(i32, type, associate(@typeInfo(T).Union.fields));
            return (ids.get(self.packet_id.value) orelse return b.ProtocolError.InvalidPacketId).*.zcDeserialize(self.data, allocator);
        }

        pub fn deinitialize(self: Self, allocator: b.Allocator) void {
            allocator.free(self.data);
        }
    };
};
