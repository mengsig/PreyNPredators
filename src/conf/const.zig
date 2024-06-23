// Threads stuff
pub const NUM_THREADS = 12;

// Save stuff
pub const SAVE_FREQUENCY = 5000;
pub const LOOPS = false;
pub const COPYNUM = 10;

// Simulation stuff
pub const COOPERATION: bool = false;
pub const ENERGY_MAX: f32 = 100.0;
pub const DT: f32 = 0.37;
pub const PREY_ENERGY_GAIN: f32 = 2.5;
pub const PREY_LOSS_FACTOR: f32 = 10;
pub const SPLIT_ADD: f32 = 1.0 * DT;
pub const DEFAULT_ENERGY_LOSS: f32 = SPLIT_ADD / 6;
pub const ENERGY_SCALE_LOSS: f32 = 0.025;
pub const DEFAULT_DIGESTION_RATE: f32 = 1;
pub const RADIUS: f32 = 5.0;
pub const AGENTNO: u16 = 750;
pub const RADIUS2: f32 = RADIUS * RADIUS;
pub const SPLIT_MAX: f32 = 100.0;
pub const SPLIT_DECAY: f32 = 0.2 * DT;
pub const DIGESTION_MAX: f32 = 25;
pub const NUMBER_OF_RAYS: usize = 30;
pub const VISION_LENGTH: f32 = 500;
pub const PREY_FOV: f32 = 360.0 / 180.0 * 3.1415;
pub const PREDATOR_FOV: f32 = 80.0 / 180.0 * 3.1415;
pub const FNUMBER_OF_RAYS: f32 = @floatFromInt(NUMBER_OF_RAYS);
pub const MOMENTUM: f32 = 0.95;

// Plotting stuff
pub const PLOT_WINDOW_HEIGHT: u16 = 400;
pub const PLOT_WINDOW_WIDTH: u16 = 1600;
pub const PLOT_MAX_POINTS: i32 = @intCast(AGENTNO);
pub const GRID_SIZE: i32 = 1250;
pub const TOTAL_SIZE: i32 = GRID_SIZE * GRID_SIZE;
pub const CELL_SIZE: i8 = 1;
pub const WINDOW_SIZE: i32 = CELL_SIZE * GRID_SIZE;

// Follow POV
pub const FOLLOW: bool = true;
pub const ZOOM: i32 = 5;
