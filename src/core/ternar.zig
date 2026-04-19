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

const T2     = def.T2;
const T0     = def.T0;
const T1     = def.T1;
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


// structs

const MemBank   = def.MemBank;
const OpCode    = def.OpCode;
const PRegTryte = def.PRegTryte;
const PFlagTrit = def.PFlagTrit;


// TODO : review name and implementation of "nudge" functions
// TODO : use trit/tryte aritmetic functions in tryte.zig for all maths

pub const Ternar = struct
{
  RAM : MemBank = .{},


  // =========================== ACCESSORS AND MUTATORS ===========================

  // ========= TRIT FLAGS =========

  inline fn getProcFlagTrit( self : *Ternar, flag : PFlagTrit ) Trit
  {
    const tritOffset = @intFromEnum( PRegTryte.PFLG ) * TRITS_PER_TRYTE;

    return self.RAM.getTrit( @intFromEnum( flag ) + tritOffset ) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to get flag trit");
      return 0;
    };
  }

  inline fn setProcFlagTrit( self : *Ternar, flag : PFlagTrit, val : Trit ) Trit
  {
    const tritOffset = @intFromEnum( PRegTryte.PFLG ) * TRITS_PER_TRYTE;

    self.RAM.setTrit( @intFromEnum( flag ) + tritOffset, val ) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to set flag trit");
      return 0;
    };

    return val;
  }

  inline fn nudgeProcFlagTrit( self : *Ternar, flag : PFlagTrit, delta : Trit ) Trit
  {
    const tritOffset = @intFromEnum( PRegTryte.PFLG ) * TRITS_PER_TRYTE;

    const newVal = delta + self.RAM.getTrit( @intFromEnum( flag ) + tritOffset ) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to get flag trit");
      return 0;
    };

    self.RAM.setTrit( @intFromEnum( flag ) + tritOffset, newVal ) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to set flag trit");
      return 0;
    };

    return newVal;
  }


  // ========= PROCESS REGISTERS =========

  inline fn getProcRegTryte( self : *Ternar, register : PRegTryte ) Tryte
  {
    return self.RAM.getTryte( @intFromEnum( register )) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to get register tryte");
      return 0;
    };
  }

  inline fn setProcRegTryte( self : *Ternar, register : PRegTryte, val : Tryte ) Tryte
  {
    self.RAM.setTryte( @intFromEnum( register ), val ) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to set register tryte");
      return 0;
    };

    return val;
  }

  inline fn nudgeProcRegTryte( self : *Ternar,  register : PRegTryte, delta : Tryte ) Tryte
  {
    var newVal = self.RAM.getTryte( @intFromEnum( register )) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to get register tryte");
      return 0;
    };

    newVal += delta;

    self.RAM.setTryte( @intFromEnum( register ), newVal ) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to set register tryte");
      return 0;
    };

    return newVal;
  }

  // ========= GENERAL RAM REGISTERS =========

  inline fn getTryteFromRam( self : *Ternar, register : Tryte ) Tryte
  {
    return self.RAM.getTryte( @intCast( register )) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to get RAM tryte");
      return 0;
    };
  }

  inline fn setTryteFromRam( self : *Ternar, register : Tryte, val : Tryte ) Tryte
  {
    self.RAM.setTryte( @intCast( register ), val ) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to set RAM tryte");
      return 0;
    };

    return val;
  }

  inline fn nudgeTryteFromRam( self : *Ternar, register : Tryte, delta : Tryte ) Tryte
  {
    var newVal = self.RAM.getTryte( @intCast( register )) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to get RAM tryte");
      return 0;
    };

    newVal += delta;

    self.RAM.setTryte( @intCast( register ), newVal ) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to set RAM tryte");
      return 0;
    };

    return newVal;
  }

  inline fn maskTryteFromRam( self : *Ternar, register : Tryte, mask : Tryte ) Tryte
  {
    var newVal = self.RAM.getTryte( @intCast( register )) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to get RAM tryte");
      return 0;
    };

    newVal &= mask;

    self.RAM.setTryte( @intCast( register ), newVal ) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to set RAM tryte");
      return 0;
    };

    return newVal;
  }


  // =========================== OPCODE EXECUTION ===========================

  pub fn execOp( self : *Ternar, op : Tryte, arg1 : ?Tryte, arg2 : ?Tryte, arg3 : ?Tryte, arg4 : ?Tryte, ) bool
  {
    // VALIDATING OPMODS

    const IAS = def.getOpComp( op, ._IAS_ );
    const OAS = def.getOpComp( op, ._OAS_ );
    const EXC = def.getOpComp( op, ._EXC_ );

    if( !switch( IAS )
    {
      OpCode.I_VAL => true,
      OpCode.I_ADR => false,
      OpCode.I_RAM => false,
      else         => false,
    })
    { def.log( .ERROR, 0, @src(), "INPUT SPACE {s} not supported", .{ tryteToStr( IAS )}); return false; }

    if( !switch( OAS )
    {
      OpCode.O_VAL => true,
      OpCode.O_ADR => false,
      OpCode.O_RAM => false,
      else         => false,
    })
    { def.log( .ERROR, 0, @src(), "OUTPUT SPACE {s} not supported", .{ tryteToStr( OAS )}); return false; }

    if( !switch( EXC )
    {
      OpCode.C_ALW => true,
      OpCode.C_IFC => false,
      OpCode.C_IFF => false,

      OpCode.C_IFZ => false,
      OpCode.C_IFP => false,
      OpCode.C_IFN => false,

      OpCode.C_INV => false,
      OpCode.C_SKP => false,
    //OpCode.C_XXX => false,

      else         => false,
    })
    { def.log( .ERROR, 0, @src(), "OP CONDITION {s} not supported", .{ tryteToStr( EXC )}); return false; }


    // VALIDATING ARGCOUNT

    var argC : u4 = 0;
    var foundNull = false;

    var A : Tryte = 0;
    var B : Tryte = 0;
    var C : Tryte = 0;
    var D : Tryte = 0;

    if( !foundNull ){ if( arg1 )| arg |{ argC += 1; A = arg; } else { foundNull = true; }}
    if( !foundNull ){ if( arg2 )| arg |{ argC += 1; B = arg; } else { foundNull = true; }}
    if( !foundNull ){ if( arg3 )| arg |{ argC += 1; C = arg; } else { foundNull = true; }}
    if( !foundNull ){ if( arg4 )| arg |{ argC += 1; D = arg; } else { foundNull = true; }}

    const expectedOpLen = argC + 1;

    const opLen = def.getOpLen( op );

    if( opLen == null )
    {
      def.qlog( .ERROR, 0, @src(), "failed to obtain opLen" );
      return false;
    }

    if( expectedOpLen != opLen.?  )
    {
      def.log( .ERROR, 0, @src(), "found {d} args for a {d} args op", .{ expectedOpLen - 1, opLen.? - 1 });
      return false;
    }

    // PARSING OPNAMES

    const opName : OpCode = @enumFromInt( def.getOpComp( op, ._OPN_ ));

    switch( opName )
    {
      OpCode.NOPE => { def.opList.NOPE( self, A ); },

      else =>
      {
        def.qlog( .ERROR, 0, @src(), "unrecognized opName" );
        return false;
      },
    }

    // STEPPING TO NEXT OP

    self.stepProcess( opLen.? );

    return true;
  }


  inline fn stepProcess( self : *Ternar, lastOpLen : Tryte ) void
  {
    const newAdr = self.nudgeProcRegTryte( .R_PADR, lastOpLen );

    def.log( .DEBUG, 0, @src(), "Stepped process address to {s}: ", .{ tryteToStr( newAdr )});
  }


};