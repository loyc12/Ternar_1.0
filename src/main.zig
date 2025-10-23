const std = @import( "std" );
const def = @import( "defs" );

const MemBank = def.MemBank;


// ================================ INITIALIZATION ================================

pub fn initCriticals() void
{
  def.GLOBAL_EPOCH = def.getNow();

  def.qlog( .INFO, 0, @src(), "# Initializing all subsystems..." );

  def.initAllUtils( def.alloc );



  def.qlog( .INFO, 0, @src(), "$ Initialized all subsystems !\n" );
}

pub fn deinitCriticals() void
{
  def.qlog( .INFO, 0, @src(), "# Deinitializing all subsystems..." );



  def.deinitAllUtils();

  def.qlog( .INFO, 0, @src(), "$ Deinitialized all subsystems\n" );
}

// ================================ MAIN FUNCTION ================================

pub fn main() !void
{
  initCriticals();
  defer deinitCriticals();

  def.qlog( .INFO, 0, @src(), "# Hello, world!" );

  var bank : MemBank = .{};

  bank.logTrit( 19 );
  bank.setTrit( 19, 0b11 ) catch {};
  bank.logTrit( 19 );

  bank.logTrit( 20 );
  bank.setTrit( 20, 0b01 ) catch {};
  bank.logTrit( 20 );

  bank.logTrit( 22 );
  bank.setTrit( 22, 0b10 ) catch {};
  bank.logTrit( 22 );

  bank.logTrit( 25 );
  bank.setTrit( 25, 0b00 ) catch {};
  bank.logTrit( 25 );

  bank.logTryte( 2 );
  bank.setTryte( 2, 0b11_10_11_11_11_11_10_11_10 ) catch {};
  bank.logTryte( 2 );

  bank.setTryte( 2, 0b11_11_01_11_11_01_11_11_01 ) catch {};
  bank.logTryte( 2 );

  bank.setTryte( 2, 0b11_11_10_11_11_11_01_11_11 ) catch {};
  bank.logTryte( 2 );

  bank.setTryte( 2, 0b11_01_11_10_11_11_00_11_00 ) catch {};
  bank.logTryte( 2 );

  bank.logTrit(  1272138956297856235 );
  bank.logTryte( 1272138956297856235 );

  def.qlog( .INFO, 0, @src(), "# Goodbye, world!" );
}

