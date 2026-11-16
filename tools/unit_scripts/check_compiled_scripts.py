#!/usr/bin/env python3
"""Checks that compiled unit scripts (.cob) match their sources (.bos).

Given a list of files, every .bos or .cob is compiled with BARScriptCompiler in a scratch copy of
the scripts/ dir and compared against the checked-in .cob. The comparison passes when any of the
compilers passed in reproduces the .cob. Compiler versions fold constants differently currently,
and newer versions likely will have other differences which this file may need to comprehend.

Scripts with changed headers are reached by this check as well. They are reported but not failed.

The comparison decodes both binaries and compares their piece names, script names, static
variable counts, and each script's instructions in file order, with jump targets made relative to
their script, so relinking still compares equal.

usage: check_compiled_scripts.py --compiler-dir <BARScriptCompiler checkout> [--compiler-dir ...]
       --changed <file> [--repo <BAR.sdd root>]
"""

import argparse
import collections
import difflib
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPTS_DIR = "scripts"
INCLUDE_PATTERN = re.compile(r'^\s*#\s*include\s*[<"]([^">]+)[">]', re.MULTILINE)
DIFF_CONTEXT_LINES = 40
ANNOTATION_CAP = 10
COMPILER_REPOSITORY = "https://github.com/beyond-all-reason/BARScriptCompiler"

# Opcodes and how many operands follow each in the code, from the engine's CobOpCodes.h and the
# reads in CobThread.cpp. CALL is the only call written to files; the engine rewrites it in place.
OPCODES = {
	0x10001000: ("MOVE", 2),
	0x10002000: ("TURN", 2),
	0x10003000: ("SPIN", 2),
	0x10004000: ("STOP_SPIN", 2),
	0x10005000: ("SHOW", 1),
	0x10006000: ("HIDE", 1),
	0x10007000: ("CACHE", 1),
	0x10008000: ("DONT_CACHE", 1),
	0x1000B000: ("MOVE_NOW", 2),
	0x1000C000: ("TURN_NOW", 2),
	0x1000D000: ("SHADE", 1),
	0x1000E000: ("DONT_SHADE", 1),
	0x1000F000: ("EMIT_SFX", 1),
	0x10011000: ("WAIT_TURN", 2),
	0x10012000: ("WAIT_MOVE", 2),
	0x10013000: ("SLEEP", 0),
	0x10021001: ("PUSH_CONSTANT", 1),
	0x10021002: ("PUSH_LOCAL_VAR", 1),
	0x10021004: ("PUSH_STATIC", 1),
	0x10022000: ("CREATE_LOCAL_VAR", 0),
	0x10023002: ("POP_LOCAL_VAR", 1),
	0x10023004: ("POP_STATIC", 1),
	0x10024000: ("POP_STACK", 0),
	0x10031000: ("ADD", 0),
	0x10032000: ("SUB", 0),
	0x10033000: ("MUL", 0),
	0x10034000: ("DIV", 0),
	0x10034001: ("MOD", 0),
	0x10035000: ("BITWISE_AND", 0),
	0x10036000: ("BITWISE_OR", 0),
	0x10037000: ("BITWISE_XOR", 0),
	0x10038000: ("BITWISE_NOT", 0),
	0x10041000: ("RAND", 0),
	0x10042000: ("GET_UNIT_VALUE", 0),
	0x10043000: ("GET", 0),
	0x10051000: ("SET_LESS", 0),
	0x10052000: ("SET_LESS_OR_EQUAL", 0),
	0x10053000: ("SET_GREATER", 0),
	0x10054000: ("SET_GREATER_OR_EQUAL", 0),
	0x10055000: ("SET_EQUAL", 0),
	0x10056000: ("SET_NOT_EQUAL", 0),
	0x10057000: ("LOGICAL_AND", 0),
	0x10058000: ("LOGICAL_OR", 0),
	0x10059000: ("LOGICAL_XOR", 0),
	0x1005A000: ("LOGICAL_NOT", 0),
	0x10061000: ("START", 2),
	0x10062000: ("CALL", 2),
	0x10062001: ("REAL_CALL", 2),
	0x10062002: ("LUA_CALL", 2),
	0x10062004: ("BATCH_LUA", 2),
	0x10064000: ("JUMP", 1),
	0x10065000: ("RETURN", 0),
	0x10066000: ("JUMP_NOT_EQUAL", 1),
	0x10067000: ("SIGNAL", 0),
	0x10068000: ("SET_SIGNAL_MASK", 0),
	0x10071000: ("EXPLODE", 1),
	0x10072000: ("PLAY_SOUND", 1),
	0x10082000: ("SET", 0),
	0x10083000: ("ATTACH", 0),
	0x10084000: ("DROP", 0),
	0x10090000: ("SIGNATURE_LUA", 0),
	0x100A0000: ("SCALE", 1),
	0x100A1000: ("SCALE_NOW", 1),
	0x100A2000: ("WAIT_SCALE", 1),
}
JUMPS = {"JUMP", "JUMP_NOT_EQUAL"}
COB_HEADER_FIELDS = (
	"VersionSignature",
	"NumberOfScripts",
	"NumberOfPieces",
	"TotalScriptLen",
	"NumberOfStaticVars",
	"Unknown_2",
	"OffsetToScriptCodeIndexArray",
	"OffsetToScriptNameOffsetArray",
	"OffsetToPieceNameOffsetArray",
	"OffsetToScriptCode",
	"OffsetToNamesArray",
)


