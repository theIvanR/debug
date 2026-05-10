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
- open anaconda prompt
- create venv:
  ```bash
  conda create -n py311 python=3.11
  conda activate py311
  ```
