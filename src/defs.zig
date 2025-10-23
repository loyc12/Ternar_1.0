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

  _ = allocator;
  //std.debug.print( "allocator.ptr    = {}\n", .{ allocator.ptr });
  //std.debug.print( "allocater.vtable = {}\n", .{ allocator.vtable });

  log_u.initFile();

  rng_u.initGlobalRNG();
  G_RNG = rng_u.G_RNG;
}

pub fn deinitAllUtils() void
{
  log_u.deinitFile();

  G_RNG = undefined;
}

// ================================ CORE SHORTHAND ================================

// ================ MEMORY SHORTHANDS ================

pub const mem_c = @import( "core/memory.zig" );
pub const MemBank = mem_c.MemBank;


// ================ TRYTE SHORTHANDS ================

pub const trt_c = @import( "core/tryte.zig" );

pub const Bit             = trt_c.Bit;
pub const Byte            = trt_c.Byte;
pub const BITS_PER_BYTE   = trt_c.BITS_PER_BYTE;

pub const Trit            = trt_c.Trit;
pub const BITS_PER_TRIT   = trt_c.BITS_PER_TRIT;

pub const Tryte           = trt_c.Tryte;
pub const TRITS_PER_TRYTE = trt_c.TRITS_PER_TRYTE;

pub const BITS_PER_TRYTE  = trt_c.BITS_PER_TRYTE;
pub const TRITS_PER_BYTE  = trt_c.TRITS_PER_BYTE;

pub const tritToChar      = trt_c.tritToChar;
pub const tryteToChar     = trt_c.tryteToChar;


// ================================ UTILS SHORTHAND ================================

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
