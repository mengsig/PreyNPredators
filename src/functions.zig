const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const cstd = @cImport({
    @cInclude("stdio.h");
});
const Thread = std.Thread;
const NUM_THREADS = 12;

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

// our random number generator
var prng = std.rand.DefaultPrng.init(0);
pub const randomGenerator = prng.random();

pub inline fn abs(x: f32) f32 {
    if (x < 0) {
        return -x;
    } else {
        return x;
    }
}

pub const Species = enum {
    prey,
    predator,
};

pub const agent = struct {
    species: Species,
    posx: f32,
    posy: f32,
    vel: f32,
    theta: f32,
    energy: f32,
    split: f32,
    digestion: f32,
    is_dead: bool,
    neuronx: @Vector(NUMBER_OF_RAYS, f32),
    neurony: @Vector(NUMBER_OF_RAYS, f32),
    vision: @Vector(NUMBER_OF_RAYS, f32),

    const Self = @This();

    pub fn init(species: Species, posx: f32, posy: f32, velx: f32, vely: f32, energy: f32, split: f32, digestion: f32, is_dead: bool, neuronx: @Vector(NUMBER_OF_RAYS, f32), neurony: @Vector(NUMBER_OF_RAYS, f32)) agent {
        return agent{
            .species = species,
            .posx = posx,
            .posy = posy,
            .vel = velx,
            .theta = vely,
            .energy = energy,
            .split = split,
            .digestion = digestion,
            .is_dead = is_dead,
            .neuronx = neuronx,
            .neurony = neurony,
            .vision = neuronx,
        };
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
                    array[i].vel = self.vel;
                    array[i].theta = self.theta;
                    array[i].energy = ENERGY_MAX;
                    array[i].split = 0;
                    array[i].digestion = 0;
                    for (0..NUMBER_OF_RAYS) |j| {
                        if (randomGenerator.float(f32) < 2 / FNUMBER_OF_RAYS) {
                            array[i].neuronx[j] = self.neuronx[j] + (randomGenerator.float(f32) - 0.5) / 5;
                        } else {
                            array[i].neuronx[j] = self.neuronx[j];
                        }
                        if (randomGenerator.float(f32) < 2 / FNUMBER_OF_RAYS) {
                            array[i].neurony[j] = self.neurony[j] + (randomGenerator.float(f32) - 0.5) / 5;
                        } else {
                            array[i].neurony[j] = self.neurony[j];
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
        var t: f32 = 0;
        var endpointx: f32 = 0;
        var endpointy: f32 = 0;
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
        for (0..NUMBER_OF_RAYS) |i| {
            endpointx = self.posx + (VISION_LENGTH * math.cos(angle + self.theta));
            endpointy = self.posy + (VISION_LENGTH * math.sin(angle + self.theta));
            dx = endpointx - self.posx;
            dy = endpointy - self.posy;
            t = 100000.0;
            for (0..AGENTNO) |j| {
                if (self.species != array[j].species and (!array[j].is_dead)) {
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
            if (t == 100000.0) {
                self.vision[i] = 0;
            } else {
                self.vision[i] = 1 / (t + 0.2);
            }
            angle += step;
        }
    }

    pub fn update_velocity(self: *Self) void {
        const xvec: @Vector(NUMBER_OF_RAYS, f32) = self.vision * self.neuronx;
        const yvec: @Vector(NUMBER_OF_RAYS, f32) = self.vision * self.neurony;
        var dsum: f32 = 0;
        var thetasum: f32 = 0;
        for (0..NUMBER_OF_RAYS) |i| {
            dsum += xvec[i];
            thetasum += yvec[i];
        }
        dsum = 1 / (1 + @exp(dsum)) - 0.5;
        thetasum = 1 / (1 + @exp(thetasum)) - 0.5;
        if ((dsum == 0) and (thetasum == 0)) {
            thetasum = 0.2;
        }
        if (self.vel * self.vel < 1e-5) {
            self.theta += 6.28 / 100.0 * DT;
        }
        if (self.energy == 0) {
            self.vel = 0;
            if (self.species == Species.predator) {
                self.is_dead = true;
            }
        } else {
            self.vel += dsum * DT;
        }
        self.theta += thetasum / 10 * DT;
        self.vel = self.vel * MOMENTUM;
    }

    pub fn update_position(self: *Self) void {
        self.posx += self.vel * math.cos(self.theta) * DT;
        self.posy += self.vel * math.sin(self.theta) * DT;
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
                if (self.vel < 0.001) {
                    self.energy += PREY_ENERGY_GAIN;
                } else {
                    self.energy += (-self.vel * ENERGY_SCALE_LOSS * PREY_LOSS_FACTOR);
                    if (self.energy < 0) {
                        self.energy = 0;
                    }
                }
            },
            // remember that one is predator
            Species.predator => {
                self.energy += (-self.vel * ENERGY_SCALE_LOSS) - DEFAULT_ENERGY_LOSS;
            },
        }
    }

    pub fn eats(self: *Self, array: *[AGENTNO]agent) void {
        if (self.species == Species.predator) {
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
                                    self.energy += ENERGY_MAX / 2;
                                    if (self.energy > ENERGY_MAX) {
                                        self.energy = ENERGY_MAX;
                                    }
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
        if (self.species == Species.prey) {
            self.split += SPLIT_ADD / (1 + @sqrt(abs(self.vel)));
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
            if (randomGenerator.float(f32) < 0.2 / FNUMBER_OF_RAYS) {
                neuronx[j] = 2 * (randomGenerator.float(f32) - 0.5) * 1;
                neurony[j] = 2 * (randomGenerator.float(f32) - 0.5) * 1;
            } else {
                neuronx[j] = 0;
                neurony[j] = 0;
            }
        }
        if (randomGenerator.boolean()) {
            array[i] = agent.init(Species.prey, randomGenerator.float(f32) * GRID_SIZE, randomGenerator.float(f32) * GRID_SIZE, 0.0, 0.0, randomGenerator.float(f32) * ENERGY_MAX, randomGenerator.float(f32) * SPLIT_MAX, 0.0, false, neuronx, neurony);
        } else {
            array[i] = agent.init(Species.predator, randomGenerator.float(f32) * GRID_SIZE, randomGenerator.float(f32) * GRID_SIZE, 0.0, 0.0, randomGenerator.float(f32) * ENERGY_MAX, randomGenerator.float(f32) * SPLIT_MAX, 0.0, false, neuronx, neurony);
        }
    }
}

pub fn update_agent(array: *[AGENTNO]agent, ourAgent: *agent) !void {
    if (!ourAgent.is_dead) {
        ourAgent.update_vision(array);
        ourAgent.update_velocity();
        ourAgent.update_position();
        ourAgent.update_energy();
        if (ourAgent.energy > ENERGY_MAX) {
            ourAgent.energy = ENERGY_MAX;
        }

        ourAgent.update_death();
        ourAgent.update_digestion();
        ourAgent.eats(array);
        ourAgent.update_children(array);
    }
}
pub const UpdateContext = struct {
    array: *[AGENTNO]agent,
    start: usize,
    end: usize,
};

pub fn update_agent_chunk(ctx: *UpdateContext) !void {
    for (ctx.start..ctx.end) |i| {
        try update_agent(ctx.array, &ctx.array[i]);
    }
}
