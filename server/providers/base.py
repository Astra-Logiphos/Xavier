from abc import ABC, abstractmethod
from dataclasses import dataclass

@dataclass
class LLMResult:
    text: str
    provider: str
    mode: str
    usage: dict | None = None

class LLMProvider(ABC):
    @abstractmethod
    def complete(self, messages): ...
