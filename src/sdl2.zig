// src/sdl2.zig
const std = @import("std");

pub usingnamespace @cImport({
    @cInclude("SDL2/SDL.h");
});
