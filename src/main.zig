const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const cstd = @cImport({
    @cInclude("stdio.h");
});
const math = @import("std").math;
const GRID_SIZE: i32 = 1500;
const TOTAL_SIZE: i32 = GRID_SIZE * GRID_SIZE;
const CELL_SIZE: i8 = 1;
const WINDOW_SIZE: i32 = CELL_SIZE * GRID_SIZE;
const ENERGY_MAX: f32 = 100.0;
const PREY_ENERGY_GAIN: f32 = 2.5;
const PREDATOR_ENERGY_GAIN: f32 = PREY_ENERGY_GAIN * 10.0;
const DEFAULT_ENERGY_LOSS: f32 = 0.002;
const ENERGY_SCALE_LOSS: f32 = 0.1;
const DEFAULT_DIGESTION_RATE: f32 = 0.1;
const RADIUS: f32 = 10.0;
const DT: f32 = 1.0;
const AGENTNO: u16 = 250;
const RADIUS2: f32 = RADIUS * RADIUS;
const SPLIT_MAX: f32 = 100.0;
const SPLIT_DECAY: f32 = 0.1;
const SPLIT_ADD: f32 = 0.1;
const DIGESTION_MAX: f32 = 10;
const NUMBER_OF_RAYS: usize = 24;
const VISION_LENGTH: f32 = 100000;
const PREY_FOV: f32 = 300.0 / 180.0 * math.pi;
const PREDATOR_FOV: f32 = 120.0 / 180.0 * math.pi;

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
    neuronx: @Vector(NUMBER_OF_RAYS, f32),
    neurony: @Vector(NUMBER_OF_RAYS, f32),
    vision: @Vector(NUMBER_OF_RAYS, f32),

    const Self = @This();

    pub fn init(species: Species, posx: f32, posy: f32, velx: f32, vely: f32, speed: f32, energy: f32, split: f32, digestion: f32, is_child: bool, is_dead: bool, neuronx: @Vector(NUMBER_OF_RAYS, f32), neurony: @Vector(NUMBER_OF_RAYS, f32)) agent {
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
            .neuronx = neuronx,
            .neurony = neurony,
            .vision = neuronx,
        };
    }
    pub fn update_speed(self: *Self) void {
        //potentially make it scale with x and y
        self.speed = @sqrt(self.velx * self.velx + self.vely * self.vely);
    }

    pub fn update_children(self: *Self, array: *[AGENTNO]agent) void {
        if (self.split > SPLIT_MAX) {
            self.split += -SPLIT_MAX;
            var set: bool = false;
            var i: u32 = 0;
            while ((set) or (i < AGENTNO - 1)) {
                if (array[i].is_dead) {
                    array[i].species = self.species;
                    array[i].is_dead = false;
                    array[i].posx = self.posx + RADIUS;
                    array[i].posy = self.posy + RADIUS;
                    array[i].velx = self.velx + RADIUS;
                    array[i].vely = self.vely + RADIUS;
                    array[i].energy = ENERGY_MAX;
                    array[i].split = 0;
                    array[i].digestion = 0;
                    array[i].vision = self.vision;
                    for (0..NUMBER_OF_RAYS) |j| {
                        if (randomGenerator.float(f32) < 0.1) {
                            array[i].vision[j] = (randomGenerator.float(f32) - 0.5) * 2;
                        }
                    }
                    set = true;
                    break;
                }
                i += 1;
            }
        }
    }
    pub fn update_vision(self: *Self, array: *[AGENTNO]agent) void {
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
        switch (self.species) {
            Species.prey => {
                step = PREY_FOV / (NUMBER_OF_RAYS - 1);
                angle = -PREY_FOV / 2;
            },
            Species.predator => {
                step = PREDATOR_FOV / (NUMBER_OF_RAYS - 1);
                angle = -PREDATOR_FOV / 2;
            },
        }
        var looking: f32 = 0;
        if ((self.vely == 0) and (self.velx == 0)) {
            looking = randomGenerator.float(f32) * 2 * math.pi;
        } else {
            looking = math.atan(self.vely / self.velx);
        }
        if (self.velx < 0) {
            looking += math.pi;
        }
        for (0..NUMBER_OF_RAYS) |i| {
            const endpointx: f32 = self.posx + (VISION_LENGTH * math.cos(angle));
            const endpointy: f32 = self.posy + (VISION_LENGTH * math.sin(angle));
            dx = endpointx - self.posx;
            dy = endpointy - self.posy;
            var t: f32 = 0;
            for (0..AGENTNO) |j| {
                if (self.species != array[j].species) {
                    fx = self.posx - array[j].posx;
                    fy = self.posy - array[j].posy;
                    a = (dx * dx) + (dy * dy);
                    b = 2 * (fx * dx + fy * dy);
                    ct = (fx * fx + fy * fy) - (RADIUS2);
                    discriminant = b * b - 4 * a * ct;
                    if (discriminant > 0) {
                        discriminant = math.sqrt(discriminant);
                        t1 = (-b - discriminant) / (2 * a);
                        t2 = (-b + discriminant) / (2 * a);
                        if ((t1 > 0) and (t1 < 1)) {
                            if ((t2 > 0) and (t2 < t1)) {
                                t = t2;
                            } else {
                                t = t1;
                            }
                        }
                        if ((t2 > 0) and (t2 < 1)) {
                            t = t2;
                        }
                    }
                }
            }
            self.vision[i] = t;
            angle += step;
        }
    }
    pub fn update_velocity(self: *Self) void {
        const xvec: @Vector(NUMBER_OF_RAYS, f32) = self.vision * self.neuronx;
        const yvec: @Vector(NUMBER_OF_RAYS, f32) = self.vision * self.neurony;
        var xsum: f32 = 0;
        var ysum: f32 = 0;
        for (0..NUMBER_OF_RAYS) |i| {
            xsum += xvec[i];
            ysum += yvec[i];
        }
        self.velx = xsum;
        self.vely = ysum;
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
                    if (xdistance < 4 * RADIUS2) {
                        ydistance = (self.posy - array[i].posy) * (self.posy - array[i].posy);
                        if (ydistance < 4 * RADIUS2) {
                            distance = xdistance + ydistance;
                            if (distance < 4 * RADIUS2) {
                                if (self.digestion == 0) {
                                    array[i].is_dead = true;
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
        if ((!self.is_dead) and (self.species == Species.prey)) {
            self.split += SPLIT_ADD;
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
    var neuronx: @Vector(NUMBER_OF_RAYS, f32) = undefined;
    var neurony: @Vector(NUMBER_OF_RAYS, f32) = undefined;
    for (0..AGENTNO) |i| {
        for (0..NUMBER_OF_RAYS) |j| {
            if (randomGenerator.float(f32) < 0.1) {
                neuronx[j] = 2 * (randomGenerator.float(f32) - 0.5);
                neurony[j] = 2 * (randomGenerator.float(f32) - 0.5);
                std.debug.print("{}, {} \n", .{ neuronx[j], neurony[j] });
            } else {
                neuronx[j] = 0;
                neurony[j] = 0;
            }
        }
        if (randomGenerator.boolean()) {
            array[i] = agent.init(Species.prey, randomGenerator.float(f32) * GRID_SIZE, randomGenerator.float(f32) * GRID_SIZE, 0.0, 0.0, 0.0, ENERGY_MAX, 0.0, 0.0, true, false, neuronx, neurony);
        } else {
            array[i] = agent.init(Species.predator, randomGenerator.float(f32) * GRID_SIZE, randomGenerator.float(f32) * GRID_SIZE, 0.0, 0.0, 0.0, ENERGY_MAX, 0.0, 0.0, true, false, neuronx, neurony);
        }
    }
}

pub fn update_agent(array: *[AGENTNO]agent, ourAgent: *agent) void {
    if (!ourAgent.is_dead) {
        ourAgent.update_vision(array);
        ourAgent.update_velocity();
        ourAgent.update_speed();
        ourAgent.update_position();
        ourAgent.update_energy();
        ourAgent.update_death();
        ourAgent.update_digestion();
        ourAgent.eats(array);
        ourAgent.update_children(array);
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
