
const std = @import( "std" );
const def = @import( "defs" );

pub const Bit  = u1;
pub const Byte = u8;
pub const BITS_PER_BYTE = 8;

pub const Trit  = u2;  // 01 = +, 11 = 0, 10 = -, 00 = . ( invalid )
pub const BITS_PER_TRIT = 2; // MUST divide 8 fully

pub const Tryte = u18; // aka 9 trits
pub const TRITS_PER_TRYTE = 9;

pub const BITS_PER_TRYTE = BITS_PER_TRIT * TRITS_PER_TRYTE;
pub const TRITS_PER_BYTE = BITS_PER_BYTE / BITS_PER_TRIT;


pub const TritChar = u8;
pub const TryteStr = [ TRITS_PER_TRYTE ]u8;


pub const T2 = 0b10;
pub const T0 = 0b00;
pub const T1 = 0b01;

pub const tPos  = 0b01;
pub const tZero = 0b00;
pub const tNeg  = 0b10;

pub const tFalse = 0b01;
pub const tMaybe = 0b00;
pub const tTrue  = 0b10;


// =========================== TRIT-TRYTE CONVERSION ===========================

pub inline fn tritToTryte( trit : Trit, index : u5 ) Tryte
{
  const t : Tryte = @intCast( trit );
  return( t << ( index * BITS_PER_TRIT ));
}

pub inline fn tryteToTrit( tryte : Tryte, index : u5 ) Trit
{
  return @intCast( 0b11 & ( tryte >> ( index * BITS_PER_TRIT )));
}


// =========================== SYMBOLIC CONVERSION ===========================

pub inline fn tritToChar( trit : Trit ) u8
{
  return switch( trit )
  {
    0b10 => '2',
    0b00 => '0',
    0b01 => '1',
    0b11 => '.',
  };
}

pub inline fn charToTrit( c : u8 ) !Trit
{
  switch( c )
  {
    '-', 'F', '2', 'N' => return 0b10,
    'M', 'U', '0', 'Z' => return 0b00,
    '+', 'T', '1', 'P' => return 0b01,
    '.', '_', ':', 'X' => return 0b11,

    else =>
    {
      def.log( .ERROR, 0, @src(), "'{c}'' is not a valid trit symbol", .{ c });
      return error.InvalidTritChar;
    }
  }
}

pub inline fn tryteToStr( tryte : Tryte ) TryteStr
{
  var i : u5 = 0;
  var s : TryteStr = undefined;

  while( i < TRITS_PER_TRYTE ) : ( i += 1 )
  {
    const trit : Trit = tryteToTrit( tryte, TRITS_PER_TRYTE - i - 1 ); // Big endian

    s[ i ] = tritToChar( trit );
  }
  return s;
}


pub inline fn strToTryte( s : TryteStr ) !Tryte
{
  var i : u5 = 0;
  var tryte : Tryte = 0;

  while( i < TRITS_PER_TRYTE ) : ( i += 1 )
  {
    const trit       : Trit  = try charToTrit( s[ i ]);
    const tryte_mask : Tryte = tritToTryte( trit, TRITS_PER_TRYTE - i - 1 ); // Big endian
    tryte |= tryte_mask;
  }
  return tryte;
}