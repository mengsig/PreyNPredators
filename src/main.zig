const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const cstd = @cImport({
    @cInclude("stdio.h");
});

const Thread = std.Thread;
const NUM_THREADS = 12;
const SAVE_FREQUENCY = 5000;
const LOOPS = false;
const COPYNUM = 10;
//const MODEL_LOADING = true;
//const MODEL_PATH = "models/";
//const MODEL_N = 1000;
//const MODEL_COUNTER = 45000;

const COOPERATION: bool = false;
const f = if (COOPERATION) @import("functionscooperation.zig") else @import("functions.zig");

const math = @import("std").math;
const DT: f32 = 0.37;
const GRID_SIZE: i32 = 1500;
const TOTAL_SIZE: i32 = GRID_SIZE * GRID_SIZE;
const CELL_SIZE: i8 = 1;
const WINDOW_SIZE: i32 = CELL_SIZE * GRID_SIZE;

const ENERGY_MAX: f32 = 100.0;
const PREY_ENERGY_GAIN: f32 = 2.5;
const PREY_LOSS_FACTOR: f32 = 10;
const SPLIT_ADD: f32 = 1.0 * DT;
const DEFAULT_ENERGY_LOSS: f32 = SPLIT_ADD / 8;
const ENERGY_SCALE_LOSS: f32 = 0.025;
const DEFAULT_DIGESTION_RATE: f32 = 1;
const RADIUS: f32 = 5.0;
const AGENTNO: u16 = 750;
const RADIUS2: f32 = RADIUS * RADIUS;
const SPLIT_MAX: f32 = 100.0;
const SPLIT_DECAY: f32 = 0.2 * DT;
const DIGESTION_MAX: f32 = 25;
const NUMBER_OF_RAYS: usize = 30;
const VISION_LENGTH: f32 = 750;
const PREY_FOV: f32 = 360.0 / 180.0 * math.pi;
const PREDATOR_FOV: f32 = 80.0 / 180.0 * math.pi;
const FNUMBER_OF_RAYS: f32 = @floatFromInt(NUMBER_OF_RAYS);
const MOMENTUM: f32 = 0.95;

// Plotting stuff
const PLOT_WINDOW_HEIGHT: u16 = 1500;
const PLOT_WINDOW_WIDTH: u16 = 800;
const PLOT_MAX_POINTS: i32 = @intCast(AGENTNO);

// our random number generator
var prng = std.rand.DefaultPrng.init(0);
const randomGenerator = prng.random();

