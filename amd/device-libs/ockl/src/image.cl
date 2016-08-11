/*===--------------------------------------------------------------------------
 *                   ROCm Device Libraries
 *
 * This file is distributed under the University of Illinois Open Source
 * License. See LICENSE.TXT for details.
 *===------------------------------------------------------------------------*/

#include "irif.h"
#include "ockl.h"

#pragma OPENCL EXTENSION cl_khr_fp16 : enable

#define RATTR __attribute__((always_inline, pure))
#define WATTR __attribute__((always_inline))
#define GATTR __attribute__((always_inline, const))

// TSHARP/SSHARP access
#define FIELD(P,B,W) ((P[B >> 5] >> (B & 0x1f)) & ((1 << W) - 1))
#define WORD(P,I) P[I]
#define LOAD_TSHARP(I) *(__constant uint8 *)I
#define LOAD_VSHARP(I) *(__constant uint4 *)I

#if 0
RATTR float4
OCKL_MANGLE_T(image_load,1D)(TSHARP i, int c)
{
    return __llvm_amdgcn_image_load_v4f32_i32(c, LOAD_TSHARP(i), 0xf, false, false, false, false);
}

RATTR float4
OCKL_MANGLE_T(image_load,1Da)(TSHARP i, int2 c)
{
    return __llvm_amdgcn_image_load_v4f32_v2i32(c, LOAD_TSHARP(i), 0xf, false, false, false, true);
}

RATTR float4
OCKL_MANGLE_T(image_load,1Db)(TSHARP i, int c)
{
    return __llvm_amdgcn_buffer_load_format_v4f32(LOAD_VSHARP(i), c, 0, false, false);
}

RATTR float4
OCKL_MANGLE_T(image_load,2D)(TSHARP i, int2 c)
{
    return __llvm_amdgcn_image_load_v4f32_v2i32(c, LOAD_TSHARP(i), 0xf, false, false, false, false);
}

RATTR float4
OCKL_MANGLE_T(image_load,2Da)(TSHARP i, int4 c)
{
    return __llvm_amdgcn_image_load_v4f32_v4i32(c, LOAD_TSHARP(i), 0xf, false, false, false, true);
}

RATTR float
OCKL_MANGLE_T(image_load,2Dad)(TSHARP i, int4 c)
{
    return __llvm_amdgcn_image_load_f32_v4i32(c, LOAD_TSHARP(i), 0x1, false, false, false, true);
}

RATTR float
OCKL_MANGLE_T(image_load,2Dd)(TSHARP i, int2 c)
{
    return __llvm_amdgcn_image_load_f32_v2i32(c, LOAD_TSHARP(i), 0x1, false, false, false, false);
}

RATTR float4
OCKL_MANGLE_T(image_load,3D)(TSHARP i, int4 c)
{
    return __llvm_amdgcn_image_load_v4f32_v4i32(c, LOAD_TSHARP(i), 0xf, false, false, false, false);
}

RATTR float4
OCKL_MANGLE_T(image_load_lod,1D)(TSHARP i, int c, int l)
{
    return __llvm_amdgcn_image_load_mip_v4f32_v2i32((int2)(c, l), LOAD_TSHARP(i), 0xf, false, false, false, false);
}

RATTR float4
OCKL_MANGLE_T(image_load_lod,1Da)(TSHARP i, int2 c, int l)
{
    return __llvm_amdgcn_image_load_mip_v4f32_v4i32((int4)(c, l, 0), LOAD_TSHARP(i), 0xf, false, false, false, true);
}

RATTR float4
OCKL_MANGLE_T(image_load_lod,2D)(TSHARP i, int2 c, int l)
{
    return __llvm_amdgcn_image_load_mip_v4f32_v4i32((int4)(c, l, 0), LOAD_TSHARP(i), 0xf, false, false, false, false);
}

RATTR float4
OCKL_MANGLE_T(image_load_lod,2Da)(TSHARP i, int4 c, int l)
{
    return __llvm_amdgcn_image_load_mip_v4f32_v4i32((int4)(c.x, c.y, c.z, l), LOAD_TSHARP(i), 0xf, false, false, false, true);
}

RATTR float
OCKL_MANGLE_T(image_load_lod,2Dad)(TSHARP i, int4 c, int l)
{
    return __llvm_amdgcn_image_load_mip_f32_v4i32((int4)(c.x, c.y, c.z, l), LOAD_TSHARP(i), 0x1, false, false, false, true);
}

