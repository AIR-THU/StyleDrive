from typing import Any, List, Dict, Optional, Union
import json

import torch
from torch.optim import Optimizer
from torch.optim.lr_scheduler import LRScheduler

import pytorch_lightning as pl
from pytorch_lightning.callbacks import ModelCheckpoint

from nuplan.planning.simulation.trajectory.trajectory_sampling import TrajectorySampling

from navsim.agents.abstract_agent import AbstractAgent
from navsim.common.dataclasses import AgentInput, SensorConfig, Scene
from navsim.planning.training.abstract_feature_target_builder import AbstractFeatureBuilder, AbstractTargetBuilder


class EgoStatusFeatureBuilder(AbstractFeatureBuilder):
    """Input feature builder of EgoStatusMLP."""

    def __init__(self):
        """Initializes the feature builder."""
        pass

    def get_unique_name(self) -> str:
        """Inherited, see superclass."""
        return "ego_status_feature"

    def compute_features(self, agent_input: AgentInput) -> Dict[str, torch.Tensor]:
        """Inherited, see superclass."""
        ego_status = agent_input.ego_statuses[-1]
        velocity = torch.tensor(ego_status.ego_velocity)
        acceleration = torch.tensor(ego_status.ego_acceleration)
        driving_command = torch.tensor(ego_status.driving_command)
        ego_status_feature = torch.cat([velocity, acceleration, driving_command], dim=-1)
        return {"ego_status": ego_status_feature}


class TrajectoryTargetBuilder(AbstractTargetBuilder):
    """Input feature builder of EgoStatusMLP."""

    def __init__(self, trajectory_sampling: TrajectorySampling):
        """
        Initializes the target builder.
        :param trajectory_sampling: trajectory sampling specification.
        """

        self._trajectory_sampling = trajectory_sampling

    def get_unique_name(self) -> str:
        """Inherited, see superclass."""
        return "trajectory_target"

    def compute_targets(self, scene: Scene) -> Dict[str, torch.Tensor]:
        """Inherited, see superclass."""
        future_trajectory = scene.get_future_trajectory(num_trajectory_frames=self._trajectory_sampling.num_poses)
        return {"trajectory": torch.tensor(future_trajectory.poses)}


class EgoStatusMLPAgent(AbstractAgent):
    """EgoStatMLP agent interface."""

    def __init__(
        self,
        trajectory_sampling: TrajectorySampling,
        hidden_layer_dim: int,
        lr: float,
        checkpoint_path: Optional[str] = None,
        with_style: bool = False,
        styletrain_path: Optional[str] = None,
        styletest_path: Optional[str] = None
    ):
        """
        Initializes the agent interface for EgoStatusMLP.
        :param trajectory_sampling: trajectory sampling specification.
        :param hidden_layer_dim: dimensionality of hidden layer.
        :param lr: learning rate during training.
        :param checkpoint_path: optional checkpoint path as string, defaults to None
        """
        super().__init__()
        self._trajectory_sampling = trajectory_sampling
        self._checkpoint_path = checkpoint_path

        self._with_style = with_style
        self._styletrain_path = styletrain_path
        self._styletest_path = styletest_path

        if self._with_style and self._styletest_path:
            with open(self._styletest_path, 'r', encoding='utf-8') as f:
                    style_dict = json.load(f)

            self._style_test_data = {key: value["ANC_result"] for key, value in style_dict.items()}

        self._lr = lr

        if self._with_style:
            input_dims = 11
        else:
            input_dims = 8
        self._mlp = torch.nn.Sequential(
            torch.nn.Linear(input_dims, hidden_layer_dim),
            torch.nn.ReLU(),
            torch.nn.Linear(hidden_layer_dim, hidden_layer_dim),
            torch.nn.ReLU(),
            torch.nn.Linear(hidden_layer_dim, hidden_layer_dim),
            torch.nn.ReLU(),
            torch.nn.Linear(hidden_layer_dim, self._trajectory_sampling.num_poses * 3),
        )

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
        return SensorConfig.build_no_sensors()

    def get_target_builders(self) -> List[AbstractTargetBuilder]:
        """Inherited, see superclass."""
        return [TrajectoryTargetBuilder(trajectory_sampling=self._trajectory_sampling)]

    def get_feature_builders(self) -> List[AbstractFeatureBuilder]:
        """Inherited, see superclass."""
        return [EgoStatusFeatureBuilder()]

    def forward(self, features: Dict[str, torch.Tensor]) -> Dict[str, torch.Tensor]:
        """Inherited, see superclass."""
        if self._with_style:
            input_feature = torch.cat([features["ego_status"], features["style_feature"]], dim=-1)
        else:
            input_feature = features["ego_status"]
        poses: torch.Tensor = self._mlp(input_feature)
        return {"trajectory": poses.reshape(-1, self._trajectory_sampling.num_poses, 3)}

    def compute_loss(
        self, features: Dict[str, torch.Tensor], targets: Dict[str, torch.Tensor], predictions: Dict[str, torch.Tensor]
    ) -> torch.Tensor:
        """Inherited, see superclass."""
        return torch.nn.functional.l1_loss(predictions["trajectory"], targets["trajectory"])

    def get_optimizers(self) -> Union[Optimizer, Dict[str, Union[Optimizer, LRScheduler]]]:
        """Inherited, see superclass."""
        return torch.optim.Adam(self._mlp.parameters(), lr=self._lr)
