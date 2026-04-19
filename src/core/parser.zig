const std = @import( "std" );
const def = @import( "defs" );


const OpCode = def.OpCode;
const Tryte  = def.Tryte;

pub const ArgLine = struct
{
  op : ?OpCode = null,
  A  : ?Tryte  = null,
  B  : ?Tryte  = null,
  C  : ?Tryte  = null,
  D  : ?Tryte  = null,
};

const LINE_DELIMITER = '\n';
const ARG_DELIMITERS = "\t\r ,;.:(){}[]#/|\\";
const COMMENT_DELIMITER = '#';

pub const Parser = struct
{
  isFileInit : bool               = false,
  readBuffer : [ 1024 ]u8         = undefined,
  fileReader : std.fs.File.Reader = undefined,

  file : std.fs.File = undefined,
  line : ?[]u8       = null,
  eof  : bool        = false,
  row  : u32         = 0,

  // ================================ FILE PARSER FUNCTIONS ================================

  pub fn openFile( self : *Parser, comptime filePath : [:0] const u8 ) void
  {
    if( self.isFileInit )
    {
      def.qlog( .WARN, 0, @src(), "Closing previous file beforehand" );
      self.file.close();
    }

    if( std.fs.cwd().openFile( filePath, .{} ))| f |{ self.file = f; }
    else | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to open file '{s}' : {}", .{ filePath, err });
      self.isFileInit = false;
      return;
    }

    self.fileReader = self.file.reader( &self.readBuffer );
    self.isFileInit = true;

    self.eof = false;
    self.row = 0;
  }

  pub fn closeFile( self : *Parser ) void
  {
    if( !self.isFileInit )
    {
      def.qlog( .WARN, 0, @src(), "Cannot close file : none opened yet");
      return;
    }

    self.isFileInit = false;
    self.file.close();
  }

  pub fn loadNextLine( self : *Parser ) bool
  {
    if( !self.isFileInit )
    {
      def.qlog( .WARN, 0, @src(), "Cannot read line : none opened yet");
      return false;
    }

    if( self.fileReader.interface.takeDelimiter( LINE_DELIMITER ))| l |{ self.line = l; }
    else | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to read file line : {}", .{ err });
      return false;
    }

    if( !self.eof )
    {
      self.row += 1;
      self.eof = ( self.line == null );
    }

    return true;
  }


  pub fn parseNextLine( self : *Parser ) ArgLine
  {
    if( !self.loadNextLine() )
    {
      def.qlog( .ERROR, 0, @src(), "Failed to obtain parsable line : load error");
      return .{};
    }

    if( self.eof )
    {
      def.qlog( .ERROR, 0, @src(), "Failed to obtain parsable line : end of file");
      return .{};
    }

    const codeLine = std.mem.sliceTo( self.line.?, COMMENT_DELIMITER );
    var it = std.mem.tokenizeAny( u8, codeLine, ARG_DELIMITERS );
    var tokenIndex : u32 = 0;

    while( it.next() )| token |
    {
      if( tokenIndex == 0 )
      {
        const opCode = def.opCodeMap.get( token );
        if( opCode != null )
        {
          std.debug.print("\n-L{d}-\t: {s}\n", .{ self.row, @tagName( opCode.? )}); // TODO : build return struct
        }
      }
      else
      {
        const arg : ?u18 = std.fmt.parseInt( u18, token, 3 ) catch null;

        if( arg != null )
        {
          std.debug.print(" A{d}\t: {}\n", .{ tokenIndex, arg.? }); // TODO : build return struct
        }

      }
      tokenIndex += 1;
    }

    return .{};
  }

  // ================================ DEBUG FUNCTIONS ================================

  fn logNextLine( self : *Parser ) void
  {
    if( !self.loadNextLine() ){ return; }

    if( !self.eof ){ def.log(  .INFO, self.row, @src(), "[{s}]", .{ self.line.? }); }
    else           { def.qlog( .WARN, self.row, @src(), "EOF reached"          ); }
  }
};


pub fn testParser() void
{
  def.qlog( .DEBUG, 0, @src(), "TESTING PARSER\n");

  var p : Parser = .{};

  p.closeFile();

  p.logNextLine();

  p.openFile( "BAD_PATH" );
  p.logNextLine();
  p.closeFile();

  p.openFile( "BAD_PATH" );
  p.openFile( "exampleAssemblies/debug.trn" );
  p.logNextLine();
  p.closeFile();
  p.closeFile();

  p.openFile( "exampleAssemblies/debug.trn" );
  p.openFile( "BAD_PATH" );
  p.logNextLine();
  p.closeFile();

  p.logNextLine();

  p.openFile( "exampleAssemblies/debug.trn" );

  p.logNextLine();
  p.logNextLine();
  p.logNextLine();
  p.logNextLine();
  p.logNextLine();

  p.openFile( "exampleAssemblies/debug.trn" );

  _ = p.parseNextLine();
  _ = p.parseNextLine();
  _ = p.parseNextLine();
  _ = p.parseNextLine();
  _ = p.parseNextLine();

  p.closeFile();

  def.qlog( .DEBUG, 0, @src(), "PARSER TESTED\n");
}

