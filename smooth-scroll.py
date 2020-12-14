#!/usr/bin/env python3
"""
This module defines a KakSender class to communicate with Kakoune sessions
over Unix sockets. It implements smooth scrolling when executed as a script.
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
        b_content = self._encode_length(len(b_cmd)) + b_cmd
        b_header = b'\x02' + self._encode_length(len(b_content) + 5)
        b_message = b_header + b_content
        return sock.send(b_message) == len(b_message)

    def send_keys(self, keys: str) -> bool:
        """Send a sequence of keys to the client in the Kakoune session."""
        cmd = f"execute-keys -client {self.client} {keys}"
        return self.send_cmd(cmd)

    @staticmethod
    def _encode_length(str_length: int) -> bytes:
        return str_length.to_bytes(4, byteorder=sys.byteorder)


def parse_options(option_name: str) -> dict:
    """Parse a Kakoune map option and return a str-to-str dict."""
    items = [
        elt.split('=', maxsplit=1)
        for elt in os.environ[f"kak_opt_{option_name}"].split()
    ]
    return {v[0]: v[1] for v in items}


def scroll_once(sender: KakSender, step: int, interval: float) -> None:
    """
    Send a scroll event to Kakoune client and make sure it takes at least
    `interval` seconds.
    """
    t_start = time.time()
    speed = abs(step)
    keys = f"{speed}j{speed}vj" if step > 0 else f"{speed}k{speed}vk"
    sender.send_keys(keys)
    t_end = time.time()
    elapsed = t_end - t_start
    if elapsed < interval:
        time.sleep(interval - elapsed)


def linear_scroll(sender: KakSender, target: int, speed: int, duration: float) -> None:
    """
    Do linear scrolling with fixed velocity.
    """
    n_lines, step = abs(target), speed if target > 0 else -speed
    times = n_lines // max(speed, 1)
    interval = duration / (times - 1)

    t_init = time.time()
    for i in range(times):
        if time.time() - t_init > duration:
            scroll_once(sender, step * (times - i), 0)
            break
        scroll_once(sender, step, interval * (i < times - 1))


def inertial_scroll(sender: KakSender, target: int, duration: float) -> None:
    """
    Do inertial scrolling with initial velocity decreasing linearly at each
    step towards zero. Per-step scrolling duration d_i is the inverse of the
    instantaneous velocity v_i. Compute initial velocity v_1 such that the
    total duration (omitting the final step) matches the linear scrolling
    duration. For S = abs(target) this is obtained by solving the formula

        duration = sum_{i=1}^{S-1} d_i

    where d_i = 1/v_i and v_i = v_1*(S-i+1)/S.
    """
    n_lines, step = abs(target), 1 if target > 0 else -1
    velocity = n_lines * sum(1.0 / x for x in range(2, n_lines + 1)) / duration  # type: ignore
    d_velocity = velocity / n_lines

    t_init = time.time()
    for i in range(n_lines):
        if time.time() - t_init > duration:
            scroll_once(sender, step * (n_lines - i), 0)
            break
        scroll_once(sender, step, 1 / velocity * (i < n_lines - 1))
        velocity -= d_velocity


def scroll() -> None:
    """
    Do smooth scrolling using KakSender methods. Expected positional arguments:
        amount:   number of lines to scroll; positive for down, negative for up
    """
    amount = int(sys.argv[1])
    options = parse_options("scroll_options")
    interval = (
        float(options.get("interval", 10)) / 1000
    )  # interval between ticks, convert ms to s
    speed = int(options.get("speed", 0))  # number of lines per tick
    max_duration = (
        int(options.get("max_duration", 1000)) / 1000
    )  # max amount of time to scroll

    sender = KakSender()

    duration = min((abs(amount) - 1) * interval, max_duration)

    # smoothly scroll to target
    if speed > 0 or interval < 1e-3:  # fixed speed scroll
        linear_scroll(sender, amount, speed, duration)
    else:  # inertial scroll
        inertial_scroll(sender, amount, duration)

    # report we are done
    sender.send_cmd('set-option window scroll_running ""', client=True)


if __name__ == '__main__':
    scroll()
