"""UNVERIFIED PLACEHOLDER：AI 食物热量估算预留契约，未实现任何模型请求。

DisabledFoodEstimator 主动抛错，避免静默给出未标注的估算结果；
未来接入时结果必须带 estimated=True，Key 仅从本机环境变量读取。
"""
from typing import Protocol
class FoodEstimator(Protocol):
    def estimate(self,description: str)->dict:
        """Future local server adapter; result must include estimated=True."""
        ...
class DisabledFoodEstimator:
    def estimate(self,description):
        raise NotImplementedError('AI 食物热量估算尚未启用；未来结果必须标注估算，Key 仅在本机环境变量配置')
