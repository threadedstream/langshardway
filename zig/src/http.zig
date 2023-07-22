const std = @import("std");
const bufPrint = std.fmt.bufPrint;

const testing = std.testing;

const HttpParsingError = error{
    MalformedRequest,
    UnknownMethod,
};

pub const Error = error{
    NoSuchHeader,
};

pub const Method = enum {
    GET,
    POST,
    DELETE,
    HEAD,
    UNKNOWN,

    pub fn string(self: Method) []const u8 {
        return switch (self) {
            Method.GET => "GET",
            Method.POST => "POST",
            Method.DELETE => "DELETE",
            Method.HEAD => "HEAD",
            Method.UNKNOWN => "UNKNOWN",
        };
    }
};

pub const Status = enum(u16) {
    Ok = 200,
    Forbidden = 403,
    Unauthenticated = 401,
    InternalServerError = 500,

    pub fn string(self: Status) []const u8 {
        return switch (self) {
            Status.Ok => "OK",
            Status.Forbidden => "Forbidden",
            Status.Unauthenticated => "Unauthenticated",
            Status.InternalServerError => "Internal Server Error",
        };
    }
};

const heap = std.heap;
const ArenaAllocator = heap.ArenaAllocator;

pub const Headers = std.StringHashMap([]const u8);
pub const Query = std.StringHashMap([]const u8);

pub const Request = struct {
    allocator: ArenaAllocator,
    headers: Headers,
    method: Method,
    path: []u8,
    body: ?[]u8,

    pub fn init(req_str: []const u8) anyerror!Request {
        var arena_alloc = ArenaAllocator.init(heap.page_allocator);
        var headers = Headers.init(arena_alloc.allocator());
        var req = Request{
            .headers = headers,
            .allocator = arena_alloc,
            .method = Method.UNKNOWN,
            .path = &[_]u8{},
            .body = null,
        };
        try req.parse(req_str);
        return req;
    }

    pub fn getHeader(self: *Request, key: []const u8) anyerror![]const u8 {
        const value = self.headers.get(key);
        if (value) |v| {
            return v;
        } else {
            return Error.NoSuchHeader;
        }
    }

    fn parse(self: *Request, req_str: []const u8) anyerror!void {
        // parse method
        var method_string = std.ArrayList(u8).init(self.allocator.allocator());
        defer method_string.deinit();

        var i: usize = 0;
        while (i < req_str.len) : (i += 1) {
            if (req_str[i] == ' ') {
                i += 1;
                break;
            }
            try method_string.append(req_str[i]);
        }

        if (std.mem.eql(u8, method_string.items, "GET")) {
            self.method = Method.GET;
        } else if (std.mem.eql(u8, method_string.items, "POST")) {
            self.method = Method.POST;
        } else if (std.mem.eql(u8, method_string.items, "DELETE")) {
            self.method = Method.DELETE;
        } else if (std.mem.eql(u8, method_string.items, "HEAD")) {
            self.method = Method.HEAD;
        } else {
            return HttpParsingError.UnknownMethod;
        }

        var path = std.ArrayList(u8).init(self.allocator.allocator());
        while (i < req_str.len) : (i += 1) {
            if (req_str[i] == ' ') {
                i += 1;
                break;
            }
            try path.append(req_str[i]);
        }

        self.path = try self.allocator.allocator().alloc(u8, path.items.len);
        std.mem.copy(u8, self.path, path.items);

        var version = std.ArrayList(u8).init(self.allocator.allocator());
        defer version.deinit();

        while (i < req_str.len) : (i += 1) {
            if (req_str[i] == '\r') {
                i += 2;
                break;
            }
            try version.append(req_str[i]);
        }

        if (!std.mem.eql(u8, version.items, "HTTP/1.1")) {
            return HttpParsingError.MalformedRequest;
        }

        // parsing headers
        var splits = std.mem.split(u8, req_str[i..req_str.len], "\r\n\r\n");
        var headers = splits.next();
        var body = splits.next();

        var hdrs = std.mem.split(u8, headers.?, "\r\n");

        if (!std.mem.eql(u8, body.?, "")) {
            self.body = try self.allocator.allocator().alloc(u8, body.?.len);
            std.mem.copy(u8, self.body.?, body.?);
        }

        while (hdrs.next()) |chunk| {
            var parts = std.mem.split(u8, chunk, ": ");
            _ = try self.headers.put(parts.next().?, parts.next().?);
        }
    }

    pub fn deinit(self: *Request) void {
        self.headers.deinit();
        self.allocator.deinit();
    }
};

pub const Response = struct {
    allocator: ArenaAllocator,
    headers: Headers,
    method: Method,
    status: Status,
    body: ?[]u8,

    pub fn init() Response {
        var arena_alloc = ArenaAllocator.init(heap.page_allocator);
        var headers = Headers.init(arena_alloc.allocator());
        return Response{
            .allocator = arena_alloc,
            .method = Method.UNKNOWN,
            .status = Status.Ok,
            .headers = headers,
            .body = null,
        };
    }

    pub fn deinit(self: *Response) void {
        self.headers.deinit();
        self.allocator.deinit();
    }

    pub fn response_string(self: *Response) ![]u8 {
        var list = std.ArrayList(u8).init(self.allocator.allocator());
        defer list.deinit();

        const fmt = "HTTP/1.1 {d} {s}\r\n";
        var prologue: [128]u8 = undefined;
        _ = try bufPrint(&prologue, fmt, .{ @intFromEnum(self.status), self.status.string() });
        try list.appendSlice(&prologue);
        var keyIter = self.headers.iterator();
        while (keyIter.next()) |k| {
            try list.appendSlice(k.key_ptr.*);
            std.log.info("{s}", .{list.items});
            try list.appendSlice(": ");
            try list.appendSlice(k.value_ptr.*);
            try list.appendSlice("\r\n");
        }

        var resp_str = try self.allocator.allocator().alloc(u8, list.items.len + 1);
        std.mem.copy(u8, resp_str, list.items);
        // TODO(threadedstream): do strings in zig have a null-terminator?
        resp_str[resp_str.len - 1] = '0';
        return resp_str;
    }
};

test "sample request" {
    const req_str = "GET /path HTTP/1.1\r\nContent-Type: application/json\r\nAccept: application/json\r\n\r\nthisisbody";
    var request = try Request.init(req_str);
    try testing.expectEqual(request.method, Method.GET);
    try testing.expect(std.mem.eql(u8, request.path, "/path"));
    try testing.expect(std.mem.eql(u8, request.body.?, "thisisbody"));
    try testing.expect(std.mem.eql(u8, try request.getHeader("Content-Type"), "application/json"));
}
