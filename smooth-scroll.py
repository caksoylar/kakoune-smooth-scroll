#!/usr/bin/env python3

import sys
import os
import time
import socket


class KakSender:
    def __init__(self):
        self.session = os.environ['kak_session']
        self.client = os.environ['kak_client']
        self.socket_path = f"{os.environ.get('TMPDIR', '/tmp')}/kakoune/{os.environ['USER']}/{self.session}"

    def send_cmd(self, b_cmd: bytes) -> float:
        ts = time.time()
        sock = socket.socket(socket.AF_UNIX)
        sock.connect(self.socket_path)
        b_size = self._get_length_bytes(len(b_cmd))
        b_content = b_size + b_cmd
        b_header = b'\x02' + self._get_length_bytes(len(b_content) + 5)
        sock.send(b_header + b_content)
        te = time.time()
        return te - ts

    def send_keys(self, keys: str) -> float:
        b_cmd = f"execute-keys -client {self.client} {keys}".encode('ascii')
        return self.send_cmd(b_cmd)

    @staticmethod
    def _get_length_bytes(str_length: int) -> bytes:
        return str_length.to_bytes(4, byteorder=sys.byteorder)


def scroll(sender: KakSender, direction: str, speed: int, duration: float) -> None:
    keys = f"{speed}j{speed}vj" if direction == 'd' else f"{speed}k{speed}vk"
    elapsed = sender.send_keys(keys)
    # print(duration, elapsed)
    if elapsed < duration:
        time.sleep(duration - elapsed)


def main():
    direction, half, duration, speed = sys.argv[1:]
    cursor_line   = int(os.environ.get('kak_cursor_line'))
    line_count    = int(os.environ.get('kak_buf_line_count'))
    window_height = int(os.environ.get('kak_window_height'))
    half          = int(half)               # 0 or 1 depending on full or half-screen scroll
    duration      = float(duration) / 1000  # interval between ticks, convert from ms to s
    speed         = int(speed)              # number of lines per tick

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
