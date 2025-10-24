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

  def.qlog( .INFO, 0, @src(), "# Hello, world!\n" );

  testBank();

  def.qlog( .INFO, 0, @src(), "# Goodbye, world...\n" );
}


fn testBank() void
{
  var bank : MemBank = .{};

  def.qlog( .INFO, 0, @src(), "@ Testing Trits\n" );

  bank.logTrit( 9, @src() );
  bank.setTrit( 9, 0b00 ) catch {};
  bank.logTrit( 9, @src() );

  bank.logTrit( 10, @src() );
  bank.setTrit( 10, 0b01 ) catch {};
  bank.logTrit( 10, @src() );

  bank.logTrit( 12, @src() );
  bank.setTrit( 12, 0b10 ) catch {};
  bank.logTrit( 12, @src() );

  bank.logTrit( 15, @src() );
  bank.setTrit( 15, 0b11 ) catch {};
  bank.logTrit( 15, @src() );

  def.qlog( .INFO, 0, @src(), "@ Testing Trytes\n" );

  bank.logTryte( 1, @src() );
  bank.setTryte( 1, 0b00_10_00_00_11_00_10_00_01 ) catch {};
  bank.logTryte( 1, @src() );

  bank.setTryte( 1, def.strToTryte( "0102201.0".* ) catch 0 ) catch {};
  bank.logTryte( 1, @src() );

  bank.setTryte( 1, def.strToTryte( "-U1:PZF+.".* ) catch 0 ) catch {};
  bank.logTryte( 1, @src() );

  bank.setTryte( 1, def.strToTryte( "sdgsfdsff".* ) catch 0 ) catch {};
  bank.logTryte( 1, @src() );


  bank.setTryte( 2, 0b10_00_01_11_00_00 ) catch {};
  bank.logTryte( 2, @src() );

  def.qlog( .INFO, 0, @src(), "@ Printing Memory\n" );
  for( 0 .. 27 )| i | { bank.logTrit( i, @src() ); }

  bank.logTrit(  1272138956297856235, @src() );
  bank.logTryte( 1272138956297856235, @src() );
}

