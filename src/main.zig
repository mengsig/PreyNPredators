const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const cstd = @cImport({
    @cInclude("stdio.h");
});
const GRID_SIZE: i32 = 1500;
const TOTAL_SIZE: i32 = GRID_SIZE * GRID_SIZE;
const CELL_SIZE: i8 = 1;
const WINDOW_SIZE: i32 = CELL_SIZE * GRID_SIZE;
const ENERGY_MAX: f32 = 100.0;
const PREY_ENERGY_GAIN: f32 = 2.5;
const PREDATOR_ENERGY_GAIN: f32 = PREY_ENERGY_GAIN * 10.0;
const DEFAULT_ENERGY_LOSS: f32 = 0.052;
const ENERGY_SCALE_LOSS: f32 = 0.0;
const DEFAULT_DIGESTION_RATE: f32 = 0.1;
const RADIUS: f32 = 10.0;
const DT: f32 = 1.0;
const AGENTNO: u16 = 100;
const RADIUS2: f32 = RADIUS * RADIUS;
const SPLIT_MAX: f32 = 100.0;
const SPLIT_DECAY: f32 = 0.1;
const DIGESTION_MAX: f32 = 10;

// our random number generator
var prng = std.rand.DefaultPrng.init(0);
const randomGenerator = prng.random();

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

    pub fn update_velocity(self: *Self) void {
        self.velx += randomGenerator.float(f32) - 0.5;
        self.vely += randomGenerator.float(f32) - 0.5;
        if ((self.energy <= 0) and (self.species == Species.prey)) {
            self.velx = 0;
            self.vely = 0;
        }
    }

    pub fn update_position(self: *Self) void {
        self.posx += self.velx * DT;
        self.posy += self.vely * DT;
        if (self.posx > GRID_SIZE) {
            self.posx += -GRID_SIZE;
        }
        if (self.posx < 0) {
            self.posx += GRID_SIZE;
        }
        if (self.posy > GRID_SIZE) {
            self.posy += -GRID_SIZE;
        }
        if (self.posy < 0) {
            self.posy += GRID_SIZE;
        }
    }

    pub fn update_energy(self: *Self) void {
        switch (self.species) {
            // remember that zero is prey
            Species.prey => {
                if (self.speed < 0.001) {
                    self.energy += PREY_ENERGY_GAIN;
                } else {
                    self.energy += -self.speed * ENERGY_SCALE_LOSS;
                    if (self.energy < 0) {
                        self.energy = 0;
                    }
                }
            },
            // remember that one is predator
            Species.predator => {
                self.energy += (-self.speed * ENERGY_SCALE_LOSS) - DEFAULT_ENERGY_LOSS;
            },
        }
    }

    pub fn eats(self: *Self, array: *[AGENTNO]agent) void {
        if ((!self.is_dead) and (self.species == Species.predator)) {
            var distance: f32 = 0;
            var xdistance: f32 = 0;
            var ydistance: f32 = 0;
            for (0..AGENTNO) |i| {
                if ((!array[i].is_dead) and (array[i].species == Species.prey)) {
                    xdistance = (self.posx - array[i].posx) * (self.posx - array[i].posx);
                    if (xdistance < RADIUS2) {
                        ydistance = (self.posy - array[i].posy) * (self.posy - array[i].posy);
                        if (ydistance < RADIUS2) {
                            distance = xdistance + ydistance;
                            if (distance < RADIUS2) {
                                array[i].is_dead = true;
                                if (self.digestion == 0) {
                                    self.energy += PREY_ENERGY_GAIN;
                                    self.split += SPLIT_MAX / 2;
                                    self.digestion = DIGESTION_MAX;
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }
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
        if (randomGenerator.boolean()) {
            array[i] = agent.init(Species.prey, randomGenerator.float(f32) * GRID_SIZE, randomGenerator.float(f32) * GRID_SIZE, 0.0, 0.0, 0.0, ENERGY_MAX, 0.0, 0.0, true, false);
        } else {
            array[i] = agent.init(Species.predator, randomGenerator.float(f32) * GRID_SIZE, randomGenerator.float(f32) * GRID_SIZE, 0.0, 0.0, 0.0, ENERGY_MAX, 0.0, 0.0, true, false);
        }
    }
}

pub fn update_agent(array: *[AGENTNO]agent, ourAgent: *agent) void {
    if (!ourAgent.is_dead) {
        ourAgent.update_velocity();
        ourAgent.update_speed();
        ourAgent.update_position();
        ourAgent.update_energy();
        ourAgent.update_death();
        ourAgent.update_digestion();
        ourAgent.eats(array);
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

    var ourArray: [AGENTNO]agent = undefined;

    initialize(&ourArray);
    var counter: u32 = 0;
    while (true) {
        counter += 1;
        std.debug.print("{}\n", .{counter});
        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF); // Black color
        _ = c.SDL_RenderClear(renderer);
        for (0..AGENTNO) |i| {
            update_agent(&ourArray, &ourArray[i]);
            if (ourArray[i].is_dead == false) {
                switch (ourArray[i].species) {
                    Species.predator => {
                        _ = c.SDL_SetRenderDrawColor(renderer, 0xFF, 0x00, 0x00, 0xFF); //Red;
                    },
                    Species.prey => {
                        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0xFF, 0x00, 0xFF); //Green
                    },
                }
                DrawCircle(renderer, ourArray[i].posx, ourArray[i].posy, RADIUS);
            }
        }
        _ = c.SDL_RenderPresent(renderer);
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
