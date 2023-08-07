const s = @import("std");
const ev = s.event;
const packets = @import("protocol/packets.zig");
const b = @import("protocol/base.zig");
const chan = @import("util/chan.zig");
const Runtime = @import("util/Runtime.zig");

pub const ServerInner = struct {
    players: s.AutoArrayHashMap(s.net.Address, ev.RwLocked(NetPlayer)),
    stream: s.net.StreamServer,
    pub fn init(allocator: b.Allocator) @This() {
        return .{ .players = s.AutoArrayHashMap(s.net.Address, ev.RwLocked(NetPlayer)).init(allocator), .stream = s.net.StreamServer.init(.{}) };
    }
};
pub const Server = ev.RwLocked(ServerInner);
pub const NetPlayer = struct { conn: s.net.StreamServer.Connection, packets: Packets, state: b.State };
pub const Packets = struct { clientbound: chan.Channel(packets.PacketClientbound).SendHalf, serverbound: chan.Channel(packets.PacketServerbound).RecvHalf };

pub fn serverLifecycle(server_lock: *Server, allocator: s.mem.Allocator) !void {
    var server_raii = await async server_lock.acquireWrite();
    errdefer server_raii.release();
    try server_raii.value.stream.listen();
    while (server_raii.value.stream.accept()) |conn| {
        const clientbound = try chan.Channel(packets.PacketClientbound).init(allocator);
        const serverbound = try chan.Channel(packets.PacketServerbound).init(allocator);
        const net = NetPlayer{ .conn = conn, .packets = Packets{ .clientbound = .{ .parent = clientbound.inner.strongClone() }, .serverbound = .{ .parent = serverbound.inner.strongClone() } } };
        async netLifecycle(&net, clientbound.inner.strongClone(), serverbound.inner.strongClone(), allocator);
        try server_raii.value.players.put(conn.address, net);
    } else |err| {
        return err;
    }
}

fn netLifecycle(net: *ev.RwLocked(NetPlayer), clientbound: chan.Channel(packets.PacketClientbound).Rc, serverbound: chan.Channel(packets.PacketServerbound).Rc, allocator: s.mem.Allocator) !void {
    Runtime.spawn(handleClientbound, .{ net, .{ .parent = clientbound }, allocator });
    Runtime.spawn(handleServerbound, .{ net, .{ .parent = serverbound }, allocator });
    Runtime.spawn(loginSequence, .{ net, .{ .parent = clientbound.strongClone() }, .{ .parent = serverbound.strongClone() } });
}

fn handleClientbound(socket: *ev.RwLocked(s.net.StreamServer.Connection), channel: chan.Channel(packets.PacketClientbound).RecvHalf) !void {
    // TODO no op as there are no clientbound packets right now
    _ = socket;
    while (await channel.recv()) |packet| {
        _ = packet;
    }
}

fn handleServerbound(socket: *ev.Locked(s.net.StreamServer.Connection), channel: chan.Channel(packets.PacketServerbound).SendHalf, allocator: s.mem.Allocator) !void {
    const lock = socket.acquire();
    defer lock.release();
    const unlocked: *s.net.StreamServer.Connection = lock.value;
    const stream: *s.net.Stream = &unlocked.stream;
    const reader = s.io.bufferedReaderSize(packets.SerializedPacket.max_size, stream.reader());
    var dest: []u8 = undefined;
    while (true) {
        if (try reader.read(dest) == 0) continue;
        const packet = try packets.SerializedPacket.Uncompressed.zcDeserialize(&dest, allocator);
        await async channel.send(try packet.toPacketUnion(packets.PacketServerbound, allocator));
    }
}

fn loginSequence(net: *NetPlayer, serverbound: chan.Channel(packets.PacketServerbound).SendHalf, clientbound: chan.Channel(packets.PacketClientbound).RecvHalf) !void {
    _ = clientbound;
    _ = serverbound;
    _ = net;
}

pub fn init(allocator: b.Allocator) Server {
    return Server.init(ServerInner.init(allocator));
}
