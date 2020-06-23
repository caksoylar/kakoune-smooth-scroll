#!/usr/bin/env python3

import sys
import os
import time
import socket


class KakSender:
    def __init__(self, session, client):
        self.session = session
        self.client = client
        self.user = os.environ.get('USER')

    def send_keys(self, keys):
        ts = time.time()
        sock = socket.socket(socket.AF_UNIX)
        sock.connect(f"/tmp/kakoune/{self.user}/{self.session}")
        b_cmd = f"execute-keys -client {self.client} {keys}".encode('ascii')
        b_size = len(b_cmd).to_bytes(4, byteorder=sys.byteorder)
        b_content = b_size + b_cmd
        b_header = b'\x02' + (len(b_content) + 5).to_bytes(4, byteorder=sys.byteorder)
        sock.send(b_header + b_content)
        te = time.time()
        return te - ts


def scroll(sender, direction, speed, duration):
    keys = f"{speed}j{speed}vj" if direction == 'd' else f"{speed}k{speed}vk"
    elapsed = sender.send_keys(keys)
    # print(duration, elapsed)
    if elapsed < duration:
        time.sleep(duration - elapsed)


def main():
    (
        session,
        client,
        cursor_line,
        line_count,
        window_height,
        direction,
        half,
        duration,
        speed,
    ) = sys.argv[1:]
    cursor_line = int(cursor_line)
    line_count = int(line_count)
    window_height = int(window_height)
    half = int(half)
    duration = float(duration)
    speed = int(speed)

    maxscroll = line_count - cursor_line if direction == 'd' else cursor_line - 1
    if maxscroll == 0:
        return

    sender = KakSender(session, client)
    amount = min((window_height - 2) // (1 + half), maxscroll)
    times = amount // speed
    for _ in range(times):
        scroll(sender, direction, speed, duration)


if __name__ == '__main__':
    main()
