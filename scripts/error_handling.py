"""
Error handling utilities for Oracle orchestration system.
"""

from typing import TypeVar, Optional, Any
from dataclasses import dataclass
import logging

T = TypeVar('T')

@dataclass
class Result:
    """Simple result wrapper for error handling."""
    value: Optional[Any] = None
    error: Optional[str] = None
    success: bool = False
    
    @classmethod
    def ok(cls, value: Any) -> 'Result':
        """Create a successful result."""
        return cls(value=value, success=True)
    
    @classmethod
    def error(cls, error: str) -> 'Result':
        """Create an error result."""
        return cls(error=error, success=False)

def log_error(func_name: str, error: Exception) -> None:
    """Utility to log errors consistently."""
    logging.error(f"{func_name} failed: {str(error)}", exc_info=True)
