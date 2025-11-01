const std = @import( "std" );

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build( b: *std.Build ) void
{
  // ================================ BUILD CONFIGURATION ================================

  // This is the "standard" build target, which is the default target for the
  // current platform and architecture. It is used to compile the code for the
  // current platform and architecture, and it is the default target for the
  // build system.
  const target   = b.standardTargetOptions(  .{} );
  const optimize = b.standardOptimizeOption( .{} );


  // ================================ EXECUTABLE ================================

  // This creates a module for the executable itself
  const exe_mod = b.createModule(
  .{
    .root_source_file = b.path( "src/main.zig" ),
    .target           = target,
    .optimize         = optimize,
  });

  // This adds the executable module to the build graph,
  // which is the main entry point of the application.
  const exe = b.addExecutable(
  .{
    .name        = "Ternar",
    .root_module = exe_mod,
    .use_llvm    = false,
  });

  // This declares the intent to install the executable artifact,
  // which is the binary that will be built by the build system.
  b.installArtifact( exe );


  // ================================ INTERNAL MODULES ================================

  // This adds defs.zig as a module, which contains common definitions and utilities
  // used throughout the project. This module is expected to be in the `src/` directory,
  // and it is used to provide a simple way to access commonly used src definitions
  const defs = b.createModule(
  .{
    .root_source_file = b.path( "src/defs.zig" ),
    .target   = target,
    .optimize = optimize,
  });
  defs.addImport( "defs", defs );
  exe.root_module.addImport( "defs", defs );


  // ================================ COMMANDS ================================

  // This creates a Run step in the build graph, to be executed when call, or if
  // another step is evaluated that depends on it ( similar to Makefile targets ).
  const run_cmd = b.addRunArtifact( exe );
  run_cmd.step.dependOn( b.getInstallStep() );
  if( b.args )| args |{ run_cmd.addArgs( args ); }

  const run_step = b.step( "run", "Run the debug environment" );
  run_step.dependOn( &run_cmd.step );
}