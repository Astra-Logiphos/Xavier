"""Reserved GLM-4-Flash estimation contract. No model request is implemented."""
from typing import Protocol
class FoodEstimator(Protocol):
    def estimate(self,description: str)->dict:
        """Future local server adapter; result must include estimated=True."""
        ...
class DisabledFoodEstimator:
    def estimate(self,description):
        raise NotImplementedError('AI 食物热量估算尚未启用；未来结果必须标注估算，Key 仅在本机环境变量配置')
