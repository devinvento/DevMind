"""brd-to-production phase 0 smoke tests (pytest). Case ids live in the test names."""
import sys


def test_TC_0_01_python_runs():
    assert sys.version_info >= (3, 8)


def test_TC_0_02_project_importable():
    # Phase 0: replace "json" with the project's main package, so a broken import fails here.
    __import__("json")