RATTR float
OCKL_MANGLE_T(image_load_lod,2Dd)(TSHARP i, int2 c, int l)
{
    return __llvm_amdgcn_image_load_mip_f32_v4i32((int4)(c, l, 0), LOAD_TSHARP(i), 0x1, false, false, false, false);
}

RATTR float4
OCKL_MANGLE_T(image_load_lod,3D)(TSHARP i, int4 c, int l)
{
    return __llvm_amdgcn_image_load_mip_v4f32_v4i32((int4)(c.x, c.y, c.z, l), LOAD_TSHARP(i), 0xf, false, false, false, false);
}

RATTR half4
OCKL_MANGLE_T(image_loadh,1D)(TSHARP i, int c)
{
    return __llvm_amdgcn_image_load_v4f16_i32(c, LOAD_TSHARP(i), 0xf, false, false, false, false);
}

RATTR half4
OCKL_MANGLE_T(image_loadh,1Da)(TSHARP i, int2 c)
{
    return __llvm_amdgcn_image_load_v4f16_v2i32(c, LOAD_TSHARP(i), 0xf, false, false, false, true);
}

RATTR half4
OCKL_MANGLE_T(image_loadh,1Db)(TSHARP i, int c)
{
    return __llvm_amdgcn_buffer_load_format_v4f16(LOAD_VSHARP(i), c, 0, false, false);
}

RATTR half4
OCKL_MANGLE_T(image_loadh,2D)(TSHARP i, int2 c)
{
    return __llvm_amdgcn_image_load_v4f16_v2i32(c, LOAD_TSHARP(i), 0xf, false, false, false, false);
}

RATTR half4
OCKL_MANGLE_T(image_loadh,2Da)(TSHARP i, int4 c)
{
    return __llvm_amdgcn_image_load_v4f16_v4i32(c, LOAD_TSHARP(i), 0xf, false, false, false, true);
}

RATTR half4
OCKL_MANGLE_T(image_loadh,3D)(TSHARP i, int4 c)
{
    return __llvm_amdgcn_image_load_v4f16_v4i32(c, LOAD_TSHARP(i), 0xf, false, false, false, false);
}

RATTR half4
OCKL_MANGLE_T(image_loadh_lod,1D)(TSHARP i, int c, int l)
{
    return __llvm_amdgcn_image_load_mip_v4f16_v2i32((int2)(c, l), LOAD_TSHARP(i), 0xf, false, false, false, false);
}

RATTR half4
OCKL_MANGLE_T(image_loadh_lod,1Da)(TSHARP i, int2 c, int l)
{
    return __llvm_amdgcn_image_load_mip_v4f16_v4i32((int4)(c, l, 0), LOAD_TSHARP(i), 0xf, false, false, false, true);
}

RATTR half4
OCKL_MANGLE_T(image_loadh_lod,2D)(TSHARP i, int2 c, int l)
{
    return __llvm_amdgcn_image_load_mip_v4f16_v4i32((int4)(c, l, 0), LOAD_TSHARP(i), 0xf, false, false, false, false);
}

RATTR half4
OCKL_MANGLE_T(image_loadh_lod,2Da)(TSHARP i, int4 c, int l)
{
    return __llvm_amdgcn_image_load_mip_v4f16_v4i32((int4)(c.x, c.y, c.z, l), LOAD_TSHARP(i), 0xf, false, false, false, true);
}

RATTR half4
OCKL_MANGLE_T(image_loadh_lod,3D)(TSHARP i, int4 c, int l)
{
    return __llvm_amdgcn_image_load_mip_v4f16_v4i32((int4)(c.x, c.y, c.z, l), LOAD_TSHARP(i), 0xf, false, false, false, false);
}


WATTR void
OCKL_MANGLE_T(image_store,1D)(TSHARP i, int c, float4 p)
{
    __llvm_amdgcn_image_store_v4f32_i32(p, c, LOAD_TSHARP(i), 0xf, false, false, false, false);
}

WATTR void
OCKL_MANGLE_T(image_store,1Da)(TSHARP i, int2 c, float4 p)
{
    __llvm_amdgcn_image_store_v4f32_v2i32(p, c, LOAD_TSHARP(i), 0xf, false, false, false, true);
}

WATTR void
OCKL_MANGLE_T(image_store,1Db)(TSHARP i, int c, float4 p)
{
    __llvm_amdgcn_buffer_store_format_v4f32(p, LOAD_VSHARP(i), c, 0, false, false);
}

