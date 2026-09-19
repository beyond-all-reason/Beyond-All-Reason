#!/usr/bin/env python3
"""Convert legacy desiredFrames commands to animAmplitude-based commands."""

import argparse
import re
import sys
from pathlib import Path


COMMAND_PATTERN = re.compile(
    r"^(?P<indent>\s*)"
    r"(?P<command>turn|move) (?P<piece>\S+) to (?P<axis>[xyz])-axis "
    r"(?P<value><[+-]?(?:\d+(?:\.\d*)?|\.\d+)>|\[[+-]?(?:\d+(?:\.\d*)?|\.\d+)\])[ \t]+"
    r"speed (?P<speed><[+-]?(?:\d+(?:\.\d*)?|\.\d+)>|\[[+-]?(?:\d+(?:\.\d*)?|\.\d+)\])[ \t]+"
    r"/ desiredFrames;"
    r"(?P<comment>[ \t]*//delta=.*?)(?P<newline>\r?\n)?$"
)


def convert_line(line: str) -> str:
    """Convert one matching command, preserving indentation and line endings."""
    match = COMMAND_PATTERN.match(line)
    if not match:
        return line

    if match["command"] == "turn":
        value = f"({match['value']} *animAmplitude)/100"
        speed = f"({match['speed']} *animAmplitude)/100"
        value = f"({value})"
        speed = f"({speed})"
    else:
        value = f"((({match['value']} *MOVESCALE)/100) *animAmplitude)/100"
        speed = f"((({match['speed']} *MOVESCALE)/100) *animAmplitude)/100"

    return (
        f"{match['indent']}{match['command']} {match['piece']} to "
        f"{match['axis']}-axis {value} speed {speed} / animspeed; "
        f"//delta=%.2f{match['newline'] or ''}"
    )


def convert_text(text: str) -> tuple[str, int]:
    """Convert all matching lines and return the converted text and count."""
    lines = text.splitlines(keepends=True)
    converted = [convert_line(line) for line in lines]
    return "".join(converted), sum(old != new for old, new in zip(lines, converted))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Add animAmplitude scaling to legacy desiredFrames commands."
    )
    parser.add_argument("input", type=Path, help="File to convert in place")
    args = parser.parse_args()

    text = args.input.read_text(encoding="utf-8")
    converted, count = convert_text(text)
    args.input.write_text(converted, encoding="utf-8")
    print(f"Converted {count} command line(s).", file=sys.stderr)


if __name__ == "__main__":
    main()