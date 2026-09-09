#!/usr/bin/env python3
"""Opt-in, local file-queue bridge between Terraform Brush and a trusted GitHub repo.

Git never checks out repository code, invokes hooks, merges binary maps, or
modifies an existing project. Only explicit publish requests can push.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import threading
import time
import uuid

VERSION = 1
MAX_FILE = 95 * 1024 * 1024  # Below GitHub's 100 MiB hard limit; LFS is not implicit.
MAX_PROJECT = 1024 * 1024 * 1024
MAX_FILES = 10000
MAX_CONTROL = 2 * 1024 * 1024
RESERVED = {"con", "prn", "aux", "nul"} | {f"{p}{i}" for p in ("com", "lpt") for i in range(1, 10)}
EXTENSIONS = {".lua", ".png", ".jpg", ".jpeg", ".tga", ".dds", ".bmp", ".json", ".txt", ".md"}
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


def no_links(path: Path) -> None:
    """Reject symlinks AND Windows junctions, including any existing ancestor."""
    for item in (path, *path.parents):
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
        self.data, self.state = Path(os.path.abspath(data)), Path(os.path.abspath(state))
        no_links(self.data)
        no_links(self.state)
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
            raise LibraryError("git_failed")
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
        self.bridge = Path(os.path.abspath(data)) / "Terraform Brush" / "Map Library"
        self.projects = Path(os.path.abspath(data)) / "MapProjects"
        for path in (self.bridge, self.projects):
            no_links(path)
            path.mkdir(parents=True, exist_ok=True)
        if (not re.fullmatch(r"[A-Za-z0-9_ -]{1,32}", author) or not author.strip()
                or not re.fullmatch(r"[^\s<>@]+@[^\s<>@]+", email)):
            raise LibraryError("invalid_identity")
        self.author, self.email = author, email
        self.stages = sorted(set(slug(stage, 3) for stage in stages))
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
        entries = self.tree(revision)
        projects, stages = [], set(self.stages)
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
            if folder:
                stages.add(slug(folder, 3))
            entry = {"slug": project, "folder": folder, "name": name, "revision": revision}
            for key in ("size_x", "size_z"):
                match = re.search(r"\b" + key + r"\s*=\s*(\d+)", raw)
                if match:
                    entry[key] = int(match.group(1))
            match = re.search(r'modified\s*=\s*["\']([0-9TZ:-]+)["\']', raw)
            entry["modified"] = match.group(1) if match else ""
            projects.append(entry)
        # Preserve empty pipeline directories tracked using .gitkeep.
        for path in entries:
            if path.endswith("/.gitkeep"):
                stages.add(slug(path[:-len("/.gitkeep")], 3))
        result = {"version": VERSION, "remote": self.remote, "branch": self.branch,
                  "revision": revision, "projects": projects, "stages": sorted(stages)}
        if len(json.dumps(result, ensure_ascii=True).encode()) > MAX_CONTROL:
            raise LibraryError("too_large")
        return result

    def refresh(self) -> dict:
        catalog = self.catalog(self.fetch())
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

    def unique_target(self, entries: dict, target: str, request_id: str) -> str:
        def occupied(candidate: str) -> bool:
            candidate = candidate.casefold()
            for path in entries:
                path = path.casefold()
                if path == candidate or path.startswith(candidate + "/") or candidate.startswith(path + "/"):
                    return True
                # A project cannot be nested inside another project.
                if path.endswith("/project.lua") and candidate.startswith(path[:-len("project.lua")]):
                    return True
            return False

        if not occupied(target):
            return target
        parent, _, name = target.rpartition("/")
        suffix = "--" + self.author.strip().replace(" ", "-")[:12] + "-" + datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S") + "-" + request_id[:8]
        budget = min(64, 128 - len(parent) - 1) - len(suffix)
        if budget < 1:
            raise LibraryError("invalid_path")
        candidate = slug(parent + "/" + name[:budget].rstrip() + suffix)
        if occupied(candidate):
            raise LibraryError("name_collision")
        return candidate

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
            target = self.unique_target(entries, slug(stage + "/" + source.split("/")[-1]), request_id)
            with tempfile.TemporaryDirectory(prefix="index-", dir=self.state) as temporary:
                no_links(Path(temporary))
                env = {"GIT_INDEX_FILE": str(Path(temporary) / "index")}
                self.git("read-tree", head, extra_env=env)
                index = bytearray()
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
                commit = self.git("-c", "commit.gpgSign=false", "commit-tree", tree, "-p", head,
                                  input_data=f"Add map project {target}\n\nMap-Library-Request: {request_id}\n".encode(),
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

    def download(self, request: dict) -> dict:
        catalog = read_json(self.bridge / "catalog.json")
        if (request.get("revision") != catalog.get("revision") or catalog.get("remote") != self.remote
            or catalog.get("branch") != self.branch):
            raise LibraryError("stale_catalog")
        project = slug(request["source"])
        if project not in {entry["slug"] for entry in catalog["projects"]}:
            raise LibraryError("missing_project")
        entries = self.project_files(self.tree(catalog["revision"]), project)
        # A fresh, editable local copy. Never replace the project currently open in-game.
        name = project.split("/")[-1][:40].rstrip() + "--" + request["id"][:12]
        local_slug = slug(name)
        destination = self.projects / local_slug
        no_links(destination)
        if any(path.name.casefold() == name.casefold() for path in self.projects.iterdir()):
            raise LibraryError("name_collision")
        with tempfile.TemporaryDirectory(prefix="download-", dir=self.state) as temporary:
            staging = Path(temporary)
            for relative, (_mode, oid, _size) in entries.items():
                path = staging / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(self.blob(oid))
            # Exclusive directory creation + manifest last means partial downloads do
            # not list. On failure the partial folder remains for manual inspection.
            try:
                destination.mkdir()
            except FileExistsError as exc:
                raise LibraryError("name_collision") from exc
            for relative in sorted(entries, key=lambda value: value == "project.lua"):
                target = destination / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                with target.open("xb") as handle:
                    handle.write((staging / relative).read_bytes())
        return {"code": "downloaded", "local_slug": local_slug}

    def process(self, request: dict) -> dict:
        if (request.get("version") != VERSION or not re.fullmatch(r"[a-f0-9]{16,64}", str(request.get("id", "")))
                or request.get("operation") not in {"pull", "publish", "download",
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
        else:
            result = self.download(request)
        atomic_json(completed, {"request": request, "result": result})
        return result

    def _startup_shader_check(self) -> dict:
        try:
            self.shader.check()
        except LibraryError as exc:
            self.shader.report.update(code=str(exc), checked=time.time())
        except Exception:
            self.shader.report.update(code="helper_error", checked=time.time())
        return {"code": "ready"}

    def serve(self, stop: threading.Event | None = None) -> None:
        status = {"version": VERSION, "session": self.session, "remote": self.remote,
                  "branch": self.branch, "allow_push": self.allow_push, "stages": self.stages,
                  "busy": False, "code": "ready", "request_id": "",
                  "shader": dict(self.shader.report) if self.shader else {"configured": False}}
        request_path = self.bridge / "request.json"
        stop = stop or threading.Event()
        future = None
        with ThreadPoolExecutor(max_workers=1) as worker:
            if self.shader is not None:
                # Answer "is my shader current?" before the panel ever asks.
                future = worker.submit(self._startup_shader_check)
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
                        status["busy"] = False
                        # Publish acknowledgement first; readers never see an idle gap
                        # between removing their request and receiving its outcome.
                        atomic_json(self.bridge / "status.json", {**status, "heartbeat": time.time()})
                        request_path.unlink(missing_ok=True)
                        future = None
                    if future is None and request_path.exists():
                        try:
                            request = read_json(request_path)
                        except (ValueError, LibraryError):
                            request = None  # Lua may still be writing; only newline-terminated JSON is ready.
                        if request is not None:
                            status.update(busy=True, code="working", request_id=str(request.get("id", "")),
                                          local_slug="", target="")
                            future = worker.submit(self.process, request)
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
    try:
        # Lock belongs to the data directory, not remote: two helpers cannot consume
        # the same game queue even if configured with different repository URLs.
        with exclusive_lock(args.data_dir / "Terraform Brush" / "Map Library" / "service.lock"):
            library = Library(args.data_dir, state, args.remote, args.branch, args.author, args.email,
                              args.stage or ["01 Design pass", "02 Texture pass", "03 Gameplay pass", "04 Review"], args.allow_push)
            if args.shader_remote:
                shader_key = hashlib.sha256(
                    (str(args.data_dir.absolute()) + args.shader_remote + args.shader_branch).encode()
                ).hexdigest()[:16]
                library.shader = ShaderLibrary(args.data_dir, Path.home() / ".bar-map-library" / shader_key,
                                               args.shader_remote, args.shader_branch)
            print(f"Map library: {args.remote} [{args.branch}] - {'uploads enabled' if args.allow_push else 'read only'}")
            if args.shader_remote:
                print(f"Shader library: {args.shader_remote} [{args.shader_branch}] - read only")
            print("Use Terraform Brush > File > Open Project. Ctrl+C stops the helper.")
            library.serve()
    except LibraryError as exc:
        parser.exit(1, f"Map library stopped: {exc}. See README troubleshooting.\n")


if __name__ == "__main__":
    main()