WATTR void
OCKL_MANGLE_T(image_store,2D)(TSHARP i, int2 c, float4 p)
{
    __llvm_amdgcn_image_store_v4f32_v2i32(p, c, LOAD_TSHARP(i), 0xf, false, false, false, false);
}

WATTR void
OCKL_MANGLE_T(image_store,2Da)(TSHARP i, int4 c, float4 p)
{
    __llvm_amdgcn_image_store_v4f32_v4i32(p, c, LOAD_TSHARP(i), 0xf, false, false, false, true);
}

WATTR void
OCKL_MANGLE_T(image_store,2Dad)(TSHARP i, int4 c, float p)
{
    __llvm_amdgcn_image_store_f32_v4i32(p, c, LOAD_TSHARP(i), 0x1, false, false, false, true);
}

WATTR void
OCKL_MANGLE_T(image_store,2Dd)(TSHARP i, int2 c, float p)
{
    __llvm_amdgcn_image_store_f32_v2i32(p, c, LOAD_TSHARP(i), 0x1, false, false, false, false);
}

WATTR void
OCKL_MANGLE_T(image_store,3D)(TSHARP i, int4 c, float4 p)
{
    __llvm_amdgcn_image_store_v4f32_v4i32(p, c, LOAD_TSHARP(i), 0xf, false, false, false, false);
}

WATTR void
OCKL_MANGLE_T(image_store_lod,1D)(TSHARP i, int c, int l, float4 p)
{
    __llvm_amdgcn_image_store_mip_v4f32_v2i32(p, (int2)(c, l), LOAD_TSHARP(i), 0xf, false, false, false, false);
}

WATTR void
OCKL_MANGLE_T(image_store_lod,1Da)(TSHARP i, int2 c, int l, float4 p)
{
    __llvm_amdgcn_image_store_mip_v4f32_v4i32(p, (int4)(c, l, 0), LOAD_TSHARP(i), 0xf, false, false, false, true);
}

WATTR void
OCKL_MANGLE_T(image_store_lod,2D)(TSHARP i, int2 c, int l, float4 p)
{
    __llvm_amdgcn_image_store_mip_v4f32_v4i32(p, (int4)(c, l, 0), LOAD_TSHARP(i), 0xf, false, false, false, false);
}

WATTR void
OCKL_MANGLE_T(image_store_lod,2Da)(TSHARP i, int4 c, int l, float4 p)
{
    __llvm_amdgcn_image_store_mip_v4f32_v4i32(p, (int4)(c.x, c.y, c.z, l), LOAD_TSHARP(i), 0xf, false, false, false, true);
}

WATTR void
OCKL_MANGLE_T(image_store_lod,2Dad)(TSHARP i, int4 c, int l, float p)
{
    __llvm_amdgcn_image_store_mip_f32_v4i32(p, (int4)(c.x, c.y, c.z, l), LOAD_TSHARP(i), 0x1, false, false, false, true);
}

WATTR void
OCKL_MANGLE_T(image_store_lod,2Dd)(TSHARP i, int2 c, int l, float p)
{
    __llvm_amdgcn_image_store_mip_f32_v4i32(p, (int4)(c, l, 0), LOAD_TSHARP(i), 0x1, false, false, false, false);
}

WATTR void
OCKL_MANGLE_T(image_store_lod,3D)(TSHARP i, int4 c, int l, float4 p)
{
    __llvm_amdgcn_image_store_mip_v4f32_v4i32(p, (int4)(c.x, c.y, c.z, l), LOAD_TSHARP(i), 0xf, false, false, false, false);
}

WATTR void
OCKL_MANGLE_T(image_storeh,1D)(TSHARP i, int c, half4 p)
{
    __llvm_amdgcn_image_store_v4f16_i32(p, c, LOAD_TSHARP(i), 0xf, false, false, false, false);
}

WATTR void
OCKL_MANGLE_T(image_storeh,1Da)(TSHARP i, int2 c, half4 p)
{
    __llvm_amdgcn_image_store_v4f16_v2i32(p, c, LOAD_TSHARP(i), 0xf, false, false, false, true);
}

WATTR void
OCKL_MANGLE_T(image_storeh,1Db)(TSHARP i, int c, half4 p)
{
    __llvm_amdgcn_buffer_store_format_v4f16(p, LOAD_VSHARP(i), c, 0, false, false);
}

