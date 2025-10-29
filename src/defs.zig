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


// ================ OPCODE SHORTHANDS ================

pub const trn_c = @import( "core/ternar.zig" );
pub const Ternar = trn_c.Ternar;


// ================ OPCODE SHORTHANDS ================

pub const opc_c = @import( "core/opcodes.zig" );
pub const OpCode = opc_c.e_OpCode;

pub const PFlagTrit = opc_c.e_PFlagTrit;
pub const PRegTryte = opc_c.e_PRegTryte;


// ================ TRYTE SHORTHANDS ================

pub const trt_c = @import( "core/tryte.zig" );

// Typedefs

pub const Bit             = trt_c.Bit;
pub const Byte            = trt_c.Byte;
pub const BITS_PER_BYTE   = trt_c.BITS_PER_BYTE;

pub const Trit            = trt_c.Trit;
pub const BITS_PER_TRIT   = trt_c.BITS_PER_TRIT;

pub const Tryte           = trt_c.Tryte;
pub const TRITS_PER_TRYTE = trt_c.TRITS_PER_TRYTE;

pub const BITS_PER_TRYTE  = trt_c.BITS_PER_TRYTE;
pub const TRITS_PER_BYTE  = trt_c.TRITS_PER_BYTE;

pub const TritChar        = trt_c.TritChar;
pub const TryteStr        = trt_c.TryteStr;


// Constants

pub const T2 = trt_c.T2;
pub const T0 = trt_c.T0;
pub const T1 = trt_c.T1;

pub const tPos   = trt_c.tPos;
pub const tZero  = trt_c.tZero;
pub const tNeg   = trt_c.tNeg;

pub const tFalse = trt_c.tFalse;
pub const tMaybe = trt_c.tMaybe;
pub const tTrue  = trt_c.tTrue;


// Functions

pub const tritToTryte = trt_c.tritToTryte;
pub const tryteToTrit = trt_c.tryteToTrit;

pub const tritToChar  = trt_c.tritToChar;
pub const tryteToStr  = trt_c.tryteToStr;

pub const charToTrit  = trt_c.charToTrit;
pub const strToTryte  = trt_c.strToTryte;


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
