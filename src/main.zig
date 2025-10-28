const std = @import( "std" );
const def = @import( "defs" );


var ternarCore : ?def.Ternar = null;

pub fn initCriticals() void
{
  def.GLOBAL_EPOCH = def.getNow();

  def.qlog( .INFO, 0, @src(), "# Initializing all subsystems..." );

  def.initAllUtils( def.alloc );

  ternarCore = .{};

  def.qlog( .INFO, 0, @src(), "$ Initialized all subsystems !\n" );
}

pub fn deinitCriticals() void
{
  def.qlog( .INFO, 0, @src(), "# Deinitializing all subsystems..." );

  ternarCore = null;

  def.deinitAllUtils();

  def.qlog( .INFO, 0, @src(), "$ Deinitialized all subsystems\n" );
}


// ================================ MAIN FUNCTION ================================

pub fn main() !void
{
  initCriticals();
  defer deinitCriticals();

  def.qlog( .INFO, 0, @src(), "# Hello, world!\n" );

  _ = ternarCore ;

  def.mem_c.testBank();

  def.qlog( .INFO, 0, @src(), "# Goodbye, world...\n" );
}