WATTR void
OCKL_MANGLE_T(image_storeh,2D)(TSHARP i, int2 c, half4 p)
{
    __llvm_amdgcn_image_store_v4f16_v2i32(p, c, LOAD_TSHARP(i), 0xf, false, false, false, false);
}

WATTR void
OCKL_MANGLE_T(image_storeh,2Da)(TSHARP i, int4 c, half4 p)
{
    __llvm_amdgcn_image_store_v4f16_v4i32(p, c, LOAD_TSHARP(i), 0xf, false, false, false, true);
}

WATTR void
OCKL_MANGLE_T(image_storeh,3D)(TSHARP i, int4 c, half4 p)
{
    __llvm_amdgcn_image_store_v4f16_v4i32(p, c, LOAD_TSHARP(i), 0xf, false, false, false, false);
}

WATTR void
OCKL_MANGLE_T(image_storeh_lod,1D)(TSHARP i, int c, int l, half4 p)
{
    __llvm_amdgcn_image_store_mip_v4f16_v2i32(p, (int2)(c, l), LOAD_TSHARP(i), 0xf, false, false, false, false);
}

WATTR void
OCKL_MANGLE_T(image_storeh_lod,1Da)(TSHARP i, int2 c, int l, half4 p)
{
    __llvm_amdgcn_image_store_mip_v4f16_v4i32(p, (int4)(c, l, 0), LOAD_TSHARP(i), 0xf, false, false, false, true);
}

WATTR void
OCKL_MANGLE_T(image_storeh_lod,2D)(TSHARP i, int2 c, int l, half4 p)
{
    __llvm_amdgcn_image_store_mip_v4f16_v4i32(p, (int4)(c, l, 0), LOAD_TSHARP(i), 0xf, false, false, false, false);
}

WATTR void
OCKL_MANGLE_T(image_storeh_lod,2Da)(TSHARP i, int4 c, int l, half4 p)
{
    __llvm_amdgcn_image_store_mip_v4f16_v4i32(p, (int4)(c.x, c.y, c.z, l), LOAD_TSHARP(i), 0xf, false, false, false, true);
}

WATTR void
OCKL_MANGLE_T(image_storeh_lod,3D)(TSHARP i, int4 c, int l, half4 p)
{
    __llvm_amdgcn_image_store_mip_v4f16_v4i32(p, (int4)(c.x, c.y, c.z, l), LOAD_TSHARP(i), 0xf, false, false, false, false);
}
#endif

