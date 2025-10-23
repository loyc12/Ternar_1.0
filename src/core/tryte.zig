
const std = @import( "std" );
const def = @import( "defs" );

pub const Bit  = u1;
pub const Byte = u8;
pub const BITS_PER_BYTE   = 8;

pub const Trit  = u2;  // 01 = +, 11 = 0, 10 = -, 00 = . ( invalid )
pub const BITS_PER_TRIT = 2; // MUST divide 8 fully

pub const Tryte = u18; // aka 9 trits
pub const TRITS_PER_TRYTE = 9;

pub const BITS_PER_TRYTE = BITS_PER_TRIT * TRITS_PER_TRYTE;
pub const TRITS_PER_BYTE = BITS_PER_BYTE / BITS_PER_TRIT;


// =========================== DEBUG PRINTING ===========================

pub inline fn tritToChar( trit : Trit ) u8
{
  return switch( trit )
  {
    0b01 => '+',
    0b11 => '0',
    0b10 => '-',
    0b00 => '.',
  };
}

pub inline fn tryteToChar( tryte : Tryte ) [ TRITS_PER_TRYTE ]u8
{
  var i    : u5 = 0;
  var buff : [ TRITS_PER_TRYTE ]u8 = undefined;

  while( i < TRITS_PER_TRYTE ) : ( i += 1 )
  {
    const trit : Trit = @intCast( 0b11 & ( tryte >> ( i * BITS_PER_TRIT )));
    buff[ TRITS_PER_TRYTE - i - 1 ] = tritToChar( trit ); // fliping the trits so the values are in intuitive order
  }
  return buff;
}