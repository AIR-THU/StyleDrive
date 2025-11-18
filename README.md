<div align="center">
<h1>StyleDrive: Towards Driving-Style Aware Benchmarking of End-To-End Autonomous Driving</h1>

[Ruiyang Hao](https://ry-hao.top/)<sup>1,2</sup>, [Bowen Jing](https://arthur12137.com/)<sup>3</sup>, [Haibao Yu](https://scholar.google.com/citations?user=JW4F5HoAAAAJ)<sup>1,4</sup>, [Zaiqing Nie](https://scholar.google.com/citations?user=Qg7T6vUAAAAJ)<sup>1,\*</sup>

<sup>1</sup> AIR, Tsinghua University, <sup>2</sup> King's College London, <br> <sup>3</sup> The University of Manchester, <sup>4</sup> The University of Hong Kong

<strong>AAAI 2026 Oral</strong>

[![StyleDrive](https://img.shields.io/badge/Arxiv-Paper-red)](https://arxiv.org/abs/2506.23982)&nbsp;
[![Dataset](https://img.shields.io/badge/Dataset-Download-yellow)](https://huggingface.co/datasets/Ryhn98/StyleDrive-Dataset)&nbsp;
[![Weights](https://img.shields.io/badge/Weights-Download-blue)](https://huggingface.co/datasets/Ryhn98/StyleDrive-Dataset)&nbsp;
[![Homepage](https://img.shields.io/badge/Project-Website-cyan)](https://styledrive.github.io/)&nbsp;

</div>

## News

- **` Nov. 7th, 2025`:** StyleDrive is accepted to AAAI 2026 and will be presented in an oral session.
- **` Aug. 5th, 2025`:** We update the [Arxiv paper](https://arxiv.org/abs/2506.23982) with more experimental results, and supply more demos in the [Project Homepage](https://styledrive.github.io/).
- **` Jul. 1st, 2025`:** We release the initial version of code and weight (except for WoTE-Style model), along with documentation and training/evaluation scripts.
- **` Jun. 30th, 2025`:** We released our paper on [Arxiv](https://arxiv.org/abs/2506.23982). Code/Models are coming soon. Please stay tuned! ☕️

## Table of Contents

- [Introduction](#introduction)
- [StyleDrive Dataset Construction](#styledrive-dataset-construction)
- [Getting Started](#getting-started)
- [Benchmark Results](#benchmark-results)
- [Qualitative Results on StyleDrive Benchmark](#qualitative-results-on-styledrive-benchmark)
- [Contact](#contact)
- [Acknowledgement](#acknowledgement)
- [Citation](#citation)

## Introduction

We introduce the first large-scale real-world dataset with rich annotations of diverse driving preferences, addressing a key gap in personalized end-to-end autonomous driving (E2EAD). Using static road topology and a fine-tuned visual language model (VLM), we extract contextual features to construct fine-grained scenarios. Objective and subjective preference labels are derived through behavior analysis, VLM-based modeling, and human-in-the-loop verification. Building on this, we propose the first benchmark for evaluating personalized E2EAD models. Experiments show that conditioning on preferences leads to behavior better aligned with human driving. Our work establishes a foundation for human-centric, personalized E2EAD.

<div align="center"><b>Overview and Motivation of StyleDrive.</b>
<img src="assets/paper_overview.png" />
To bridge the gap between personalized autonomous driving and end-to-end autonomous driving, we introduce the first benchmark tailored for personalized E2EAD.
</div>
<br>

## StyleDrive Dataset Construction

We propose a unified framework for modeling and labeling personalized driving preferences, as shown in the figure below.

<div align="center"><b>Pipeline of StyleDrive Dataset Construction.</b>
<img src="assets/annoframework.png" />
</div>

## Getting Started

- [Environment and Dataset Setup](docs/install.md)
- [Dataset Structure Design](docs/dataset_stat.md)
- [Training and Evaluation](docs/train_eval.md)

## Benchmark Results

Main results are shown in the table below:

| Models                                                     | NC                                                     | DAC                                                    | TTC                                                   | Comf.                                                  | EP                                                     | SM-PDMS                                                |
| ---------------------------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------ | ----------------------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------ | ------------------------------------------------------ |
| [AD-MLP](https://github.com/autonomousvision/navsim)       | 92.63                                                  | 77.68                                                  | 83.83                                                 | 99.75                                                  | 78.01                                                  | 63.72                                                  |
| [TransFuser](https://github.com/autonomousvision/navsim)   | 96.74                                                  | 88.43                                                  | 91.08                                                 | 99.65                                                  | 84.39                                                  | 78.12                                                  |
| [WoTE](https://github.com/liyingyanUCAS/WoTE)              | 97.29                                                  | 92.39                                                  | 92.53                                                 | 99.13                                                  | 76.31                                                  | 79.56                                                  |
| [DiffusionDrive](https://github.com/hustvl/DiffusionDrive) | 96.66                                                  | 91.45                                                  | 90.63                                                 | 99.73                                                  | 80.39                                                  | 79.33                                                  |
| AD-MLP-Style                                               | 92.38                                                  | 73.23                                                  | 83.14                                                 | <span style="color:red"><strong>99.90</strong></span>  | 78.55                                                  | 60.02                                                  |
| TransFuser-Style                                           | 97.23                                                  | 90.36                                                  | 92.61                                                 | 99.73                                                  | <span style="color:red"><strong>84.95</strong></span>  | 81.09                                                  |
| WoTE-Style                                                 | <span style="color:blue"><strong>97.58</strong></span> | <span style="color:blue"><strong>93.44</strong></span> | <span style="color:red"><strong>93.70</strong></span> | 99.26                                                  | 77.38                                                  | <span style="color:blue"><strong>81.38</strong></span> |
| DiffusionDrive-Style                                       | <span style="color:red"><strong>97.81</strong></span>  | <span style="color:red"><strong>93.45</strong></span>  | 92.81                                                 | <span style="color:blue"><strong>99.85</strong></span> | <span style="color:blue"><strong>84.84</strong></span> | <span style="color:red"><strong>84.10</strong></span>  |

All the checkpoints are open-sourced in this [Link](https://huggingface.co/datasets/Ryhn98/StyleDrive-Dataset/).

More discussions and analysis are provided in paper.

## Qualitative Results on StyleDrive Benchmark

<div align="center">
<img src="assets/policycases.png" />
<p>Qualitative illustration of DiffusionDrive-Style predictions under different style conditions
across identical scenarios. Left: Aggressive vs. Normal; Right: Conservative vs. Normal. Red
lines indicate the model’s predicted trajectory under the given style condition; green lines denote the
ground-truth human trajectory. Clear behavioral differences emerge with style variation, reflecting
the model’s ability to adapt its outputs to driving preferences.</p>
</div>

## Contact

If you have any questions, please contact [Ruiyang Hao](https://ry-hao.top/) via email (haory369@gmail.com).

## Acknowledgement

This work is partly built upon [NAVSIM](https://github.com/autonomousvision/navsim), [Transfuser](https://github.com/autonomousvision/transfuser), [DiffusionDrive](https://github.com/hustvl/DiffusionDrive), [WoTE](https://github.com/liyingyanUCAS/WoTE), and [nuplan-devkit](https://github.com/motional/nuplan-devkit). Thanks them for their great works!

## Citation

If you find StyleDrive is useful in your research or applications, please consider giving us a star 🌟 and citing it by the following BibTeX entry.

```bibtex
 @article{hao2025styledrive,
  title={StyleDrive: Towards Driving-Style Aware Benchmarking of End-To-End Autonomous Driving},
  author={Hao, Ruiyang and Jing, Bowen and Yu, Haibao and Nie, Zaiqing},
  journal={arXiv preprint arXiv:2506.23982},
  year={2025}
}
```
