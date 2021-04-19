#!/bin/bash

# programs and flags
CUR=`pwd`
MINERFLAGS="-DBIN_KERN -DUSE_SYS_OPENCL -DBOOST_BIND_GLOBAL_PLACEHOLDERS -DETH_ETHASHCUDA -DETH_ETHASHCL" #  
CXX="/usr/bin/c++"
CXXFLAGS="-Wall -Wno-unknown-pragmas -Wextra -Wno-error=parentheses -pedantic -Ofast -fpic -std=c++11 -DNDEBUG"
AR="/usr/bin/ar"
RANLIB="/usr/bin/ranlib"
NVCC="/opt/cuda/bin/nvcc"
CUDAINC="-I/opt/cuda/include"
HWMON="-I$CUR/../libhwmon/.."
LIBS="-L/usr/lib -lboost_system -lboost_program_options -lboost_thread -lboost_filesystem -lOpenCL -lrt -lpthread -ldl -ljsoncpp -lethash -lssl -lcrypto  /opt/cuda/lib64/libcudart_static.a" # 

# buildinfo.h vars
NAME="nsfminer"
VERSION="0.20.0"
SYSTEM=`uname`
ARCH=`uname -m`
COMPILER=`$CXX --version | head -n1 | awk -F'(' '{print $2}'| cut -c1-3`
COMPILER_VER=`$CXX --version | head -n1 | rev | awk -F' ' '{print $1}' | rev`
COMMIT=`git describe --always --long --tags --match=v*`
DIRTY="false"
TYPE="release"
PROJECT_NAME_VER="$PROJECT_NAME.$PROJECT_VERSION"

# make directory structure
mkdir -p nsfminer
cd $CUR/nsfminer

# BUILDINFO
$CXX -o libnsfminer-buildinfo.o -I../nsfminer -DPROJECT_NAME_VERSION="$PROJECT_NAME_VER" -DPROJECT_NAME="$NAME" -DPROJECT_VERSION=0.19.0 -DCOMMIT="$COMMIT" -DSYSTEM_NAME="$SYSTEM" -DSYSTEM_PROCESSOR="$ARCH" -DCOMPILER_ID="$COMPILER" -DCOMPILER_VERSION="$COMPILER_VERSION" -DBUILD_TYPE="$TYPE" -c $CUR/../nsfminer/buildinfo.c &

# DEVICE MANAGER 
$CXX $MINERFLAGS $CXXFLAGS -o CommonData.cpp.o -c $CUR/../libdev/CommonData.cpp &
$CXX $MINERFLAGS $CXXFLAGS -o FixedHash.cpp.o -c $CUR/../libdev/FixedHash.cpp &
$CXX $MINERFLAGS $CXXFLAGS -o Log.cpp.o -c $CUR/../libdev/Log.cpp &
$CXX $MINERFLAGS $CXXFLAGS -o Worker.cpp.o -c $CUR/../libdev/Worker.cpp &

# HARDWARE MONITOR
$CXX $MINERFLAGS $HWMON $CUDAINC $CXXFLAGS -o wraphelper.cpp.o -c $CUR/../libhwmon/wraphelper.cpp &
$CXX $MINERFLAGS $HWMON $CUDAINC $CXXFLAGS -o wrapnvml.cpp.o -c $CUR/../libhwmon/wrapnvml.cpp &
$CXX $MINERFLAGS $HWMON $CUDAINC $CXXFLAGS -o wrapadl.cpp.o -c $CUR/../libhwmon/wrapadl.cpp &
$CXX $MINERFLAGS $HWMON $CUDAINC $CXXFLAGS -o wrapamdsysfs.cpp.o -c $CUR/../libhwmon/wrapamdsysfs.cpp &

