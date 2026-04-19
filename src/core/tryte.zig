
const std = @import( "std" );
const def = @import( "defs" );

pub const Bit  = u1;
pub const Byte = u8;
pub const BITS_PER_BYTE = 8;

pub const Trit  = u2;  // 01 = +, 00 = 0, 10 = -, 11 = . ( invalid / only for tritmasking by emulator itself )
pub const BITS_PER_TRIT = 2; // MUST divide 8 fully

pub const Tryte = u18; // aka 9 trits
pub const TRITS_PER_TRYTE = 9;

pub const BITS_PER_TRYTE = BITS_PER_TRIT * TRITS_PER_TRYTE;
pub const TRITS_PER_BYTE = BITS_PER_BYTE / BITS_PER_TRIT;


pub const TritChar = u8;
pub const TryteStr = [ TRITS_PER_TRYTE ]u8;


pub const T1 : Trit = 0b01; // 1
pub const T0 : Trit = 0b00; // 0
pub const T2 : Trit = 0b10; // 2

pub const tPos  : Trit = 0b01; // +
pub const tZero : Trit = 0b00; // 0
pub const tNeg  : Trit = 0b10; // -

pub const tTrue  : Trit = 0b01; // T
pub const tMaybe : Trit = 0b00; // M
pub const tFalse : Trit = 0b10; // F


// NOTE : Using balanced ternary, so all numerical values are signed by default
// NOTE : Sign of a tryte is determined by the sign of its MSD


// ================================ TRIT FUNCTIONS ================================

// ================ CONVERSION ================

pub inline fn tritToTryte( trit : Trit, index : u5 ) Tryte
{
  const t : Tryte = @intCast( trit );
  return( t << ( index * BITS_PER_TRIT ));
}

pub inline fn tritToChar( trit : Trit ) u8
{
  return switch( trit )
  {
    0b01 => '1',
    0b00 => '0',
    0b10 => '2',
    0b11 => '.',
  };
}

pub inline fn charToTrit( c : u8 ) !Trit
{
  switch( c )
  {
    '+', 'T', '1', 'P' => return 0b01,
    'M', 'U', '0', 'Z' => return 0b00,
    '-', 'F', '2', 'N' => return 0b10,
    '.', '_', ':', 'X' => return 0b11,

    else =>
    {
      def.log( .ERROR, 0, @src(), "'{c}'' is not a valid trit symbol", .{ c });
      return error.InvalidTritChar;
    }
  }
}


// ================ OPERATIONS ================

// ======== UNARY TRIT OPS ========

pub inline fn tritInv( a : Trit ) Trit        // TABS : - => +, 0 => 0, + => -
{
  return switch( a ){ tPos => tNeg, tNeg => tPos, else => tZero };
}

pub inline fn tritIsPos( a : Trit ) Trit
{
  return if( a == tPos ) tPos else tNeg;
}
pub inline fn tritIsZero( a : Trit ) Trit     // TEQZ : 0 => +, +/- => -
{
  return if( a == tZero ) tPos else tNeg;
}
pub inline fn tritIsNeg( a : Trit ) Trit
{
  return if( a == tNeg ) tPos else tNeg;
}

pub inline fn tritPosToNeg( a : Trit ) Trit   // TABP : + => -, others unchanged
{
  return if( a == tPos ) tNeg else a;
}
pub inline fn tritPosToZero( a : Trit ) Trit  // TPTZ : + => 0
{
  return if( a == tPos ) tZero else a;
}

pub inline fn tritNegToPos( a : Trit ) Trit   // TABN : - => +, others unchanged
{
  return if( a == tNeg ) tPos else a;
}
pub inline fn tritNegToZero( a : Trit ) Trit  // TNTZ : - => 0
{
  return if( a == tNeg ) tZero else a;
}

pub inline fn tritZeroToPos( a : Trit ) Trit  // TZTP : 0 => +, others unchanged
{
  return if( a == tZero ) tPos else a;
}
pub inline fn tritZeroToNeg( a : Trit ) Trit  // TZTN : 0 => -, others unchanged
{
  return if( a == tZero ) tNeg else a;
}

pub inline fn tritCycleUp( a : Trit ) Trit    // TCYU : - => 0 => + => -
{
  return switch( a )
  {
    tNeg  => tZero,
    tZero => tPos,
    tPos  => tNeg,
    else  => unreachable };
}
pub inline fn tritCycleDown( a : Trit ) Trit  // TCYD : + => 0 => - => +
{
  return switch( a )
  {
    tPos  => tZero,
    tZero => tNeg,
    tNeg  => tPos,
    else  => unreachable };
}

pub inline fn tritDet( a : Trit ) Trit        // TDET : +/- => +, 0 => -
{
  return if( a != tZero ) tPos else tNeg;
}
pub inline fn tritNDet( a : Trit ) Trit       // TNDT : +/- => -, 0 => +
{
  return if( a != tZero ) tNeg else tPos;
}


// ======== BINARY TRIT OPS ========

pub inline fn tritMin( a : Trit, b : Trit ) Trit   // TMIN : min( a, b ),  - < 0 < +
{
  if( a == tNeg  or b == tNeg  ) return tNeg;
  if( a == tZero or b == tZero ) return tZero;
  return tPos;
}
pub inline fn tritNMin( a : Trit, b : Trit ) Trit  // TNMN : -min( a, b )
{
  return tritInv( tritMin( a, b ));
}

