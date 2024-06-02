const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const cstd = @cImport({@cInclude("stdio.h");});
const GRID_SIZE:u32 = 1500;
const TOTAL_SIZE: u32 = GRID_SIZE*GRID_SIZE;
const CELL_SIZE: i8 = 1;
const WINDOW_SIZE: i32 = CELL_SIZE*GRID_SIZE;
const PREY_ENERGY_GAIN: f32 = 2.5;
const PREDATOR_ENERGY_GAIN: f32 = PREY_ENERGY_GAIN * 10.0;
const DEFAULT_ENERGY_LOSS: f32 = 1.0;
const ENERGY_SCALE_LOSS: f32 = 1.0;
const DEFAULT_DIGESTION_RATE: f32 = 0.1;
const SIZE: f32 = 1.0;
const DT: f32 = 1.0;
const AGENTNO: u16 = 100;
const RADUIS: f32 = 1.0;
const Species = enum {
    prey,
    predator,
};




const agent = struct {
    species: Species,
    posx: f32,
    posy: f32,
    velx: f32,
    vely: f32,
    speed: f32,
    energy: f32,
    split: f32,
    digestion: f32,
    is_child: bool,
    is_dead: bool,

    const Self = @This();

    pub fn init(species: Species, posx: f32, posy: f32, velx: f32, vely: f32, speed: f32, energy: f32, split: f32, digestion: f32, is_child: bool, is_dead: bool) agent {
        return agent{
            .species = species,
            .posx = posx,
            .posy = posy,
            .velx = velx,
            .vely = vely,
            .speed = speed,
            .energy = energy,
            .split = split,
            .digestion = digestion,
            .is_child = is_child,
            .is_dead = is_dead,
        };
    }
    pub fn update_speed(self: *Self) void {
        //potentially make it scale with x and y
        self.speed = @sqrt(self.velx * self.velx + self.vely * self.vely);
    }

    pub fn update_position(self: *Self) void {
        self.posx += self.velx * DT;
        self.posy += self.vely * DT;
    }

    pub fn update_energy(self: *Self) void {
        switch (self.species) {
            // remember that zero is prey
            Species.prey => {
                if (self.speed < 0.001) {
                    self.energy += 2.5;
                } else {
                    self.energy += -self.speed * ENERGY_SCALE_LOSS;
                }
            },
            // remember that one is predator
            Species.predator => {
                self.energy += (-self.speed * ENERGY_SCALE_LOSS) - DEFAULT_ENERGY_LOSS;
            },
        }
    }

    pub fn eats(self: *Self) void {
        self.energy += PREDATOR_ENERGY_GAIN;
    }

    pub fn update_digestion(self: *Self) void {
        self.digestion += -DEFAULT_DIGESTION_RATE;
        if (self.digestion < 0) {
            self.digestion = 0;
        }
    }

    pub fn update_death(self: *Self) void {
        if (self.energy < 0) {
            self.is_dead = true;
        }
    }
};

pub fn initialize(array: *[AGENTNO]agent) void {
    for (0..AGENTNO) |i| {
        array[i] = agent.init(Species.predator, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, true, false);
    }
}

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const screen = c.SDL_CreateWindow("My Game Window", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, WINDOW_SIZE, WINDOW_SIZE, c.SDL_WINDOW_OPENGL) orelse
    {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(screen);

    const renderer = c.SDL_CreateRenderer(screen, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    var testPredator = agent.init(Species.predator, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, true, false);
    var testPrey = agent.init(Species.prey, 0.0, 0.0, 0.5, -1.0, 0.0, 0.0, 0.0, 0.0, true, false);
    var ourArray: [AGENTNO]agent = undefined;
    initialize(&ourArray);
    ourArray[0].update_speed();
    ourArray[16].update_speed();
    std.debug.print("{}\n", .{ourArray[16].speed});

    testPredator.update_speed();
    testPredator.update_position();
    testPredator.update_energy();
    testPredator.update_digestion();
    testPredator.update_death();
    std.debug.print("{}\n", .{testPredator.is_dead});
    std.debug.print("{}\n", .{testPredator.posx});
    std.debug.print("{}\n", .{testPredator.posy});

    testPrey.update_speed();
    testPrey.update_position();
    testPrey.update_energy();
    testPrey.update_digestion();
    testPrey.update_death();
    std.debug.print("{}\n", .{testPrey.is_dead});
    std.debug.print("{}\n", .{testPrey.posx});
    std.debug.print("{}\n", .{testPrey.posy});

    while (true) {
        for(0..AGENTNO) |i|{
            if(ourArray[i].is_dead == false){
                _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF); // Black color
                _ = c.SDL_RenderClear(renderer);
                switch (ourArray[i].species) {
                    Species.predator => {
                        _ = c.SDL_SetRenderDrawColor(renderer, 0xFF, 0x00, 0x00, 0xFF); //Red;
                    },
                    Species.prey => {
                        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0xFF, 0xFF); //Green
                    },
                }
                DrawCircle(renderer, ourArray[i].posx+20, ourArray[i].posy+20, RADUIS*10);
                //DrawCircle(renderer,  10,10,2);
                _ = c.SDL_RenderPresent(renderer);

            }
        }
    }
}

pub fn  DrawCircle(renderer: *c.SDL_Renderer,centerX: f32,centerY: f32,radius: f32) void {
    // Using the Midpoint Circle Algorithm
    var x: i32 = @intFromFloat(radius);
    var y: i32 = 0;
    var p: i32 = 1 - @as(i32, @intFromFloat(radius));

    // Draw the initial point on each octant
    while (x > y) {
        y += 1;

        if (p <= 0) {
            p = p + 2 * y + 1;
        } else {
            x -=1;
            p = p + 2 * y - 2 * x + 1;
        }

        // Draw points in all eight octants
        const centerX1: i32 = @intFromFloat(centerX);
        const centerY1: i32 = @intFromFloat(centerY);
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