# POOL MANAGER
$CXX $MINERFLAGS -I$CUR/.. -I$CUR/../libpool -I$CUR $CXXFLAGS -o PoolURI.cpp.o -c $CUR/../libpool/PoolURI.cpp &
$CXX $MINERFLAGS -I$CUR/.. -I$CUR/../libpool -I$CUR $CXXFLAGS -o PoolManager.cpp.o -c $CUR/../libpool/PoolManager.cpp &
$CXX $MINERFLAGS -I$CUR/.. -I$CUR/../libpool -I$CUR $CXXFLAGS -o SimulateClient.cpp.o -c $CUR/../libpool/testing/SimulateClient.cpp &
$CXX $MINERFLAGS -I$CUR/.. -I$CUR/../libpool -I$CUR $CXXFLAGS -o EthStratumClient.cpp.o -c $CUR/../libpool/stratum/EthStratumClient.cpp &
$CXX $MINERFLAGS -I$CUR/.. -I$CUR/../libpool -I$CUR $CXXFLAGS -o EthGetworkClient.cpp.o -c $CUR/../libpool/getwork/EthGetworkClient.cpp &

# CUDA KERNELS
# -Xptxas "--use_fast_math,--allow-expensive-optimizations,--fmad,--maxrregcount 12288,--warn-on-double-precision-use --extra-device-vectorization"
$NVCC -I/opt/cuda/include -I$CUR/../ -I$CUR/../libcuda --ptxas-options=-v --default-stream=per-thread --extra-device-vectorization --use_fast_math --disable-warnings -gencode arch=compute_35,code=sm_35 -gencode arch=compute_50,code=sm_50 -gencode arch=compute_52,code=sm_52 -gencode arch=compute_53,code=sm_53 -gencode arch=compute_60,code=sm_60 -gencode arch=compute_61,code=sm_61 -gencode arch=compute_62,code=sm_62 -gencode arch=compute_70,code=sm_70 -gencode arch=compute_75,code=sm_75 --fmad=true --maxrregcount=256 -DNVCC -o ethash_cuda_miner_kernel.cu.o -c $CUR/../libcuda/ethash_cuda_miner_kernel.cu &
$CXX $MINERFLAGS $CUDAINC -I$CUR/../libcuda -I$CUR/.. $CXXFLAGS -o CUDAMiner.cpp.o -c $CUR/../libcuda/CUDAMiner.cpp &

# OPENCL KERNEL
$CUR/cl2h.sh "$CUR/../libcl/ethash.cl" "ethash_cl" "ethash.h"
$CXX $MINERFLAGS -I$CUR/../libcl -I$CUR/.. -I. $CUDAINC $CXXFLAGS -o CLMiner.cpp.o -c $CUR/../libcl/CLMiner.cpp &

# nsfminer  
$CXX $MINERFLAGS -I$CUR/../libeth -I$CUR/.. $CUDAINC $CXXFLAGS -o EthashAux.cpp.o -c $CUR/../libeth/EthashAux.cpp &
$CXX $MINERFLAGS -I$CUR/../libeth -I$CUR/.. $CUDAINC $CXXFLAGS -o Farm.cpp.o -c $CUR/../libeth/Farm.cpp &
$CXX $MINERFLAGS -I$CUR/../libeth -I$CUR/.. $CUDAINC $CXXFLAGS -o Miner.cpp.o -c $CUR/../libeth/Miner.cpp &

# COMPILE MAIN BINARY AND LINK TO ALL ABOVE STUFF
$CXX $MINERFLAGS -I$CUR/../nsfminer -I$CUR/.. $CUDAINC -I$CUR $CXXFLAGS -o main.cpp.o -c $CUR/../nsfminer/main.cpp &

OBJECTS=`cat $CUR/compile.sh | head -n69 | grep -o "\.o" | wc -l`
CUROBJ=0;

while test $CUROBJ -ne $OBJECTS
do
	sleep 0.5 
	CUROBJ=`ls -l *.o | wc -l`
done

# Compile the final binary
$CXX $CXXFLAGS main.cpp.o EthashAux.cpp.o Farm.cpp.o Miner.cpp.o CLMiner.cpp.o CUDAMiner.cpp.o ethash_cuda_miner_kernel.cu.o PoolURI.cpp.o PoolManager.cpp.o SimulateClient.cpp.o EthStratumClient.cpp.o EthGetworkClient.cpp.o wraphelper.cpp.o wrapnvml.cpp.o wrapadl.cpp.o wrapamdsysfs.cpp.o CommonData.cpp.o FixedHash.cpp.o Log.cpp.o Worker.cpp.o libnsfminer-buildinfo.o -o nsfminer $LIBS
rm *.{o,h}
strip nsfminer
