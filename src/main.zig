const std = @import("std");

const PREY_ENERGY_GAIN: f16 = 2.5;
const PREDATOR_ENERGY_GAIN: f16 = PREY_ENERGY_GAIN * 10.0;
const DEFAULT_ENERGY_LOSS: f16 = 1.0;
const ENERGY_SCALE_LOSS: f16 = 1.0;
const DEFAULT_DIGESTION_RATE: f16 = 0.1;
const SIZE: f16 = 1.0;
const DT: f16 = 1.0;
const AGENTNO: u16 = 100;

const Species = enum {
    prey,
    predator,
};

const agent = struct {
    species: Species,
    posx: f16,
    posy: f16,
    velx: f16,
    vely: f16,
    speed: f16,
    energy: f16,
    split: f16,
    digestion: f16,
    is_child: bool,
    is_dead: bool,

    const Self = @This();

    pub fn init(species: Species, posx: f16, posy: f16, velx: f16, vely: f16, speed: f16, energy: f16, split: f16, digestion: f16, is_child: bool, is_dead: bool) agent {
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
    var testPredator = agent.init(Species.predator, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, true, false);
    var testPrey = agent.init(Species.prey, 0.0, 0.0, 0.5, -1.0, 0.0, 0.0, 0.0, 0.0, true, false);
    var ourArray: [AGENTNO]agent = undefined;
    initialize(&ourArray);
    ourArray[0].update_speed();
    ourArray[16].update_speed();
    std.debug.print("{}\n", .{ourArray[16].speed});
    std.debug.print("{}\n", .{});
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
