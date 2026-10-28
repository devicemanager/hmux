#!/usr/bin/env python3
"""Subprocess environment and wire helpers for tests that drive the hmux CLI against a fake socket.

A shell that hmux launched carries HMUX_SOCKET_PATH, HMUX_SOCKET_CAPABILITY and
the focused workspace and surface ids. A CLI started with that environment wraps
every request in a capability envelope and resolves targets the fake server never
defined, so the test fails at the socket before it reaches the behavior under
test. Build the subprocess environment with ``cli_environment`` instead of
copying ``os.environ``, and run wire lines through ``unwrap_capability`` in a
fake server that reads them directly, so a stray envelope is still understood.
"""

from __future__ import annotations

import functools
import os
import tempfile

# What a hmux-launched shell adds that would point the CLI at the running app,
# make it authenticate against a fake server that speaks the bare protocol, or
# pre-resolve the focused target the test meant to leave undefined.
INHERITED_SOCKET_KEYS = (
    "HMUX_SOCKET_PATH",
    "HMUX_SOCKET",
    "HMUX_SOCKET_PASSWORD",
    "HMUX_SOCKET_PASSWORD_FILE",
    "HMUX_SOCKET_CAPABILITY",
    "HMUX_RELAY_ID",
    "HMUX_RELAY_TOKEN",
    "HMUX_WORKSPACE_ID",
    "HMUX_SURFACE_ID",
    "HMUX_TAB_ID",
    "HMUX_PANEL_ID",
    "HMUX_PANE_ID",
)

# Resources/shell-integration prefixes a request with this when the shell
# holds a capability; the CLI does the same from HMUX_SOCKET_CAPABILITY.
CAPABILITY_PREFIX = "_hmux_capability_v1 "


@functools.cache
def _empty_foundation_home() -> tempfile.TemporaryDirectory:
    # Cached for the process, removed by TemporaryDirectory's finalizer at exit.
    return tempfile.TemporaryDirectory(prefix="hmux-cli-test-home-")


def cli_environment(socket_path: "str | os.PathLike[str] | None" = None, *,
                    home: "str | os.PathLike[str] | None" = None, **overrides: str) -> dict[str, str]:
    """A copy of the environment with the inherited socket state removed.

    ``socket_path`` sets both spellings the CLI reads, ``HMUX_SOCKET_PATH`` and
    ``HMUX_SOCKET``. ``home`` points the CLI at a test-owned home directory:
    it sets ``HOME`` for shells and scripts and ``CFFIXED_USER_HOME`` for the
    CLI itself, because Foundation resolves the home directory through
    getpwuid unless that variable is set, so ``HOME`` alone moves nothing for
    Swift code and ``~/.local/state/hmux`` would still be the real one.
    Without ``home``, the CLI still gets an empty Foundation home, as
    ``scripts/ci/run_python_test_lane.py`` gives each test in CI, so a socket
    password saved there is never sent to the fake socket as ``auth``; a
    ``CFFIXED_USER_HOME`` that runner already set is kept.
    Keyword overrides are applied last, so a test can still pin a workspace
    or surface id of its own.
    """
    env = {key: value for key, value in os.environ.items() if key not in INHERITED_SOCKET_KEYS}
    env["HMUX_CLI_SENTRY_DISABLED"] = "1"
    if socket_path is not None:
        env["HMUX_SOCKET_PATH"] = str(socket_path)
        env["HMUX_SOCKET"] = str(socket_path)
    if home is not None:
        env["HOME"] = str(home)
        env["CFFIXED_USER_HOME"] = str(home)
    else:
        env.setdefault("CFFIXED_USER_HOME", _empty_foundation_home().name)
    env.update(overrides)
    return env


def unwrap_capability(line: str) -> str:
    """The request inside a ``_hmux_capability_v1 <token> <request>`` envelope, or the line unchanged."""
    if not line.startswith(CAPABILITY_PREFIX):
        return line
    parts = line.split(" ", 2)
    if len(parts) != 3 or not parts[1] or not parts[2]:
        return line
    return parts[2]
