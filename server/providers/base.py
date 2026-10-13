from abc import ABC, abstractmethod
from dataclasses import dataclass

@dataclass
class LLMResult:
    text: str
    provider: str
    mode: str

class LLMProvider(ABC):
    @abstractmethod
    def complete(self, messages): ...
