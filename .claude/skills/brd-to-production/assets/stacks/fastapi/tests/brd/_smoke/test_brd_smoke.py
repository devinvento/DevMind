"""brd-to-production phase 0 smoke tests for FastAPI (pytest + TestClient)."""
import importlib
import os

from fastapi.testclient import TestClient

# Phase 0: set BRD_APP to "<module>:<app variable>", for example "app.main:app".
MODULE, _, ATTR = os.environ.get("BRD_APP", "app.main:app").partition(":")


def client():
    return TestClient(getattr(importlib.import_module(MODULE), ATTR or "app"))


def test_TC_0_01_app_imports():
    assert client().app is not None


def test_TC_0_02_openapi_served():
    r = client().get("/openapi.json")
    assert r.status_code == 200 and "paths" in r.json()
