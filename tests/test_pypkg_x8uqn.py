"""Tests for `pypkg_x8uqn` package."""

import contextlib
import io

from pkg_resources import parse_version

import pypkg_x8uqn


def test_valid_version():
    """Check that the package defines a valid ``__version__``."""
    v_curr = parse_version(pypkg_x8uqn.__version__)
    v_orig = parse_version("0.1.0-dev")
    assert v_curr >= v_orig


def test_hello_world():
    """Test the hello_world function."""
    stdout = io.StringIO()
    with contextlib.redirect_stdout(stdout):
        pypkg_x8uqn.mod.hello_world()
    assert "Hello World" in stdout.getvalue()
