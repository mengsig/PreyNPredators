const std = @import("std");

const ENERGY_MAX: f32 = 100.0;
const PREY_ENERGY_GAIN: f32 = 2.5;
const PREDATOR_ENERGY_GAIN: f32 = PREY_ENERGY_GAIN * 10.0;
const DEFAULT_ENERGY_LOSS: f32 = 0.2;
const ENERGY_SCALE_LOSS: f32 = 1.0;
const DEFAULT_DIGESTION_RATE: f32 = 0.1;
const RADIUS: f32 = 1.0;
const DT: f32 = 1.0;
const AGENTNO: u16 = 100;
const RADIUS2: f32 = RADIUS * RADIUS;
const SPLIT_MAX: f32 = 100.0;
const SPLIT_DECAY: f32 = 0.1;
const DIGESTION_MAX: f32 = 10;
const GRID_SIZE = 100;

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
        array[i] = agent.init(Species.predator, randomGenerator.float(f32) * GRID_SIZE, randomGenerator.float(f32) * GRID_SIZE, 0.0, 0.0, 0.0, ENERGY_MAX, 0.0, 0.0, true, false);
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
    var testPredator = agent.init(Species.predator, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, true, false);
    var testPrey = agent.init(Species.prey, 0.0, 0.0, 0.5, -1.0, 0.0, 0.0, 0.0, 0.0, true, false);
    var ourArray: [AGENTNO]agent = undefined;
    initialize(&ourArray);
    ourArray[0].update_speed();
    ourArray[16].update_speed();
    for (0..AGENTNO) |i| {
        update_agent(&ourArray, &ourArray[0]);
        std.debug.print("{}: {}, {} \n", .{ i, ourArray[0].energy, ourArray[0].is_dead });
    }

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
}
