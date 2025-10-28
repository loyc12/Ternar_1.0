const std = @import( "std" );
const def = @import( "defs" );

// =========================== DEFS IMPORTS ===========================

// Typedefs

const Bit             = def.Bit;
const Byte            = def.Byte;
const BITS_PER_BYTE   = def.BITS_PER_BYTE;
const Trit            = def.Trit;
const BITS_PER_TRIT   = def.BITS_PER_TRIT;
const Tryte           = def.Tryte;
const TRITS_PER_TRYTE = def.TRITS_PER_TRYTE;
const BITS_PER_TRYTE  = def.BITS_PER_TRYTE;
const TRITS_PER_BYTE  = def.TRITS_PER_BYTE;
const TritChar        = def.TritChar;
const TryteStr        = def.TryteStr;


// Constants

const T2 = def.T2;
const T0 = def.T0;
const T1 = def.T1;
const tPos   = def.tPos;
const tZero  = def.tZero;
const tNeg   = def.tNeg;
const tFalse = def.tFalse;
const tMaybe = def.tMaybe;
const tTrue  = def.tTrue;


// Functions

const tritToTryte = def.tritToTryte;
const tryteToTrit = def.tryteToTrit;
const tritToChar  = def.tritToChar;
const tryteToStr  = def.tryteToStr;
const charToTrit  = def.charToTrit;
const strToTryte  = def.strToTryte;



// =========================== DEFS IMPORTS ===========================

const BANK_TRYTE_SIZE : u64 = 531_441; // CAREFUL NOT TO OVERDO IT HERE
const BANK_BYTE_SIZE  : u64 = @divFloor( BITS_PER_TRIT * TRITS_PER_TRYTE * BANK_TRYTE_SIZE, BITS_PER_BYTE ) + 1;

pub inline fn isTritValid( trit : Trit ) bool { return ( trit != 0b00 ); }

pub inline fn isTritIndexValid(  index : usize ) bool { return ( index < BANK_TRYTE_SIZE * TRITS_PER_TRYTE ); }
pub inline fn isTryteIndexValid( index : usize ) bool { return ( index < BANK_TRYTE_SIZE                   ); }

pub inline fn isBitIndexValid(   index : usize ) bool { return ( index < BANK_BYTE_SIZE * BITS_PER_BYTE ); }
pub inline fn isByteIndexValid(  index : usize ) bool { return ( index < BANK_BYTE_SIZE                 ); }



pub const MemBank = struct
{
  tritArray : [ BANK_BYTE_SIZE ]u8 = [ _ ]u8 { 0b00 } ** BANK_BYTE_SIZE, // Creates an array of BANK_BYTE_SIZE times the u8 value of 0

  // =========================== TRIT OPERATIONS ===========================

  // Can and will set any trit to an invalid value if asked
  pub fn setTrit( self : *MemBank, trit_index: usize, trit : Trit ) !void
  {
    const bit_index  : u64 = trit_index * BITS_PER_TRIT;
    const byte_index : u64 = bit_index  / BITS_PER_BYTE;

    if( !isByteIndexValid( byte_index )){ return error.OutOfBounds; }

    // Encode ternary values into byte masks
    const bit_offset : u3 = @intCast( bit_index % BITS_PER_BYTE );

    const base_mask : Byte = @as( u8, @intCast( 0b11 )) << bit_offset;
    const trit_mask : Byte = @as( u8, @intCast( trit )) << bit_offset;

    // Getting a pointer to modify the array directly
    const byte_ptr = &self.tritArray[ byte_index ];

    byte_ptr.* &= ~base_mask;
    byte_ptr.* |=  trit_mask;
  }

  // Can and will return any invalid trit value encountered
  pub fn getTrit( self : *const MemBank, trit_index : usize ) !Trit
  {
    const bit_index  : u64 = trit_index * BITS_PER_TRIT;
    const byte_index : u64 = bit_index  / BITS_PER_BYTE;

    if( !isByteIndexValid( byte_index )){ return error.OutOfBounds; }

    const bit_offset : u3 = @intCast( bit_index % BITS_PER_BYTE );

    const byte : Byte = self.tritArray[ byte_index ];
    const trit : Trit = @intCast( 0b11 & ( byte >> bit_offset ));

    return trit;
  }

  pub fn logTrit( self : *const MemBank, trit_index : usize, cLoc : ?std.builtin.SourceLocation ) void
  {
    const trit = self.getTrit( trit_index ) catch
    {
      def.log( .ERROR, 0, cLoc, "[ {} ] Error : Address out of bounds", .{ trit_index });
      return;
    };

    def.log( .INFO, 0, cLoc, "[ {} ] => {c}", .{ trit_index, tritToChar( trit )});
  }


  // =========================== TRYTE OPERATIONS ===========================

  pub fn setTryte( self : *MemBank, tryte_index : usize, tryte : Tryte ) !void
  {
    if( !isTryteIndexValid( tryte_index )){ return error.OutOfBounds; }

    var i : u5 = 0;

    const start_trit = (( tryte_index + 1 ) * TRITS_PER_TRYTE ) - 1; // Big endian

    while( i < TRITS_PER_TRYTE ) : ( i += 1 )
    {
      const trit : Trit = tryteToTrit( tryte, i );

      try self.setTrit( start_trit - i, trit ); // Big endian
    }
  }

  pub fn getTryte( self : *const MemBank, tryte_index : usize ) !Tryte
  {
    if( !isTryteIndexValid( tryte_index )){ return error.OutOfBounds; }

    var i : u5    = 0;
    var t : Tryte = 0;

    const start_trit = (( tryte_index + 1 ) * TRITS_PER_TRYTE ) - 1; // Big endian

    while( i < TRITS_PER_TRYTE ) : ( i += 1 )
    {
      const trit = try self.getTrit( start_trit - i ); // Big endian

      t |= tritToTryte( trit, i );
    }
    return t;
  }

  pub fn logTryte( self : *const MemBank, tryte_index : usize, cLoc : ?std.builtin.SourceLocation ) void
  {
    const tryte = self.getTryte( tryte_index ) catch
    {
      def.log( .ERROR, 0, cLoc, "[ {} ] Error : Address out of bounds", .{ tryte_index * TRITS_PER_TRYTE });
      return;
    };

    def.log( .INFO, 0, cLoc, "[ {} ] => {s}", .{ tryte_index * TRITS_PER_TRYTE, tryteToStr( tryte )});
  }
};