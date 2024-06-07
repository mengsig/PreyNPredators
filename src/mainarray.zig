const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const cstd = @cImport({
    @cInclude("stdio.h");
});

const f = @import("array.zig");
const Thread = std.Thread;
const NUM_THREADS = 12;
const SAVE_FREQUENCY = 5000;

const math = @import("std").math;
const DT: f32 = 0.37;
const GRID_SIZE: i32 = 1500;
const TOTAL_SIZE: i32 = GRID_SIZE * GRID_SIZE;
const CELL_SIZE: i8 = 1;
const WINDOW_SIZE: i32 = CELL_SIZE * GRID_SIZE;

const PLOT_WINDOW_HEIGHT: u16 = 600;
const PLOT_WINDOW_WIDTH: u16 = 800;

const ENERGY_MAX: f32 = 100.0;
const PREY_ENERGY_GAIN: f32 = 2.5;
const PREY_LOSS_FACTOR: f32 = 10;
const SPLIT_ADD: f32 = 1.0 * DT;
const DEFAULT_ENERGY_LOSS: f32 = SPLIT_ADD / 5;
const ENERGY_SCALE_LOSS: f32 = 0.025;
const DEFAULT_DIGESTION_RATE: f32 = 1;
const RADIUS: f32 = 5.0;
const AGENTNO: u16 = 750;
const RADIUS2: f32 = RADIUS * RADIUS;
const SPLIT_MAX: f32 = 100.0;
const SPLIT_DECAY: f32 = 0.2 * DT;
const DIGESTION_MAX: f32 = 25;
const NUMBER_OF_RAYS: usize = 30;
const VISION_LENGTH: f32 = 300;
const PREY_FOV: f32 = 300.0 / 180.0 * math.pi;
const PREDATOR_FOV: f32 = 80.0 / 180.0 * math.pi;
const FNUMBER_OF_RAYS: f32 = @floatFromInt(NUMBER_OF_RAYS);
const MOMENTUM: f32 = 0.95;
const PLOT_MAX_POINTS: i32 = AGENTNO;

// our random number generator
var prng = std.rand.DefaultPrng.init(0);
const randomGenerator = prng.random();

