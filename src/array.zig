const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const cstd = @cImport({
    @cInclude("stdio.h");
});

const params = @import("./conf/const.zig");
const Thread = std.Thread;
const math = @import("std").math;
const f = @import("array.zig");

const stdout = std.io.getStdOut().writer();
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// our random number generator
var prng = std.rand.DefaultPrng.init(0);
pub const randomGenerator = prng.random();

//pub inline fn abs(x: f32) f32 {
//    if (x < 0) {
//        return -x;
//    } else {
//        return x;
//    }
//}

pub const Species = enum {
    prey,
    predator,
};

pub const neuralnet = struct {
    neuronx: @Vector(params.NUMBER_OF_RAYS, f32),
    neurony: @Vector(params.NUMBER_OF_RAYS, f32),
    vision: @Vector(params.NUMBER_OF_RAYS, f32),
    pub fn init(neuronx: @Vector(params.NUMBER_OF_RAYS, f32), neurony: @Vector(params.NUMBER_OF_RAYS, f32)) neuralnet {
        return neuralnet{
            .neuronx = neuronx,
            .neurony = neurony,
            .vision = neuronx,
        };
    }
};

pub fn update_children(posx: *[params.AGENTNO]f32, posy: *[params.AGENTNO]f32, vel: *[params.AGENTNO]f32, theta: *[params.AGENTNO]f32, energy: *[params.AGENTNO]f32, split: *[params.AGENTNO]f32, digestion: *[params.AGENTNO]f32, species: *[params.AGENTNO]Species, is_dead: *[params.AGENTNO]bool, nn: *[params.AGENTNO]neuralnet) void {
    var index: u32 = 0;
    for (0..params.AGENTNO) |i| {
        if ((!is_dead[i]) and (species[i] == Species.predator)) {
            if (split[i] > params.SPLIT_MAX) {
                split[i] += -params.SPLIT_MAX;
                while (index < params.AGENTNO - 1) {
                    if (is_dead[index]) {
                        species[index] = species[i];
                        is_dead[index] = false;
                        posx[index] = posx[i] + params.RADIUS;
                        posy[index] = posy[i] + params.RADIUS;
                        vel[index] = vel[i];
                        theta[index] = theta[i];
                        energy[index] = params.ENERGY_MAX;
                        split[index] = 0;
                        digestion[index] = 0;
                        for (0..params.NUMBER_OF_RAYS) |j| {
                            if (randomGenerator.float(f32) < 1 / params.FNUMBER_OF_RAYS) {
                                nn[index].neuronx[j] = nn[i].neuronx[j] + (randomGenerator.float(f32) - 0.5) / 5;
                            } else {
                                nn[index].neuronx[j] = nn[i].neuronx[j];
                            }
                            if (randomGenerator.float(f32) < 1 / params.FNUMBER_OF_RAYS) {
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
    for (0..params.AGENTNO) |i| {
        if ((!is_dead[i]) and (species[i] == Species.prey)) {
            if (split[i] > params.SPLIT_MAX) {
                split[i] += -params.SPLIT_MAX;
                while (index < params.AGENTNO - 1) {
                    if (is_dead[index]) {
                        species[index] = species[i];
                        is_dead[index] = false;
                        posx[index] = posx[i] + params.RADIUS;
                        posy[index] = posy[i] + params.RADIUS;
                        vel[index] = vel[i];
                        theta[index] = theta[i];
                        energy[index] = params.ENERGY_MAX;
                        split[index] = 0;
                        digestion[index] = 0;
                        for (0..params.NUMBER_OF_RAYS) |j| {
                            if (randomGenerator.float(f32) < 1 / params.FNUMBER_OF_RAYS) {
                                nn[index].neuronx[j] = nn[i].neuronx[j] + (randomGenerator.float(f32) - 0.5) / 5;
                            } else {
                                nn[index].neuronx[j] = nn[i].neuronx[j];
                            }
                            if (randomGenerator.float(f32) < 1 / params.FNUMBER_OF_RAYS) {
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
    posx: *[params.AGENTNO]f32,
    posy: *[params.AGENTNO]f32,
    theta: *[params.AGENTNO]f32,
    species: *[params.AGENTNO]Species,
    is_dead: *[params.AGENTNO]bool,
    nn: *[params.AGENTNO]neuralnet,
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
                step = params.PREY_FOV / (params.NUMBER_OF_RAYS - 1);
                angle = -params.PREY_FOV / 2;
            },
            Species.predator => {
                step = params.PREDATOR_FOV / (params.NUMBER_OF_RAYS - 1);
                angle = -params.PREDATOR_FOV / 2;
            },
        }
        for (0..params.NUMBER_OF_RAYS) |k| {
            endpointx = ctx.posx[i] + (params.VISION_LENGTH * math.cos(angle + ctx.theta[i]));
            endpointy = ctx.posy[i] + (params.VISION_LENGTH * math.sin(angle + ctx.theta[i]));
            dx = endpointx - ctx.posx[i];
            dy = endpointy - ctx.posy[i];
            t = 100000.0;
            for (0..params.AGENTNO) |j| {
                if (ctx.species[i] != ctx.species[j] and (!ctx.is_dead[j])) {
                    fx = ctx.posx[i] - ctx.posx[j];
                    fy = ctx.posy[i] - ctx.posy[j];
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
            if (t == 100000.0) {
                ctx.nn[i].vision[k] = 0;
            } else {
                ctx.nn[i].vision[k] = 1 / (t + 0.2);
            }
            angle += step;
        }
    }
}

pub fn update_vision(posx: *[params.AGENTNO]f32, posy: *[params.AGENTNO]f32, theta: *[params.AGENTNO]f32, species: *[params.AGENTNO]Species, is_dead: *[params.AGENTNO]bool, nn: *[params.AGENTNO]neuralnet) !void {
    const num_threads = 4;
    const chunk_size = params.AGENTNO / num_threads;
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
            .end = if (t == num_threads - 1) params.AGENTNO else (t + 1) * chunk_size,
        };
        threads[t] = try std.Thread.spawn(.{
            //     .stack_size = stack_size
        }, update_vision_chunk, .{&contexts[t]});
    }

    for (0..num_threads) |t| {
        threads[t].join();
    }
}

pub fn update_velocity(vel: *[params.AGENTNO]f32, theta: *[params.AGENTNO]f32, energy: *[params.AGENTNO]f32, species: *[params.AGENTNO]Species, is_dead: *[params.AGENTNO]bool, nn: *[params.AGENTNO]neuralnet) void {
    var xvec: @Vector(params.NUMBER_OF_RAYS, f32) = nn[0].vision * nn[0].neuronx;
    var yvec: @Vector(params.NUMBER_OF_RAYS, f32) = nn[0].vision * nn[0].neurony;
    var dsum: f32 = 0;
    var thetasum: f32 = 0;
    for (0..params.AGENTNO) |i| {
        if (!is_dead[i]) {
            xvec = nn[i].vision * nn[i].neuronx;
            yvec = nn[i].vision * nn[i].neurony;
            dsum = 0;
            thetasum = 0;
            for (0..params.NUMBER_OF_RAYS) |j| {
                dsum += xvec[j];
                thetasum += yvec[j];
            }
            dsum = 1 / (1 + @exp(dsum)) - 0.5;
            thetasum = 1 / (1 + @exp(thetasum)) - 0.5;
            if ((dsum == 0) and (thetasum == 0)) {
                thetasum = 0.2;
            }
            if (vel[i] * vel[i] < 1e-4) {
                theta[i] += 6.28 / 100.0 * params.DT;
            }
            if (energy[i] == 0) {
                vel[i] = 0;
                if (species[i] == Species.predator) {
                    is_dead[i] = true;
                }
            } else {
                vel[i] += dsum * params.DT;
            }
            theta[i] += thetasum / 10 * params.DT;
            vel[i] = vel[i] * params.MOMENTUM;
        }
    }
}

pub fn update_position(posx: *[params.AGENTNO]f32, posy: *[params.AGENTNO]f32, vel: *[params.AGENTNO]f32, theta: *[params.AGENTNO]f32, is_dead: *[params.AGENTNO]bool) void {
    for (0..params.AGENTNO) |i| {
        if (!is_dead[i]) {
            posx[i] += vel[i] * math.cos(theta[i]) * params.DT;
            posy[i] += vel[i] * math.sin(theta[i]) * params.DT;
            if (posx[i] > params.GRID_SIZE) {
                posx[i] += -params.GRID_SIZE;
            }
            if (posx[i] < 0) {
                posx[i] += params.GRID_SIZE;
            }
            if (posy[i] > params.GRID_SIZE) {
                posy[i] += -params.GRID_SIZE;
            }
            if (posy[i] < 0) {
                posy[i] += params.GRID_SIZE;
            }
        }
    }
}

pub fn update_energy(vel: *[params.AGENTNO]f32, energy: *[params.AGENTNO]f32, species: *[params.AGENTNO]Species, is_dead: *[params.AGENTNO]bool) void {
    for (0..params.AGENTNO) |i| {
        if (!is_dead[i]) {
            switch (species[i]) {
                // remember that zero is prey
                Species.prey => {
                    if (vel[i] < 0.001) {
                        energy[i] += params.PREY_ENERGY_GAIN;
                    } else {
                        energy[i] += (-vel[i] * params.ENERGY_SCALE_LOSS * params.PREY_LOSS_FACTOR);
                        if (energy[i] < 0) {
                            energy[i] = 0;
                        }
                    }
                },
                // remember that one is predator
                Species.predator => {
                    energy[i] += (-vel[i] * params.ENERGY_SCALE_LOSS) - params.DEFAULT_ENERGY_LOSS;
                    if (energy[i] > params.ENERGY_MAX) {
                        energy[i] = params.ENERGY_MAX;
                    }
                },
            }
        }
    }
}

pub fn eats(posx: *[params.AGENTNO]f32, posy: *[params.AGENTNO]f32, vel: *[params.AGENTNO]f32, energy: *[params.AGENTNO]f32, split: *[params.AGENTNO]f32, digestion: *[params.AGENTNO]f32, species: *[params.AGENTNO]Species, is_dead: *[params.AGENTNO]bool) void {
    for (0..params.AGENTNO) |i| {
        if (species[i] == Species.predator) {
            var distance: f32 = 0;
            var xdistance: f32 = 0;
            var ydistance: f32 = 0;
            for (0..params.AGENTNO) |j| {
                if ((!is_dead[j]) and (species[j] == Species.prey)) {
                    xdistance = (posx[i] - posx[j]) * (posx[i] - posx[j]);
                    if (xdistance < 4 * params.RADIUS2) {
                        ydistance = (posy[i] - posy[j]) * (posy[i] - posy[j]);
                        if (ydistance < 4 * params.RADIUS2) {
                            distance = xdistance + ydistance;
                            if (distance < 4 * params.RADIUS2) {
                                if (digestion[i] == 0) {
                                    is_dead[j] = true;
                                    energy[i] += params.ENERGY_MAX / 2;
                                    if (energy[i] > params.ENERGY_MAX) {
                                        energy[i] = params.ENERGY_MAX;
                                    }
                                    split[i] += params.SPLIT_MAX / 2;
                                    digestion[i] = params.DIGESTION_MAX;
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }
        if (species[i] == Species.prey) {
            split[i] += params.SPLIT_ADD; // (1 + @sqrt(abs(vel[i])));
            vel[i] += 0;
        }
    }
}

pub fn update_digestion(digestion: *[params.AGENTNO]f32) void {
    for (0..params.AGENTNO) |i| {
        digestion[i] += -params.DEFAULT_DIGESTION_RATE;
        if (digestion[i] < 0) {
            digestion[i] = 0;
        }
    }
}

pub fn update_death(energy: *[params.AGENTNO]f32, is_dead: *[params.AGENTNO]bool) void {
    for (0..params.AGENTNO) |i| {
        if (energy[i] < 0) {
            is_dead[i] = true;
        }
    }
}

pub fn initialize_posx() [params.AGENTNO]f32 {
    var posx: [params.AGENTNO]f32 = undefined;
    for (0..params.AGENTNO) |i| {
        posx[i] = randomGenerator.float(f32) * params.GRID_SIZE;
    }
    return posx;
}

pub fn initialize_posy() [params.AGENTNO]f32 {
    var posy: [params.AGENTNO]f32 = undefined;
    for (0..params.AGENTNO) |i| {
        posy[i] = randomGenerator.float(f32) * params.GRID_SIZE;
    }
    return posy;
}

pub fn initialize_vel() [params.AGENTNO]f32 {
    var vel: [params.AGENTNO]f32 = undefined;
    for (0..params.AGENTNO) |i| {
        vel[i] = randomGenerator.float(f32);
    }
    return vel;
}

pub fn initialize_theta() [params.AGENTNO]f32 {
    var theta: [params.AGENTNO]f32 = undefined;
    for (0..params.AGENTNO) |i| {
        theta[i] = randomGenerator.float(f32) * math.pi * 2;
    }
    return theta;
}

pub fn initialize_energy() [params.AGENTNO]f32 {
    var energy: [params.AGENTNO]f32 = undefined;
    for (0..params.AGENTNO) |i| {
        energy[i] = randomGenerator.float(f32) * params.ENERGY_MAX;
    }
    return energy;
}

pub fn initialize_split() [params.AGENTNO]f32 {
    var split: [params.AGENTNO]f32 = undefined;
    for (0..params.AGENTNO) |i| {
        split[i] = randomGenerator.float(f32) * params.SPLIT_MAX;
    }
    return split;
}

pub fn initialize_digestion() [params.AGENTNO]f32 {
    var digestion: [params.AGENTNO]f32 = undefined;
    for (0..params.AGENTNO) |i| {
        digestion[i] = 0;
    }
    return digestion;
}

pub fn initialize_species() [params.AGENTNO]Species {
    var species: [params.AGENTNO]Species = undefined;
    for (0..params.AGENTNO) |i| {
        if (randomGenerator.boolean()) {
            species[i] = Species.prey;
        } else {
            species[i] = Species.predator;
        }
    }
    return species;
}

pub fn initialize_is_dead() [params.AGENTNO]bool {
    var is_dead: [params.AGENTNO]bool = undefined;
    for (0..params.AGENTNO) |i| {
        is_dead[i] = false;
    }
    return is_dead;
}

pub fn initialize_nn() [params.AGENTNO]neuralnet {
    var neuronx: @Vector(params.NUMBER_OF_RAYS, f32) = undefined;
    var neurony: @Vector(params.NUMBER_OF_RAYS, f32) = undefined;
    var nn: [params.AGENTNO]neuralnet = undefined;
    for (0..params.AGENTNO) |i| {
        for (0..params.NUMBER_OF_RAYS) |j| {
            if (randomGenerator.float(f32) < 0.2 / params.FNUMBER_OF_RAYS) {
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

pub fn update_agents(posx: *[params.AGENTNO]f32, posy: *[params.AGENTNO]f32, vel: *[params.AGENTNO]f32, theta: *[params.AGENTNO]f32, energy: *[params.AGENTNO]f32, split: *[params.AGENTNO]f32, digestion: *[params.AGENTNO]f32, species: *[params.AGENTNO]Species, is_dead: *[params.AGENTNO]bool, nn: *[params.AGENTNO]neuralnet) !void {
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
//    array: *[params.AGENTNO]agent,
//    start: usize,
//    end: usize,
//};

//pub fn update_agent_chunk(ctx: *UpdateContext) !void {
//    for (ctx.start..ctx.end) |i| {
//        try update_agent(ctx.array, &ctx.array[i]);
//    }
//}