pub inline fn tritMax( a : Trit, b : Trit ) Trit   // TMAX : max( a, b )
{
  if( a == tPos  or b == tPos  ) return tPos;
  if( a == tZero or b == tZero ) return tZero;
  return tNeg;
}
pub inline fn tritNMax( a : Trit, b : Trit ) Trit  // TNMX : -max( a, b )
{
  return tritInv( tritMax( a, b ));
}

pub inline fn tritAgr( a : Trit, b : Trit ) Trit   // TAGR : SIGN( a * b )
{
  if( a == tZero or b == tZero ) return tZero;
  return if( a == b ) tPos else tNeg;
}
pub inline fn tritDis( a : Trit, b : Trit ) Trit   // TDIS : -SIGN( a * b )
{
  return tritInv( tritAgr( a, b ));
}

pub inline fn tritMaj( a : Trit, b : Trit ) Trit   // TMAJ : SIGN( a + b )
{
  if( a == b )     return a;
  if( a == tZero ) return b;
  if( b == tZero ) return a;
  return   tZero; // opposite signs
}
pub inline fn tritNMaj( a : Trit, b : Trit ) Trit  // TNMJ : -SIGN( a + b )
{
  return tritInv( tritMaj( a, b ));
}

pub inline fn tritCon( a : Trit, b : Trit ) Trit   // TCON : carry trit ( + iff a=b=+, - iff a=b=- )
{
  if( a == tPos and b == tPos ) return tPos;
  if( a == tNeg and b == tNeg ) return tNeg;
  return tZero;
}
pub inline fn tritNCon( a : Trit, b : Trit ) Trit  // TNCN : negated carry
{
  return tritInv( tritCon( a, b ));
}

pub inline fn tritEql( a : Trit, b : Trit ) Trit   // TEQL : + if a == b, else -
{
  return if( a == b ) tPos else tNeg;
}
pub inline fn tritNEql( a : Trit, b : Trit ) Trit  // TNEQ : - if a == b, else +
{
  return if( a == b ) tNeg else tPos;
}

pub inline fn tritBiasPos( a : Trit, b : Trit ) Trit    // TBPS : SIGN( a + b + 1 )
{
  if(  a == tNeg and b == tNeg )  return tNeg;
  if(( a == tNeg and b == tZero ) or ( a == tZero and b == tNeg )) return tZero;
  return tPos;
}

pub inline fn tritBiasNeg( a : Trit, b : Trit ) Trit    // TBNG : SIGN( a + b - 1 )
{
  if(  a == tPos and b == tPos  ) return tPos;
  if(( a == tPos and b == tZero ) or ( a == tZero and b == tPos )) return tZero;
  return tNeg;
}

pub inline fn tritJointZero( a : Trit, b : Trit ) Trit  // TJZR : SIGN( 1 - |a| - |b| )
{
  if( a == tZero and b == tZero ) return tPos;
  if( a != tZero and b != tZero ) return tNeg;
  return tZero;
}
pub inline fn tritNJointZero( a : Trit, b : Trit ) Trit // TNJZ : -SIGN( 1 - |a| - |b| )
{
  return tritInv( tritJointZero( a, b ));
}

// ================ ARITHMETICS ================

pub const tritMathResult = struct
{
  value    : Trit,
  overflow : Trit = tZero,
};

pub inline fn tritInc1( a : Trit ) tritMathResult  // a + 1
{
  return tritAdd( a, tPos );
}
pub inline fn tritDec1( a : Trit ) tritMathResult  // a - 1
{
  return tritSub( a, tPos );
}

pub inline fn tritAdd( a : Trit, b : Trit ) tritMathResult
{
  // sum range: [ -2, 2 ];  overflow wraps via balanced ternary carry ( ±3 )
  const av : i4 = switch( a ){ 0b01 => 1, 0b10 => -1, else => 0 };
  const bv : i4 = switch( b ){ 0b01 => 1, 0b10 => -1, else => 0 };
  return switch( av + bv )
  {
     2 => .{ .value = tNeg, .overflow = tPos  }, //  2 - 3 = -1,  arry +1
     1 => .{ .value = tPos,                   },
     0 => .{ .value = tZero,                  },
    -1 => .{ .value = tNeg,                   },
    -2 => .{ .value = tPos, .overflow = tNeg  }, // -2 + 3 = +1, carry -1
    else => unreachable,
  };
}
pub inline fn tritSub( a : Trit, b : Trit ) tritMathResult
{
  return tritAdd( a, tritInv( b ));
}

pub inline fn tritMul( a : Trit, b : Trit ) tritMathResult
{
  // NOTE : same truth table as tritAgr
  return .{ .value = tritAgr( a, b )};
}
pub inline fn tritDiv( a : Trit, b : Trit ) tritMathResult
{
  // NOTE : same truth table as tritAgr when b != 0
  std.debug.assert( b != tZero );

  return .{ .value = tritAgr( a, b )};
}
pub inline fn tritAvg( a : Trit, b : Trit ) tritMathResult
{
  // AVERAGE( a, b ) rounded toward 0: same sign → that trit, mixed/zero → 0
  // NOTE : same truth table as tritCon
  return .{ .value = tritCon( a, b )};
}



// ================================ TRYTE FUNCTIONS ================================

// ================ CONVERSION ================

pub inline fn tryteToTrit( tryte : Tryte, index : u5 ) Trit
{
  return @intCast( 0b11 & ( tryte >> ( index * BITS_PER_TRIT )));
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



// =========================== OPERATIONS ===========================


// =========================== ARITHMETICS ===========================
