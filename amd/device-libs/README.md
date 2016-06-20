## OVERVIEW

ROCm Device libraries are currently in early development and considered experimental and incomplete.

This repository contains the following libraries:

| **Name** | **Comments** | **Dependencies** |
| --- | --- | --- |
| llvm | Utility functions | |
| ocml | Open Compute Math library. | llvm |
| ockl | Open Compute Kernel library. | llvm |
| opencl | OpenCL built-in library | ocml, ockl |

All libraries are compiled to LLVM Bitcode which can be linked. Note that libraries use specific AMDGPU intrinsics.


## BUILDING

This project requires reasonably recent LLVM/Clang build (April 2016 trunk). Testing also requires amdhsacod utility from ROCm Runtime.

Use out-of-source CMake build and create separate directory to run CMake.

The following build steps are performed:

    mkdir -p build
    cd build
    export LLVM_BUILD=... (path to LLVM build)
    CC=$LLVM_BUILD/bin/clang cmake -DLLVM_DIR=$LLVM_BUILD -DAMDHSACOD=$HSA_DIR/bin/x86_64/amdhsacod ..
    make
    make install
    make test

## TESTING

Currently all tests are offline:
 * OpenCL source is compiled to LLVM bitcode
 * Test bitcode is linked to library bitcode with llvm-link
 * Clang OpenCL compiler is run on resulting bitcode, producing code object.
 * Resulting code object is passed to llvm-objdump and amdhsacod -test.

The output of tests (which includes AMDGPU disassembly) can be displayed by running ctest -VV in build directory.

Tests for OpenCL conformance kernels can be enabled by specifying -DOCL_CONFORMANCE_HOME=<path> to CMake, for example,
  cmake ... -DOCL_CONFORMANCE_HOME=/srv/hsa/drivers/opencl/tests/extra/hsa/ocl/conformance/1.2
