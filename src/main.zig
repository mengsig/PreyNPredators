const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const cstd = @cImport({
    @cInclude("stdio.h");
});
const params = @import("./conf/const.zig");
const Thread = std.Thread;
//const MODEL_LOADING = true;
//const MODEL_PATH = "models/";
//const MODEL_N = 1000;
//const MODEL_COUNTER = 45000;

const f = if (params.COOPERATION) @import("functionscooperation.zig") else @import("functions.zig");

const math = @import("std").math;

// our random number generator
var prng = std.rand.DefaultPrng.init(0);
const randomGenerator = prng.random();

pub fn count(preyNo: *u16, predatorNo: *u16, array: *[params.AGENTNO]f.agent) void {
    preyNo.* = 0;
    predatorNo.* = 0;
    for (0..params.AGENTNO) |i| {
        if (!array[i].is_dead) {
            switch (array[i].species) {
                f.Species.prey => {
                    preyNo.* += 1;
                },
                f.Species.predator => {
                    predatorNo.* += 1;
                },
            }
        }
    }
}

const stdout = std.io.getStdOut().writer();
pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    // Main display
    const screen = c.SDL_CreateWindow("Prey & Predators", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, params.WINDOW_SIZE, params.WINDOW_SIZE, c.SDL_WINDOW_OPENGL) orelse {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(screen);

    const renderer = c.SDL_CreateRenderer(screen, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);
    // Zoomed in Display
    //if (params.FOLLOW) {
    const follow_screen = c.SDL_CreateWindow("Prey & Predators", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, params.WINDOW_SIZE, params.WINDOW_SIZE, c.SDL_WINDOW_OPENGL) orelse {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(screen);

    const follow_renderer = c.SDL_CreateRenderer(follow_screen, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(follow_renderer);
    //}
    // Create second window for plotting
    const plot_window = c.SDL_CreateWindow("Population Display", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, params.PLOT_WINDOW_WIDTH, params.PLOT_WINDOW_HEIGHT, c.SDL_WINDOW_OPENGL) orelse {
        c.SDL_Log("Unable to create plot window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(plot_window);

    const plot_renderer = c.SDL_CreateRenderer(plot_window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to create plot renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(plot_renderer);

    //Plotting stuff
    var preyNo: u16 = 0;
    var predatorNo: u16 = 0;
    var theCount: i32 = 0;
    var preyData: [params.PLOT_MAX_POINTS]u16 = undefined;
    var predatorData: [params.PLOT_MAX_POINTS]u16 = undefined;
    preyData[0] = 0;
    predatorData[0] = 0;
    var currentIndex: u32 = 0;

    // initializing stuff for saving
    const fs = std.fs.cwd();
    const allocator1 = std.heap.page_allocator;

    //Test different allocators for speed
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const chunk_size = params.AGENTNO / params.NUM_THREADS;

    //Intializing our array of agents
    var ourArray: [params.AGENTNO]f.agent = undefined;
    var predneuronx: @Vector(params.NUMBER_OF_RAYS, f32) = undefined;
    var predneurony: @Vector(params.NUMBER_OF_RAYS, f32) = undefined;
    var preyneuronx: @Vector(params.NUMBER_OF_RAYS, f32) = undefined;
    var preyneurony: @Vector(params.NUMBER_OF_RAYS, f32) = undefined;

    //Initial conditions
    f.initialize(&ourArray);

    //Create threads array for parallel processing
    var threads = try allocator.alloc(std.Thread, params.NUM_THREADS);
    defer allocator.free(threads);

    //Create contexts array for parallel processing
    var contexts = try allocator.alloc(f.UpdateContext, params.NUM_THREADS);
    defer allocator.free(contexts);

    var quit: bool = false;
    var counter: u32 = 0;
    while (!quit) {
        counter += 1;
        // Save function
        if (counter % params.SAVE_FREQUENCY == 0) {
            const filenamePrey = try std.fmt.allocPrint(allocator1, "models/prey1_{}_{}.txt", .{ counter, params.AGENTNO });
            var filePrey = try fs.createFile(filenamePrey, .{});
            defer filePrey.close();
            var writerPrey = filePrey.writer();

            const filenamePredator = try std.fmt.allocPrint(allocator1, "models/predator1_{}_{}.txt", .{ counter, params.AGENTNO });
            var filePredator = try fs.createFile(filenamePredator, .{});
            defer filePredator.close();
            var writerPredator = filePredator.writer();
            for (0..params.AGENTNO) |i| {
                if (!ourArray[i].is_dead) {
                    if (ourArray[i].species == f.Species.prey) {
                        preyneuronx = ourArray[i].neuronx;
                        preyneurony = ourArray[i].neurony;
                        for (0..params.NUMBER_OF_RAYS) |j| {
                            try writerPrey.print("{},{},", .{ ourArray[i].neuronx[j], ourArray[i].neurony[j] });
                        }
                    } else {
                        predneuronx = ourArray[i].neuronx;
                        predneurony = ourArray[i].neurony;
                        for (0..params.NUMBER_OF_RAYS) |j| {
                            try writerPredator.print("{},{},", .{ ourArray[i].neuronx[j], ourArray[i].neurony[j] });
                        }
                    }
                }
            }
        }

        try stdout.print("{} \n", .{counter});
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }
        for (0..params.NUM_THREADS) |t| {
            const start = t * chunk_size;
            const end = if (t == params.NUM_THREADS - 1) params.AGENTNO else start + chunk_size;
            contexts[t] = f.UpdateContext{ .array = &ourArray, .start = start, .end = end };
            threads[t] = try std.Thread.spawn(.{
                .stack_size = 512 * 512, //  Adjust depending on Number of Agents.
                .allocator = allocator, // Pass the allocator
            }, f.update_agent_chunk, .{&contexts[t]});
        }

        for (0..params.NUM_THREADS) |t| {
            threads[t].join();
        }

        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF); // Black color
        _ = c.SDL_RenderClear(renderer);
        for (0..params.AGENTNO) |i| {
            if (i == 0) {
                _ = c.SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0x00, 0xFF); // Red
                DrawCircle(renderer, ourArray[i].posx, ourArray[i].posy, params.RADIUS);
            } else if (!ourArray[i].is_dead) {
                switch (ourArray[i].species) {
                    f.Species.predator => {
                        _ = c.SDL_SetRenderDrawColor(renderer, 0xFF, 0x00, 0x00, 0xFF); // Red
                    },
                    f.Species.prey => {
                        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0xFF, 0x00, 0xFF); // Green
                    },
                }
                DrawCircle(renderer, ourArray[i].posx, ourArray[i].posy, params.RADIUS);
            }
        }
        const leftx: f32 = ourArray[0].posx - (params.GRID_SIZE / params.ZOOM / 2);
        const rightx: f32 = ourArray[0].posx + (params.GRID_SIZE / params.ZOOM / 2);
        const diff: f32 = rightx - leftx;
        const bottomy: f32 = ourArray[0].posy - (params.GRID_SIZE / params.ZOOM / 2);
        if (params.FOLLOW) {
            _ = c.SDL_SetRenderDrawColor(follow_renderer, 0x00, 0x00, 0x00, 0xFF); // Black color
            _ = c.SDL_RenderClear(follow_renderer);
            for (0..params.AGENTNO) |i| {
                if (!ourArray[i].is_dead) {
                    if (i == 0) {
                        _ = c.SDL_SetRenderDrawColor(follow_renderer, 0xFF, 0xFF, 0x00, 0xFF); // Red
                        DrawCircle(follow_renderer, (ourArray[i].posx - leftx) / diff * params.GRID_SIZE, (ourArray[i].posy - bottomy) / diff * params.GRID_SIZE, params.RADIUS * params.ZOOM);

                        var dx: f32 = 0;
                        var dy: f32 = 0;
                        var fx: f32 = 0;
                        var fy: f32 = 0;
                        var a: f32 = 0;
                        var b: f32 = 0;
                        var ct: f32 = 0;
                        var discriminant: f32 = 0;
                        var step: f32 = 0;
                        var angle: f32 = 0;
                        var t1: f32 = 0;
                        var t2: f32 = 0;
                        var t: f32 = 0;
                        var endpointx: f32 = 0;
                        var endpointy: f32 = 0;
                        var x1: i32 = 0;
                        var y1: i32 = 0;
                        var x2: i32 = 0;
                        var y2: i32 = 0;
                        switch (ourArray[0].species) {
                            f.Species.prey => {
                                step = params.PREY_FOV / (params.NUMBER_OF_RAYS - 1);
                                angle = -params.PREY_FOV / 2;
                            },
                            f.Species.predator => {
                                step = params.PREDATOR_FOV / (params.NUMBER_OF_RAYS - 1);
                                angle = -params.PREDATOR_FOV / 2;
                            },
                        }
                        for (0..params.NUMBER_OF_RAYS) |_| {
                            endpointx = ourArray[0].posx + (params.VISION_LENGTH * math.cos(angle + ourArray[0].theta));
                            endpointy = ourArray[0].posy + (params.VISION_LENGTH * math.sin(angle + ourArray[0].theta));
                            dx = endpointx - ourArray[0].posx;
                            dy = endpointy - ourArray[0].posy;
                            t = 100000.0;
                            for (0..params.AGENTNO) |j| {
                                if (ourArray[0].species != ourArray[j].species and (!ourArray[j].is_dead)) {
                                    fx = ourArray[0].posx - ourArray[j].posx;
                                    fy = ourArray[0].posy - ourArray[j].posy;
                                    a = (dx * dx) + (dy * dy);
                                    b = 2 * (fx * dx + fy * dy);
                                    ct = (fx * fx + fy * fy) - (params.RADIUS2);
                                    discriminant = b * b - 4 * a * ct;
                                    if (discriminant > 0) {
                                        discriminant = math.sqrt(discriminant);
                                        t1 = (-b - discriminant) / (2 * a);
                                        t2 = (-b + discriminant) / (2 * a);
                                        if ((t1 > 0) and (t1 < 1)) {
                                            if ((t2 > 0) and (t2 < t1)) {
                                                if (t > t2) {
                                                    t = t2;
                                                }
                                            } else {
                                                if (t > t1) {
                                                    t = t1;
                                                }
                                            }
                                        }
                                        if ((t2 > 0) and (t2 < 1)) {
                                            if (t > t2) {
                                                t = t2;
                                            }
                                        }
                                    }
                                }
                            }
                            if (t != 100000.0) {
                                endpointx = ourArray[0].posx + dx * t;
                                endpointy = ourArray[0].posy + dy * t;
                            }
                            y2 = @intFromFloat((endpointy - bottomy) / diff * params.GRID_SIZE);
                            x2 = @intFromFloat((endpointx - leftx) / diff * params.GRID_SIZE);
                            x1 = @intFromFloat((ourArray[0].posx - leftx) / diff * params.GRID_SIZE);
                            y1 = @intFromFloat((ourArray[0].posy - bottomy) / diff * params.GRID_SIZE);
                            //_ = c.SDL_SetRenderDrawColor(follow_renderer, 0xFF, 0xFF, 0x00, 0xFF); // Red
                            //std.debug.print("{}, {} \n", .{ x2 - x1, y2 - y1 });
                            //std.debug.print("{}, {}, {}, {} \n", .{});
                            _ = c.SDL_RenderDrawLine(follow_renderer, x1, y1, x2, y2);
                            angle += step;
                        }
                    } else if ((@abs(ourArray[i].posx - ourArray[0].posx) < params.GRID_SIZE / params.ZOOM / 2) and (@abs(ourArray[i].posy - ourArray[0].posy) < params.GRID_SIZE / params.ZOOM / 2)) {
                        switch (ourArray[i].species) {
                            f.Species.predator => {
                                _ = c.SDL_SetRenderDrawColor(follow_renderer, 0xFF, 0x00, 0x00, 0xFF); // Red
                            },
                            f.Species.prey => {
                                _ = c.SDL_SetRenderDrawColor(follow_renderer, 0x00, 0xFF, 0x00, 0xFF); // Green
                            },
                        }

                        DrawCircle(follow_renderer, (ourArray[i].posx - leftx) / diff * params.GRID_SIZE, (ourArray[i].posy - bottomy) / diff * params.GRID_SIZE, params.RADIUS * params.ZOOM);
                    }
                }
            }
        }
        _ = c.SDL_RenderPresent(renderer);
        _ = c.SDL_RenderPresent(follow_renderer);

        // Update plot data (dummy update for demonstration purposes)
        count(&preyNo, &predatorNo, &ourArray);

        // Store the data
        preyData[currentIndex] = preyNo;
        predatorData[currentIndex] = predatorNo;
        currentIndex = (currentIndex + 1) % params.PLOT_MAX_POINTS;

        // Render plot
        _ = c.SDL_SetRenderDrawColor(plot_renderer, 0x00, 0x00, 0x00, 0xFF); // Black background
        _ = c.SDL_RenderClear(plot_renderer);

        theCount = 0;
        while (theCount < params.PLOT_MAX_POINTS - 1) {
            const x1 = @divFloor(((theCount) * params.PLOT_WINDOW_WIDTH), params.PLOT_MAX_POINTS);
            const x2 = @divFloor(((theCount + 1) * params.PLOT_WINDOW_WIDTH), params.PLOT_MAX_POINTS);

            const newCount: u32 = @intCast(theCount);
            const preyY1: i32 = @intCast(params.PLOT_WINDOW_HEIGHT - (preyData[(currentIndex + newCount) % params.PLOT_MAX_POINTS]) * (params.PLOT_WINDOW_HEIGHT / params.PLOT_MAX_POINTS));
            const preyY2: i32 = @intCast(params.PLOT_WINDOW_HEIGHT - (preyData[(currentIndex + newCount + 1) % params.PLOT_MAX_POINTS]) * (params.PLOT_WINDOW_HEIGHT / params.PLOT_MAX_POINTS));

            const predatorY1: i32 = @intCast(params.PLOT_WINDOW_HEIGHT - (predatorData[(currentIndex + newCount) % params.PLOT_MAX_POINTS]) * (params.PLOT_WINDOW_HEIGHT / params.PLOT_MAX_POINTS));
            const predatorY2: i32 = @intCast(params.PLOT_WINDOW_HEIGHT - (predatorData[(currentIndex + newCount + 1) % params.PLOT_MAX_POINTS]) * (params.PLOT_WINDOW_HEIGHT / params.PLOT_MAX_POINTS));

            // Draw prey line
            _ = c.SDL_SetRenderDrawColor(plot_renderer, 0, 255, 0, 255); // Green
            _ = c.SDL_RenderDrawLine(plot_renderer, x1, preyY1, x2, preyY2);

            // Draw predator line
            _ = c.SDL_SetRenderDrawColor(plot_renderer, 255, 0, 0, 255); // Red
            _ = c.SDL_RenderDrawLine(plot_renderer, x1, predatorY1, x2, predatorY2);
            theCount += 1;
        }

        var tempCounter: u32 = 0;
        _ = c.SDL_RenderPresent(plot_renderer);
        if ((preyNo == 0) or (predatorNo == 0)) {
            if (params.LOOPS) {
                for (0..params.AGENTNO - params.COPYNUM) |i| {
                    ourArray[i].is_dead = false;
                    if (tempCounter < params.COPYNUM) {
                        ourArray[i].species = f.Species.prey;
                        ourArray[i].neuronx = preyneuronx;
                        ourArray[i].neurony = preyneurony;
                        ourArray[i].posx = randomGenerator.float(f32) * params.GRID_SIZE;
                        ourArray[i].posy = randomGenerator.float(f32) * params.GRID_SIZE;
                        ourArray[params.AGENTNO - 1 - tempCounter].posx = randomGenerator.float(f32) * params.GRID_SIZE;
                        ourArray[params.AGENTNO - 1 - tempCounter].posx = randomGenerator.float(f32) * params.GRID_SIZE;
                        ourArray[params.AGENTNO - 1 - tempCounter].species = f.Species.predator;
                        ourArray[params.AGENTNO - 1 - tempCounter].neuronx = predneuronx;
                        ourArray[params.AGENTNO - 1 - tempCounter].neurony = predneurony;
                        tempCounter += 1;
                    } else {
                        ourArray[i].posx = randomGenerator.float(f32) * params.GRID_SIZE;
                        ourArray[i].posy = randomGenerator.float(f32) * params.GRID_SIZE;
                    }
                }
            } else {
                break;
            }
        }
    }
}

pub fn DrawCircle(renderer: *c.SDL_Renderer, centerX: f32, centerY: f32, radius: f32) void {
    // Using the Midpoint Circle Algorithm
    var counter: i32 = 0;
    const iRad: i32 = @intFromFloat(radius);
    while (counter < iRad) {
        counter += 1;
        var x: i32 = counter;
        var y: i32 = 0;
        var p: i32 = 1 - counter;
        const centerX1: i32 = @intFromFloat(centerX);
        const centerY1: i32 = @intFromFloat(centerY);

        // Draw the initial point on each octant
        while (x > y) {
            y += 1;

            if (p <= 0) {
                p = p + 2 * y + 1;
            } else {
                x -= 1;
                p = p + 2 * y - 2 * x + 1;
            }

            // Draw points in all eight octants
            _ = c.SDL_RenderDrawPoint(renderer, centerX1 + x, centerY1 + y);
            _ = c.SDL_RenderDrawPoint(renderer, centerX1 - x, centerY1 + y);
            _ = c.SDL_RenderDrawPoint(renderer, centerX1 + x, centerY1 - y);
            _ = c.SDL_RenderDrawPoint(renderer, centerX1 - x, centerY1 - y);
            _ = c.SDL_RenderDrawPoint(renderer, centerX1 + y, centerY1 + x);
            _ = c.SDL_RenderDrawPoint(renderer, centerX1 - y, centerY1 + x);
            _ = c.SDL_RenderDrawPoint(renderer, centerX1 + y, centerY1 - x);
            _ = c.SDL_RenderDrawPoint(renderer, centerX1 - y, centerY1 - x);
        }
    }
}
