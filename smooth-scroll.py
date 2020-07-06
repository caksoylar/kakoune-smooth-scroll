#!/usr/bin/env python3
"""
This module defines a KakSender class to communicate with Kakoune sessions
over Unix sockets. It implements smooth scrolling when called as a script.
"""

import sys
import os
import time
import socket
from typing import Optional


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

    def send_cmd(self, cmd: str) -> bool:
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
        b_cmd = cmd.encode('utf-8')
        sock = socket.socket(socket.AF_UNIX)
        sock.connect(self.socket_path)
        b_content = self._get_length_bytes(len(b_cmd)) + b_cmd
        b_header = b'\x02' + self._get_length_bytes(len(b_content) + 5)
        b_message = b_header + b_content
        return sock.send(b_message) == len(b_message)

    def send_keys(self, keys: str, client: Optional[str] = None) -> bool:
        """Send a sequence of keys to a client in the Kakoune session."""
        if client is None:
            client = self.client
        cmd = f"execute-keys -client {client} {keys}"
        return self.send_cmd(cmd)

    @staticmethod
    def _get_length_bytes(str_length: int) -> bytes:
        return str_length.to_bytes(4, byteorder=sys.byteorder)


def scroll(sender: KakSender, direction: str, speed: int, duration: float) -> None:
    """Send a scroll event to Kakoune client and make sure it takes at least
    `duration` seconds."""
    t_start = time.time()
    keys = f"{speed}j{speed}vj" if direction == 'd' else f"{speed}k{speed}vk"
    sender.send_keys(keys)
    t_end = time.time()
    elapsed = t_end - t_start
    if elapsed < duration:
        time.sleep(duration - elapsed)


def main() -> None:
    """
    Do smooth scrolling using KakSender methods. Expected positional arguments:
        direction: 'd' for down or 'u' for up
        half:      0 for full screen scroll (<c-f>/<c-b>), 1 for half (<c-d>/<c-u>)
        duration:  amount of time between each scroll tick, in milliseconds
        speed:     number of lines scroll with each tick
    """
    cursor_line = int(os.environ['kak_cursor_line'])
    line_count = int(os.environ['kak_buf_line_count'])
    window_height = int(os.environ['kak_window_height'])
    direction = sys.argv[1]  # 'd' for down, 'u' for up
    half = int(sys.argv[2])  # 0 or 1 depending on full or half-screen scroll
    duration = float(sys.argv[3]) / 1000  # interval between ticks, convert ms to s
    speed = int(sys.argv[4])  # number of lines per tick

    maxscroll = line_count - cursor_line if direction == 'd' else cursor_line - 1
    if maxscroll == 0:
        return

    sender = KakSender()
    amount = min((window_height - 2) // (1 + half), maxscroll)
    times = amount // speed
    for _ in range(times):
        scroll(sender, direction, speed, duration)


if __name__ == '__main__':
    main()
