CC = gcc
ARCHFLAGS_GABA = -march=native
BIT = 4
CFLAGS_GABA = -O3 -Wall -Wno-unused-function -Wno-unused-label -std=c99 -pipe -DBIT=$(BIT) -fopenmp
LIBGABA_FDR=../libgaba
LIBGABA_LIB=../libgaba/libgaba.a

WFA_FDR=../WFA2-lib
WFA_FDR2=../WFA2-lib/lib
WFA_LIB=../WFA2-lib/lib/libwfa.a
WFA_LIBS=-fopenmp -lm 
ifeq ($(UNAME), Linux)
  WFA_LIBS+=-lrt 
endif

SCROOGE_SRC := ../Scrooge/src
SCROOGE_SOURCES := genasm_gpu.cu genasm_cpu.cpp util.cpp bitvector_test.cu
SCROOGE_SRCPATHS := $(SCROOGE_SOURCES:%=$(SCROOGE_SRC)/%)
SCROOGE_HEADERS := bitvector_test.hpp bitvector.hpp cuda_list.hpp cuda_util.hpp filesystem.hpp genasm_cpu.hpp genasm_gpu.hpp util.hpp
SCROOGE_HEADERPATHS := $(SCROOGE_HEADERS:%=$(SCROOGE_SRC)/%)
SCROOGE_NVCC := $(if $(SCROOGE_NVCC),$(SCROOGE_NVCC),nvcc)
SCROOGE_CXX := $(if $(SCROOGE_CXX),$(SCROOGE_CXX),g++)
SCROOGE_NVCC_ARCH := $(if $(SCROOGE_NVCC_ARCH),$(SCROOGE_NVCC_ARCH),sm_86)
SCROOGE_CXX_FLAGS := -O3 -std=c++17
SCROOGE_NVCC_FLAGS := -arch=$(SCROOGE_NVCC_ARCH) -lineinfo -rdc=true


native: libgaba wadapt scrooge_cpu

libgaba: src/libgaba.c $(LIBGABA_LIB)
	$(CC) -L$(LIBGABA_FDR) -I$(LIBGABA_FDR) src/libgaba.c -o libgaba $(CFLAGS_GABA) $(ARCHFLAGS_GABA) $(LIBGABA_LIB)

wadapt: src/wfa_adapt.c $(WFA_LIB)
	$(CC) $(CC_FLAGS) -L$(WFA_FDR2) -I$(WFA_FDR) src/wfa_adapt.c -o wadapt -lwfa $(WFA_LIBS)

scrooge_cpu: src/scrooge_cpu.cpp $(SCROOGE_SRCPATHS) $(SCROOGE_HEADERPATHS)
	$(SCROOGE_NVCC) $(SCROOGE_NVCC_FLAGS)  src/scrooge_cpu.cpp $(SCROOGE_SRCPATHS) -L$(SCROOGE_SRC) -I$(SCROOGE_SRC) -o scrooge_cpu $(SCROOGE_CXX_FLAGS) -lstdc++fs -Xcompiler -fopenmp

