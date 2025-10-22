pub const std = @import( "std" );

pub const tcl_u  = @import( "utils/termColourer.zig" );
pub const rng_u  = @import( "utils/rng.zig" );

pub var G_RNG : rng_u.randomiser = .{};

pub const alloc = std.heap.smp_allocator; // Global allocator instance

// ================================ GLOBAL INITIALIZATION / DEINITIALIZATION ================================

pub var GLOBAL_EPOCH : TimeVal = .{};

pub fn initAllUtils( allocator : std.mem.Allocator ) void
{
  //GLOBAL_EPOCH = getNow();

  std.debug.print( "allocator.ptr    = {}\n", .{ allocator.ptr });
  std.debug.print( "allocater.vtable = {}\n", .{ allocator.vtable });

  log_u.initFile();

  rng_u.initGlobalRNG();
  G_RNG = rng_u.G_RNG;
}

pub fn deinitAllUtils() void
{
  log_u.deinitFile();

  G_RNG = undefined;
}


// ================================ INTERFACER HANDLERS ================================

// ================ LOGGER SHORTHANDS ================

pub const log_u = @import( "utils/logger.zig" );

pub const log   = log_u.log;  // for argument-formatting logging
pub const qlog  = log_u.qlog; // for quick logging ( no args )

pub const resetTmpTimer = log_u.resetTmpTimer;
pub const logTmpTimer   = log_u.logTmpTimer;


// ================ TIMER SHORTHANDS ================

pub const tmr_u         = @import( "utils/timer.zig" );

pub const TimeVal       = tmr_u.TimeVal;
pub const Timer         = tmr_u.Timer;
pub const e_timer_flags = tmr_u.e_timer_flags;

pub const getNow        = tmr_u.getNow;