def is_github_actions():
	return os.environ.get("GITHUB_ACTIONS") == "true"


annotation_counts = collections.Counter()


def annotate(level, path, message):
	annotation_counts[level] += 1
	if is_github_actions() and annotation_counts[level] <= ANNOTATION_CAP:
		print(f"::{level} file={path}::{message}")
	else:
		print(f"{level}: {path}: {message}")


def print_unshown_annotations():
	if is_github_actions():
		for level, count in annotation_counts.items():
			if count > ANNOTATION_CAP:
				print(f"::notice::Only {ANNOTATION_CAP} of {count} {level}s are annotated; the log lists every one.")


def read_changed(changed_file: Path):
	raw = changed_file.read_bytes().decode("utf-8")
	return [p for p in raw.split("\0") if p]


def find_case_insensitive(directory: Path, name: str):
	"""Includes are written on Windows, where path case does not matter, so match the way the
	authors' compiler did when the exact case is missing."""
	candidate = directory / name
	if candidate.exists():
		return candidate
	current = directory
	for part in Path(name).parts:
		if part in ("..", "."):
			current = current / part
			continue
		if not current.is_dir():
			return None
		matches = [child for child in current.iterdir() if child.name.lower() == part.lower()]
		if not matches:
			return None
		current = matches[0]
	return current if current.exists() else None


def includes_of(bos_path: Path):
	"""Every file a .bos includes, directly or through other includes. Includes resolve from the
	including file's folder first, then from the .bos file's folder, as the preprocessor does."""
	seen = set()
	pending = [bos_path]
	while pending:
		current = pending.pop()
		try:
			text = current.read_text(encoding="utf-8", errors="replace")
		except OSError:
			continue
		for name in INCLUDE_PATTERN.findall(text):
			found = find_case_insensitive(current.parent, name) or find_case_insensitive(bos_path.parent, name)
			if found:
				resolved = found.resolve()
				if resolved not in seen:
					seen.add(resolved)
					pending.append(resolved)
	return seen


def sibling(path: Path, extension: str):
	for candidate in path.parent.glob(path.stem + ".*"):
		if candidate.suffix.lower() == extension:
			return candidate
	return None


