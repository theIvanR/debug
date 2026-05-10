Instructions:
- display driver 472.50
- cuda 11.8 (without display driver!)
- cudnn 8.7.0
- oneAPI newest
- visual studio code any with v142 compatibility

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
