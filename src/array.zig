const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const cstd = @cImport({
    @cInclude("stdio.h");
});

const f = @import("array.zig");
const Thread = std.Thread;
const NUM_THREADS = 14;

const math = @import("std").math;
const DT: f32 = 0.37;
const GRID_SIZE: i32 = 1500;
const TOTAL_SIZE: i32 = GRID_SIZE * GRID_SIZE;
const CELL_SIZE: i8 = 1;
const WINDOW_SIZE: i32 = CELL_SIZE * GRID_SIZE;

const PLOT_WINDOW_HEIGHT: u16 = 600;
const PLOT_WINDOW_WIDTH: u16 = 800;
const PLOT_MAX_POINTS: i32 = 1000;

const ENERGY_MAX: f32 = 100.0;
const PREY_ENERGY_GAIN: f32 = 2.5;
const PREY_LOSS_FACTOR: f32 = 10;
const SPLIT_ADD: f32 = 1.0 * DT;
const DEFAULT_ENERGY_LOSS: f32 = SPLIT_ADD / 5;
const ENERGY_SCALE_LOSS: f32 = 0.025;
const DEFAULT_DIGESTION_RATE: f32 = 1;
const RADIUS: f32 = 5.0;
const AGENTNO: u16 = 1500;
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

const stdout = std.io.getStdOut().writer();
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

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

pub const neuralnet = struct {
    neuronx: @Vector(NUMBER_OF_RAYS, f32),
    neurony: @Vector(NUMBER_OF_RAYS, f32),
    vision: @Vector(NUMBER_OF_RAYS, f32),
    pub fn init(neuronx: @Vector(NUMBER_OF_RAYS, f32), neurony: @Vector(NUMBER_OF_RAYS, f32)) neuralnet {
        return neuralnet{
            .neuronx = neuronx,
            .neurony = neurony,
            .vision = neuronx,
        };
    }
};

pub fn update_children(posx: *[AGENTNO]f32, posy: *[AGENTNO]f32, vel: *[AGENTNO]f32, theta: *[AGENTNO]f32, energy: *[AGENTNO]f32, split: *[AGENTNO]f32, digestion: *[AGENTNO]f32, species: *[AGENTNO]Species, is_dead: *[AGENTNO]bool, nn: *[AGENTNO]neuralnet) void {
    var index: u32 = 0;
    for (0..AGENTNO) |i| {
        if ((!is_dead[i]) and (species[i] == Species.predator)) {
            if (split[i] > SPLIT_MAX) {
                split[i] += -SPLIT_MAX;
                while (index < AGENTNO - 1) {
                    if (is_dead[index]) {
                        species[index] = species[i];
                        is_dead[index] = false;
                        posx[index] = posx[i] + RADIUS;
                        posy[index] = posy[i] + RADIUS;
                        vel[index] = vel[i];
                        theta[index] = theta[i];
                        energy[index] = ENERGY_MAX;
                        split[index] = 0;
                        digestion[index] = 0;
                        for (0..NUMBER_OF_RAYS) |j| {
                            if (randomGenerator.float(f32) < 1 / FNUMBER_OF_RAYS) {
                                nn[index].neuronx[j] = nn[i].neuronx[j] + (randomGenerator.float(f32) - 0.5) / 5;
                            } else {
                                nn[index].neuronx[j] = nn[i].neuronx[j];
                            }
                            if (randomGenerator.float(f32) < 1 / FNUMBER_OF_RAYS) {
                                nn[index].neurony[j] = nn[i].neurony[j] + (randomGenerator.float(f32) - 0.5) / 5;
                            } else {
                                nn[index].neurony[j] = nn[i].neurony[j];
                            }
                        }
                        break;
                    }
                    index += 1;
                }
            }
        }
    }
    for (0..AGENTNO) |i| {
        if ((!is_dead[i]) and (species[i] == Species.prey)) {
            if (split[i] > SPLIT_MAX) {
                split[i] += -SPLIT_MAX;
                while (index < AGENTNO - 1) {
                    if (is_dead[index]) {
                        species[index] = species[i];
                        is_dead[index] = false;
                        posx[index] = posx[i] + RADIUS;
                        posy[index] = posy[i] + RADIUS;
                        vel[index] = vel[i];
                        theta[index] = theta[i];
                        energy[index] = ENERGY_MAX;
                        split[index] = 0;
                        digestion[index] = 0;
                        for (0..NUMBER_OF_RAYS) |j| {
                            if (randomGenerator.float(f32) < 1 / FNUMBER_OF_RAYS) {
                                nn[index].neuronx[j] = nn[i].neuronx[j] + (randomGenerator.float(f32) - 0.5) / 5;
                            } else {
                                nn[index].neuronx[j] = nn[i].neuronx[j];
                            }
                            if (randomGenerator.float(f32) < 1 / FNUMBER_OF_RAYS) {
                                nn[index].neurony[j] = nn[i].neurony[j] + (randomGenerator.float(f32) - 0.5) / 5;
                            } else {
                                nn[index].neurony[j] = nn[i].neurony[j];
                            }
                        }
                        break;
                    }
                    index += 1;
                }
            }
        }
    }
}

