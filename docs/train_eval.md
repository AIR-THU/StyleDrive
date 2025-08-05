# DiffusionDrive Training and Evaluation

## 1. Cache dataset for faster training and evaluation

```bash
# cache dataset for training
bash scripts/caching/caching_training_tran_diff.sh

# cache dataset for evaluation
bash scripts/caching/run_metric_caching.sh
```

Notes: If you have previously cached the training datasets, you will need to re-cache to properly encode the style features (A key point is to set the agent to diffusiondrive_style_agent or transfuser_style_agent during caching). Otherwise, you may encounter the same [issue](https://github.com/AIR-THU/StyleDrive/issues/3) described here.

## 2. Training

If your training machine does not have network access, you should download the pretrained ResNet-34 model from [huggingface](https://huggingface.co/timm/resnet34.a1_in1k) and upload it to your training machine.

#### DiffusionDrive-Style Model

```bash
bash scripts/training/run_diffusiondrive_style_training.sh
```

#### Transfuser-Style Model

```bash
bash scripts/training/run_transfuser_style_training.sh
```

#### AD-MLP-Style Model

```bash
bash scripts/training/run_ego_mlp_style_agent_training.sh
```

## 3. Evaluation

All the ckpts are open-sourced in [Huggingface](https://huggingface.co/datasets/Ryhn98/StyleDrive-Dataset).

You can modify the ckpt's path in the following scripts and run the evaluation as follows:

#### DiffusionDrive-Style Model

```bash
bash scripts/evaluation/run_diffusiondrive_style.sh
```

#### Transfuser-Style Model

```bash
bash scripts/evaluation/run_transfuser_style.sh
```

#### AD-MLP-Style Model

```bash
bash scripts/evaluation/run_ego_mlp_style_agent_pdm_score_evaluation.sh
```