def compile_bos(compiler_dir: Path, bos_path: Path):
	"""Compiles in place; the compiler always writes the .cob next to its .bos."""
	cob_path = bos_path.with_suffix(".cob")
	if cob_path.exists():
		cob_path.unlink()
	result = subprocess.run(
		[sys.executable, str(compiler_dir / "bos2cob_py3.py"), str(bos_path)],
		cwd=compiler_dir,
		capture_output=True,
		text=True,
	)
	if result.returncode != 0 or not cob_path.exists():
		return None, (result.stdout + result.stderr).strip()
	return cob_path, None


def final_line(log: str):
	"""The compiler ends its output with the cause, after any traceback."""
	return log.splitlines()[-1] if log else "The compiler printed nothing."


def decode(cob_path: Path):
	"""The script as comparable lines: header facts, then each script's instructions."""
	data = cob_path.read_bytes()

	def word(offset):
		return struct.unpack_from("<L", data, offset)[0]

	def name(offset):
		return data[offset : data.index(b"\0", offset)].decode("latin-1")

	header = dict(zip(COB_HEADER_FIELDS, struct.unpack_from("<%dL" % len(COB_HEADER_FIELDS), data, 0)))
	scripts = [name(word(header["OffsetToScriptNameOffsetArray"] + 4 * i)) for i in range(header["NumberOfScripts"])]
	pieces = [name(word(header["OffsetToPieceNameOffsetArray"] + 4 * i)) for i in range(header["NumberOfPieces"])]
	starts = [word(header["OffsetToScriptCodeIndexArray"] + 4 * i) for i in range(header["NumberOfScripts"])]
	code = [word(header["OffsetToScriptCode"] + 4 * i) for i in range(header["TotalScriptLen"])]

	lines = [
		f"version {header['VersionSignature']}",
		f"static variables {header['NumberOfStaticVars']}",
		"pieces " + " ".join(pieces),
	]
	for index, script in enumerate(scripts):
		start = starts[index]
		end = starts[index + 1] if index + 1 < len(starts) else len(code)
		lines.append(f"script {script}")
		pc = start
		while pc < end:
			opcode = code[pc]
			op_name, operand_count = OPCODES.get(opcode, (f"UNKNOWN_{opcode:#010x}", 0))
			operands = code[pc + 1 : pc + 1 + operand_count]
			if op_name in JUMPS:
				operands = [target - start for target in operands]
			lines.append(" ".join([op_name] + [str(operand) for operand in operands]))
			pc += 1 + operand_count
	return lines


def script_bodies(lines):
	bodies = {}
	body = None
	for line in lines:
		if line.startswith("script "):
			body = bodies.setdefault(line.removeprefix("script "), [])
		elif body is not None:
			body.append(line)
	return bodies


def summarize_difference(expected, actual):
	"""Says what differs in one line, since the diff that follows can be cut off."""
	header_fields = ("version", "static variables", "pieces")
	header = [field for field, ours, theirs in zip(header_fields, expected, actual) if ours != theirs]
	ours = script_bodies(expected)
	theirs = script_bodies(actual)
	scripts = sorted(name for name in ours.keys() | theirs.keys() if ours.get(name) != theirs.get(name))
	summary = []
	if header:
		summary.append("Header differs: " + ", ".join(header) + ".")
	if scripts:
		summary.append("Scripts differ: " + ", ".join(scripts) + ".")
	return " ".join(summary) or "Only the order of the scripts differs."


def compiler_label(compiler_dir: Path):
	source = (compiler_dir / "bos2cob_py3.py").read_text(encoding="utf-8", errors="replace")
	version = re.search(r'^version\s*=\s*"([^"]+)"', source, re.MULTILINE)
	return f"{compiler_dir.name} (version {version.group(1) if version else '?'})"


