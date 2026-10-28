#!/usr/bin/env python3
"""Behavior coverage for the fake-socket CLI environment helpers."""

from __future__ import annotations

import os
import unittest
from unittest.mock import patch

from fake_socket_env import INHERITED_SOCKET_KEYS, cli_environment, unwrap_capability


LAUNCHED_BY_HMUX = {
    "HMUX_SOCKET_PATH": "/Users/me/.local/state/hmux/hmux.sock",
    "HMUX_SOCKET": "/Users/me/.local/state/hmux/hmux.sock",
    "HMUX_SOCKET_CAPABILITY": "v1.token.signature",
    "HMUX_SOCKET_PASSWORD": "hunter2",
    "HMUX_SOCKET_PASSWORD_FILE": "/Users/me/.local/state/hmux/password",
    "HMUX_WORKSPACE_ID": "workspace:9",
    "HMUX_SURFACE_ID": "surface:9",
    "HMUX_TAB_ID": "tab:9",
    "HMUX_PANEL_ID": "panel:9",
    "HMUX_PANE_ID": "pane:9",
    "HMUX_RELAY_ID": "relay",
    "HMUX_RELAY_TOKEN": "11" * 32,
    "HOME": "/Users/me",
    "PATH": "/usr/bin:/bin",
}


class CliEnvironmentTests(unittest.TestCase):
    def test_a_hmux_launched_shell_leaves_no_socket_state_behind(self) -> None:
        with patch.dict(os.environ, LAUNCHED_BY_HMUX, clear=True):
            env = cli_environment()
        for key in INHERITED_SOCKET_KEYS:
            self.assertNotIn(key, env)
        self.assertEqual(env["HOME"], "/Users/me")
        self.assertEqual(env["PATH"], "/usr/bin:/bin")
        self.assertEqual(env["HMUX_CLI_SENTRY_DISABLED"], "1")
        self.assertNotIn("HMUX_PANEL_ID", env)
        self.assertNotIn("HMUX_PANE_ID", env)

    def test_the_fake_socket_is_set_under_both_names_the_cli_reads(self) -> None:
        with patch.dict(os.environ, LAUNCHED_BY_HMUX, clear=True):
            env = cli_environment("/tmp/fake.sock")
        self.assertEqual(env["HMUX_SOCKET_PATH"], "/tmp/fake.sock")
        self.assertEqual(env["HMUX_SOCKET"], "/tmp/fake.sock")
        self.assertNotIn("HMUX_SOCKET_CAPABILITY", env)

    def test_overrides_win_over_the_scrub_so_a_test_can_pin_its_own_target(self) -> None:
        with patch.dict(os.environ, LAUNCHED_BY_HMUX, clear=True):
            env = cli_environment("/tmp/fake.sock", HMUX_WORKSPACE_ID="workspace:1", HMUX_SURFACE_ID="surface:1")
        self.assertEqual(env["HMUX_WORKSPACE_ID"], "workspace:1")
        self.assertEqual(env["HMUX_SURFACE_ID"], "surface:1")
        self.assertNotIn("HMUX_TAB_ID", env)

    def test_a_test_owned_home_moves_the_shell_and_foundation_homes_together(self) -> None:
        with patch.dict(os.environ, LAUNCHED_BY_HMUX, clear=True):
            env = cli_environment("/tmp/fake.sock", home="/tmp/fake-home")
        self.assertEqual(env["HOME"], "/tmp/fake-home")
        self.assertEqual(env["CFFIXED_USER_HOME"], "/tmp/fake-home")

    def test_without_a_test_owned_home_foundation_still_gets_an_empty_one(self) -> None:
        with patch.dict(os.environ, LAUNCHED_BY_HMUX, clear=True):
            env = cli_environment("/tmp/fake.sock")
        self.assertEqual(env["HOME"], "/Users/me")
        self.assertTrue(os.path.isdir(env["CFFIXED_USER_HOME"]))
        self.assertEqual(os.listdir(env["CFFIXED_USER_HOME"]), [])

    def test_a_foundation_home_the_test_runner_set_is_kept(self) -> None:
        with patch.dict(os.environ, {**LAUNCHED_BY_HMUX, "CFFIXED_USER_HOME": "/tmp/lane.home"}, clear=True):
            env = cli_environment("/tmp/fake.sock")
        self.assertEqual(env["CFFIXED_USER_HOME"], "/tmp/lane.home")

    def test_the_caller_environment_is_not_mutated(self) -> None:
        with patch.dict(os.environ, LAUNCHED_BY_HMUX, clear=True):
            cli_environment("/tmp/fake.sock")
            self.assertEqual(os.environ["HMUX_SOCKET_CAPABILITY"], "v1.token.signature")


class UnwrapCapabilityTests(unittest.TestCase):
    def test_an_enveloped_request_yields_the_bare_request(self) -> None:
        request = '{"method":"workspace.list","params":{},"id":"1"}'
        self.assertEqual(unwrap_capability(f"_hmux_capability_v1 v1.token.sig {request}"), request)

    def test_a_bare_line_passes_through(self) -> None:
        for line in ('{"method":"ping"}', "auth secret", "ping", ""):
            with self.subTest(line=line):
                self.assertEqual(unwrap_capability(line), line)

    def test_a_malformed_envelope_is_left_for_the_server_to_reject(self) -> None:
        for line in ("_hmux_capability_v1 ", "_hmux_capability_v1 token-only", "_hmux_capability_v1  {}"):
            with self.subTest(line=line):
                self.assertEqual(unwrap_capability(line), line)


if __name__ == "__main__":
    unittest.main()
