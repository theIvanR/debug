## 🏗️ PyTorch on Windows for Older GPUS (Kepler +)
- **Goal:** Run PyTorch on Windows with Kepler GPUs (Tesla K40c, compute capability **3.5**).  
- **Stack:** Pytorch **2.7.1**, CUDA **11.8**, cuDNN **8.7.0**, Visual Studio **2022**, **Intel oneAPI**, **Python 3.11**.  
- **Arch List** CUDA 3.5;3.7;5.0;5.2;6.0;6.1;7.0;7.5


## 0: configure environment
- install git
- install miniconda
- install visual studio (any) supporting v142, recommended 2022 with backwards tool.
- install oneAPI (latest)
- install driver 472.50
- install cuda 11.8
- install cudnn 8.7.0 (drag and drop into nvidia)

**Strongly recommended**
- download debug_system to test if all prerequesites work. (output should confirm compiler, cuda, cudnn, and oneapi working)
  ```bash
  ./test_env_cfg.cmd
  ```
  
## 1: Set up environment
- open anaconda prompt and create new venv
  ```bash
  conda create -n py311 python=3.11
  conda activate py311
  ```
- fetch pytorch and install dependencies:
  ```bash
  git config --system core.longpaths true
  git clone --recursive https://github.com/pytorch/pytorch.git --branch v2.7.1

  cd pytorch
  pip install -r requirements.txt
  ```
## 2: Build Pytorch from source
```bash
@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64 -vcvars_ver=14.29

REM Point this at the actual MKL directory under oneAPI, not the oneAPI root
set "MKLROOT=C:\Program Files (x86)\Intel\oneAPI\mkl\latest"
set "CMAKE_INCLUDE_PATH=%MKLROOT%\include"
set "LIB=%MKLROOT%\lib;%LIB%"

python -m pip install -U build

cd pytorch
set "USE_MKLDNN=1"
set "USE_CUDNN=1"
set "TORCH_CUDA_ARCH_LIST=3.5"
python -m build --wheel --no-isolation
```

When it finishes you will be greeted with: 
```bash
Successfully built torch-2.7.1a0+gite2d141d-cp311-cp311-win_amd64.whl
```

## 3: Test and Enjoy
- install wheel via pip from /dist
- if something complains about a missing dll like AOTI, run dependency walker (modern one). Usual suspects will be: mkl_intel_thread.2.dll and cupti64_2022.3.0.dll. Plop them into your install folder.
- 
- libiomp5md dll
- 
- 
