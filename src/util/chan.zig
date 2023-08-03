const s = @import("std");
const ev = s.event;
const rc = @import("rc.zig");

pub fn Channel(comptime T: type) type {
    return struct {
        inner: Rc,

        const SelfChannel = @This();
        const Rc = rc.Rc(ev.Locked(ev.Channel(T)), rc.Atomic);

        pub const RecvHalf = struct {
            parent: Rc,

            pub fn recv(self: *RecvHalf) callconv(.Async) T {
                const parent = await self.parent.unsafePtr().acquire();
                defer parent.release();
                return await parent.value.get();
            }

            pub fn recvOrNull(self: *RecvHalf) ?T {
                const parent = await self.parent.unsafePtr().acquire();
                defer parent.release();
                return await parent.value.getOrNull();
            }

            pub fn deinit(self: *RecvHalf) void {
                self.parent.deinit();
            }
        };

        pub const SendHalf = struct {
            parent: Rc,

            pub fn send(self: *SendHalf, item: T) callconv(.Async) void {
                const parent = await self.parent.unsafePtr().acquire();
                defer parent.release();
                return await parent.value.put(item);
            }

            pub fn deinit(self: *SendHalf) void {
                self.parent.deinit();
            }
        };

        pub fn deinit(self: *SelfChannel) void {
            self.inner.deinit();
        }

        pub fn split(self: SelfChannel) struct { RecvHalf, SendHalf } {
            return .{ RecvHalf{ .parent = self.inner }, SendHalf{ .parent = self.inner } };
        }

        pub fn init(allocator: s.mem.Allocator) !SelfChannel {
            var chan: ev.Channel(T) = undefined;
            chan.init([0]T{});
            return .{ .inner = try Rc.init(ev.Locked(ev.Channel(T)).init(), allocator) };
        }
    };
}
