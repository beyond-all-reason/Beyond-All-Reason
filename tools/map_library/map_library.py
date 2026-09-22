#!/usr/bin/env python3
"""Opt-in, local file-queue bridge between Terraform Brush and a trusted GitHub repo.

Git never checks out repository code, invokes hooks, merges binary maps, or
modifies an existing project. Only explicit publish requests can push.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import threading
import time
import uuid

VERSION = 1
# The build, for the panel: it asks for a restart when an older one is serving.
HELPER_VERSION = 2
MAX_FILE = 95 * 1024 * 1024  # Below GitHub's 100 MiB hard limit; LFS is not implicit.
MAX_PROJECT = 1024 * 1024 * 1024
MAX_FILES = 10000
MAX_CONTROL = 2 * 1024 * 1024
RESERVED = {"con", "prn", "aux", "nul"} | {f"{p}{i}" for p in ("com", "lpt") for i in range(1, 10)}
EXTENSIONS = {".lua", ".png", ".jpg", ".jpeg", ".tga", ".dds", ".bmp", ".json", ".txt", ".md"}
# The team library's folder structure. Fixed, not discovered: these are the only
# places a project may be uploaded or moved to, and the editor draws its tree
# from this list whether or not anything has been put in them yet. The two
# parents ("Map Prototypes", "Texture Pass") exist only as the shared prefix of
# their children -- a project lives in a stage, never in the grouping above it.
# --stage overrides the whole list for a helper pointed at a different library.
DEFAULT_STAGES = [
    "Map Prototypes/Drafts",
    "Map Prototypes/Review",
    "Map Prototypes/Done",
    "Texture Pass/Drafts",
    "Texture Pass/Review",
    "Texture Pass/Done",
    "Other",
]
# Shader library. Syncing writes widget code, so the write targets are an
# allowlist rather than anything the manifest happens to name.
SHADER_EXTENSIONS = EXTENSIONS | {".rml", ".rcss"}
SHADER_ROOT = "LuaUI/Widgets/tileset_dev/"
SHADER_SINGLES = ("LuaUI/Widgets/dev_tileset_terrain.lua", "LuaUI/Widgets/dev_surface_painter.lua")
SHADER_MANIFEST = "manifest.json"
SHADER_MAX_FILES = 5000
SHADER_MAX_TOTAL = 4 * 1024 * 1024 * 1024
LFS_HEADER = b"version https://git-lfs.github.com/spec/v1"


class LibraryError(Exception):
    """A stable error code, translated in-game rather than exposing Git output."""


# What Git's stderr means, as a code the game translates. The text itself is
# never passed on: it can carry a URL with credentials in it.
# SIGN_IN: Git has no GitHub login stored, or GitHub rejected the stored one.
# The helper forbids every prompt, so Git Credential Manager cannot open its
# browser sign-in from here; the user signs in once from a terminal instead.
SIGN_IN = ("cannot prompt because user interactivity", "unable to get password",
           "could not read username", "could not read password", "terminal prompts disabled",
           "authentication failed", " 401")
NO_ACCESS = ("permission denied", "repository not found", "access denied", "not authorized", " 403")
NO_NETWORK = ("could not resolve host", "connection timed out", "connection refused",
              "network is unreachable", "failed to connect", "unable to access",
              "could not connect", "timed out")


def classify_git_error(stderr: bytes) -> str:
    text = stderr.decode("utf-8", errors="replace").lower()
    if any(mark in text for mark in SIGN_IN):
        return "sign_in"
    if any(mark in text for mark in NO_ACCESS):
        return "no_access"
    if any(mark in text for mark in NO_NETWORK):
        return "no_network"
    return "git_failed"


def slug(value: str, depth: int = 4) -> str:
    if not isinstance(value, str) or not value or len(value) > 128:
        raise LibraryError("invalid_path")
    parts = value.split("/")
    if len(parts) > depth:
        raise LibraryError("invalid_path")
    for part in parts:
        if (not re.fullmatch(r"[A-Za-z0-9_ -]{1,64}", part)
                or part != part.strip() or part.lower() in RESERVED):
            raise LibraryError("invalid_path")
    return value


def asset_path(value: str) -> str:
    parts = value.split("/")
    if len(value) > 220 or len(parts) > 12:
        raise LibraryError("invalid_path")
    for part in parts:
        if (not re.fullmatch(r"[A-Za-z0-9_ .-]+", part) or part.startswith(".")
                or part != part.strip() or part.endswith(".")
                or part.split(".")[0].lower() in RESERVED):
            raise LibraryError("invalid_path")
    if Path(value).suffix.lower() not in EXTENSIONS:
        raise LibraryError("unsupported_file")
    return value


def shader_path(value: str) -> str:
    """A repository path a shader sync is allowed to write into the data dir."""
    if not isinstance(value, str) or not value or len(value) > 220:
        raise LibraryError("invalid_path")
    if value not in SHADER_SINGLES and not value.startswith(SHADER_ROOT):
        raise LibraryError("invalid_path")
    parts = value.split("/")
    if len(parts) > 8:
        raise LibraryError("invalid_path")
    for part in parts:
        if (not re.fullmatch(r"[A-Za-z0-9_ .-]+", part) or part.startswith(".")
                or part != part.strip() or part.endswith(".")
                or part.split(".")[0].lower() in RESERVED):
            raise LibraryError("invalid_path")
    if Path(value).suffix.lower() not in SHADER_EXTENSIONS:
        raise LibraryError("unsupported_file")
    return value


def file_digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


# The operator's own roots: the data dir and the helper's state dir. Links above
# them are the operator's business (a Linux home on another drive, /home ->
# /var/home on Fedora Atomic); what must never be a link is anything the helper
# writes through inside them.
TRUSTED_ROOTS: set = set()


def trust_root(path: Path) -> Path:
    root = Path(os.path.abspath(path))
    TRUSTED_ROOTS.add(root)
    return root


def no_links(path: Path) -> None:
    """Reject symlinks AND Windows junctions at `path` or in any ancestor below a
    trusted root; the walk stops at the root itself."""
    for item in (path, *path.parents):
        if item in TRUSTED_ROOTS:
            return
        if item.is_symlink() or (hasattr(item, "is_junction") and item.is_junction()):
            raise LibraryError("unsafe_link")


def atomic_json(path: Path, value: dict) -> None:
    no_links(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    no_links(temporary)
    with temporary.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, ensure_ascii=True, separators=(",", ":"))
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    for attempt in range(5):
        try:
            os.replace(temporary, path)
            return
        except PermissionError:
            # Windows CRT readers may briefly omit FILE_SHARE_DELETE.
            if attempt == 4:
                raise LibraryError("write_failed")
            threading.Event().wait(0.05)


def read_json(path: Path) -> dict:
    no_links(path)
    with path.open("rb") as handle:
        raw = handle.read(MAX_CONTROL + 1)
    if len(raw) > MAX_CONTROL or not raw.endswith(b"\n"):
        raise LibraryError("invalid_request")
    value = json.loads(raw)
    if not isinstance(value, dict):
        raise LibraryError("invalid_request")
    return value


@contextmanager
def exclusive_lock(path: Path):
    """OS-held lock releases on process death; never delete somebody else's lock."""
    no_links(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = path.open("a+b")
    try:
        handle.write(b"0")
        handle.flush()
        handle.seek(0)
        if os.name == "nt":
            import msvcrt
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError as exc:
        handle.close()
        raise LibraryError("already_running") from exc
    try:
        yield
    finally:
        handle.close()


class GitStore:
    """Owned bare mirror of one branch of one remote. No working tree, ever."""

    def __init__(self, data: Path, state: Path, remote: str, branch: str,
                 *, local_test_remote: bool = False):
        self.data, self.state = trust_root(data), trust_root(state)
        if self.state.is_relative_to(self.data) or self.data.is_relative_to(self.state):
            raise LibraryError("unsafe_repository")
        if not local_test_remote and not re.fullmatch(
            r"(?:https://github\.com/|git@github\.com:)[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+", remote
        ):
            raise LibraryError("invalid_remote")
        if not re.fullmatch(r"[A-Za-z0-9_/-]+", branch) or "//" in branch:
            raise LibraryError("invalid_branch")
        self.remote, self.branch = remote, branch
        self.repo = self.state / "objects.git"
        self.local_test_remote = local_test_remote
        for path in (self.state, self.state / "empty-hooks"):
            no_links(path)
            path.mkdir(parents=True, exist_ok=True)
        # A state directory belongs to ONE remote/branch/data-dir, never silently retarget it.
        binding = {"remote": remote, "branch": branch, "data": str(self.data)}
        config = self.state / "binding.json"
        if config.exists() and read_json(config) != binding:
            raise LibraryError("state_mismatch")
        if self.repo.exists() and not config.exists():
            raise LibraryError("unsafe_repository")
        atomic_json(config, binding)
        if not self.repo.exists():
            self.git("init", "--bare", str(self.repo), outside=True)
        no_links(self.repo)
        if self.git("rev-parse", "--is-bare-repository").strip() != b"true":
            raise LibraryError("unsafe_repository")
        self.git("check-ref-format", "refs/heads/" + branch)


    def git(self, *args: str, input_data: bytes | None = None,
            extra_env: dict | None = None, outside: bool = False, check: bool = True) -> bytes:
        # No shell interpolation, inherited GIT_DIR/index injection, checkout filters,
        # hooks, credential prompts or interactive SSH host-key acceptance.
        env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        env.update({"GIT_TERMINAL_PROMPT": "0", "GCM_INTERACTIVE": "never", "GIT_LFS_SKIP_SMUDGE": "1"})
        if extra_env:
            env.update(extra_env)
        command = ["git", "-c", "core.hooksPath=" + str(self.state / "empty-hooks"),
                   "-c", "http.sslVerify=true", "-c", "fetch.fsckObjects=true", "-c", "transfer.fsckObjects=true",
                   "-c", "protocol.ext.allow=never", "-c", "protocol.file.allow=" + ("always" if self.local_test_remote else "never"),
                   "-c", "credential.interactive=false", "-c", "core.sshCommand=ssh -oBatchMode=yes -oStrictHostKeyChecking=yes"]
        if not outside:
            command += ["--git-dir=" + str(self.repo)]
        command += list(args)
        try:
            result = subprocess.run(command, input=input_data, stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE, env=env, timeout=120, check=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise LibraryError("git_unavailable") from exc
        if result.returncode and check:
            raise LibraryError(classify_git_error(result.stderr))
        return result.stdout if result.returncode == 0 else b""

    def fetch(self) -> str:
        previous = self.git("rev-parse", "--verify", "refs/remotes/library", check=False).decode().strip()
        # Git permits non-FF updates outside refs/heads even WITHOUT '+'. Fetch
        # into FETCH_HEAD, then explicitly check ancestry before advancing our cache.
        self.git("fetch", "--no-tags", "--no-recurse-submodules", self.remote,
                 f"refs/heads/{self.branch}")
        head = self.git("rev-parse", "FETCH_HEAD").decode().strip()
        if previous and self.git("merge-base", previous, head, check=False).decode().strip() != previous:
            raise LibraryError("history_rewritten")
        self.git("update-ref", "refs/remotes/library", head)
        return head

    def tree(self, revision: str) -> dict[str, tuple[str, str, int]]:
        output = self.git("ls-tree", "-rlz", revision)
        entries = {}
        folded = {}
        for record in output.split(b"\0"):
            if not record:
                continue
            metadata, raw_path = record.split(b"\t", 1)
            mode, kind, oid, size = metadata.split()
            path = raw_path.decode("utf-8", errors="strict")
            # Symlinks/submodules anywhere in the library fail closed.
            if mode != b"100644" or kind != b"blob":
                raise LibraryError("unsafe_link")
            parts = path.split("/")
            for index in range(1, len(parts) + 1):
                prefix = "/".join(parts[:index])
                previous = folded.setdefault(prefix.casefold(), prefix)
                if previous != prefix:
                    raise LibraryError("case_collision")
            entries[path] = (mode.decode(), oid.decode(), int(size))
            if len(entries) > MAX_FILES * 10:
                raise LibraryError("too_large")
        return entries

    def blob(self, oid: str) -> bytes:
        raw = self.git("cat-file", "blob", oid)
        digest = hashlib.sha1 if len(oid) == 40 else hashlib.sha256
        if digest(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest() != oid:
            raise LibraryError("blob_corrupted")
        if raw.startswith(LFS_HEADER):
            raise LibraryError("lfs_unsupported")
        return raw


class ShaderLibrary(GitStore):
    """Read-only mirror of the tileset shader repository.

    Sync is a per-file diff against what is already on disk, so a shader-only
    release moves a few hundred kilobytes even though the library is ~1.2 GB.
    Nothing is ever deleted: a file the manifest stops listing is left alone.
    """

    def __init__(self, data: Path, state: Path, remote: str, branch: str,
                 *, local_test_remote: bool = False):
        super().__init__(data, state, remote, branch, local_test_remote=local_test_remote)
        self.cache_path = self.state / "disk-digests.json"
        self.cache = read_json(self.cache_path) if self.cache_path.exists() else {}
        self.report = {"configured": True, "remote": remote, "branch": branch,
                       "code": "unchecked", "shader_version": "", "build": 0,
                       "brush_versions": [], "changed": 0, "bytes": 0,
                       "checked": 0, "revision": ""}

    def local_digest(self, relative: str) -> str | None:
        """SHA-256 of the installed file, memoised on (size, mtime)."""
        target = self.data / relative
        try:
            info = target.stat()
        except OSError:
            return None
        key = [info.st_size, info.st_mtime_ns]
        cached = self.cache.get(relative)
        if cached and cached[:2] == key:
            return cached[2]
        no_links(target)
        digest = file_digest(target)
        self.cache[relative] = [info.st_size, info.st_mtime_ns, digest]
        return digest

    def manifest(self, entries: dict) -> dict:
        if SHADER_MANIFEST not in entries:
            raise LibraryError("missing_manifest")
        if entries[SHADER_MANIFEST][2] > MAX_CONTROL:
            raise LibraryError("too_large")
        try:
            document = json.loads(self.blob(entries[SHADER_MANIFEST][1]).decode("utf-8"))
        except (ValueError, UnicodeDecodeError) as exc:
            raise LibraryError("invalid_manifest") from exc
        if not isinstance(document, dict) or document.get("version") != VERSION:
            raise LibraryError("invalid_manifest")
        files = document.get("files")
        if not isinstance(files, list) or not files or len(files) > SHADER_MAX_FILES:
            raise LibraryError("invalid_manifest")
        if not re.fullmatch(r"[0-9]+\.[0-9]+", str(document.get("shader_version", ""))):
            raise LibraryError("invalid_manifest")
        return document

    def plan(self, revision: str) -> tuple[dict, list, int]:
        """(manifest, entries needing a write, total bytes of those entries)."""
        entries = self.tree(revision)
        document = self.manifest(entries)
        delta, total, seen = [], 0, 0
        for record in document["files"]:
            if not isinstance(record, dict):
                raise LibraryError("invalid_manifest")
            relative = shader_path(str(record.get("path", "")))
            digest = str(record.get("sha256", ""))
            if not re.fullmatch(r"[0-9a-f]{64}", digest):
                raise LibraryError("invalid_manifest")
            if relative not in entries:
                raise LibraryError("invalid_manifest")
            _mode, oid, size = entries[relative]
            if size != record.get("size") or size > MAX_FILE:
                raise LibraryError("invalid_manifest")
            seen += size
            if seen > SHADER_MAX_TOTAL:
                raise LibraryError("too_large")
            if self.local_digest(relative) != digest:
                delta.append((relative, oid, size, digest))
                total += size
        return document, delta, total

    def check(self) -> dict:
        revision = self.fetch()
        document, delta, total = self.plan(revision)
        self.report.update(
            code="synced" if not delta else "update",
            shader_version=str(document.get("shader_version", "")),
            build=int(document.get("build") or 0),
            brush_versions=[str(v) for v in document.get("brush_versions", []) if isinstance(v, (str, int))],
            changed=len(delta), bytes=total, checked=time.time(), revision=revision,
        )
        atomic_json(self.cache_path, self.cache)
        return dict(self.report)

    def sync(self) -> dict:
        revision = self.fetch()
        document, delta, total = self.plan(revision)
        written = 0
        for relative, oid, _size, digest in delta:
            raw = self.blob(oid)
            if hashlib.sha256(raw).hexdigest() != digest:
                raise LibraryError("blob_corrupted")
            target = self.data / relative
            no_links(target.parent)
            target.parent.mkdir(parents=True, exist_ok=True)
            temporary = target.with_name(target.name + ".part")
            no_links(temporary)
            with temporary.open("wb") as handle:
                handle.write(raw)
            os.replace(temporary, target)
            self.cache.pop(relative, None)
            self.local_digest(relative)
            written += 1
        atomic_json(self.cache_path, self.cache)
        self.report.update(code="synced", shader_version=str(document.get("shader_version", "")),
                           build=int(document.get("build") or 0),
                           brush_versions=[str(v) for v in document.get("brush_versions", [])
                                           if isinstance(v, (str, int))],
                           changed=0, bytes=0, checked=time.time(), revision=revision)
        return {**self.report, "synced_files": written, "synced_bytes": total}


class Library(GitStore):
    def __init__(self, data: Path, state: Path, remote: str, branch: str,
                 author: str, email: str, stages: list[str], allow_push: bool = False,
                 *, local_test_remote: bool = False):
        # The data dir is a trusted root before anything under it is checked
        # (GitStore registers it too, but only once its own turn comes).
        data = trust_root(data)
        self.bridge = data / "Terraform Brush" / "Map Library"
        self.projects = data / "MapProjects"
        for path in (self.bridge, self.projects):
            no_links(path)
            path.mkdir(parents=True, exist_ok=True)
        if (not re.fullmatch(r"[A-Za-z0-9_ -]{1,32}", author) or not author.strip()
                or not re.fullmatch(r"[^\s<>@]+@[^\s<>@]+", email)):
            raise LibraryError("invalid_identity")
        self.author, self.email = author, email
        # Configured order, not sorted: the list is a pipeline, so Drafts comes
        # before Review comes before Done, the chips draw in that order and a
        # new project defaults to the first stage rather than the alphabetical
        # one. Duplicates drop, the first mention wins.
        self.stages = list(dict.fromkeys(slug(stage, 3) for stage in stages))
        if not self.stages:
            raise LibraryError("invalid_stage")
        self.allow_push = allow_push
        self.session = uuid.uuid4().hex
        self.shader = None
        super().__init__(data, state, remote, branch, local_test_remote=local_test_remote)

    def project_files(self, entries: dict, project: str) -> dict:
        slug(project)
        prefix = project + "/"
        result = {asset_path(path[len(prefix):]): info for path, info in entries.items() if path.startswith(prefix)}
        if "project.lua" not in result:
            raise LibraryError("missing_project")
        if len(result) > MAX_FILES or sum(info[2] for info in result.values()) > MAX_PROJECT:
            raise LibraryError("too_large")
        if any(info[2] > MAX_FILE for info in result.values()):
            raise LibraryError("too_large")
        return result

    def catalog(self, revision: str) -> dict:
        """Describe the library: its fixed folders and every project in it.

        The folder list is exactly the configured one. It used to grow to fit
        whatever the tree happened to contain -- a project's own folder, any
        directory with a .gitkeep in it -- which made the pipeline whatever
        anyone had last uploaded into. The team asked for a fixed structure, so
        `stages` is now a statement of where work is allowed to go, not a
        report of where it has been put. Projects outside it still list (they
        carry their own path), they are simply not destinations any more.
        """
        entries = self.tree(revision)
        projects, stages = [], list(self.stages)
        for path in sorted(entries):
            if not path.endswith("/project.lua"):
                continue
            project = path[:-len("/project.lua")]
            slug(project)
            files = self.project_files(entries, project)
            if files["project.lua"][2] > MAX_CONTROL:
                raise LibraryError("too_large")
            raw = self.blob(files["project.lua"][1]).decode("utf-8")
            # Metadata only. Never execute Lua to list an unreviewed project.
            if not re.search(r'kind\s*=\s*["\']bar-map-project["\']', raw):
                raise LibraryError("missing_project")
            folder, _, name = project.rpartition("/")
            entry = {"slug": project, "folder": folder, "name": name, "revision": revision,
                     "bytes": sum(info[2] for info in files.values())}
            for key in ("size_x", "size_z"):
                match = re.search(r"\b" + key + r"\s*=\s*(\d+)", raw)
                if match:
                    entry[key] = int(match.group(1))
            match = re.search(r'modified\s*=\s*["\']([0-9TZ:-]+)["\']', raw)
            entry["modified"] = match.group(1) if match else ""
            projects.append(entry)
        result = {"version": VERSION, "remote": self.remote, "branch": self.branch,
                  "revision": revision, "projects": projects, "stages": stages,
                  "fetched": time.time()}
        if len(json.dumps(result, ensure_ascii=True).encode()) > MAX_CONTROL:
            raise LibraryError("too_large")
        return result

    def history(self, revision: str, projects: list) -> None:
        """Stamp each catalogue entry with who last changed it and when.

        One walk of the branch, newest first; a project takes the first commit
        that touched anything under it. Only for a commit (publish validates a
        proposed tree through catalog(), and a tree has no history).
        """
        by_prefix = {entry["slug"] + "/": entry for entry in projects}
        if not by_prefix:
            return
        output = self.git("-c", "core.quotepath=false", "log", "-n", "5000", "--no-renames",
                          "--format=%x01%an%x00%ct", "--name-only", revision, check=False)
        author, stamp, pending = "", 0, len(by_prefix)
        for line in output.decode("utf-8", errors="replace").splitlines():
            if line.startswith("\x01"):
                head = line[1:].split("\x00")
                author = head[0][:32]
                stamp = int(head[1]) if len(head) > 1 and head[1].isdigit() else 0
                continue
            if not line:
                continue
            for prefix, entry in by_prefix.items():
                if "author" not in entry and line.startswith(prefix):
                    entry["author"], entry["uploaded"] = author, stamp
                    pending -= 1
            if pending <= 0:
                break

    def refresh(self) -> dict:
        head = self.fetch()
        catalog = self.catalog(head)
        self.history(head, catalog["projects"])
        atomic_json(self.bridge / "catalog.json", catalog)
        return {"code": "pulled", "revision": catalog["revision"]}

    def snapshot(self, source: str, destination: Path) -> dict[str, str]:
        root = self.projects / slug(source)
        no_links(root)
        if not (root / "project.lua").is_file():
            raise LibraryError("missing_project")

        def scan(copy: bool) -> dict[str, str]:
            hashes, total = {}, 0
            folded = set()
            for parent, directories, names in os.walk(root, followlinks=False):
                for name in directories:
                    no_links(Path(parent) / name)
                    if name.startswith("."):
                        raise LibraryError("unsupported_file")
                for name in sorted(names):
                    path = Path(parent) / name
                    no_links(path)
                    if not stat.S_ISREG(path.stat().st_mode):
                        raise LibraryError("unsupported_file")
                    relative = asset_path(path.relative_to(root).as_posix())
                    if relative.casefold() in folded:
                        raise LibraryError("case_collision")
                    folded.add(relative.casefold())
                    size = path.stat().st_size
                    total += size
                    if size > MAX_FILE or total > MAX_PROJECT or len(hashes) >= MAX_FILES:
                        raise LibraryError("too_large")
                    raw = path.read_bytes()
                    if len(raw) != size:
                        raise LibraryError("source_changed")
                    if raw.startswith(LFS_HEADER):
                        raise LibraryError("lfs_unsupported")
                    hashes[relative] = hashlib.sha256(raw).hexdigest()
                    if copy:
                        target = destination / relative
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.write_bytes(raw)
            return hashes

        first = scan(True)
        if "project.lua" not in first:
            raise LibraryError("missing_project")
        if first != scan(False):
            raise LibraryError("source_changed")
        return first

    def check_target(self, entries: dict, target: str) -> None:
        """Refuse a destination that would nest one project inside another.

        A project already at exactly this path is replaced rather than dodged:
        the helper pushes fast-forward only and never rewrites history, so the
        previous version stays reachable in the branch's history and `git
        checkout <sha> -- <path>` brings it back. The old behaviour allocated a
        suffixed copy instead, which never lost anything but left the library
        full of near-duplicate names nobody could tell apart.

        What is NOT negotiable is the shape of the tree: a project inside
        another project has no meaning to the catalogue, so both directions are
        still refused.
        """
        inside = target + "/"
        for path in entries:
            if path.startswith(inside):
                # Under the target. Only the project being replaced may live
                # here; a project nested deeper means the tree is already wrong
                # or this upload would bury someone else's map.
                rest = path[len(inside):]
                if "/" in rest and rest.endswith("/project.lua"):
                    raise LibraryError("invalid_path")
                continue
            if path.endswith("/project.lua"):
                owner = path[: -len("/project.lua")]
                if target.startswith(owner + "/"):
                    raise LibraryError("invalid_path")

    def remove_entries(self, entries: dict, target: str) -> bytearray:
        """Index lines that drop everything currently under `target`.

        An overwrite has to take the old files out in the same commit. Adding
        the new ones over the top would leave whatever the previous version had
        and this one does not -- a stale diffuse tile, a heightmap from two
        shapes ago -- sitting in the project forever.
        """
        index = bytearray()
        inside = target + "/"
        for path in sorted(entries):
            if path.startswith(inside):
                index.extend(b"0 " + b"0" * 40 + b"\t" + path.encode() + b"\0")
        return index

    def publish(self, request: dict) -> dict:
        if not self.allow_push:
            raise LibraryError("read_only")
        request_id = request["id"]
        source = slug(request["source"])
        stage = slug(request["stage"], 3)
        # Stages come from operator configuration or the fetched tree, never a command string.
        catalog = self.catalog(self.fetch())
        if stage not in catalog["stages"]:
            raise LibraryError("invalid_stage")
        journal_path = self.state / (request_id + ".json")
        journal = read_json(journal_path) if journal_path.exists() else {}
        if journal and journal.get("request") != request:
            raise LibraryError("invalid_request")
        snapshot = self.state / (request_id + "-snapshot")
        no_links(snapshot)
        if not journal:
            if snapshot.exists():
                # Incomplete snapshot from an interrupted pre-commit phase is never published.
                raise LibraryError("interrupted")
            snapshot.mkdir()
            hashes = self.snapshot(source, snapshot)
            journal = {"request": request, "hashes": hashes}
            atomic_json(journal_path, journal)
        for _attempt in range(4):
            head = self.fetch()
            if journal.get("commit"):
                ancestor = self.git("merge-base", head, journal["commit"], check=False).decode().strip()
                if ancestor == journal["commit"]:
                    self.refresh()
                    return {"code": "published", "target": journal["target"], "revision": head}
            entries = self.tree(head)
            target = slug(stage + "/" + source.split("/")[-1])
            self.check_target(entries, target)
            replacing = any(path.startswith(target + "/") for path in entries)
            with tempfile.TemporaryDirectory(prefix="index-", dir=self.state) as temporary:
                no_links(Path(temporary))
                env = {"GIT_INDEX_FILE": str(Path(temporary) / "index")}
                self.git("read-tree", head, extra_env=env)
                # Clear the destination first, so a replaced project keeps no
                # files the new version does not have.
                index = self.remove_entries(entries, target)
                for relative, expected in sorted(journal["hashes"].items()):
                    path = snapshot / asset_path(relative)
                    no_links(path)
                    raw = path.read_bytes()
                    if hashlib.sha256(raw).hexdigest() != expected:
                        raise LibraryError("source_changed")
                    oid = self.git("hash-object", "-w", "--stdin", input_data=raw).strip()
                    index.extend(b"100644 " + oid + b"\t" + (target + "/" + relative).encode() + b"\0")
                self.git("update-index", "-z", "--index-info", input_data=bytes(index), extra_env=env)
                tree = self.git("write-tree", extra_env=env).decode().strip()
                # Validate the proposed tree BEFORE pushing. This also catches a
                # configured stage whose casing aliases an existing repository folder.
                self.catalog(tree)
                identity = {"GIT_AUTHOR_NAME": self.author, "GIT_COMMITTER_NAME": self.author,
                            "GIT_AUTHOR_EMAIL": self.email, "GIT_COMMITTER_EMAIL": self.email}
                verb = "Update" if replacing else "Add"
                commit = self.git("-c", "commit.gpgSign=false", "commit-tree", tree, "-p", head,
                                  input_data=f"{verb} map project {target}\n\n"
                                             f"Map-Library-Request: {request_id}\n".encode(),
                                  extra_env=identity).decode().strip()
            journal.update({"commit": commit, "target": target})
            self.git("update-ref", "refs/library-pending/" + request_id, commit)
            atomic_json(journal_path, journal)  # Before push: a lost acknowledgement is recoverable.
            self.git("push", "--porcelain", "--no-verify", "--recurse-submodules=no", self.remote,
                     commit + ":refs/heads/" + self.branch, check=False)
            # A normal fast-forward push is the concurrency guard. Re-fetch and
            # reconstruct on rejection; never rebase/merge/force-push map binaries.
        head = self.fetch()
        if self.git("merge-base", head, journal["commit"], check=False).decode().strip() == journal["commit"]:
            self.refresh()
            return {"code": "published", "target": journal["target"], "revision": head}
        raise LibraryError("push_rejected")

    def move(self, request: dict) -> dict:
        """Move a published project into another pipeline folder.

        This is the one operation that removes anything from the remote, so it
        is fenced in tightly. It only ever deletes paths under `source + "/"`,
        and it re-adds every one of those blobs unchanged under the destination,
        so the commit is a pure rename: the tree outside the project is copied
        from HEAD untouched. Both ends are slug()-validated, the source has to
        be a project the catalogue knows, the destination has to be a configured
        pipeline folder, and check_target refuses a destination that would nest
        one project inside another or alias an existing path by case. The source
        deliberately does NOT have to be in a configured folder: moving work out
        of somewhere that is no longer part of the pipeline and into somewhere
        that is exactly the job, and the destination is what bounds this.
        The proposed tree is validated before the
        push, and the push is the same fast-forward-only one publish uses -- no
        rebase, no merge, no force. Replay is safe: the journal records the
        commit, and a rerun that finds it already an ancestor of HEAD reports
        success instead of moving anything a second time.
        """
        if not self.allow_push:
            raise LibraryError("read_only")
        request_id = request["id"]
        source = slug(request["source"])
        stage = slug(request["stage"], 3)
        catalog = self.catalog(self.fetch())
        if stage not in catalog["stages"]:
            raise LibraryError("invalid_stage")
        # The catalogue is the fence on this end: a published project can be
        # moved, anything else in the repository is not the helper's to touch.
        if source not in {entry["slug"] for entry in catalog["projects"]}:
            raise LibraryError("missing_project")
        parent, _, leaf = source.rpartition("/")
        # A move may rename: `name` is the new leaf, the old one otherwise.
        name = request.get("name") or leaf
        if not isinstance(name, str) or "/" in name:
            raise LibraryError("invalid_path")
        slug(name, 1)
        if parent == stage and name == leaf:
            raise LibraryError("invalid_request")
        journal_path = self.state / (request_id + ".json")
        journal = read_json(journal_path) if journal_path.exists() else {}
        if journal and journal.get("request") != request:
            raise LibraryError("invalid_request")
        for _attempt in range(4):
            head = self.fetch()
            if journal.get("commit"):
                ancestor = self.git("merge-base", head, journal["commit"], check=False).decode().strip()
                if ancestor == journal["commit"]:
                    self.refresh()
                    return {"code": "moved", "target": journal["target"], "revision": head}
            entries = self.tree(head)
            # Raises missing_project when the source is gone (someone else moved
            # or removed it), rather than committing an empty rename.
            files = self.project_files(entries, source)
            target = slug(stage + "/" + name)
            self.check_target(entries, target)
            with tempfile.TemporaryDirectory(prefix="index-", dir=self.state) as temporary:
                no_links(Path(temporary))
                env = {"GIT_INDEX_FILE": str(Path(temporary) / "index")}
                self.git("read-tree", head, extra_env=env)
                # Anything already at the destination goes, then the project's
                # own blobs are re-added there.
                index = self.remove_entries(entries, target)
                for relative in sorted(files):
                    mode, oid, _size = files[relative]
                    # Mode 0 removes the old path; the same blob goes back in at
                    # the new one, so no content is rewritten and none is lost.
                    index.extend(b"0 " + b"0" * 40 + b"\t" + (source + "/" + relative).encode() + b"\0")
                    index.extend(mode.encode() + b" " + oid.encode() + b"\t"
                                 + (target + "/" + relative).encode() + b"\0")
                self.git("update-index", "-z", "--index-info", input_data=bytes(index), extra_env=env)
                tree = self.git("write-tree", extra_env=env).decode().strip()
                # Validate the proposed tree BEFORE pushing, exactly as publish
                # does: this catches a destination whose casing aliases an
                # existing folder, and any project the rename would have nested.
                moved_catalog = self.catalog(tree)
                if any(entry["slug"] == source for entry in moved_catalog["projects"]):
                    raise LibraryError("invalid_request")
                if not any(entry["slug"] == target for entry in moved_catalog["projects"]):
                    raise LibraryError("missing_project")
                identity = {"GIT_AUTHOR_NAME": self.author, "GIT_COMMITTER_NAME": self.author,
                            "GIT_AUTHOR_EMAIL": self.email, "GIT_COMMITTER_EMAIL": self.email}
                message = (f"Move map project {source} to {target}\n\n"
                           f"Map-Library-Request: {request_id}\n").encode()
                commit = self.git("-c", "commit.gpgSign=false", "commit-tree", tree, "-p", head,
                                  input_data=message, extra_env=identity).decode().strip()
            journal.update({"request": request, "commit": commit, "target": target})
            self.git("update-ref", "refs/library-pending/" + request_id, commit)
            atomic_json(journal_path, journal)  # Before push: a lost acknowledgement is recoverable.
            self.git("push", "--porcelain", "--no-verify", "--recurse-submodules=no", self.remote,
                     commit + ":refs/heads/" + self.branch, check=False)
        head = self.fetch()
        if self.git("merge-base", head, journal["commit"], check=False).decode().strip() == journal["commit"]:
            self.refresh()
            return {"code": "moved", "target": journal["target"], "revision": head}
        raise LibraryError("push_rejected")

    def remove(self, request: dict) -> dict:
        """Delete one published project from the library.

        Destructive by intent, so it is bounded the same way move is: push
        permission required, the target has to be a project the catalogue
        already knows, and the commit only ever drops paths under `target/`.
        The rest of the tree is carried over from HEAD untouched, the push stays
        fast-forward only, and every deleted file remains reachable in the
        branch's history -- `git checkout <sha> -- <path>` is the undo.

        A folder is not a target. The structure is fixed (see DEFAULT_STAGES),
        so there is no folder here that anyone is entitled to delete, and
        emptying one a project at a time is the same work done visibly.
        """
        if not self.allow_push:
            raise LibraryError("read_only")
        request_id = request["id"]
        target = slug(request["source"])
        catalog = self.catalog(self.fetch())
        known = {entry["slug"] for entry in catalog["projects"]}
        if target not in known:
            raise LibraryError("missing_project")
        journal_path = self.state / (request_id + ".json")
        journal = read_json(journal_path) if journal_path.exists() else {}
        if journal and journal.get("request") != request:
            raise LibraryError("invalid_request")
        for _attempt in range(4):
            head = self.fetch()
            if journal.get("commit"):
                ancestor = self.git("merge-base", head, journal["commit"], check=False).decode().strip()
                if ancestor == journal["commit"]:
                    self.refresh()
                    return {"code": "removed", "target": target, "revision": head}
            entries = self.tree(head)
            index = self.remove_entries(entries, target)
            if not index:
                # Someone else already removed it; that is the requested state.
                self.refresh()
                return {"code": "removed", "target": target, "revision": head}
            count = sum(1 for path in entries if path.startswith(target + "/") and path.endswith("/project.lua"))
            count += 1 if (target + "/project.lua") in entries else 0
            with tempfile.TemporaryDirectory(prefix="index-", dir=self.state) as temporary:
                no_links(Path(temporary))
                env = {"GIT_INDEX_FILE": str(Path(temporary) / "index")}
                self.git("read-tree", head, extra_env=env)
                self.git("update-index", "-z", "--index-info", input_data=bytes(index), extra_env=env)
                tree = self.git("write-tree", extra_env=env).decode().strip()
                # Same pre-push validation as every other write.
                self.catalog(tree)
                identity = {"GIT_AUTHOR_NAME": self.author, "GIT_COMMITTER_NAME": self.author,
                            "GIT_AUTHOR_EMAIL": self.email, "GIT_COMMITTER_EMAIL": self.email}
                message = (f"Remove {target} from the map library\n\n"
                           f"Projects removed: {count}\n"
                           f"Map-Library-Request: {request_id}\n").encode()
                commit = self.git("-c", "commit.gpgSign=false", "commit-tree", tree, "-p", head,
                                  input_data=message, extra_env=identity).decode().strip()
            journal.update({"request": request, "commit": commit, "target": target})
            self.git("update-ref", "refs/library-pending/" + request_id, commit)
            atomic_json(journal_path, journal)
            self.git("push", "--porcelain", "--no-verify", "--recurse-submodules=no", self.remote,
                     commit + ":refs/heads/" + self.branch, check=False)
        head = self.fetch()
        if self.git("merge-base", head, journal["commit"], check=False).decode().strip() == journal["commit"]:
            self.refresh()
            return {"code": "removed", "target": journal["target"], "revision": head}
        raise LibraryError("push_rejected")

    def download(self, request: dict) -> dict:
        catalog = read_json(self.bridge / "catalog.json")
        if (request.get("revision") != catalog.get("revision") or catalog.get("remote") != self.remote
            or catalog.get("branch") != self.branch):
            raise LibraryError("stale_catalog")
        project = slug(request["source"])
        if project not in {entry["slug"] for entry in catalog["projects"]}:
            raise LibraryError("missing_project")
        entries = self.project_files(self.tree(catalog["revision"]), project)
        # The local copy lands at the repository's own path, so both sides share
        # one structure and a team project is recognisable as the same project
        # locally. A copy already there is replaced: the editor refuses to
        # download over the project it currently has open, and every other
        # version is still in the branch's history.
        local_slug = slug(project)
        destination = self.projects / local_slug
        no_links(destination)
        with tempfile.TemporaryDirectory(prefix="download-", dir=self.state) as temporary:
            staging = Path(temporary)
            for relative, (_mode, oid, _size) in entries.items():
                path = staging / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(self.blob(oid))
            # Staged in full first, so a transfer that fails part way cannot
            # leave a half-replaced project behind. The manifest is written last:
            # until it lands the folder does not list as a project at all.
            previous = destination.with_name(destination.name + ".replacing")
            if destination.exists():
                no_links(destination)
                if previous.exists():
                    shutil.rmtree(previous)
                destination.rename(previous)
            try:
                destination.mkdir(parents=True)
                for relative in sorted(entries, key=lambda value: value == "project.lua"):
                    target = destination / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with target.open("xb") as handle:
                        handle.write((staging / relative).read_bytes())
            except Exception:
                # Put the old copy back rather than leaving nothing at the path.
                if previous.exists():
                    if destination.exists():
                        shutil.rmtree(destination)
                    previous.rename(destination)
                raise
            if previous.exists():
                self.retire(previous, local_slug)
        return {"code": "downloaded", "local_slug": local_slug}

    def retire(self, previous: Path, local_slug: str) -> None:
        """Keep the copy a download replaced, under MapProjects/_replaced.

        Newest three per project. The editor's browser skips that folder, so
        the copies are there for a hand recovery and never list as projects.
        """
        keep = self.projects / "_replaced"
        no_links(keep)
        keep.mkdir(parents=True, exist_ok=True)
        key = local_slug.replace("/", "__")
        stamp = time.strftime("%Y%m%d-%H%M%S", time.gmtime())
        target = keep / f"{key}-{stamp}"
        suffix = 0
        while target.exists():
            suffix += 1
            target = keep / f"{key}-{stamp}-{suffix}"
        previous.rename(target)
        older = sorted(path for path in keep.iterdir() if path.is_dir() and path.name.startswith(key + "-"))
        for path in older[:-3]:
            shutil.rmtree(path)

    def process(self, request: dict) -> dict:
        if (request.get("version") != VERSION or not re.fullmatch(r"[a-f0-9]{16,64}", str(request.get("id", "")))
                or request.get("operation") not in {"pull", "publish", "download", "move", "remove",
                                                    "shader_check", "shader_sync"}):
            raise LibraryError("invalid_request")
        completed = self.state / (request["id"] + "-result.json")
        if completed.exists() and not str(request.get("operation", "")).startswith("shader_"):
            saved = read_json(completed)
            if saved["request"] != request:
                raise LibraryError("invalid_request")
            return saved["result"]
        if request.get("session") != self.session:
            raise LibraryError("interrupted")
        if request["operation"] in ("shader_check", "shader_sync"):
            if self.shader is None:
                raise LibraryError("shader_not_configured")
            # Never cached as a completed result: the answer is about disk state,
            # which moves on its own, so a replay must re-examine it.
            report = (self.shader.check() if request["operation"] == "shader_check"
                      else self.shader.sync())
            return {"code": "shader_" + report["code"], "shader": report}
        if request["operation"] == "pull":
            result = self.refresh()
        elif request["operation"] == "publish":
            result = self.publish(request)
        elif request["operation"] == "move":
            result = self.move(request)
        elif request["operation"] == "remove":
            result = self.remove(request)
        else:
            result = self.download(request)
        atomic_json(completed, {"request": request, "result": result})
        return result

    def _startup(self) -> dict:
        """Answer "is my shader current?" and "what is in the library?" before
        the panel ever asks: the connection is the moment both matter."""
        if self.shader is not None:
            try:
                self.shader.check()
            except LibraryError as exc:
                self.shader.report.update(code=str(exc), checked=time.time())
            except Exception:
                self.shader.report.update(code="helper_error", checked=time.time())
        return self.refresh()

    def serve(self, stop: threading.Event | None = None) -> None:
        status = {"version": VERSION, "session": self.session, "remote": self.remote,
                  "branch": self.branch, "allow_push": self.allow_push, "stages": self.stages,
                  "busy": False, "code": "ready", "request_id": "", "started": time.time(),
                  "last_pull": 0, "helper": HELPER_VERSION,
                  "shader": dict(self.shader.report) if self.shader else {"configured": False}}
        request_path = self.bridge / "request.json"
        stop = stop or threading.Event()
        future = None
        # Whether the running future was started for a request in the mailbox.
        # The startup work is not, and its completion must not take a request
        # that arrived meanwhile out of the mailbox unprocessed.
        consumes = False
        with ThreadPoolExecutor(max_workers=1) as worker:
            # Pull once (and check the shader) before the panel asks: the
            # connection is the moment the library on screen should be today's.
            future = worker.submit(self._startup)
            status.update(busy=True, code="working")
            try:
                while not stop.is_set():
                    if future is not None and future.done():
                        try:
                            status.update(future.result())
                        except LibraryError as exc:
                            status.update(code=str(exc))
                        except Exception:
                            status.update(code="helper_error")
                        if self.shader is not None:
                            status["shader"] = dict(self.shader.report)
                        if status.get("code") in ("pulled", "published", "moved", "removed"):
                            status["last_pull"] = time.time()
                        status["busy"] = False
                        print(("%s %s %s" % (time.strftime("%H:%M"), status.get("code", ""),
                                             status.get("target") or status.get("local_slug") or "")).rstrip())
                        # Publish acknowledgement first; readers never see an idle gap
                        # between removing their request and receiving its outcome.
                        atomic_json(self.bridge / "status.json", {**status, "heartbeat": time.time()})
                        if consumes:
                            request_path.unlink(missing_ok=True)
                        future, consumes = None, False
                    if future is None and request_path.exists():
                        try:
                            request = read_json(request_path)
                        except (ValueError, LibraryError):
                            request = None  # Lua may still be writing; only newline-terminated JSON is ready.
                        if request is not None:
                            status.update(busy=True, code="working", request_id=str(request.get("id", "")),
                                          local_slug="", target="")
                            future, consumes = worker.submit(self.process, request), True
                    atomic_json(self.bridge / "status.json", {**status, "heartbeat": time.time()})
                    stop.wait(1)
            except KeyboardInterrupt:
                # Wait for the bounded Git operation; never abandon it while advertising idle.
                print("Stopping after current operation completes.")
            finally:
                if future is not None:
                    try:
                        status.update(future.result())
                    except Exception:
                        status.update(code="interrupted")
                atomic_json(self.bridge / "status.json", {**status, "heartbeat": 0, "busy": False})


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    if sys.version_info < (3, 12):
        parser.error("Python 3.12+ is required (including Windows junction detection).")
    parser.add_argument("--data-dir", type=Path, required=True, help="BAR writable data directory (contains MapProjects)")
    parser.add_argument("--remote", required=True, help="Trusted private github.com HTTPS or SSH URL; no embedded credentials")
    parser.add_argument("--branch", default="main")
    parser.add_argument("--author", required=True, help="Short contributor name used in commits and conflict-copy names")
    parser.add_argument("--email", required=True, help="Git commit email; a GitHub noreply address is supported")
    parser.add_argument("--stage", action="append", help="Pipeline folder, repeatable; nested folders use /")
    parser.add_argument("--state-dir", type=Path, help="Dedicated private helper storage, OUTSIDE MapProjects and game repos")
    parser.add_argument("--allow-push", action="store_true", help="Explicitly allow confirmed in-game uploads for this helper session")
    parser.add_argument("--shader-remote", help="Trusted private repository holding the tileset shader and its textures")
    parser.add_argument("--shader-branch", default="main")
    args = parser.parse_args()
    key = hashlib.sha256((str(args.data_dir.absolute()) + args.remote + args.branch).encode()).hexdigest()[:16]
    state = args.state_dir or Path.home() / ".bar-map-library" / key
    # The key above keeps the raw argument so existing state dirs stay bound;
    # the lock lives inside the data dir, which is a trusted root from here on.
    data = trust_root(args.data_dir)
    try:
        # Lock belongs to the data directory, not remote: two helpers cannot consume
        # the same game queue even if configured with different repository URLs.
        with exclusive_lock(data / "Terraform Brush" / "Map Library" / "service.lock"):
            library = Library(args.data_dir, state, args.remote, args.branch, args.author, args.email,
                              args.stage or DEFAULT_STAGES, args.allow_push)
            if args.shader_remote:
                shader_key = hashlib.sha256(
                    (str(args.data_dir.absolute()) + args.shader_remote + args.shader_branch).encode()
                ).hexdigest()[:16]
                library.shader = ShaderLibrary(args.data_dir, Path.home() / ".bar-map-library" / shader_key,
                                               args.shader_remote, args.shader_branch)
            print("Team Sync for Terraform Brush")
            print(f"Library: {args.remote} [{args.branch}] - {'uploads on' if args.allow_push else 'read only'}")
            if args.shader_remote:
                print(f"Shader:  {args.shader_remote} [{args.shader_branch}] - read only")
            print("Leave this window open while you work. Ctrl+C stops it.")
            library.serve()
    except LibraryError as exc:
        parser.exit(1, f"Team Sync stopped: {exc}. See the README's troubleshooting table.\n")


if __name__ == "__main__":
    main()