pub fn count(preyNo: *u16, predatorNo: *u16, array: *[AGENTNO]f.agent) void {
    preyNo.* = 0;
    predatorNo.* = 0;
    for (0..AGENTNO) |i| {
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

    const screen = c.SDL_CreateWindow("Prey & Predators", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, WINDOW_SIZE, WINDOW_SIZE, c.SDL_WINDOW_OPENGL) orelse {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(screen);

    const renderer = c.SDL_CreateRenderer(screen, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    // Create second window for plotting
    const plot_window = c.SDL_CreateWindow("Population Display", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, PLOT_WINDOW_WIDTH, PLOT_WINDOW_HEIGHT, c.SDL_WINDOW_OPENGL) orelse {
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
    var preyData: [PLOT_MAX_POINTS]u16 = undefined;
    var predatorData: [PLOT_MAX_POINTS]u16 = undefined;
    preyData[0] = 0;
    predatorData[0] = 0;
    var currentIndex: u32 = 0;

    // initializing stuff for saving
    const fs = std.fs.cwd();
    const allocator1 = std.heap.page_allocator;
    var filename = try std.fmt.allocPrint(allocator1, "models/prey1_{}_{}_{}.txt", .{ 0, AGENTNO, 0 });

    //Test different allocators for speed
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const chunk_size = AGENTNO / NUM_THREADS;

    //Intializing our array of agents
    var ourArray: [AGENTNO]f.agent = undefined;
    var predneuronx: @Vector(NUMBER_OF_RAYS, f32) = undefined;
    var predneurony: @Vector(NUMBER_OF_RAYS, f32) = undefined;
    var preyneuronx: @Vector(NUMBER_OF_RAYS, f32) = undefined;
    var preyneurony: @Vector(NUMBER_OF_RAYS, f32) = undefined;

    //Initial conditions
    f.initialize(&ourArray);

    //Create threads array for parallel processing
    var threads = try allocator.alloc(std.Thread, NUM_THREADS);
    defer allocator.free(threads);

    //Create contexts array for parallel processing
    var contexts = try allocator.alloc(f.UpdateContext, NUM_THREADS);
    defer allocator.free(contexts);

    var quit: bool = false;
    var counter: u32 = 0;
    while (!quit) {
        counter += 1;
        // Save function
        if (counter % SAVE_FREQUENCY == 0) {
            for (0..AGENTNO) |i| {
                if (ourArray[i].species == f.Species.prey) {
                    if (!ourArray[i].is_dead) {
                        preyneuronx = ourArray[i].neuronx;
                        preyneurony = ourArray[i].neurony;
                    }
                    filename = try std.fmt.allocPrint(allocator1, "models/prey1_{}_{}_{}.txt", .{ counter, AGENTNO, i });
                    var file = try fs.createFile(filename, .{});
                    defer file.close();
                    var writer = file.writer();
                    try writer.print("neuron1,neuron2\n", .{});
                    for (0..NUMBER_OF_RAYS) |j| {
                        try writer.print("{},{}\n", .{ ourArray[i].neuronx[j], ourArray[i].neurony[j] });
                    }
                } else {
                    if (!ourArray[i].is_dead) {
                        predneuronx = ourArray[i].neuronx;
                        predneurony = ourArray[i].neurony;
                    }
                    filename = try std.fmt.allocPrint(allocator1, "models/predator1_{}_{}_{}.txt", .{ counter, AGENTNO, i });
                    var file = try fs.createFile(filename, .{});
                    defer file.close();
                    var writer = file.writer();
                    try writer.print("neuron1,neuron2\n", .{});
                    for (0..NUMBER_OF_RAYS) |j| {
                        try writer.print("{},{}\n", .{ ourArray[i].neuronx[j], ourArray[i].neurony[j] });
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
        for (0..NUM_THREADS) |t| {
            const start = t * chunk_size;
            const end = if (t == NUM_THREADS - 1) AGENTNO else start + chunk_size;
            contexts[t] = f.UpdateContext{ .array = &ourArray, .start = start, .end = end };
            threads[t] = try std.Thread.spawn(.{
                .stack_size = 512 * 512, //  Adjust depending on Number of Agents.
                .allocator = allocator, // Pass the allocator
            }, f.update_agent_chunk, .{&contexts[t]});
        }

        for (0..NUM_THREADS) |t| {
            threads[t].join();
        }

        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF); // Black color
        _ = c.SDL_RenderClear(renderer);
        for (0..AGENTNO) |i| {
            if (!ourArray[i].is_dead) {
                switch (ourArray[i].species) {
                    f.Species.predator => {
                        _ = c.SDL_SetRenderDrawColor(renderer, 0xFF, 0x00, 0x00, 0xFF); // Red
                    },
                    f.Species.prey => {
                        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0xFF, 0x00, 0xFF); // Green
                    },
                }
                DrawCircle(renderer, ourArray[i].posx, ourArray[i].posy, RADIUS);
            }
        }
        _ = c.SDL_RenderPresent(renderer);

        // Update plot data (dummy update for demonstration purposes)
        count(&preyNo, &predatorNo, &ourArray);

        // Store the data
        currentIndex = (currentIndex + 1) % PLOT_MAX_POINTS;
        preyData[currentIndex] = preyNo;
        predatorData[currentIndex] = predatorNo;

        // Render plot
        _ = c.SDL_SetRenderDrawColor(plot_renderer, 0x00, 0x00, 0x00, 0xFF); // Black background
        _ = c.SDL_RenderClear(plot_renderer);

        theCount = 0;
        while (theCount < PLOT_MAX_POINTS - 1) {
            const x1 = @divFloor((theCount * PLOT_WINDOW_WIDTH), PLOT_MAX_POINTS);
            const x2 = @divFloor(((theCount + 1) * PLOT_WINDOW_WIDTH), PLOT_MAX_POINTS);

            const newCount: u32 = @intCast(theCount);
            const preyY1: i32 = @intCast(PLOT_WINDOW_HEIGHT - (preyData[(currentIndex + newCount) % PLOT_MAX_POINTS]) * (PLOT_WINDOW_HEIGHT / PLOT_MAX_POINTS));
            const preyY2: i32 = @intCast(PLOT_WINDOW_HEIGHT - (preyData[(currentIndex + newCount + 1) % PLOT_MAX_POINTS]) * (PLOT_WINDOW_HEIGHT / PLOT_MAX_POINTS));

            const predatorY1: i32 = @intCast(PLOT_WINDOW_HEIGHT - (predatorData[(currentIndex + newCount) % PLOT_MAX_POINTS]) * (PLOT_WINDOW_HEIGHT / PLOT_MAX_POINTS));
            const predatorY2: i32 = @intCast(PLOT_WINDOW_HEIGHT - (predatorData[(currentIndex + newCount + 1) % PLOT_MAX_POINTS]) * (PLOT_WINDOW_HEIGHT / PLOT_MAX_POINTS));

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
            if (LOOPS) {
                for (0..AGENTNO - COPYNUM) |i| {
                    ourArray[i].is_dead = false;
                    if (tempCounter < COPYNUM) {
                        ourArray[i].species = f.Species.prey;
                        ourArray[i].neuronx = preyneuronx;
                        ourArray[i].neurony = preyneurony;
                        ourArray[i].posx = randomGenerator.float(f32) * GRID_SIZE;
                        ourArray[i].posy = randomGenerator.float(f32) * GRID_SIZE;
                        ourArray[AGENTNO - 1 - tempCounter].posx = randomGenerator.float(f32) * GRID_SIZE;
                        ourArray[AGENTNO - 1 - tempCounter].posx = randomGenerator.float(f32) * GRID_SIZE;
                        ourArray[AGENTNO - 1 - tempCounter].species = f.Species.predator;
                        ourArray[AGENTNO - 1 - tempCounter].neuronx = predneuronx;
                        ourArray[AGENTNO - 1 - tempCounter].neurony = predneurony;
                        tempCounter += 1;
                    } else {
                        ourArray[i].posx = randomGenerator.float(f32) * GRID_SIZE;
                        ourArray[i].posy = randomGenerator.float(f32) * GRID_SIZE;
                    }
                }
            } else {
                break;
            }
        }
    }
    for (0..AGENTNO) |i| {
        if (ourArray[i].species == f.Species.prey) {
            filename = try std.fmt.allocPrint(allocator1, "models/prey1_{}_{}_{}.txt", .{ counter, AGENTNO, i });
            var file = try fs.createFile(filename, .{});
            defer file.close();
            var writer = file.writer();
            try writer.print("neuron1,neuron2\n", .{});
            for (0..NUMBER_OF_RAYS) |j| {
                try writer.print("{},{}\n", .{ ourArray[i].neuronx[j], ourArray[i].neurony[j] });
            }
        } else {
            filename = try std.fmt.allocPrint(allocator1, "models/predator1_{}_{}_{}.txt", .{ counter, AGENTNO, i });
            var file = try fs.createFile(filename, .{});
            defer file.close();
            var writer = file.writer();
            try writer.print("neuron1,neuron2\n", .{});
            for (0..NUMBER_OF_RAYS) |j| {
                try writer.print("{},{}\n", .{ ourArray[i].neuronx[j], ourArray[i].neurony[j] });
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
