const std = @import("std");
const version = @import("build.zig.zon").dependencies.fftw.version;
const sources = @import("sources.zon");

// Extra flags set by FFTW upstream
// https://github.com/FFTW/fftw3/blob/4fca9817e68f77c118e4704562d63e45c02d38bf/m4/ax_cc_maxopt.m4#L64-L67
pub const flags = &.{
    "-fomit-frame-pointer",
    "-fstrict-aliasing",
};

const Precision = enum {
    single,
    double,
    long_double,
    quad,
};

pub fn build(b: *std.Build) void {
    const upstream = b.dependency("fftw", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const is_windows = target.result.os.tag == .windows;
    const is_mac = target.result.os.tag == .macos;
    const is_x86 = target.result.cpu.arch == .x86_64;
    const is_aarch64 = target.result.cpu.arch == .aarch64;

    const strip = b.option(bool, "strip", "Enable debug symbol stripping (default true if ReleaseFast else false)") orelse 
        if(optimize == .ReleaseFast) true else false;
    const pic = b.option(bool, "pic", "Enable PIC (position independent code) (default true)") orelse true;

    const use_sse2 = b.option(bool, "enable-sse2", "Enable SSE2 optimizations (default CPU target)") orelse
        is_x86 and std.Target.x86.featureSetHas(target.result.cpu.features, .sse2);
    const use_avx = b.option(bool, "enable-avx", "Enable AVX optimizations (default CPU target)") orelse
        is_x86 and std.Target.x86.featureSetHas(target.result.cpu.features, .avx);
    const use_avx2 = b.option(bool, "enable-avx2", "Enable AVX2 optimizations (default CPU target)") orelse
        is_x86 and std.Target.x86.featureSetHas(target.result.cpu.features, .avx2);
    const use_avx512 = b.option(bool, "enable-avx512", "Enable AVX512 optimizations (default CPU target)") orelse
        is_x86 and std.Target.x86.featureSetHas(target.result.cpu.features, .avx512f);
    const use_neon = b.option(bool, "enable-neon", "Enable NEON optimizations (default CPU target)") orelse
        is_aarch64 and std.Target.aarch64.featureSetHas(target.result.cpu.features, .neon);
    const use_sve = b.option(bool, "enable-sve", "Enable SVE optimizations (default CPU target)") orelse
        is_aarch64 and std.Target.aarch64.featureSetHas(target.result.cpu.features, .sve);

    const precision = b.option(Precision, "precision", "Which precision to compile for (default single)") orelse .single;
    const use_threads = b.option(bool, "threads", "Enable FFTW SMP threads library (default false)") orelse false;

    const config = b.addConfigHeader(.{
        .include_path = "config.h",
        .style = .{ .autoconf_undef = upstream.path("config.h.in") },
    }, .{
        //TODO: Sort all these alphabetically
        .PACKAGE = "fftw",
        .PACKAGE_BUGREPORT = "fftw@fftw.org",
        .PACKAGE_NAME = "fftw",
        .PACKAGE_STRING = b.fmt("fftw {s}", .{version}),
        .PACKAGE_TARNAME = "fftw",
        .PACKAGE_URL = "",
        .PACKAGE_VERSION = version,
        .VERSION = version,

        .FFTW_ENABLE_ALLOCA = true,

        //TODO: Unsure about these across platforms
        .HAVE_ABORT = true,

        .HAVE_ALLOCA = if (is_windows) null else true,
        .HAVE_ALLOCA_H = if (is_windows) null else true,
        .HAVE_CLOCK_GETTIME = if (is_windows) null else true,

        // C library functions
        .STDC_HEADERS = true,
        .HAVE_COSL = true,
        .HAVE_DECL_COSL = true,
        .HAVE_DECL_COSQ = false,
        .HAVE_DECL_DRAND48 = true,
        .HAVE_DECL_MEMALIGN = !is_windows,
        .HAVE_DECL_POSIX_MEMALIGN = !is_windows,
        .HAVE_DECL_SINL = true,
        .HAVE_DECL_SINQ = false,
        .HAVE_DECL_SRAND48 = true,
        .HAVE_DLFCN_H = true,
        .HAVE_DOPRNT = null,
        .HAVE_DRAND48 = true,
        .HAVE_FCNTL_H = true,
        .HAVE_FENV_H = true,
        .HAVE_GETPAGESIZE = true,
        .HAVE_GETTIMEOFDAY = true,
        .HAVE_INTTYPES_H = true,
        .HAVE_ISNAN = true,
        .HAVE_LIBM = true,
        .HAVE_LIMITS_H = true,
        .HAVE_LONG_DOUBLE = true,
        .HAVE_MALLOC_H = if(!is_mac) true else null,
        .HAVE_MEMALIGN = !is_windows,
        .HAVE_MEMMOVE = true,
        .HAVE_MEMSET = true,
        .HAVE_POSIX_MEMALIGN = true,
        .HAVE_PTRDIFF_T = true,
        .HAVE_SINL = true,
        .HAVE_SNPRINTF = true,
        .HAVE_SQRT = true,
        .HAVE_STDDEF_H = true,
        .HAVE_STDINT_H = true,
        .HAVE_STDIO_H = true,
        .HAVE_STDLIB_H = true,
        .HAVE_STRCHR = true,
        .HAVE_STRINGS_H = true,
        .HAVE_STRING_H = true,
        .HAVE_SYS_STAT_H = true,
        .HAVE_SYS_TIME_H = true,
        .HAVE_SYS_TYPES_H = true,
        .HAVE_THREADS = use_threads,
        .HAVE_UINTPTR_T = true,
        .HAVE_UNISTD_H = true,
        .HAVE_VPRINTF = true,

        // Sizes
        .SIZEOF_DOUBLE = target.result.cTypeByteSize(.double),
        // Seems to be the size of the R2R calculation flag enum
        // https://github.com/FFTW/fftw3/blob/4fca9817e68f77c118e4704562d63e45c02d38bf/configure.ac#L597-L601
        // Not sure how to calculate this dynamically, so hard coding for now.
        .SIZEOF_FFTW_R2R_KIND = 4,
        .SIZEOF_FLOAT = target.result.cTypeByteSize(.float),
        .SIZEOF_INT = target.result.cTypeByteSize(.int),
        .SIZEOF_LONG = target.result.cTypeByteSize(.long),
        .SIZEOF_LONG_LONG = target.result.cTypeByteSize(.longlong),
        .SIZEOF_MPI_FINT = null,
        .SIZEOF_PTRDIFF_T = target.result.ptrBitWidth() / 8,
        .SIZEOF_SIZE_T = target.result.ptrBitWidth() / 8,
        .SIZEOF_UNSIGNED_INT = target.result.cTypeByteSize(.uint),
        .SIZEOF_UNSIGNED_LONG = target.result.cTypeByteSize(.ulong),
        .SIZEOF_UNSIGNED_LONG_LONG = target.result.cTypeByteSize(.ulonglong),
        .SIZEOF_VOID_P = null,

        .TIME_WITH_SYS_TIME = 1,
        .USING_POSIX_THREADS = if (!is_windows and use_threads) true else null,

        .ARCH_PREFERS_FMA = null,
        .BENCHFFT_LDOUBLE = null,
        .BENCHFFT_QUAD = null,
        .BENCHFFT_SINGLE = null,
        .C_ALLOCA = null,
        .DISABLE_FORTRAN = null,
        .F77_DUMMY_MAIN = null,
        .F77_FUNC = null,
        .F77_FUNC_ = null,
        .F77_FUNC_EQUIV = null,
        .FC_DUMMY_MAIN_EQ_F77 = null,

        .FFTW_CC = "zig cc",
        .FFTW_DEBUG = null,

        .FFTW_SINGLE = if (precision == .single) true else null,
        .FFTW_LDOUBLE = if (precision == .long_double) true else null,
        .FFTW_QUAD = if (precision == .quad) true else null,
        .FFTW_RANDOM_ESTIMATOR = null,

        //TODO: Set these based on arch/cpu
        .HAVE_ALTIVEC = null,
        .HAVE_ALTIVEC_H = null,
        .HAVE_ARMV7A_CNTVCT = null,
        .HAVE_ARMV7A_PMCCNTR = null,
        .HAVE_ARMV8_CNTVCT_EL0 = null,
        .HAVE_ARMV8_PMCCNTR_EL0 = null,

        .HAVE_SSE2 = if (use_sse2) true else null,
        .HAVE_AVX = if (use_avx) true else null,
        .HAVE_AVX2 = if (use_avx2) true else null,
        .HAVE_AVX512 = if (use_avx512) true else null,
        .HAVE_AVX_128_FMA = null,
        .HAVE_GENERIC_SIMD128 = null,
        .HAVE_GENERIC_SIMD256 = null,
        .HAVE_KCVI = null,
        .HAVE_LASX = null,
        .HAVE_LSX = null,
        .HAVE_MIPS_ZBUS_TIMER = null,
        .HAVE_NEON = if (use_neon) true else null,
        .HAVE_SVE = if (use_sve) true else null,

        .HAVE_BSDGETTIMEOFDAY = null,
        .HAVE_GETHRTIME = null,
        .HAVE_HRTIME_T = null,
        .HAVE_LIBQUADMATH = null,
        .HAVE_MACH_ABSOLUTE_TIME = null,
        .HAVE_MPI = null,
        .HAVE_OPENMP = null,
        .HAVE_PTHREAD = null,
        .HAVE_READ_REAL_TIME = null,
        .HAVE_SYSCTL = null,
        .HAVE_TANL = null,
        .HAVE_TIME_BASE_TO_TIME = null,
        .HAVE_VSX = null,
        .HAVE__MM_FREE = null,
        .HAVE__MM_MALLOC = null,
        .HAVE__RTC = null,
        .LT_OBJDIR = null,
        .PTHREAD_CREATE_JOINABLE = null,
        .STACK_DIRECTION = null,
        .WINDOWS_F77_MANGLING = null,
        .WITH_G77_WRAPPERS = null,
        .WITH_OUR_MALLOC = null,
        .WITH_SLOW_TIMER = null,
        ._UINT32_T = null,
        ._UINT64_T = null,
        .@"const" = null,
        .@"inline" = null,
        .size_t = null,
        .uint32_t = null,
        .uint64_t = null,
    });

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = strip,
        .pic = pic,
    });

    mod.addConfigHeader(config);

    const lib_name = switch (precision) {
        .single => "fftw3f",
        .double => "fftw3",
        .long_double => "fftw3l",
        .quad => "fftw3q",
    };

    const lib = b.addLibrary(.{
        .name = lib_name,
        .linkage = .static,
        .root_module = mod,
    });

    // Disable building the dynamic library for now to prevent
    // ambiguity.
    // See: https://github.com/ziglang/zig/issues/20377
    // Potentially can be solved like curl, which exposes a
    // "artifact()" function:
    // https://github.com/allyourcodebase/curl/blob/master/build.zig#L946-L959
    //
    // const dynlib = b.addLibrary(.{
    //     .name = lib_name,
    //     .linkage = .dynamic,
    //     .root_module = mod,
    // });

    lib.installHeader(upstream.path("api/fftw3.h"), "fftw3.h");

    mod.addIncludePath(upstream.path("api"));
    mod.addIncludePath(upstream.path("dft"));
    mod.addIncludePath(upstream.path("kernel"));
    mod.addIncludePath(upstream.path("rdft"));
    mod.addIncludePath(upstream.path("reodft"));
    mod.addIncludePath(upstream.path("simd-support"));

    if (use_threads) {
        mod.addIncludePath(upstream.path("threads"));
    }
    mod.addIncludePath(upstream.path("."));

    // Add all pertinent files
    mod.addCSourceFiles(.{
        .root = upstream.path("api"),
        .files = &sources.api,
        .flags = flags,
    });
    mod.addCSourceFiles(.{
        .root = upstream.path("dft"),
        .files = &sources.dft.generic,
        .flags = flags,
    });
    mod.addCSourceFiles(.{
        .root = upstream.path("rdft"),
        .files = &sources.rdft.generic,
        .flags = flags,
    });

    //TODO: Finish all instruction sets
    if (use_sse2) {
        mod.addCSourceFiles(.{
            .root = upstream.path("dft"),
            .files = &sources.dft.simd.sse2,
            .flags = flags,
        });
        mod.addCSourceFiles(.{
            .root = upstream.path("rdft"),
            .files = &sources.rdft.simd.sse2,
            .flags = flags,
        });
    }
    if (use_avx) {
        mod.addCSourceFiles(.{
            .root = upstream.path("dft"),
            .files = &sources.dft.simd.avx,
            .flags = flags,
        });
        mod.addCSourceFiles(.{
            .root = upstream.path("rdft"),
            .files = &sources.rdft.simd.avx,
            .flags = flags,
        });
    }
    if (use_avx2) {
        mod.addCSourceFiles(.{
            .root = upstream.path("dft"),
            .files = &sources.dft.simd.avx2,
            .flags = flags,
        });
        mod.addCSourceFiles(.{
            .root = upstream.path("rdft"),
            .files = &sources.rdft.simd.avx2,
            .flags = flags,
        });
    }
    if (use_avx512) {
        mod.addCSourceFiles(.{
            .root = upstream.path("dft"),
            .files = &sources.dft.simd.avx512,
            .flags = flags,
        });
        mod.addCSourceFiles(.{
            .root = upstream.path("rdft"),
            .files = &sources.rdft.simd.avx512,
            .flags = flags,
        });
    }
    if (use_neon) {
        mod.addCSourceFiles(.{
            .root = upstream.path("dft"),
            .files = &sources.dft.simd.neon,
            .flags = flags,
        });
        mod.addCSourceFiles(.{
            .root = upstream.path("rdft"),
            .files = &sources.rdft.simd.neon,
            .flags = flags,
        });
    }

    mod.addCSourceFiles(.{
        .root = upstream.path("kernel"),
        .files = &sources.kernel,
        .flags = flags,
    });
    mod.addCSourceFiles(.{
        .root = upstream.path("reodft"),
        .files = &sources.reodft,
        .flags = flags,
    });
    mod.addCSourceFiles(.{
        .root = upstream.path("simd-support"),
        .files = &sources.simd_support,
        .flags = flags,
    });

    if (use_threads) {
        mod.addCSourceFiles(.{
            .root = upstream.path("threads"),
            .files = &sources.threads,
            .flags = flags,
        });
    }

    b.installArtifact(lib);
    // b.installArtifact(dynlib);
}