#if 0
RATTR float4 OCKL_MANGLE_T(image_sample,1D)(TSHARP i, SSHARP s, float c);
RATTR float4 OCKL_MANGLE_T(image_sample,1Da)(TSHARP i, SSHARP s, float2 c);
RATTR float4 OCKL_MANGLE_T(image_sample,2D)(TSHARP i, SSHARP s, float2 c);
RATTR float4 OCKL_MANGLE_T(image_sample,2Da)(TSHARP i, SSHARP s, float4 c);
RATTR float OCKL_MANGLE_T(image_sample,2Dad)(TSHARP i, SSHARP s, float4 c);
RATTR float OCKL_MANGLE_T(image_sample,2Dd)(TSHARP i, SSHARP s, float2 c);
RATTR float4 OCKL_MANGLE_T(image_sample,3D)(TSHARP i, SSHARP s, float4 c);
RATTR float4 OCKL_MANGLE_T(image_sample_grad,1D)(TSHARP i, SSHARP s, float c, float dx, float dy);
RATTR float4 OCKL_MANGLE_T(image_sample_grad,1Da)(TSHARP i, SSHARP s, float2 c, float dx, float dy);
RATTR float4 OCKL_MANGLE_T(image_sample_grad,2D)(TSHARP i, SSHARP s, float2 c, float2 dx, float2 dy);
RATTR float4 OCKL_MANGLE_T(image_sample_grad,2Da)(TSHARP i, SSHARP s, float4 c, float2 dx, float2 dy);
RATTR float OCKL_MANGLE_T(image_sample_grad,2Dad)(TSHARP i, SSHARP s, float4 c, float2 dx, float2 dy);
RATTR float OCKL_MANGLE_T(image_sample_grad,2Dd)(TSHARP i, SSHARP s, float2 c, float2 dx, float2 dy);
RATTR float4 OCKL_MANGLE_T(image_sample_grad,3D)(TSHARP i, SSHARP s, float4 c, float4 dx, float4 dy);
RATTR float4 OCKL_MANGLE_T(image_sample_lod,1D)(TSHARP i, SSHARP s, float c, float l);
RATTR float4 OCKL_MANGLE_T(image_sample_lod,1Da)(TSHARP i, SSHARP s, float2 c, float l);
RATTR float4 OCKL_MANGLE_T(image_sample_lod,2D)(TSHARP i, SSHARP s, float2 c, float l);
RATTR float4 OCKL_MANGLE_T(image_sample_lod,2Da)(TSHARP i, SSHARP s, float4 c, float l);
RATTR float OCKL_MANGLE_T(image_sample_lod,2Dad)(TSHARP i, SSHARP s, float4 c, float l);
RATTR float OCKL_MANGLE_T(image_sample_lod,2Dd)(TSHARP i, SSHARP s, float2 c, float l);
RATTR float4 OCKL_MANGLE_T(image_sample_lod,3D)(TSHARP i, SSHARP s, float4 c, float l);
RATTR half4 OCKL_MANGLE_T(image_sampleh,1D)(TSHARP i, SSHARP s, float c);
RATTR half4 OCKL_MANGLE_T(image_sampleh,1Da)(TSHARP i, SSHARP s, float2 c);
RATTR half4 OCKL_MANGLE_T(image_sampleh,2D)(TSHARP i, SSHARP s, float2 c);
RATTR half4 OCKL_MANGLE_T(image_sampleh,2Da)(TSHARP i, SSHARP s, float4 c);
RATTR half4 OCKL_MANGLE_T(image_sampleh,3D)(TSHARP i, SSHARP s, float4 c);
RATTR half4 OCKL_MANGLE_T(image_sampleh_grad,1D)(TSHARP i, SSHARP s, float c, float dx, float dy);
RATTR half4 OCKL_MANGLE_T(image_sampleh_grad,1Da)(TSHARP i, SSHARP s, float2 c, float dx, float dy);
RATTR half4 OCKL_MANGLE_T(image_sampleh_grad,2D)(TSHARP i, SSHARP s, float2 c, float2 dx, float2 dy);
RATTR half4 OCKL_MANGLE_T(image_sampleh_grad,2Da)(TSHARP i, SSHARP s, float4 c, float2 dx, float2 dy);
RATTR half4 OCKL_MANGLE_T(image_sampleh_grad,3D)(TSHARP i, SSHARP s, float4 c, float4 dx, float4 dy);
RATTR half4 OCKL_MANGLE_T(image_sampleh_lod,1D)(TSHARP i, SSHARP s, float c, float l);
RATTR half4 OCKL_MANGLE_T(image_sampleh_lod,1Da)(TSHARP i, SSHARP s, float2 c, float l);
RATTR half4 OCKL_MANGLE_T(image_sampleh_lod,2D)(TSHARP i, SSHARP s, float2 c, float l);
RATTR half4 OCKL_MANGLE_T(image_sampleh_lod,2Da)(TSHARP i, SSHARP s, float4 c, float l);
RATTR half4 OCKL_MANGLE_T(image_sampleh_lod,3D)(TSHARP i, SSHARP s, float4 c, float l);
#endif

// We rely on the fact that the runtime allocates 12 words for the T# or V#
// and fills words 8, 9, and 10 with the data we need to answer all of the queries
GATTR int OCKL_MANGLE_T(image_array_size,1Da)(TSHARP i)  { return FIELD(i, 173, 13); }
GATTR int OCKL_MANGLE_T(image_array_size,2Da)(TSHARP i)  { return FIELD(i, 173, 13); }
GATTR int OCKL_MANGLE_T(image_array_size,2Dad)(TSHARP i) { return FIELD(i, 173, 13); }

GATTR int OCKL_MANGLE_T(image_channel_data_type,1D)(TSHARP i)   { return WORD(i, 8); }
GATTR int OCKL_MANGLE_T(image_channel_data_type,1Da)(TSHARP i)  { return WORD(i, 8); }
GATTR int OCKL_MANGLE_T(image_channel_data_type,1Db)(TSHARP i)  { return WORD(i, 8); }
GATTR int OCKL_MANGLE_T(image_channel_data_type,2D)(TSHARP i)   { return WORD(i, 8); }
GATTR int OCKL_MANGLE_T(image_channel_data_type,2Da)(TSHARP i)  { return WORD(i, 8); }
GATTR int OCKL_MANGLE_T(image_channel_data_type,2Dad)(TSHARP i) { return WORD(i, 8); }
GATTR int OCKL_MANGLE_T(image_channel_data_type,2Dd)(TSHARP i)  { return WORD(i, 8); }
GATTR int OCKL_MANGLE_T(image_channel_data_type,3D)(TSHARP i)   { return WORD(i, 8); }