pub fn count(is_dead: *[AGENTNO]bool, species: *[AGENTNO]f.Species, preyNo: *u32, predatorNo: *u32) void {
    preyNo.* = 0;
    predatorNo.* = 0;
    for (0..AGENTNO) |i| {
        if (!is_dead[i]) {
            switch (species[i]) {
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

    const screen = c.SDL_CreateWindow("My Game Window", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, WINDOW_SIZE, WINDOW_SIZE, c.SDL_WINDOW_OPENGL) orelse {
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
    const plot_window = c.SDL_CreateWindow("Plot Window", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, PLOT_WINDOW_WIDTH, PLOT_WINDOW_HEIGHT, c.SDL_WINDOW_OPENGL) orelse {
        c.SDL_Log("Unable to create plot window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(plot_window);

    const plot_renderer = c.SDL_CreateRenderer(plot_window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to create plot renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(plot_renderer);

    const fs = std.fs.cwd();
    const allocator = std.heap.page_allocator;
    var filename = try std.fmt.allocPrint(allocator, "models/prey1_{}_{}_{}.txt", .{ 0, AGENTNO, 0 });

    //Plotting stuff
    var preyNo: u32 = 0;
    var predatorNo: u32 = 0;
    var theCount: i32 = 0;
    var preyData: [PLOT_MAX_POINTS]u32 = undefined;
    var predatorData: [PLOT_MAX_POINTS]u32 = undefined;
    var currentIndex: u32 = 0;
    for (0..PLOT_MAX_POINTS) |i| {
        preyData[i] = 0;
        predatorData[i] = 0;
    }

    //Test different allocators for speed
    //    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //    const allocator = gpa.allocator();
    //    const chunk_size = AGENTNO / NUM_THREADS;

    //Initial conditions

    var posx: [AGENTNO]f32 = f.initialize_posx();
    var posy: [AGENTNO]f32 = f.initialize_posy();
    var vel: [AGENTNO]f32 = f.initialize_vel();
    var theta: [AGENTNO]f32 = f.initialize_theta();
    var energy: [AGENTNO]f32 = f.initialize_energy();
    var split: [AGENTNO]f32 = f.initialize_split();
    var digestion: [AGENTNO]f32 = f.initialize_digestion();
    var species: [AGENTNO]f.Species = f.initialize_species();
    var is_dead: [AGENTNO]bool = f.initialize_is_dead();
    var nn: [AGENTNO]f.neuralnet = f.initialize_nn();

    //Create threads array for parallel processing
    //    var threads = try allocator.alloc(std.Thread, NUM_THREADS);
    //    defer allocator.free(threads);

    //Create contexts array for parallel processing
    //    var contexts = try allocator.alloc(f.UpdateContext, NUM_THREADS);
    //    defer allocator.free(contexts);

    var quit: bool = false;
    var counter: u32 = 0;
    while (!quit) {
        counter += 1;
        if (counter % SAVE_FREQUENCY == 0) {
            for (0..AGENTNO) |i| {
                if (species[i] == f.Species.prey) {
                    filename = try std.fmt.allocPrint(allocator, "models/prey1_{}_{}_{}.txt", .{ counter, AGENTNO, i });
                    var file = try fs.createFile(filename, .{});
                    defer file.close();
                    var writer = file.writer();
                    try writer.print("neuron1,neuron2\n", .{});
                    for (0..NUMBER_OF_RAYS) |j| {
                        try writer.print("{},{}\n", .{ nn[i].neuronx[j], nn[i].neurony[j] });
                    }
                } else {
                    filename = try std.fmt.allocPrint(allocator, "models/predator1_{}_{}_{}.txt", .{ counter, AGENTNO, i });
                    var file = try fs.createFile(filename, .{});
                    defer file.close();
                    var writer = file.writer();
                    try writer.print("neuron1,neuron2\n", .{});
                    for (0..NUMBER_OF_RAYS) |j| {
                        try writer.print("{},{}\n", .{ nn[i].neuronx[j], nn[i].neurony[j] });
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
        try f.update_agents(&posx, &posy, &vel, &theta, &energy, &split, &digestion, &species, &is_dead, &nn);
        //        for (0..NUM_THREADS) |t| {
        //            const start = t * chunk_size;
        //            const end = if (t == NUM_THREADS - 1) AGENTNO else start + chunk_size;
        //            contexts[t] = f.UpdateContext{ .array = &ourArray, .start = start, .end = end };
        //            threads[t] = try std.Thread.spawn(.{
        //                .stack_size = 512 * 512, //  Adjust depending on Number of Agents.
        //                .allocator = allocator, // Pass the allocator
        //            }, f.update_agent_chunk, .{&contexts[t]});
        //        }
        //
        //        for (0..NUM_THREADS) |t| {
        //            threads[t].join();
        //        }

        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF); // Black color
        _ = c.SDL_RenderClear(renderer);
        for (0..AGENTNO) |i| {
            if (!is_dead[i]) {
                switch (species[i]) {
                    f.Species.predator => {
                        _ = c.SDL_SetRenderDrawColor(renderer, 0xFF, 0x00, 0x00, 0xFF); // Red
                    },
                    f.Species.prey => {
                        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0xFF, 0x00, 0xFF); // Green
                    },
                }
                DrawCircle(renderer, posx[i], posy[i], RADIUS);
            }
        }
        _ = c.SDL_RenderPresent(renderer);

        // Update plot data (dummy update for demonstration purposes)
        count(&is_dead, &species, &preyNo, &predatorNo);

        // Store the data
        var counter1: u32 = 0;
        var counter2: u32 = 0;
        for (0..AGENTNO) |i| {
            if (species[i] == f.Species.prey) {
                counter1 += 1;
            } else {
                counter2 += 1;
            }
        }
        preyData[currentIndex] = preyNo;
        predatorData[currentIndex] = predatorNo;
        currentIndex = (currentIndex + 1) % PLOT_MAX_POINTS;

        // Render plot
        _ = c.SDL_SetRenderDrawColor(plot_renderer, 0x00, 0x00, 0x00, 0xFF); // Black background
        _ = c.SDL_RenderClear(plot_renderer);

        theCount = 0;
        while (theCount < PLOT_MAX_POINTS - 1) {
            const x1 = @divFloor((theCount * PLOT_WINDOW_WIDTH), PLOT_MAX_POINTS);
            const x2 = @divFloor(((theCount + 1) * PLOT_WINDOW_WIDTH), PLOT_MAX_POINTS);

            const newCount: u32 = @intCast(theCount);
            const preyY1: i32 = @intCast(PLOT_WINDOW_HEIGHT - @divFloor(((preyData[(currentIndex + newCount) % PLOT_MAX_POINTS]) * PLOT_WINDOW_HEIGHT), PLOT_MAX_POINTS));
            const preyY2: i32 = @intCast(PLOT_WINDOW_HEIGHT - @divFloor(((preyData[(currentIndex + newCount + 1) % PLOT_MAX_POINTS]) * PLOT_WINDOW_HEIGHT), PLOT_MAX_POINTS));

            const predatorY1: i32 = @intCast(PLOT_WINDOW_HEIGHT - @divFloor(((predatorData[(currentIndex + newCount) % PLOT_MAX_POINTS]) * PLOT_WINDOW_HEIGHT), PLOT_MAX_POINTS));
            const predatorY2: i32 = @intCast(PLOT_WINDOW_HEIGHT - @divFloor(((predatorData[(currentIndex + newCount + 1) % PLOT_MAX_POINTS]) * PLOT_WINDOW_HEIGHT), PLOT_MAX_POINTS));

            // Draw prey line
            _ = c.SDL_SetRenderDrawColor(plot_renderer, 0, 255, 0, 255); // Green
            _ = c.SDL_RenderDrawLine(plot_renderer, x1, preyY1, x2, preyY2);

            // Draw predator line
            _ = c.SDL_SetRenderDrawColor(plot_renderer, 255, 0, 0, 255); // Red
            _ = c.SDL_RenderDrawLine(plot_renderer, x1, predatorY1, x2, predatorY2);
            theCount += 1;
        }

        _ = c.SDL_RenderPresent(plot_renderer);
        if ((preyNo == 0) or (predatorNo == 0)) {
            break;
        }
    }

    for (0..AGENTNO) |i| {
        filename = try std.fmt.allocPrint(allocator, "models/prey_{}_{}_{}.txt", .{ counter, AGENTNO, i });
        var file = try fs.createFile(filename, .{});
        defer file.close();
        var writer = file.writer();
        try writer.print("neuron1,neuron2\n", .{});
        for (0..NUMBER_OF_RAYS) |j| {
            try writer.print("{},{}\n", .{ nn[i].neuronx[j], nn[i].neurony[j] });
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
