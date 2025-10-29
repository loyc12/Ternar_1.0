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
    // SYSTEM OPS                2T ( 1 arg ) |

      @intFromEnum( OpCode.NOP ) => {                      }, // TODO : handle A as a multiplier

    //@intFromEnum( OpCode.JMP ) => { self.JMP( A );       },

    // MOVE OPS                 3T ( 2 args ) | in place ops

    //@intFromEnum( OpCode.CPY ) => { self.CPY( A, B );    },
    //@intFromEnum( OpCode.SWP ) => { self.SWP( A, B );    },

    //@intFromEnum( OpCode.STR ) => { self.STR( A, B );    },
    //@intFromEnum( OpCode.LOD ) => { self.LOD( A, B );    },
    //@intFromEnum( OpCode.STL ) => { self.STR( A, null ); self.LOD( B, null ); },

    // MULTI OPS                4T ( 3 args ) |

    //@intFromEnum( OpCode.STM ) => { self.STM( A, B, C ); },
    //@intFromEnum( OpCode.CPM ) => { self.CPM( A, B, C ); },
    //@intFromEnum( OpCode.SWM ) => { self.SWM( A, B, C ); },

    //@intFromEnum( OpCode.PSH ) => { self.PSH( A, B, C ); },
    //@intFromEnum( OpCode.POP ) => { self.POP( A, B, C ); },
    //@intFromEnum( OpCode.CLR ) => { self.CLR( A, B, C ); },

    // GATE OPS                 3T ( 2 args ) | outputs to PREG only

    //@intFromEnum( OpCode.AND ) => { self.AND( A, B );    },
    //@intFromEnum( OpCode.NAN ) => { self.NAN( A, B );    },

    //@intFromEnum( OpCode.ORR ) => { self.ORR( A, B );    },
    //@intFromEnum( OpCode.NOR ) => { self.NOR( A, B );    },

    //@intFromEnum( OpCode.XOR ) => { self.XOR( A, B );    },
    //@intFromEnum( OpCode.XNR ) => { self.XNR( A, B );    },

    //@intFromEnum( OpCode.MAJ ) => { self.MAJ( A, B );    },
    //@intFromEnum( OpCode.IMJ ) => { self.IMJ( A, B );    },

    //@intFromEnum( OpCode.CON ) => { self.CON( A, B );    },
    //@intFromEnum( OpCode.ICN ) => { self.ICN( A, B );    },

    //@intFromEnum( OpCode.PAR ) => { self.PAR( A, B );    },
    //@intFromEnum( OpCode.NPR ) => { self.NPR( A, B );    },

    // TRIT1 OPS                4T ( 3 args ) | in place ops.

    //@intFromEnum( OpCode.INC ) => { self.INC( A, B, C ); },
    //@intFromEnum( OpCode.DEC ) => { self.DEC( A, B, C ); },
    //@intFromEnum( OpCode.INV ) => { self.INV( A, B, C ); },

    //@intFromEnum( OpCode.SHU ) => { self.SHU( A, B, C ); },
    //@intFromEnum( OpCode.SHD ) => { self.SHD( A, B, C ); },
    //@intFromEnum( OpCode.SHV ) => { self.SHV( A, B, C ); },

    //@intFromEnum( OpCode.RTU ) => { self.RTU( A, B, C ); },
    //@intFromEnum( OpCode.RTD ) => { self.RTD( A, B, C ); },
    //@intFromEnum( OpCode.RTV ) => { self.RTV( A, B, C ); },

    //@intFromEnum( OpCode.FLP ) => { self.INC( A, B, C ); },
    //@intFromEnum( OpCode.PTZ ) => { self.DEC( A, B, C ); },
    //@intFromEnum( OpCode.NTZ ) => { self.INV( A, B, C ); },

    //@intFromEnum( OpCode.MAG ) => { self.SHU( A, B, C ); },
    //@intFromEnum( OpCode.PTN ) => { self.SHD( A, B, C ); },
    //@intFromEnum( OpCode.NTP ) => { self.SHV( A, B, C ); },

    //@intFromEnum( OpCode.EQZ ) => { self.RTU( A, B, C ); },
    //@intFromEnum( OpCode.ZTP ) => { self.RTD( A, B, C ); },
    //@intFromEnum( OpCode.ZTN ) => { self.RTV( A, B, C ); },

    //@intFromEnum( OpCode.TUP ) => { self.TUP( A, B, C ); },
    //@intFromEnum( OpCode.TDW ) => { self.TDW( A, B, C ); },

    //@intFromEnum( OpCode.DET ) => { self.DET( A, B, C ); },
    //@intFromEnum( OpCode.IDT ) => { self.IDT( A, B, C ); },

    //@intFromEnum( OpCode.CMZ ) => { self.CMZ( A, B, C ); },

    // TRIT2 OPS                4T ( 3 args ) | outputs to C.adr

    //@intFromEnum( OpCode.CMF ) => { self.CMF( A, B, C ); },
    //@intFromEnum( OpCode.CMP ) => { self.CMP( A, B, C ); },
    //@intFromEnum( OpCode.CMN ) => { self.CMN( A, B, C ); },

    //@intFromEnum( OpCode.MSZ ) => { self.MSZ( A, B, C ); },
    //@intFromEnum( OpCode.MSP ) => { self.MSP( A, B, C ); },
    //@intFromEnum( OpCode.MSN ) => { self.MSN( A, B, C ); },

    // ALU1 OPS                 4T ( 3 args ) | outputs to C.adr

    //@intFromEnum( OpCode.ADD ) => { self.ADD( A, B, C ); },
    //@intFromEnum( OpCode.SUB ) => { self.SUB( A, B, C ); },
    //@intFromEnum( OpCode.MUL ) => { self.MUL( A, B, C ); },

    //@intFromEnum( OpCode.MOD ) => { self.MOD( A, B, C ); },
    //@intFromEnum( OpCode.EXP ) => { self.EXP( A, B, C ); },
    //@intFromEnum( OpCode.LOG ) => { self.LOG( A, B, C ); },

    //@intFromEnum( OpCode.DIV ) => { self.DIV( A, B, C ); },
    //@intFromEnum( OpCode.RND ) => { self.RND( A, B, C ); },
    //@intFromEnum( OpCode.RUT ) => { self.RUT( A, B, C ); },

    //@intFromEnum( OpCode.AVG ) => { self.AVG( A, B, C ); },
    //@intFromEnum( OpCode.MAX ) => { self.MAX( A, B, C ); },
    //@intFromEnum( OpCode.MIN ) => { self.MIN( A, B, C ); },

    //@intFromEnum( OpCode.ADC ) => { self.ADC( A, B, C ); },
    //@intFromEnum( OpCode.SBB ) => { self.SBB( A, B, C ); },

    //@intFromEnum( OpCode.SQR ) => { self.SQR( A, B, C ); },
    //@intFromEnum( OpCode.CUB ) => { self.CUB( A, B, C ); },
    //@intFromEnum( OpCode.MDT ) => { self.MDT( A, B, C ); },

    // ALU2 OPS                 5T ( 4 args ) | outputs to D.adr

    //@intFromEnum( OpCode.MED ) => { self.MED( A, B, C, D ); },
    //@intFromEnum( OpCode.MAD ) => { self.MAD( A, B, C, D ); },
    //@intFromEnum( OpCode.AMU ) => { self.AMU( A, B, C, D ); },

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