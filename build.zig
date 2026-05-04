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

    const strip = b.option(bool, "strip", "Enable debug symbol stripping (default true)") orelse true;
    const pic = b.option(bool, "pic", "Enable PIC (position independent code) (default true)") orelse true;

    const use_sse2 = b.option(bool, "enable-sse2", "Enable SSE2 optimizations (default CPU target)") orelse
        std.Target.x86.featureSetHas(target.result.cpu.features, .sse2);
    const use_avx = b.option(bool, "enable-avx", "Enable AVX optimizations (default CPU target)") orelse
        std.Target.x86.featureSetHas(target.result.cpu.features, .avx);
    const use_avx2 = b.option(bool, "enable-avx2", "Enable AVX2 optimizations (default CPU target)") orelse
        std.Target.x86.featureSetHas(target.result.cpu.features, .avx2);
    const use_avx512 = b.option(bool, "enable-avx512", "Enable AVX512 optimizations (default CPU target)") orelse
        std.Target.x86.featureSetHas(target.result.cpu.features, .avx512f);
    const use_neon = b.option(bool, "enable-neon", "Enable NEON optimizations (default CPU target)") orelse
        std.Target.aarch64.featureSetHas(target.result.cpu.features, .neon);
    const use_sve = b.option(bool, "enable-sve", "Enable SVE optimizations (default CPU target)") orelse
        std.Target.aarch64.featureSetHas(target.result.cpu.features, .sve);
    const precision = b.option(Precision, "precision", "Which precision to compile for (default single)") orelse .single;
    const use_threads = b.option(bool, "threads", "Enable FFTW SMP threads library (default false)") orelse false;

    const is_windows = target.result.os.tag == .windows;

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
        .STDC_HEADERS = 1,
        .HAVE_COSL = 1,
        .HAVE_DECL_COSL = 1,
        .HAVE_DECL_COSQ = 0,
        .HAVE_DECL_DRAND48 = 1,
        .HAVE_DECL_MEMALIGN = 1,
        .HAVE_DECL_POSIX_MEMALIGN = 1,
        .HAVE_DECL_SINL = 1,
        .HAVE_DECL_SINQ = 0,
        .HAVE_DECL_SRAND48 = 1,
        .HAVE_DLFCN_H = 1,
        .HAVE_DOPRNT = null,
        .HAVE_DRAND48 = 1,
        .HAVE_FCNTL_H = 1,
        .HAVE_FENV_H = 1,
        .HAVE_GETPAGESIZE = 1,
        .HAVE_GETTIMEOFDAY = 1,
        .HAVE_INTTYPES_H = 1,
        .HAVE_ISNAN = 1,
        .HAVE_LIBM = 1,
        .HAVE_LIMITS_H = 1,
        .HAVE_LONG_DOUBLE = 1,
        .HAVE_MALLOC_H = 1,
        .HAVE_MEMALIGN = 1,
        .HAVE_MEMMOVE = 1,
        .HAVE_MEMSET = 1,
        .HAVE_POSIX_MEMALIGN = 1,
        .HAVE_PTRDIFF_T = 1,
        .HAVE_SINL = 1,
        .HAVE_SNPRINTF = 1,
        .HAVE_SQRT = 1,
        .HAVE_STDDEF_H = 1,
        .HAVE_STDINT_H = 1,
        .HAVE_STDIO_H = 1,
        .HAVE_STDLIB_H = 1,
        .HAVE_STRCHR = 1,
        .HAVE_STRINGS_H = 1,
        .HAVE_STRING_H = 1,
        .HAVE_SYS_STAT_H = 1,
        .HAVE_SYS_TIME_H = 1,
        .HAVE_SYS_TYPES_H = 1,
        .HAVE_THREADS = use_threads,
        .HAVE_UINTPTR_T = 1,
        .HAVE_UNISTD_H = 1,
        .HAVE_VPRINTF = 1,

        // TODO: Base this on arch
        // Sizes
        .SIZEOF_DOUBLE = 8,
        .SIZEOF_FFTW_R2R_KIND = 4,
        .SIZEOF_FLOAT = 4,
        .SIZEOF_INT = 4,
        .SIZEOF_LONG = 8,
        .SIZEOF_LONG_LONG = 8,
        .SIZEOF_MPI_FINT = null,
        .SIZEOF_PTRDIFF_T = 8,
        .SIZEOF_SIZE_T = 8,
        .SIZEOF_UNSIGNED_INT = 4,
        .SIZEOF_UNSIGNED_LONG = 8,
        .SIZEOF_UNSIGNED_LONG_LONG = 8,
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

    //TODO: These might have to be different per single/double/quad/etc
    const lib = b.addLibrary(.{
        .name = lib_name,
        .linkage = .static,
        .root_module = mod,
    });

    const dynlib = b.addLibrary(.{
        .name = lib_name,
        .linkage = .dynamic,
        .root_module = mod,
    });

    lib.installHeader(upstream.path("api/fftw3.h"), ".");

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

    //TODO: Finish all instruction sets
    if (use_sse2) {
        mod.addCSourceFiles(.{
            .root = upstream.path("dft"),
            .files = &sources.dft.simd.sse2,
            .flags = flags,
        });
    }
    if (use_avx) {
        mod.addCSourceFiles(.{
            .root = upstream.path("dft"),
            .files = &sources.dft.simd.avx,
            .flags = flags,
        });
    }
    if (use_avx2) {
        mod.addCSourceFiles(.{
            .root = upstream.path("dft"),
            .files = &sources.dft.simd.avx2,
            .flags = flags,
        });
    }
    if (use_avx512) {
        mod.addCSourceFiles(.{
            .root = upstream.path("dft"),
            .files = &sources.dft.simd.avx512,
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
    b.installArtifact(dynlib);
}