const Context_vision = struct {
    posx: *[AGENTNO]f32,
    posy: *[AGENTNO]f32,
    theta: *[AGENTNO]f32,
    species: *[AGENTNO]Species,
    is_dead: *[AGENTNO]bool,
    nn: *[AGENTNO]neuralnet,
    start: usize,
    end: usize,
};

fn update_vision_chunk(ctx: *Context_vision) void {
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
    for (ctx.start..ctx.end) |i| {
        if (ctx.is_dead[i]) continue;
        switch (ctx.species[i]) {
            Species.prey => {
                step = PREY_FOV / (NUMBER_OF_RAYS - 1);
                angle = -PREY_FOV / 2;
            },
            Species.predator => {
                step = PREDATOR_FOV / (NUMBER_OF_RAYS - 1);
                angle = -PREDATOR_FOV / 2;
            },
        }
        for (0..NUMBER_OF_RAYS) |k| {
            endpointx = ctx.posx[i] + (VISION_LENGTH * math.cos(angle + ctx.theta[i]));
            endpointy = ctx.posy[i] + (VISION_LENGTH * math.sin(angle + ctx.theta[i]));
            dx = endpointx - ctx.posx[i];
            dy = endpointy - ctx.posy[i];
            t = 100000.0;
            for (0..AGENTNO) |j| {
                if (ctx.species[i] != ctx.species[j] and (!ctx.is_dead[j])) {
                    fx = ctx.posx[i] - ctx.posx[j];
                    fy = ctx.posy[i] - ctx.posy[j];
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
                ctx.nn[i].vision[k] = 0;
            } else {
                ctx.nn[i].vision[k] = 1 / (t + 0.2);
            }
            angle += step;
        }
    }
}

pub fn update_vision(posx: *[AGENTNO]f32, posy: *[AGENTNO]f32, theta: *[AGENTNO]f32, species: *[AGENTNO]Species, is_dead: *[AGENTNO]bool, nn: *[AGENTNO]neuralnet) !void {
    const num_threads = 4;
    const chunk_size = AGENTNO / num_threads;
    //const stack_size = 1 * 1; // 64 KB stack size
    var threads: [num_threads]std.Thread = undefined;
    var contexts: [num_threads]Context_vision = undefined;

    for (0..num_threads) |t| {
        contexts[t] = Context_vision{
            .posx = posx,
            .posy = posy,
            .theta = theta,
            .species = species,
            .is_dead = is_dead,
            .nn = nn,
            .start = t * chunk_size,
            .end = if (t == num_threads - 1) AGENTNO else (t + 1) * chunk_size,
        };
        threads[t] = try std.Thread.spawn(.{
            //     .stack_size = stack_size
        }, update_vision_chunk, .{&contexts[t]});
    }

    for (0..num_threads) |t| {
        threads[t].join();
    }
}

pub fn update_velocity(vel: *[AGENTNO]f32, theta: *[AGENTNO]f32, energy: *[AGENTNO]f32, species: *[AGENTNO]Species, is_dead: *[AGENTNO]bool, nn: *[AGENTNO]neuralnet) void {
    var xvec: @Vector(NUMBER_OF_RAYS, f32) = nn[0].vision * nn[0].neuronx;
    var yvec: @Vector(NUMBER_OF_RAYS, f32) = nn[0].vision * nn[0].neurony;
    var dsum: f32 = 0;
    var thetasum: f32 = 0;
    for (0..AGENTNO) |i| {
        if (!is_dead[i]) {
            xvec = nn[i].vision * nn[i].neuronx;
            yvec = nn[i].vision * nn[i].neurony;
            dsum = 0;
            thetasum = 0;
            for (0..NUMBER_OF_RAYS) |j| {
                dsum += xvec[j];
                thetasum += yvec[j];
            }
            dsum = 1 / (1 + @exp(dsum)) - 0.5;
            thetasum = 1 / (1 + @exp(thetasum)) - 0.5;
            if ((dsum == 0) and (thetasum == 0)) {
                thetasum = 0.2;
            }
            if (vel[i] * vel[i] < 1e-4) {
                theta[i] += 6.28 / 100.0 * DT;
            }
            if (energy[i] == 0) {
                vel[i] = 0;
                if (species[i] == Species.predator) {
                    is_dead[i] = true;
                }
            } else {
                vel[i] += dsum * DT;
            }
            theta[i] += thetasum / 10 * DT;
            vel[i] = vel[i] * MOMENTUM;
        }
    }
}

pub fn update_position(posx: *[AGENTNO]f32, posy: *[AGENTNO]f32, vel: *[AGENTNO]f32, theta: *[AGENTNO]f32, is_dead: *[AGENTNO]bool) void {
    for (0..AGENTNO) |i| {
        if (!is_dead[i]) {
            posx[i] += vel[i] * math.cos(theta[i]) * DT;
            posy[i] += vel[i] * math.sin(theta[i]) * DT;
            if (posx[i] > GRID_SIZE) {
                posx[i] += -GRID_SIZE;
            }
            if (posx[i] < 0) {
                posx[i] += GRID_SIZE;
            }
            if (posy[i] > GRID_SIZE) {
                posy[i] += -GRID_SIZE;
            }
            if (posy[i] < 0) {
                posy[i] += GRID_SIZE;
            }
        }
    }
}

pub fn update_energy(vel: *[AGENTNO]f32, energy: *[AGENTNO]f32, species: *[AGENTNO]Species, is_dead: *[AGENTNO]bool) void {
    for (0..AGENTNO) |i| {
        if (!is_dead[i]) {
            switch (species[i]) {
                // remember that zero is prey
                Species.prey => {
                    if (vel[i] < 0.001) {
                        energy[i] += PREY_ENERGY_GAIN;
                    } else {
                        energy[i] += (-vel[i] * ENERGY_SCALE_LOSS * PREY_LOSS_FACTOR);
                        if (energy[i] < 0) {
                            energy[i] = 0;
                        }
                    }
                },
                // remember that one is predator
                Species.predator => {
                    energy[i] += (-vel[i] * ENERGY_SCALE_LOSS) - DEFAULT_ENERGY_LOSS;
                    if (energy[i] > ENERGY_MAX) {
                        energy[i] = ENERGY_MAX;
                    }
                },
            }
        }
    }
}

pub fn eats(posx: *[AGENTNO]f32, posy: *[AGENTNO]f32, vel: *[AGENTNO]f32, energy: *[AGENTNO]f32, split: *[AGENTNO]f32, digestion: *[AGENTNO]f32, species: *[AGENTNO]Species, is_dead: *[AGENTNO]bool) void {
    for (0..AGENTNO) |i| {
        if (species[i] == Species.predator) {
            var distance: f32 = 0;
            var xdistance: f32 = 0;
            var ydistance: f32 = 0;
            for (0..AGENTNO) |j| {
                if ((!is_dead[j]) and (species[j] == Species.prey)) {
                    xdistance = (posx[i] - posx[j]) * (posx[i] - posx[j]);
                    if (xdistance < 4 * RADIUS2) {
                        ydistance = (posy[i] - posy[j]) * (posy[i] - posy[j]);
                        if (ydistance < 4 * RADIUS2) {
                            distance = xdistance + ydistance;
                            if (distance < 4 * RADIUS2) {
                                if (digestion[i] == 0) {
                                    is_dead[j] = true;
                                    energy[i] += ENERGY_MAX / 2;
                                    if (energy[i] > ENERGY_MAX) {
                                        energy[i] = ENERGY_MAX;
                                    }
                                    split[i] += SPLIT_MAX / 2;
                                    digestion[i] = DIGESTION_MAX;
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }
        if (species[i] == Species.prey) {
            split[i] += SPLIT_ADD / (1 + @sqrt(abs(vel[i])));
        }
    }
}

pub fn update_digestion(digestion: *[AGENTNO]f32) void {
    for (0..AGENTNO) |i| {
        digestion[i] += -DEFAULT_DIGESTION_RATE;
        if (digestion[i] < 0) {
            digestion[i] = 0;
        }
    }
}

pub fn update_death(energy: *[AGENTNO]f32, is_dead: *[AGENTNO]bool) void {
    for (0..AGENTNO) |i| {
        if (energy[i] < 0) {
            is_dead[i] = true;
        }
    }
}

pub fn initialize_posx() [AGENTNO]f32 {
    var posx: [AGENTNO]f32 = undefined;
    for (0..AGENTNO) |i| {
        posx[i] = randomGenerator.float(f32) * GRID_SIZE;
    }
    return posx;
}

pub fn initialize_posy() [AGENTNO]f32 {
    var posy: [AGENTNO]f32 = undefined;
    for (0..AGENTNO) |i| {
        posy[i] = randomGenerator.float(f32) * GRID_SIZE;
    }
    return posy;
}

pub fn initialize_vel() [AGENTNO]f32 {
    var vel: [AGENTNO]f32 = undefined;
    for (0..AGENTNO) |i| {
        vel[i] = randomGenerator.float(f32);
    }
    return vel;
}

pub fn initialize_theta() [AGENTNO]f32 {
    var theta: [AGENTNO]f32 = undefined;
    for (0..AGENTNO) |i| {
        theta[i] = randomGenerator.float(f32) * math.pi * 2;
    }
    return theta;
}

pub fn initialize_energy() [AGENTNO]f32 {
    var energy: [AGENTNO]f32 = undefined;
    for (0..AGENTNO) |i| {
        energy[i] = randomGenerator.float(f32) * ENERGY_MAX;
    }
    return energy;
}

pub fn initialize_split() [AGENTNO]f32 {
    var split: [AGENTNO]f32 = undefined;
    for (0..AGENTNO) |i| {
        split[i] = randomGenerator.float(f32) * SPLIT_MAX;
    }
    return split;
}

pub fn initialize_digestion() [AGENTNO]f32 {
    var digestion: [AGENTNO]f32 = undefined;
    for (0..AGENTNO) |i| {
        digestion[i] = 0;
    }
    return digestion;
}

pub fn initialize_species() [AGENTNO]Species {
    var species: [AGENTNO]Species = undefined;
    for (0..AGENTNO) |i| {
        if (randomGenerator.boolean()) {
            species[i] = Species.prey;
        } else {
            species[i] = Species.predator;
        }
    }
    return species;
}

pub fn initialize_is_dead() [AGENTNO]bool {
    var is_dead: [AGENTNO]bool = undefined;
    for (0..AGENTNO) |i| {
        is_dead[i] = false;
    }
    return is_dead;
}

pub fn initialize_nn() [AGENTNO]neuralnet {
    var neuronx: @Vector(NUMBER_OF_RAYS, f32) = undefined;
    var neurony: @Vector(NUMBER_OF_RAYS, f32) = undefined;
    var nn: [AGENTNO]neuralnet = undefined;
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
        nn[i] = neuralnet.init(neuronx, neurony);
    }
    return nn;
}

pub fn update_agents(posx: *[AGENTNO]f32, posy: *[AGENTNO]f32, vel: *[AGENTNO]f32, theta: *[AGENTNO]f32, energy: *[AGENTNO]f32, split: *[AGENTNO]f32, digestion: *[AGENTNO]f32, species: *[AGENTNO]Species, is_dead: *[AGENTNO]bool, nn: *[AGENTNO]neuralnet) !void {
    //    const start1 = try std.time.Instant.now();
    //    try update_vision(posx, posy, theta, species, is_dead, nn);
    //    const end1 = try std.time.Instant.now();
    //    const elapsed1: f64 = @floatFromInt(end1.since(start1));
    //    try stdout.print("Vision Time = {}ms \n", .{elapsed1 / std.time.ns_per_ms});
    //    const start2 = try std.time.Instant.now();
    //    update_velocity(vel, theta, energy, species, is_dead, nn);
    //    const end2 = try std.time.Instant.now();
    //    const elapsed2: f64 = @floatFromInt(end2.since(start2));
    //    try stdout.print("Velocity Time = {}ms \n", .{elapsed2 / std.time.ns_per_ms});
    //    const start3 = try std.time.Instant.now();
    //    update_position(posx, posy, vel, theta, is_dead);
    //    const end3 = try std.time.Instant.now();
    //    const elapsed3: f64 = @floatFromInt(end3.since(start3));
    //    try stdout.print("Position Time = {}ms \n", .{elapsed3 / std.time.ns_per_ms});
    //    const start4 = try std.time.Instant.now();
    //    update_energy(vel, energy, species, is_dead);
    //    const end4 = try std.time.Instant.now();
    //    const elapsed4: f64 = @floatFromInt(end4.since(start4));
    //    try stdout.print("Energy Time = {}ms \n", .{elapsed4 / std.time.ns_per_ms});
    //    update_death(energy, is_dead);
    //    update_digestion(digestion);
    //    const start5 = try std.time.Instant.now();
    //    eats(posx, posy, vel, energy, split, digestion, species, is_dead);
    //    const end5 = try std.time.Instant.now();
    //    const elapsed5: f64 = @floatFromInt(end5.since(start5));
    //    try stdout.print("Eats Time = {}ms \n", .{elapsed5 / std.time.ns_per_ms});
    //    const start6 = try std.time.Instant.now();
    //    update_children(posx, posy, vel, theta, energy, split, digestion, species, is_dead, nn);
    //    const end6 = try std.time.Instant.now();
    //    const elapsed6: f64 = @floatFromInt(end6.since(start6));
    //    try stdout.print("Children Time = {}ms \n", .{elapsed6 / std.time.ns_per_ms});
    try update_vision(posx, posy, theta, species, is_dead, nn);
    update_velocity(vel, theta, energy, species, is_dead, nn);
    update_position(posx, posy, vel, theta, is_dead);
    update_energy(vel, energy, species, is_dead);
    update_death(energy, is_dead);
    update_digestion(digestion);
    eats(posx, posy, vel, energy, split, digestion, species, is_dead);
    update_children(posx, posy, vel, theta, energy, split, digestion, species, is_dead, nn);
}
//pub const UpdateContext = struct {
//    array: *[AGENTNO]agent,
//    start: usize,
//    end: usize,
//};

//pub fn update_agent_chunk(ctx: *UpdateContext) !void {
//    for (ctx.start..ctx.end) |i| {
//        try update_agent(ctx.array, &ctx.array[i]);
//    }
//}
