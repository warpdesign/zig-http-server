const std = @import("std");
const net = @import("std").net;
const posix = @import("std").posix;
const print = std.debug.print;

const Methods = enum {
    DELETE,
    GET,
    POST,
    PUT,
    UPDATE,
    OPTIONS,
};
const Header = struct { name: []const u8, value: []const u8 };
const end_header_marker = "\r\n\r\n";
// const end_header_line = "\r\n";

pub fn main() !void {
    print("Starting Server...\n", .{});
    const address = try net.Address.parseIp("0.0.0.0", 8000);

    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128);

    print("Listening on {}\n", .{address});

    while (true) {
        var client_address: net.Address = undefined;
        var client_address_len: posix.socklen_t = @sizeOf(net.Address);

        const socket = posix.accept(listener, &client_address.any, &client_address_len, 0) catch |err| {
            // Rare that this happens, but in later parts we'll
            // see examples where it does.
            std.debug.print("error accept: {}\n", .{err});
            continue;
        };

        defer posix.close(socket);

        // Add a timeout so that we don't get stuck waiting for data when reading
        const timeout = posix.timeval{ .tv_sec = 2, .tv_usec = 500_000 };
        try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.RCVTIMEO, &std.mem.toBytes(timeout));

        const request_headers = try readAll(socket);
        const list = try parseHeaders(request_headers.items);
        print("\n======\nheaders count\n======\n {}\n", .{list.items.len});
        for (list.items) |item| {
            print("{s}:{s}\n", .{ item.name, item.value });
        }

        const response =
            \\HTTP/1.0 200 OK
            \\Content-Type: text/html
            \\Content-Length: 24;
            \\
            \\<html>
            \\Hello :)
            \\</html>
        ;

        // Just write some random valid HTML data for now
        write(socket, response) catch |err| {
            // This can easily happen, say if the client disconnects.
            std.debug.print("error writing: {}\n", .{err});
        };
    }
}

fn readAll(socket: posix.socket_t) !std.ArrayList(u8) {
    var read: usize = undefined;
    var buf: [128]u8 = undefined;
    var list = std.ArrayList(u8).init(std.heap.page_allocator);

    errdefer list.deinit();

    while (true) {
        // here we read xx bytes into our buffer
        read = posix.read(socket, &buf) catch |err| {
            std.debug.print("error reading: {}\n", .{err});
            break;
        };

        try list.appendSlice(buf[0..read]);

        // If we encounter the end of header marker, enough reading.
        // Of course in real life we should check for content_length marker and also
        // read the request's body, but let's keep things simple for now.
        if (std.mem.containsAtLeast(u8, &buf, 1, end_header_marker))
            break;

        // also end reading if we didn't have anything to read
        if (read == 0)
            break;
    }

    return list;
}

fn parseHeaders(buffer: []const u8) !std.ArrayList(Header) {
    var list = std.ArrayList(Header).init(std.heap.page_allocator);
    errdefer list.deinit();

    var line_iterator = std.mem.splitSequence(u8, buffer, "\r\n");
    while (line_iterator.next()) |line| {
        const colon = std.mem.indexOf(u8, line, ": ");
        if (colon == null)
            continue;

        try list.append(Header{ .name = line[0..colon.?], .value = line[colon.? + 1 ..] });
    }

    return list;
}

fn write(socket: posix.socket_t, msg: []const u8) !void {
    var pos: usize = 0;
    while (pos < msg.len) {
        const written = try posix.write(socket, msg[pos..]);
        if (written == 0) {
            return error.Closed;
        }
        pos += written;
    }
}
