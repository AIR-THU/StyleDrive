from typing import Any, List, Dict, Optional, Union
import json

import torch
from torch.optim import Optimizer
from torch.optim.lr_scheduler import LRScheduler
import pytorch_lightning as pl
from pytorch_lightning.callbacks import ModelCheckpoint

from navsim.agents.abstract_agent import AbstractAgent
from navsim.agents.transfuser.transfuser_config import TransfuserConfig
from navsim.agents.transfuser.transfuser_model import TransfuserModel
from navsim.agents.transfuser.transfuser_callback import TransfuserCallback
from navsim.agents.transfuser.transfuser_loss import transfuser_loss
from navsim.agents.transfuser.transfuser_features import TransfuserFeatureBuilder, TransfuserTargetBuilder
from navsim.common.dataclasses import SensorConfig
from navsim.planning.training.abstract_feature_target_builder import AbstractFeatureBuilder, AbstractTargetBuilder


class TransfuserAgent(AbstractAgent):
    """Agent interface for TransFuser baseline."""

    def __init__(
        self,
        config: TransfuserConfig,
        lr: float,
        checkpoint_path: Optional[str] = None,
    ):
        """
        Initializes TransFuser agent.
        :param config: global config of TransFuser agent
        :param lr: learning rate during training
        :param checkpoint_path: optional path string to checkpoint, defaults to None
        """
        super().__init__()

        self._config = config
        self._lr = lr

        self._checkpoint_path = checkpoint_path
        self._transfuser_model = TransfuserModel(config)
        self._with_style = config.with_style
        self._styletrain_path = config.styletrain_path
        self._styletest_path = config.styletest_path

        if self._with_style and self._styletest_path:
            with open(self._styletest_path, 'r', encoding='utf-8') as f:
                    style_dict = json.load(f)

            self._style_test_data = {key: value["ANC_result"] for key, value in style_dict.items()}

    def name(self) -> str:
        """Inherited, see superclass."""
        return self.__class__.__name__

    def initialize(self) -> None:
        """Inherited, see superclass."""
        if torch.cuda.is_available():
            state_dict: Dict[str, Any] = torch.load(self._checkpoint_path)["state_dict"]
        else:
            state_dict: Dict[str, Any] = torch.load(self._checkpoint_path, map_location=torch.device("cpu"))[
                "state_dict"
            ]
        self.load_state_dict({k.replace("agent.", ""): v for k, v in state_dict.items()})

    def get_sensor_config(self) -> SensorConfig:
        """Inherited, see superclass."""
        return SensorConfig.build_all_sensors(include=[3])

    def get_target_builders(self) -> List[AbstractTargetBuilder]:
        """Inherited, see superclass."""
        return [TransfuserTargetBuilder(config=self._config)]

    def get_feature_builders(self) -> List[AbstractFeatureBuilder]:
        """Inherited, see superclass."""
        return [TransfuserFeatureBuilder(config=self._config)]

    def forward(self, features: Dict[str, torch.Tensor]) -> Dict[str, torch.Tensor]:
        """Inherited, see superclass."""
        return self._transfuser_model(features)

    def compute_loss(
        self,
        features: Dict[str, torch.Tensor],
        targets: Dict[str, torch.Tensor],
        predictions: Dict[str, torch.Tensor],
    ) -> torch.Tensor:
        """Inherited, see superclass."""
        return transfuser_loss(targets, predictions, self._config)

    def get_optimizers(self) -> Union[Optimizer, Dict[str, Union[Optimizer, LRScheduler]]]:
        """Inherited, see superclass."""
        return torch.optim.Adam(self._transfuser_model.parameters(), lr=self._lr)

    def get_training_callbacks(self) -> List[pl.Callback]:
        checkpoint_callback = ModelCheckpoint(
            monitor="val/loss_epoch",
            mode="min",
            save_top_k=3,
            save_last=True,
            filename="epoch={epoch}-val_loss={val/loss_epoch:.4f}"
        )
        """Inherited, see superclass."""
        return [
            TransfuserCallback(self._config),
            checkpoint_callback
        ]
