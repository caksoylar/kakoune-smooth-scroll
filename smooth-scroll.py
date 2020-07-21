#!/usr/bin/env python3
"""
This module defines a KakSender class to communicate with Kakoune sessions
over Unix sockets. It implements smooth scrolling when called as a script.
"""

import sys
import os
import time
import socket


class KakSender:
    """Helper to communicate with Kakoune's remote API using Unix sockets."""

    def __init__(self):
        self.session = os.environ['kak_session']
        self.client = os.environ['kak_client']
        xdg_runtime_dir = os.environ.get('XDG_RUNTIME_DIR')
        if xdg_runtime_dir is None:
            runtime_path = os.path.join(
                os.environ.get('TMPDIR', '/tmp'), 'kakoune', os.environ['USER']
            )
        else:
            runtime_path = os.path.join(xdg_runtime_dir, 'kakoune')
        self.socket_path = os.path.join(runtime_path, self.session)

    def send_cmd(self, cmd: str, client: bool = False) -> bool:
        """
        Send a command string to the Kakoune session. Sent data is a
        concatenation of:
           - Header
             - Magic byte indicating command (\x02)
             - Length of whole message in uint32
           - Content
             - Length of command string in uint32
             - Command string
        Return whether the communication was successful.
        """
        if client:
            cmd = f"evaluate-commands -client {self.client} %😬{cmd}😬"
        b_cmd = cmd.encode('utf-8')
        sock = socket.socket(socket.AF_UNIX)
        sock.connect(self.socket_path)
        b_content = self._get_length_bytes(len(b_cmd)) + b_cmd
        b_header = b'\x02' + self._get_length_bytes(len(b_content) + 5)
        b_message = b_header + b_content
        return sock.send(b_message) == len(b_message)

    def send_keys(self, keys: str) -> bool:
        """Send a sequence of keys to the client in the Kakoune session."""
        cmd = f"execute-keys -client {self.client} {keys}"
        return self.send_cmd(cmd)

    @staticmethod
    def _get_length_bytes(str_length: int) -> bytes:
        return str_length.to_bytes(4, byteorder=sys.byteorder)


def parse_options(option_name: str) -> dict:
    """Parse a Kakoune map option and return a str-to-str dict."""
    items = [
        elt.split('=', maxsplit=1)
        for elt in os.environ[f"kak_opt_{option_name}"].split()
    ]
    return {v[0]: v[1] for v in items}


def scroll_once(sender: KakSender, step: int, duration: float) -> None:
    """Send a scroll event to Kakoune client and make sure it takes at least
    `duration` seconds."""
    t_start = time.time()
    speed = abs(step)
    keys = f"{speed}j{speed}vj" if step > 0 else f"{speed}k{speed}vk"
    sender.send_keys(keys)
    t_end = time.time()
    elapsed = t_end - t_start
    if elapsed < duration:
        time.sleep(duration - elapsed)


def inertial_scroll(sender: KakSender, target: int, duration: float) -> None:
    """
    Do inertial scrolling with initial velocity decreasing linearly at each
    step towards zero. Per-step scrolling duration d_i is the inverse of the
    instantaneous velocity v_i. Compute initial velocity v_1 such that the
    total duration (omitting the final step) matches the linear scrolling
    duration. For S = abs(target) this is obtained by solving the formula

        (S-1) * duration = sum_{i=1}^{S-1} d_i

    where d_i = 1/v_i and v_i = v_1*(S-i+1)/S.
    """
    n_lines, step = abs(target), 1 if target > 0 else -1
    velocity = (
        n_lines
        * sum(1.0 / x for x in range(2, n_lines + 1))
        / ((n_lines - 1) * duration)
    )
    d_velocity = velocity / n_lines
    for i in range(n_lines):
        scroll_once(sender, step, 1 / velocity * (i < n_lines - 1))
        velocity -= d_velocity


def main() -> None:
    """
    Do smooth scrolling using KakSender methods. Expected positional arguments:
        amount:   number of lines to scroll as the fraction of a full screen
                  positive for down, negative for up, e.g. 1 for <c-f>, -0.5 for <c-u>
        duration: amount of time between each scroll tick, in milliseconds
        speed:    number of lines to scroll with each tick, 0 for inertial scrolling
    """
    initial_window = sys.argv[1].split()
    new_window = sys.argv[2].split()
    selections = os.environ['kak_selections_desc']
    options = parse_options("scroll_options")
    duration = (
        float(options["duration"]) / 1000
    )  # interval between ticks, convert ms to s
    speed = int(options["speed"])  # number of lines per tick

    sender = KakSender()

    # make cursor invisible to make scroll less jarring
    sender.send_keys("<space>")
    sender.send_cmd(
        "set-face window PrimaryCursor @default; set-face window PrimaryCursorEol @default",
        client=True,
    )

    amount = int(new_window[0]) - int(initial_window[0])
    n_lines = abs(amount)
    sign = 1 if amount > 0 else -1

    scroll_once(sender, -amount, 0)  # scroll back to initial position

    # smoothly scroll back
    if speed > 0 or duration < 1e-3:  # fixed speed scroll
        times = n_lines // max(speed, 1)
        for i in range(times):
            scroll_once(sender, sign * speed, duration * (i < times - 1))
    else:  # inertial scroll
        inertial_scroll(sender, sign * n_lines, duration)

    # restore selections, cursor face and note we are done
    sender.send_cmd(f"select {selections}", client=True)
    sender.send_cmd(
        "unset-face window PrimaryCursor; unset-face window PrimaryCursorEol",
        client=True
    )
    sender.send_cmd("set-option global scroll_running false")


if __name__ == '__main__':
    main()