def main():
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--compiler-dir", type=Path, action="append", required=True)
	parser.add_argument("--changed", type=Path, required=True)
	parser.add_argument("--repo", type=Path, default=Path.cwd())
	args = parser.parse_args()

	repo = args.repo.resolve()
	compilers = [(path.resolve(), compiler_label(path.resolve())) for path in args.compiler_dir]
	scripts_root = repo / SCRIPTS_DIR
	recompile_help = (
		f"Recompile it with bos2cob_py3.py from {COMPILER_REPOSITORY}, at "
		+ " or ".join(label for _, label in compilers)
		+ "."
	)

	changed_bos = set()
	changed_headers = set()
	failures = 0
	for rel in read_changed(args.changed):
		if not rel.replace("\\", "/").startswith(SCRIPTS_DIR + "/"):
			continue
		path = repo / rel
		extension = path.suffix.lower()
		if extension == ".bos":
			if path.exists():
				changed_bos.add(path.resolve())
			elif sibling(path, ".cob"):
				annotate("error", rel, "This .bos was removed but its .cob was not.")
				failures += 1
		elif extension == ".cob":
			source = sibling(path, ".bos")
			if source:
				changed_bos.add(source.resolve())
			elif path.exists():
				annotate("notice", rel, "No .bos source next to this .cob, so it cannot be checked.")
		elif extension == ".h" and path.exists():
			changed_headers.add(path.resolve())

	includers = set()
	if changed_headers:
		for bos_path in scripts_root.rglob("*"):
			if bos_path.suffix.lower() == ".bos" and bos_path.resolve() not in changed_bos:
				if includes_of(bos_path) & changed_headers:
					includers.add(bos_path.resolve())

	if not changed_bos and not includers and not failures:
		print("No unit scripts to check.")
		return 0

	print(f"Checking {len(changed_bos)} changed script(s) and {len(includers)} including a changed header.")

	stale = 0
	with tempfile.TemporaryDirectory() as scratch:
		scratch_scripts = Path(scratch) / SCRIPTS_DIR
		shutil.copytree(scripts_root, scratch_scripts)

		for bos_path in sorted(changed_bos) + sorted(includers):
			required = bos_path in changed_bos
			rel = bos_path.relative_to(repo).as_posix()
			level = "error" if required else "warning"

			checked_in = sibling(bos_path, ".cob")
			if checked_in is None:
				annotate(level, rel, "No compiled .cob next to this .bos.")
				failures += required
				stale += not required
				continue

			cob_rel = checked_in.relative_to(repo).as_posix()
			expected = decode(checked_in)
			matched = None
			closest = None  # (diff, label, actual) with the fewest differing lines
			errors = []
			for compiler_dir, label in compilers:
				fresh, log = compile_bos(compiler_dir, scratch / bos_path.relative_to(repo))
				if fresh is None:
					errors.append((label, log))
					continue
				actual = decode(fresh)
				if actual == expected:
					matched = label
					break
				diff = list(difflib.unified_diff(expected, actual, fromfile=cob_rel, tofile=label, lineterm="", n=2))
				if closest is None or len(diff) < len(closest[0]):
					closest = (diff, label, actual)

			if matched:
				print(f"ok: {rel} matches {matched}")
				continue

			if closest is None:
				causes = dict.fromkeys(final_line(log) for _, log in errors)
				annotate(level, rel, "No compiler could compile this script: " + " / ".join(causes))
			elif required:
				annotate("error", cob_rel, f"No compiler reproduces this from {bos_path.name}. {recompile_help}")
			else:
				annotate("warning", cob_rel, f"Stale: no compiler reproduces this from {bos_path.name}. {recompile_help}")
			failures += required
			stale += not required
			if closest:
				for label, log in errors:
					print(f"{label} failed to compile {rel}: {final_line(log)}")
				diff, label, actual = closest
				print(summarize_difference(expected, actual))
				print(f"Closest compile, from {label}:")
				print("\n".join(diff[:DIFF_CONTEXT_LINES]))
				if len(diff) > DIFF_CONTEXT_LINES:
					print(f"... {len(diff) - DIFF_CONTEXT_LINES} more diff lines")

	print(f"\n{failures} changed script(s) failed, {stale} stale script(s) including a changed header.")
	return 1 if failures else 0


if __name__ == "__main__":
	exit_code = main()
	print_unshown_annotations()
	sys.exit(exit_code)
