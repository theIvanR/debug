# 🏗️ PyTorch on Windows for Older GPUS (Kepler +)
- **Goal:** Run PyTorch on Windows with Kepler GPUs (Tesla K40c, compute capability **3.5**).  
- **Stack:** Pytorch **2.7.1**, CUDA **11.8**, cuDNN **8.7.0**, Visual Studio **2022**, **Intel oneAPI**, **Python 3.11**.  
- **Arch List** CUDA 3.5;3.7;5.0;5.2;6.0;6.1;7.0;7.5

---
0: configure environment
- install git
- install miniconda
- install visual studio (any) supporting v142, recommended 2022 with backwards tool.
- install oneAPI (latest)
- install driver 472.50
- install cuda 11.8
- install cudnn 8.7.0 (drag and drop into nvidia)

1: Set up environment
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
