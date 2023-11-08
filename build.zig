const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const yasm_dep = b.dependency("yasm", .{ .target = target, .optimize = optimize });
    const yasm_exe = yasm_dep.artifact("yasm");

    const libvpx = b.addStaticLibrary(.{
        .name = "vpx",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const asm_config, const config_h = writeConfig(b, target) catch @panic("OOM");
    for (x86_asm) |input_file| {
        const output_basename = b.fmt("{s}.o", .{input_file});
        const yasm_run = b.addRunArtifact(yasm_exe);

        yasm_run.addArgs(&.{
            "-f",
            "elf64",
            "-I./",
        });

        yasm_run.addArg("-I");
        yasm_run.addDirectoryArg(asm_config.getDirectory());

        yasm_run.addArg("-o");
        libvpx.addObjectFile(yasm_run.addOutputFileArg(output_basename));

        yasm_run.addFileArg(.{ .path = input_file });
    }

    libvpx.addIncludePath(.{ .path = "." });
    inline for (libvpx_srcs) |s| libvpx.addCSourceFile(s);
    libvpx.defineCMacro("_FORTIFY_SOURCE", "0");
    libvpx.defineCMacro("_LARGEFILE_SOURCE", null);
    libvpx.defineCMacro("_FILE_OFFSET_BITS", "64");
    libvpx.addConfigHeader(config_h);

    b.installArtifact(libvpx);
}

const StrSlice = []const []const u8;

const common_flags: StrSlice = &.{
    "-m64",
    "-Wall",
    "-Wdeclaration-after-statement",
    "-Wdisabled-optimization",
    "-Wfloat-conversion",
    "-Wformat=2",
    "-Wpointer-arith",
    "-Wtype-limits",
    "-Wcast-qual",
    "-Wvla",
    "-Wimplicit-function-declaration",
    "-Wmissing-declarations",
    "-Wmissing-prototypes",
    "-Wshadow",
    "-Wuninitialized",
    "-Wunused",
    "-Wextra",
    "-Wundef",
    "-Wframe-larger-than=52000",
    "-std=gnu89",
};

const CSourceFile = std.Build.Step.Compile.CSourceFile;

const libvpx_srcs: []const CSourceFile = &.{
    .{ .file = .{ .path = "vpx/src/vpx_decoder.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx/src/vpx_encoder.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx/src/vpx_codec.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx/src/vpx_image.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx/src/vpx_tpl.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_mem/vpx_mem.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_scale/generic/vpx_scale.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_scale/generic/yv12config.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_scale/generic/yv12extend.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_scale/generic/gen_scalers.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_scale/vpx_scale_rtcd.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/prob.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/bitwriter.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/bitwriter_buffer.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/psnr.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/bitreader.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/bitreader_buffer.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/intrapred.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/add_noise.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/deblock.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/vpx_convolve.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/loopfilter.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/fwd_txfm.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/inv_txfm.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/quantize.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/avg.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/skin_detection.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/sad.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/subtract.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/sum_squares.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/variance.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_dsp/vpx_dsp_rtcd.c" }, .flags = common_flags },
    // .{ .file = .{ .path = "vpx_dsp/x86/avg_intrin_avx2.c" }, .flags = common_flags ++ .{ "-mavx2" } },
    .{ .file = .{ .path = "vpx_dsp/x86/avg_intrin_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    // .{ .file = .{ .path = "vpx_dsp/x86/avg_pred_avx2.c" }, .flags = common_flags ++ .{"-mavx2"} },
    .{ .file = .{ .path = "vpx_dsp/x86/avg_pred_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    // .{ .file = .{ .path = "vpx_dsp/x86/fwd_txfm_avx2.c" }, .flags = common_flags ++ .{"-mavx2"} },
    .{ .file = .{ .path = "vpx_dsp/x86/fwd_txfm_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    .{ .file = .{ .path = "vpx_dsp/x86/post_proc_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    .{ .file = .{ .path = "vpx_dsp/x86/vpx_subpixel_4t_intrin_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    // .{ .file = .{ .path = "vpx_dsp/x86/vpx_subpixel_8t_intrin_avx2.c" }, .flags = common_flags ++ .{"-mavx2"} },
    .{ .file = .{ .path = "vpx_dsp/x86/vpx_subpixel_8t_intrin_ssse3.c" }, .flags = common_flags ++ .{"-mssse3"} },
    .{ .file = .{ .path = "vpx_dsp/x86/loopfilter_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    // .{ .file = .{ .path = "vpx_dsp/x86/loopfilter_avx2.c" }, .flags = common_flags ++ .{"-mavx2"} },
    .{ .file = .{ .path = "vpx_dsp/x86/inv_txfm_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    // .{ .file = .{ .path = "vpx_dsp/x86/inv_txfm_avx2.c" }, .flags = common_flags ++ .{"-mavx2"} },
    .{ .file = .{ .path = "vpx_dsp/x86/inv_txfm_ssse3.c" }, .flags = common_flags ++ .{"-mssse3"} },
    .{ .file = .{ .path = "vpx_dsp/x86/quantize_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    .{ .file = .{ .path = "vpx_dsp/x86/quantize_ssse3.c" }, .flags = common_flags ++ .{"-mssse3"} },
    .{ .file = .{ .path = "vpx_dsp/x86/quantize_avx.c" }, .flags = common_flags ++ .{"-mavx"} },
    // .{ .file = .{ .path = "vpx_dsp/x86/quantize_avx2.c" }, .flags = common_flags ++ .{"-mavx2"} },
    .{ .file = .{ .path = "vpx_dsp/x86/sum_squares_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    // .{ .file = .{ .path = "vpx_dsp/x86/sad4d_avx2.c" }, .flags = common_flags ++ .{"-mavx2"} },
    // .{ .file = .{ .path = "vpx_dsp/x86/sad_avx2.c" }, .flags = common_flags ++ .{"-mavx2"} },
    // .{ .file = .{ .path = "vpx_dsp/x86/subtract_avx2.c" }, .flags = common_flags ++ .{"-mavx2"} },
    // .{ .file = .{ .path = "vpx_dsp/x86/sad4d_avx512.c" }, .flags = common_flags ++ .{ "-mavx512f", "-mavx512cd", "-mavx512bw", "-mavx512dq", "-mavx512vl" } },
    .{ .file = .{ .path = "vpx_dsp/x86/variance_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    // .{ .file = .{ .path = "vpx_dsp/x86/variance_avx2.c" }, .flags = common_flags ++ .{"-mavx2"} },
    .{ .file = .{ .path = "vpx_util/vpx_thread.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vpx_util/vpx_write_yuv_frame.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/alloccommon.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/blockd.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/dequantize.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/entropy.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/entropymode.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/entropymv.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/extend.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/filter.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/findnearmv.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/generic/systemdependent.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/idct_blk.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/idctllm.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/rtcd.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/vp8_loopfilter.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/loopfilter_filters.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/mbpitch.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/modecont.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/quant_common.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/reconinter.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/reconintra.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/reconintra4x4.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/setupintrarecon.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/swapyv12buffer.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/treecoder.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/x86/vp8_asm_stubs.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/x86/loopfilter_x86.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/mfqe.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/postproc.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/x86/idct_blk_mmx.c" }, .flags = common_flags ++ .{"-mmmx"} },
    .{ .file = .{ .path = "vp8/common/x86/idct_blk_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    .{ .file = .{ .path = "vp8/common/x86/bilinear_filter_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    .{ .file = .{ .path = "vp8/vp8_cx_iface.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/bitstream.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/boolhuff.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/copy_c.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/dct.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/encodeframe.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/encodeintra.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/encodemb.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/encodemv.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/ethreading.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/firstpass.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/denoising.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/lookahead.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/mcomp.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/modecosts.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/onyx_if.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/pickinter.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/picklpf.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/vp8_quantize.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/ratectrl.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/rdopt.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/segmentation.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/common/vp8_skin_detection.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/tokenize.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/treewriter.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/temporal_filter.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/encoder/x86/vp8_quantize_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    .{ .file = .{ .path = "vp8/encoder/x86/vp8_quantize_ssse3.c" }, .flags = common_flags ++ .{"-mssse3"} },
    .{ .file = .{ .path = "vp8/encoder/x86/quantize_sse4.c" }, .flags = common_flags ++ .{"-msse4.1"} },
    .{ .file = .{ .path = "vp8/encoder/x86/denoising_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    .{ .file = .{ .path = "vp8/encoder/x86/vp8_enc_stubs_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    .{ .file = .{ .path = "vp8/vp8_dx_iface.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/decoder/dboolhuff.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/decoder/decodemv.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/decoder/decodeframe.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/decoder/detokenize.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/decoder/onyxd_if.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp8/decoder/threading.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/vp9_iface_common.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_alloccommon.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_blockd.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_entropy.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_entropymode.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_entropymv.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_frame_buffers.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_idct.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_filter.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_pred_common.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_rtcd.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_scale.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_seg_common.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_tile_common.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_loopfilter.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_thread_common.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_mvref_common.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_quant_common.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_reconinter.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_reconintra.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_common_data.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/vp9_scan.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/common/x86/vp9_idct_intrin_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    .{ .file = .{ .path = "vp9/vp9_cx_iface.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_bitstream.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_context_tree.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_cost.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_dct.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_encodeframe.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_encodemb.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_encodemv.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_ethread.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_extend.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_firstpass.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_frame_scale.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_lookahead.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_multi_thread.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_mcomp.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_encoder.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_picklpf.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_quantize.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_ratectrl.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_rd.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_rdopt.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_pickmode.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_segmentation.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_speed_features.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_subexp.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_svc_layercontext.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_resize.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_tokenize.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_treewriter.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_aq_variance.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_aq_360.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_aq_cyclicrefresh.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_aq_complexity.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_alt_ref_aq.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_skin_detection.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_noise_estimate.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_ext_ratectrl.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_temporal_filter.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_tpl_model.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/vp9_mbgraph.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/encoder/x86/temporal_filter_sse4.c" }, .flags = common_flags ++ .{"-msse4.1"} },
    .{ .file = .{ .path = "vp9/encoder/x86/vp9_quantize_sse2.c" }, .flags = common_flags ++ .{"-msse"} },
    .{ .file = .{ .path = "vp9/encoder/x86/vp9_quantize_ssse3.c" }, .flags = common_flags ++ .{"-mssse3"} },
    // .{ .file = .{ .path = "vp9/encoder/x86/vp9_quantize_avx2.c" }, .flags = common_flags ++ .{"-mavx2"} },
    .{ .file = .{ .path = "vp9/encoder/x86/vp9_dct_intrin_sse2.c" }, .flags = common_flags ++ .{"-msse2"} },
    .{ .file = .{ .path = "vp9/encoder/x86/vp9_frame_scale_ssse3.c" }, .flags = common_flags ++ .{"-mssse3"} },
    // .{ .file = .{ .path = "vp9/encoder/x86/vp9_error_avx2.c" }, .flags = common_flags ++ .{"-mavx2"} },
    .{ .file = .{ .path = "vp9/vp9_dx_iface.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/decoder/vp9_decodemv.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/decoder/vp9_decodeframe.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/decoder/vp9_detokenize.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/decoder/vp9_decoder.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/decoder/vp9_dsubexp.c" }, .flags = common_flags },
    .{ .file = .{ .path = "vp9/decoder/vp9_job_queue.c" }, .flags = common_flags },
    // .{ .file = .{ .path = "vpx_config.c" }, .flags = common_flags },
};

const x86_asm: StrSlice = &.{
    "vpx_ports/emms_mmx.asm",
    "vpx_dsp/x86/intrapred_sse2.asm",
    "vpx_dsp/x86/intrapred_ssse3.asm",
    "vpx_dsp/x86/add_noise_sse2.asm",
    "vpx_dsp/x86/deblock_sse2.asm",
    "vpx_dsp/x86/vpx_subpixel_8t_sse2.asm",
    "vpx_dsp/x86/vpx_subpixel_bilinear_sse2.asm",
    "vpx_dsp/x86/vpx_subpixel_8t_ssse3.asm",
    "vpx_dsp/x86/vpx_subpixel_bilinear_ssse3.asm",
    "vpx_dsp/x86/vpx_convolve_copy_sse2.asm",
    "vpx_dsp/x86/fwd_txfm_ssse3_x86_64.asm",
    "vpx_dsp/x86/inv_wht_sse2.asm",
    "vpx_dsp/x86/avg_ssse3_x86_64.asm",
    "vpx_dsp/x86/sad4d_sse2.asm",
    "vpx_dsp/x86/sad_sse2.asm",
    "vpx_dsp/x86/subtract_sse2.asm",
    "vpx_dsp/x86/ssim_opt_x86_64.asm",
    "vpx_dsp/x86/subpel_variance_sse2.asm",
    "vp8/common/x86/dequantize_mmx.asm",
    "vp8/common/x86/idctllm_mmx.asm",
    "vp8/common/x86/recon_mmx.asm",
    "vp8/common/x86/subpixel_mmx.asm",
    "vp8/common/x86/idctllm_sse2.asm",
    "vp8/common/x86/recon_sse2.asm",
    "vp8/common/x86/subpixel_sse2.asm",
    "vp8/common/x86/loopfilter_sse2.asm",
    "vp8/common/x86/iwalsh_sse2.asm",
    "vp8/common/x86/subpixel_ssse3.asm",
    "vp8/common/x86/mfqe_sse2.asm",
    "vp8/common/x86/loopfilter_block_sse2_x86_64.asm",
    "vp8/encoder/x86/copy_sse2.asm",
    "vp8/encoder/x86/copy_sse3.asm",
    "vp8/encoder/x86/dct_sse2.asm",
    "vp8/encoder/x86/fwalsh_sse2.asm",
    "vp8/encoder/x86/block_error_sse2.asm",
    "vp8/encoder/x86/temporal_filter_apply_sse2.asm",
    "vp9/encoder/x86/vp9_dct_sse2.asm",
    "vp9/encoder/x86/vp9_error_sse2.asm",
};

fn writeConfig(b: *std.Build, target: std.zig.CrossTarget) !struct { *std.Build.Step.WriteFile, *std.Build.Step.ConfigHeader } {
    const cpu = target.getCpu();
    const arch = target.getCpuArch();
    var data = std.ArrayList(u8).init(b.allocator);
    defer data.deinit();
    const values = .{
        .VPX_ARCH_ARM = arch.isArmOrThumb(),
        .VPX_ARCH_AARCH64 = arch.isAARCH64(),
        .VPX_ARCH_MIPS = arch.isMIPS(),
        .VPX_ARCH_X86 = arch == .x86,
        .VPX_ARCH_X86_64 = arch == .x86_64,
        .VPX_ARCH_PPC = arch.isPPC() or arch.isPPC64(),
        .VPX_ARCH_LOONGARCH = arch == .loongarch32 or arch == .loongarch64,
        .HAVE_NEON_ASM = have_arm_feat(cpu, .neon) or have_aarch64_feat(cpu, .neon),
        .HAVE_NEON = have_arm_feat(cpu, .neon) or have_aarch64_feat(cpu, .neon),
        .HAVE_NEON_DOTPROD = have_arm_feat(cpu, .dotprod) or have_aarch64_feat(cpu, .dotprod),
        .HAVE_NEON_I8MM = have_arm_feat(cpu, .i8mm) or have_aarch64_feat(cpu, .i8mm),
        .HAVE_SVE = have_aarch64_feat(cpu, std.Target.aarch64.Feature.sve), // TODO this
        .HAVE_MIPS32 = have_mips_feat(cpu, .mips32) and !have_mips_feat(target.getCpu(), .mips64),
        .HAVE_DSPR2 = have_mips_feat(cpu, .dspr2),
        .HAVE_MSA = have_mips_feat(cpu, .msa),
        .HAVE_MIPS64 = have_mips_feat(cpu, .mips64),
        .HAVE_MMX = have_x86_feat(cpu, .mmx),
        .HAVE_SSE = have_x86_feat(cpu, .sse),
        .HAVE_SSE2 = have_x86_feat(cpu, .sse2),
        .HAVE_SSE3 = have_x86_feat(cpu, .sse3),
        .HAVE_SSSE3 = have_x86_feat(cpu, .ssse3),
        .HAVE_SSE4_1 = have_x86_feat(cpu, .sse4_1),
        .HAVE_AVX = have_x86_feat(cpu, .avx),
        .HAVE_AVX2 = have_x86_feat(cpu, .avx2),
        .HAVE_AVX512 = have_x86_feat(cpu, .avx512f),
        .HAVE_VSX = have_ppc_feat(cpu, .vsx),
        .HAVE_MMI = false,
        .HAVE_LSX = have_loong_feat(cpu, .lsx),
        .HAVE_LASX = have_loong_feat(cpu, .lasx),
        .HAVE_VPX_PORTS = true,
        .HAVE_PTHREAD_H = true,
        .HAVE_UNISTD_H = true,
        .CONFIG_DEPENDENCY_TRACKING = true,
        .CONFIG_EXTERNAL_BUILD = false,
        .CONFIG_INSTALL_DOCS = false,
        .CONFIG_INSTALL_BINS = true,
        .CONFIG_INSTALL_LIBS = true,
        .CONFIG_INSTALL_SRCS = false,
        .CONFIG_DEBUG = false,
        .CONFIG_GPROF = false,
        .CONFIG_GCOV = false,
        .CONFIG_RVCT = false,
        .CONFIG_GCC = true,
        .CONFIG_MSVS = false,
        .CONFIG_PIC = false,
        .CONFIG_BIG_ENDIAN = false,
        .CONFIG_CODEC_SRCS = false,
        .CONFIG_DEBUG_LIBS = false,
        .CONFIG_DEQUANT_TOKENS = false,
        .CONFIG_DC_RECON = false,
        .CONFIG_RUNTIME_CPU_DETECT = true,
        .CONFIG_POSTPROC = true,
        .CONFIG_VP9_POSTPROC = false,
        .CONFIG_MULTITHREAD = true,
        .CONFIG_INTERNAL_STATS = false,
        .CONFIG_VP8_ENCODER = true,
        .CONFIG_VP8_DECODER = true,
        .CONFIG_VP9_ENCODER = true,
        .CONFIG_VP9_DECODER = true,
        .CONFIG_VP8 = true,
        .CONFIG_VP9 = true,
        .CONFIG_ENCODERS = true,
        .CONFIG_DECODERS = true,
        .CONFIG_STATIC_MSVCRT = false,
        .CONFIG_SPATIAL_RESAMPLING = true,
        .CONFIG_REALTIME_ONLY = false,
        .CONFIG_ONTHEFLY_BITPACKING = false,
        .CONFIG_ERROR_CONCEALMENT = false,
        .CONFIG_SHARED = false,
        .CONFIG_STATIC = true,
        .CONFIG_SMALL = false,
        .CONFIG_POSTPROC_VISUALIZER = false,
        .CONFIG_OS_SUPPORT = true,
        .CONFIG_UNIT_TESTS = true,
        .CONFIG_WEBM_IO = true,
        .CONFIG_LIBYUV = true,
        .CONFIG_DECODE_PERF_TESTS = false,
        .CONFIG_ENCODE_PERF_TESTS = false,
        .CONFIG_MULTI_RES_ENCODING = false,
        .CONFIG_TEMPORAL_DENOISING = true,
        .CONFIG_VP9_TEMPORAL_DENOISING = false,
        .CONFIG_COEFFICIENT_RANGE_CHECKING = false,
        .CONFIG_VP9_HIGHBITDEPTH = false,
        .CONFIG_BETTER_HW_COMPATIBILITY = false,
        .CONFIG_EXPERIMENTAL = false,
        .CONFIG_SIZE_LIMIT = false,
        .CONFIG_ALWAYS_ADJUST_BPM = false,
        .CONFIG_BITSTREAM_DEBUG = false,
        .CONFIG_MISMATCH_DEBUG = false,
        .CONFIG_FP_MB_STATS = false,
        .CONFIG_EMULATE_HARDWARE = false,
        .CONFIG_NON_GREEDY_MV = false,
        .CONFIG_RATE_CTRL = false,
        .CONFIG_COLLECT_COMPONENT_TIMING = false,
    };

    inline for (@typeInfo(@TypeOf(values)).Struct.fields) |field| {
        try data.appendSlice(field.name);
        try data.appendSlice(if (@field(values, field.name)) " equ 1\n" else " equ 0\n");
    }
    const header = b.addConfigHeader(.{ .include_path = "vpx_config.h" }, values);
    header.addValues(.{ .RESTRICT = 1, .INLINE = .@"inline" });
    return .{
        b.addWriteFile("vpx_config.asm", try data.toOwnedSlice()),
        header,
    };
}

fn have_x86_feat(cpu: std.Target.Cpu, feat: std.Target.x86.Feature) bool {
    return switch (cpu.arch) {
        .x86, .x86_64 => std.Target.x86.featureSetHas(cpu.features, feat),
        else => false,
    };
}

fn have_arm_feat(cpu: std.Target.Cpu, feat: std.Target.arm.Feature) bool {
    return switch (cpu.arch) {
        .arm, .armeb => std.Target.arm.featureSetHas(cpu.features, feat),
        else => false,
    };
}

fn have_aarch64_feat(cpu: std.Target.Cpu, feat: std.Target.aarch64.Feature) bool {
    return switch (cpu.arch) {
        .aarch64,
        .aarch64_be,
        .aarch64_32,
        => std.Target.aarch64.featureSetHas(cpu.features, feat),

        else => false,
    };
}

fn have_ppc_feat(cpu: std.Target.Cpu, feat: std.Target.powerpc.Feature) bool {
    return switch (cpu.arch) {
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        => std.Target.powerpc.featureSetHas(cpu.features, feat),

        else => false,
    };
}

fn have_mips_feat(cpu: std.Target.Cpu, feat: std.Target.mips.Feature) bool {
    return switch (cpu.arch) {
        .mips,
        .mipsel,
        .mips64,
        .mips64el,
        => std.Target.mips.featureSetHas(cpu.features, feat),

        else => false,
    };
}

fn have_loong_feat(cpu: std.Target.Cpu, feat: std.Target.loongarch.Feature) bool {
    return switch (cpu.arch) {
        .loongarch32, .loongarch64 => std.Target.loongarch.featureSetHas(cpu.features, feat),
        else => false,
    };
}
