#!/usr/bin/env python3
"""
Wrapper for MBSetClient pointing to scripts.automation.mbset_client
"""
import importlib.util
from pathlib import Path

_TARGET = Path(__file__).resolve().parent / "automation" / "mbset_client.py"
_spec = importlib.util.spec_from_file_location("mbset_client_internal", str(_TARGET))
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

MBSetClient = _mod.MBSetClient

__all__ = ["MBSetClient"]
