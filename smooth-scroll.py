#!/usr/bin/env python3
"""
This module defines a KakSender class to communicate with Kakoune sessions
over Unix sockets. It implements smooth scrolling when executed as a script.
"""

import sys
import os
import time
import socket

SEND_INTERVAL = 2e-3  # min time interval (in s) between two sent scroll events


class Scroller:
    """Class to send smooth scrolling events to Kakoune."""

    def __init__(
        self, interval: float, speed: int, max_duration: float
    ) -> None:
        """
        Save scrolling parameters and initialize sender object. `interval`
        is the average step duration, `speed` is the size of each scroll step
        (0 implies inertial scrolling) and `max_duration` limits the total
        scrolling duration.
        """
        self.interval = interval
        self.speed = speed
        self.max_duration = max_duration
        self.command_fifo = sys.argv[2]
        self.response_fifo = sys.argv[3]

    def scroll_once(self, step: int, interval: float) -> None:
        """
        Send a scroll event of `step` lines to Kakoune client and make sure it
        takes at least `interval` seconds.
        """
        t_start = time.time()
        speed = abs(step)
        keys = f"{speed}j{speed}vj" if step > 0 else f"{speed}k{speed}vk"
        with open(self.command_fifo, "w") as handle:
            handle.write(
                f"""
                execute-keys {keys}<c-l>
                trigger-user-hook ScrollStep
                echo -to-file {self.response_fifo} ''
                """
            )
        with open(self.response_fifo, "r") as handle:
            handle.read()
        t_end = time.time()
        elapsed = t_end - t_start
        if elapsed < interval:
            time.sleep(interval - elapsed)

    def linear_scroll(self, target: int, duration: float) -> None:
        """
        Do scrolling with a fixed velocity, moving `target` lines in `duration`
        seconds.
        """
        n_lines, step = abs(target), self.speed if target > 0 else -self.speed
        times = n_lines // max(self.speed, 1)
        interval = duration / (times - 1)

        t_init = time.time()
        for i in range(times):
            if time.time() - t_init > duration:
                self.scroll_once(step * (times - i), 0)
                break
            self.scroll_once(step, interval * (i < times - 1))

    def inertial_scroll(self, target: int, duration: float) -> None:
        """
        Do scrolling with inertial movement, moving `target` lines in `duration`
        seconds. Velocity decreases linearly at each step towards zero.

        Compute initial velocity v_1 such that the total duration (omitting the
        final step) matches given `duration`. For S = abs(target) this is
        obtained by solving the formula

            duration = sum_{i=1}^{S-1} 1/v_i

        where v_i = v_1*(S-i+1)/S. Assumes `duration` > 0.
        """
        n_lines, step = abs(target), 1 if target > 0 else -1
        velocity = n_lines * sum(1.0 / x for x in range(2, n_lines + 1)) / duration  # type: ignore
        d_velocity = velocity / n_lines

        # keep track of total steps and interval for potential batching
        # before sending a scroll event
        q_step, q_duration = 0, 0.0

        t_init = time.time()
        for i in range(n_lines):
            # shortcut to the end if we are past total duration
            if time.time() - t_init > duration:
                self.scroll_once(step * (n_lines - i), 0)
                break

            # compute sleep interval and update velocity
            interval = 1 / velocity * (i < n_lines - 1)
            velocity -= d_velocity

            # update queue then check if we are past the event send interval
            q_duration += interval
            q_step += step
            if i == n_lines - 1 or q_duration >= SEND_INTERVAL:
                self.scroll_once(q_step, q_duration)
                q_step, q_duration = 0, 0.0

    def scroll(self, amount: int) -> None:
        """
        Do smooth scrolling using KakSender methods. `amount` is the total
        number of lines to scroll; positive for down, negative for up.
        Assumes abs(amount) > 1.
        """
        duration = min((abs(amount) - 1) * self.interval, self.max_duration)

        # smoothly scroll to target
        if self.speed > 0:  # fixed speed scroll
            self.linear_scroll(amount, duration)
        else:  # inertial scroll
            self.inertial_scroll(amount, duration)


def parse_options(option_name: str) -> dict:
    """Parse a Kakoune map option and return a str-to-str dict."""
    items = [
        elt.split("=", maxsplit=1)
        for elt in os.environ[f"kak_opt_{option_name}"].split()
    ]
    return {v[0]: v[1] for v in items}


def main() -> None:
    """Parse options from environment variable and call scroller."""
    amount = int(sys.argv[1])

    options = parse_options("scroll_options")

    # interval between ticks, convert ms to s
    interval = float(options.get("interval", 10)) / 1000

    # number of lines per tick
    speed = int(options.get("speed", 0))

    # max amount of time to scroll, convert ms to s
    max_duration = int(options.get("max_duration", 1000)) / 1000

    scroller = Scroller(interval, speed, max_duration)
    scroller.scroll(amount)


if __name__ == "__main__":
    main()
