# FFTW Zig
FFTW ported to the Zig build system.

Supports cross compilation

## Setup
Add fftw to your project with:

```
zig fetch --save https://github.com/adworacz/fftw/archive/refs/tags/v3.3.11-2.tar.gz
```

Then in your `build.zig`, add the following:

```zig
const fftw = b.dependency("fftw", .{
    .target = target,
    .optimize = optimize,
    .precision = .single,
    //Any other options you desire - see build.zig for all options
});

//Note the name of the artifact changes based on the desired precision.
root_module.linkLibrary(fftw.artifact("fftw3f"));
```

Just like how Linux distributions package fftw, the fftw artifact is given a specific name based on 
the precision it is compiled with.

Names:
* `fftw3` - double precision
* `fftw3f` - single precision
* `fftw3l` - long double precision
* `fftw3q` - quad precision

Finally, use it in your zig code:

```zig
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

c.fftwf_plan_r2r_2d(...)
```

## Known issues
1. Not all architectures/operating systems supported by FFTW have been configured in this package, let alone tested.
   Please open a PR if you add support/confirm something works!
2. Only the static libary/artifact is currently built due to a [known bug](https://github.com/ziglang/zig/issues/20377)
   in Zig. There is a potential workaround noted in this package's `build.zig.zon`, based on an idea from the `curl`
   package. Please open a PR if you decide to implement it.
