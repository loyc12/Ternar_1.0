const std = @import( "std" );
const def = @import( "defs" );

const ops = @import( "opfuncts.zig" );

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
    return self.RAM.getTryte( @intFromEnum( register )) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to get RAM tryte");
      return 0;
    };
  }

  inline fn setTryteFromRam( self : *Ternar, register : Tryte, val : Tryte ) Tryte
  {
    self.RAM.setTryte( @intFromEnum( register ), val ) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to set RAM tryte");
      return 0;
    };

    return val;
  }

  inline fn nudgeTryteFromRam( self : *Ternar, register : Tryte, delta : Tryte ) Tryte
  {
    var newVal = self.RAM.getTryte( @intFromEnum( register )) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to get RAM tryte");
      return 0;
    };

    newVal += delta;

    self.RAM.setTryte( @intFromEnum( register ), newVal ) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to set RAM tryte");
      return 0;
    };

    return newVal;
  }

  inline fn maskTryteFromRam( self : *Ternar, register : Tryte, mask : Tryte ) Tryte
  {
    var newVal = self.RAM.getTryte( @intFromEnum( register )) catch
    {
      def.qlog( .ERROR, 0, @src(), "failed to get RAM tryte");
      return 0;
    };

    newVal &= mask;

    self.RAM.setTryte( @intFromEnum( register ), newVal ) catch
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

    const IAS = ( op & OpCode._IAS_ );
    const OAS = ( op & OpCode._OAS_ );
    const EXC = ( op & OpCode._EXC_ );

    if( !switch( IAS )
    {
      OpCode.I_VL => true,
      OpCode.I_AD => false,
      OpCode.I_RA => false,
      else        => false,
    })
    { def.log( .ERROR, 0, @src(), "INPUT SPACE {s} not supported", .{ tryteToStr( IAS )}); return false; }

    if( !switch( OAS )
    {
      OpCode.O_VL => true,
      OpCode.O_AD => false,
      OpCode.O_RA => false,
      else        => false,
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

  //const OPT = ( op | OpCode._OPT_ );
    const expectArgC = argC; // TODO : use OPT to find expected argcount

    if( expectArgC != argC  )
    {
      def.log( .ERROR, 0, @src(), "expect {d} args, got {d} instead", .{ expectArgC, argC });
      return false;
    }

    _ = self.setProcRegTryte( .OLEN, argC + 1 );

    // PARSING OPNAMES

    const OPN = ( op & OpCode._OPN_ );

    switch( OPN )
    {
    // SYSTEM OPS      2T ( 1 arg ) |

      @intFromEnum( OpCode.NOP ) => { ops.NOP( self, A ); },
    //@intFromEnum( OpCode.INF ) => { ops.INF( self, A ); },
    //@intFromEnum( OpCode.PRT ) => { ops.PRT( self, A ); },


      else => return false,
    }

    // STEPPING TO NEXT OP

    self.stepProcess();

    return true;
  }


  inline fn stepProcess( self : *Ternar ) void
  {
    const opLenght = self.getProcRegTryte( .OLEN );
    const newAdr = self.nudgeProcRegTryte( .PADR, opLenght );

    def.log( .DEBUG, 0, @src(), "Stepped process address to {s}: ", .{ tryteToStr( newAdr )});
  }


};