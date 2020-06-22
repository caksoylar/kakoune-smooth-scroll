#!/usr/bin/env python3

import sys
import time
import subprocess
import timeit


class KakSender:
    def __init__(self, session, client):
        self.session = session
        self.client = client
        self.timer = timeit.Timer()

    def send_keys(self, keys):
        ts = self.timer.timer()
        process = ["kak", "-p", self.session]
        cmd = f"execute-keys -client {self.client} {keys}"
        subprocess.run(process, input=cmd.encode())
        te = self.timer.timer()
        return te - ts


def scroll(sender, direction, speed, interval):
    keys = f"{speed}j{speed}vj" if direction == 'd' else f"{speed}k{speed}vk"
    elapsed = sender.send_keys(keys)
    # print(interval, elapsed)
    if elapsed < interval:
        time.sleep(interval - elapsed)


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
    interval = duration / times
    for _ in range(times):
        scroll(sender, direction, speed, interval)


if __name__ == '__main__':
    main()
