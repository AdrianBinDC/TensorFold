//! One saved prompt for the next turn: its tokens through history_len. A hit starts the next prefill there. A miss throws the save away.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PromptStore = struct {
    gpa: Allocator,
    tokens: std.ArrayList(u32) = .empty,

    pub fn init(gpa: Allocator) PromptStore {
        return .{ .gpa = gpa };
    }

    pub fn deinit(s: *PromptStore) void {
        s.tokens.deinit(s.gpa);
    }

    /// Replace the save with `tokens` (a turn's `prompt[0..history_len]`).
    pub fn save(s: *PromptStore, tokens: []const u32) !void {
        s.tokens.clearRetainingCapacity();
        try s.tokens.appendSlice(s.gpa, tokens);
    }

    /// How many saved tokens start `prompt`, or 0. A miss throws the save away.
    pub fn match(s: *PromptStore, prompt: []const u32) u32 {
        const n = s.tokens.items.len;
        if (n == 0 or n >= prompt.len or !std.mem.eql(u32, s.tokens.items, prompt[0..n])) {
            s.tokens.clearRetainingCapacity();
            return 0;
        }
        return @intCast(n);
    }
};

test "a save hits only when it starts the next prompt" {
    const gpa = std.testing.allocator;
    var store = PromptStore.init(gpa);
    defer store.deinit();
    try store.save(&.{ 1, 2, 3 });
    try std.testing.expectEqual(@as(u32, 3), store.match(&.{ 1, 2, 3, 9 }));
    try store.save(&.{ 1, 2, 3 });
    try std.testing.expectEqual(@as(u32, 0), store.match(&.{ 9, 2, 3, 1 }));
    try std.testing.expectEqual(@as(u32, 0), store.match(&.{ 1, 2, 3, 9 }));
}
