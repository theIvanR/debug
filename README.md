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
  setlocal EnableExtensions
  
  REM 1) Start from MSVC only
  call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64 -vcvars_ver=14.29
  
  REM 2) Pick ONE CUDA toolkit and ONE MKL/OpenMP source
  set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8"
  set "PATH=%CUDA_PATH%\bin;%PATH%" 
  
  python -m pip install -U build
  
  cd /d C:\Users\%USERNAME%\source\pytorch
  
  set "USE_CUDA=1"
  set "USE_CUDNN=1"
  set "USE_KINETO=0"
  set "USE_MKLDNN=0"
  
  set "TORCH_CUDA_ARCH_LIST=3.5"
  
  python -m build --wheel --no-isolation
  endlocal
```

When it finishes you will be greeted with: 
```bash
Successfully built torch-2.7.1a0+gite2d141d-cp311-cp311-win_amd64.whl
```

## 3: Test and Enjoy
- install wheel via pip from "pytorch/dist"
- test via: ```python -c "import torch; print(torch.randn(2,2).cuda())"```