GATTR int OCKL_MANGLE_T(image_channel_order,1D)(TSHARP i)   { return WORD(i, 9); }
GATTR int OCKL_MANGLE_T(image_channel_order,1Da)(TSHARP i)  { return WORD(i, 9); }
GATTR int OCKL_MANGLE_T(image_channel_order,1Db)(TSHARP i)  { return WORD(i, 9); }
GATTR int OCKL_MANGLE_T(image_channel_order,2D)(TSHARP i)   { return WORD(i, 9); }
GATTR int OCKL_MANGLE_T(image_channel_order,2Da)(TSHARP i)  { return WORD(i, 9); }
GATTR int OCKL_MANGLE_T(image_channel_order,2Dad)(TSHARP i) { return WORD(i, 9); }
GATTR int OCKL_MANGLE_T(image_channel_order,2Dd)(TSHARP i)  { return WORD(i, 9); }
GATTR int OCKL_MANGLE_T(image_channel_order,3D)(TSHARP i)   { return WORD(i, 9); }

GATTR int OCKL_MANGLE_T(image_depth,3D)(TSHARP i) { return FIELD(i, 128, 13); }

GATTR int OCKL_MANGLE_T(image_height,2D)(TSHARP i)   { return FIELD(i, 78, 14); }
GATTR int OCKL_MANGLE_T(image_height,2Da)(TSHARP i)  { return FIELD(i, 78, 14); }
GATTR int OCKL_MANGLE_T(image_height,2Dad)(TSHARP i) { return FIELD(i, 78, 14); }
GATTR int OCKL_MANGLE_T(image_height,2Dd)(TSHARP i)  { return FIELD(i, 78, 14); }
GATTR int OCKL_MANGLE_T(image_height,3D)(TSHARP i)   { return FIELD(i, 78, 14); }

GATTR int OCKL_MANGLE_T(image_num_mip_levels,1D)(TSHARP i)   { return FIELD(i, 112, 4); }
GATTR int OCKL_MANGLE_T(image_num_mip_levels,1Da)(TSHARP i)  { return FIELD(i, 112, 4); }
GATTR int OCKL_MANGLE_T(image_num_mip_levels,2D)(TSHARP i)   { return FIELD(i, 112, 4); }
GATTR int OCKL_MANGLE_T(image_num_mip_levels,2Da)(TSHARP i)  { return FIELD(i, 112, 4); }
GATTR int OCKL_MANGLE_T(image_num_mip_levels,2Dad)(TSHARP i) { return FIELD(i, 112, 4); }
GATTR int OCKL_MANGLE_T(image_num_mip_levels,2Dd)(TSHARP i)  { return FIELD(i, 112, 4); }
GATTR int OCKL_MANGLE_T(image_num_mip_levels,3D)(TSHARP i)   { return FIELD(i, 112, 4); }

// In FIELD(i, 64, 14) but also copied into word 11 of the 12 that are allocated
GATTR int OCKL_MANGLE_T(image_width,1D)(TSHARP i)   { return WORD(i, 10); }
GATTR int OCKL_MANGLE_T(image_width,1Da)(TSHARP i)  { return WORD(i, 10); }
GATTR int OCKL_MANGLE_T(image_width,2D)(TSHARP i)   { return WORD(i, 10); }
GATTR int OCKL_MANGLE_T(image_width,2Da)(TSHARP i)  { return WORD(i, 10); }
GATTR int OCKL_MANGLE_T(image_width,2Dad)(TSHARP i) { return WORD(i, 10); }
GATTR int OCKL_MANGLE_T(image_width,2Dd)(TSHARP i)  { return WORD(i, 10); }
GATTR int OCKL_MANGLE_T(image_width,3D)(TSHARP i)   { return WORD(i, 10); }
// This would be a bit trickier since we actually have a V# here and need to look at const_num_records and const_stride
GATTR int OCKL_MANGLE_T(image_width,1Db)(TSHARP i)  { return WORD(i, 10); }
