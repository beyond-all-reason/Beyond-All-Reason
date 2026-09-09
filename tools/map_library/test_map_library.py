"""Real-Git integration tests. All repositories/data are temporary; no network."""

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib
import json
import os
import subprocess
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
import uuid

import map_library as ml

MANIFEST = b'return { kind = "bar-map-project", format_version = 1, name = "arena", map = { size_x = 8, size_z = 8 }, sections = {} }\n'


def git(cwd, *args):
    environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    environment.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
    result = subprocess.run(["git", "-C", str(cwd), "-c", "core.hooksPath=" + str(Path(cwd) / "no-hooks"),
                             "-c", "commit.gpgSign=false", *args], check=True, env=environment,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return result.stdout.decode().strip()


class LibraryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.remote = self.root / "remote.git"
        git(self.root, "init", "--bare", str(self.remote))
        seed = self.root / "seed"
        seed.mkdir()
        git(seed, "init", "-b", "main")
        git(seed, "config", "user.name", "Test")
        git(seed, "config", "user.email", "test@example.invalid")
        (seed / "README.md").write_text("Private map project library test fixture\n", encoding="utf-8")
        (seed / "02 Texture pass").mkdir()
        (seed / "02 Texture pass" / ".gitkeep").touch()
        git(seed, "add", ".")
        git(seed, "commit", "-m", "Initialize library")
        git(seed, "push", str(self.remote), "main")
        self.seed = seed
        self.alice = self.client("Alice")
        self.bob = self.client("Bob")

    def client(self, name):
        return ml.Library(self.root / (name + "-data"), self.root / (name + "-state"),
                          str(self.remote), "main", name, name.lower() + "@example.invalid",
                          ["01 Design pass"], True, local_test_remote=True)

    def project(self, client, source="arena", payload=b"original"):
        folder = client.projects / source
        folder.mkdir(parents=True)
        (folder / "project.lua").write_bytes(MANIFEST)
        (folder / "heightmap.png").write_bytes(payload)
        return folder

    def request(self, client, operation="publish", source="arena", **extras):
        return {"id": uuid.uuid4().hex, "version": 1, "session": client.session,
                "operation": operation, "source": source, "stage": "01 Design pass", **extras}

    def remote_files(self):
        return self.alice.tree(self.alice.fetch())

    def test_pull_preserves_local_files_and_reports_pipeline(self):
        source = self.project(self.alice)
        before = (source / "heightmap.png").read_bytes()
        self.alice.process(self.request(self.alice, "pull"))
        catalog = ml.read_json(self.alice.bridge / "catalog.json")
        self.assertIn("02 Texture pass", catalog["stages"])
        self.assertEqual(before, (source / "heightmap.png").read_bytes())

    def test_publish_is_additive_and_preserves_unrelated_files(self):
        source = self.project(self.alice)
        result = self.alice.process(self.request(self.alice))
        files = self.remote_files()
        self.assertEqual(result["target"], "01 Design pass/arena")
        self.assertIn("README.md", files)
        self.assertEqual(b"original", self.alice.blob(files[result["target"] + "/heightmap.png"][1]))
        self.assertEqual(b"original", (source / "heightmap.png").read_bytes())

    def test_concurrent_same_name_uploads_keep_both_binary_maps(self):
        self.project(self.alice, payload=b"alice terrain")
        self.project(self.bob, payload=b"bob terrain")
        barrier = threading.Barrier(2)

        def racing(client):
            original = client.git
            first = True

            def intercept(*args, **kwargs):
                nonlocal first
                if args[0] == "push" and first:
                    first = False
                    barrier.wait(timeout=30)
                return original(*args, **kwargs)

            with patch.object(client, "git", side_effect=intercept):
                return client.process(self.request(client))

        with ThreadPoolExecutor(max_workers=2) as pool:
            one = pool.submit(racing, self.alice)
            two = pool.submit(racing, self.bob)
            results = [one.result(timeout=90), two.result(timeout=90)]
        targets = {result["target"] for result in results}
        self.assertEqual(2, len(targets))
        self.assertIn("01 Design pass/arena", targets)
        renamed = next(target for target in targets if target != "01 Design pass/arena")
        self.assertRegex(renamed, r"arena--(Alice|Bob)-\d{8}-\d{6}-[a-f0-9]+$")
        files = self.remote_files()
        contents = {self.alice.blob(files[target + "/heightmap.png"][1]) for target in targets}
        self.assertEqual({b"alice terrain", b"bob terrain"}, contents)
        self.assertEqual("3", git(self.remote, "rev-list", "--count", "main"))

    def test_case_insensitive_name_collision_renames(self):
        self.project(self.alice, "Arena")
        self.project(self.bob, "arena")
        self.alice.process(self.request(self.alice, source="Arena"))
        result = self.bob.process(self.request(self.bob))
        self.assertIn("arena--Bob-", result["target"])

    def test_duplicate_completed_request_never_pushes_twice(self):
        self.project(self.alice)
        request = self.request(self.alice)
        result = self.alice.process(request)
        self.assertEqual(result, self.alice.process(request))
        self.assertEqual("2", git(self.remote, "rev-list", "--count", "main"))

    def test_lost_push_acknowledgement_is_recovered_without_duplicate(self):
        self.project(self.alice)
        request = self.request(self.alice)
        original = self.alice.git

        def lose_ack(*args, **kwargs):
            result = original(*args, **kwargs)
            if args[0] == "push":
                raise ml.LibraryError("git_unavailable")
            return result

        with patch.object(self.alice, "git", side_effect=lose_ack):
            with self.assertRaisesRegex(ml.LibraryError, "git_unavailable"):
                self.alice.process(request)
        self.assertEqual("published", self.alice.process(request)["code"])
        self.assertEqual("2", git(self.remote, "rev-list", "--count", "main"))

    def test_rejected_push_retains_snapshot_and_does_not_change_remote(self):
        self.project(self.alice)
        request = self.request(self.alice)
        original = self.alice.git

        def reject(*args, **kwargs):
            return b"" if args[0] == "push" else original(*args, **kwargs)

        with patch.object(self.alice, "git", side_effect=reject):
            with self.assertRaisesRegex(ml.LibraryError, "push_rejected"):
                self.alice.process(request)
        self.assertEqual("1", git(self.remote, "rev-list", "--count", "main"))
        self.assertTrue((self.alice.state / (request["id"] + "-snapshot") / "heightmap.png").exists())

    def test_download_makes_new_editable_copy_with_identical_bytes(self):
        original = self.project(self.alice)
        published = self.alice.process(self.request(self.alice))
        self.bob.refresh()
        catalog = ml.read_json(self.bob.bridge / "catalog.json")
        request = self.request(self.bob, "download", published["target"], revision=catalog["revision"])
        result = self.bob.process(request)
        copied = self.bob.projects / result["local_slug"]
        for path in original.iterdir():
            self.assertEqual(path.read_bytes(), (copied / path.name).read_bytes())
        self.assertEqual(result, self.bob.process(request))
        self.assertFalse((self.bob.projects / "arena").exists())

    def test_stale_download_catalog_is_rejected(self):
        self.alice.refresh()
        with self.assertRaisesRegex(ml.LibraryError, "stale_catalog"):
            self.alice.process(self.request(self.alice, "download", revision="0" * 40))

    def test_read_only_helper_cannot_publish(self):
        self.project(self.alice)
        self.alice.allow_push = False
        with self.assertRaisesRegex(ml.LibraryError, "read_only"):
            self.alice.process(self.request(self.alice))

    def test_new_session_does_not_replay_unapproved_upload(self):
        self.project(self.alice)
        request = self.request(self.alice)
        request["session"] = "old-session"
        with self.assertRaisesRegex(ml.LibraryError, "interrupted"):
            self.alice.process(request)
        self.assertEqual("1", git(self.remote, "rev-list", "--count", "main"))

    def test_no_credentials_or_arbitrary_remote_urls(self):
        for remote in ("https://token@github.com/team/maps", "file:///tmp/maps", "ssh://evil.test/maps", "-upload-pack=evil"):
            with self.subTest(remote=remote), self.assertRaisesRegex(ml.LibraryError, "invalid_remote"):
                ml.Library(self.root / "data", self.root / "state", remote, "main", "Alice", "a@b", ["Design"])

    def test_no_path_traversal_or_windows_devices(self):
        for value in ("../arena", "/arena", "C:/arena", "foo//bar", "con", "x/NUL", " x", "x ", "x\\y", "a/b/c/d/e"):
            with self.subTest(value=value), self.assertRaises(ml.LibraryError):
                ml.slug(value)
        for value in ("../key.txt", ".git/config", "CON.txt", "a:b.lua", "a./x.png", "evil.exe"):
            with self.subTest(value=value), self.assertRaises(ml.LibraryError):
                ml.asset_path(value)

    def test_lfs_pointer_fails_before_push(self):
        self.project(self.alice, payload=ml.LFS_HEADER + b"\noid sha256:123\nsize 1024\n")
        with self.assertRaisesRegex(ml.LibraryError, "lfs_unsupported"):
            self.alice.process(self.request(self.alice))
        self.assertEqual("1", git(self.remote, "rev-list", "--count", "main"))

    def test_file_limits_fail_before_push(self):
        self.project(self.alice, payload=b"0123456789")
        with patch.object(ml, "MAX_FILE", 5), self.assertRaisesRegex(ml.LibraryError, "too_large"):
            self.alice.process(self.request(self.alice))

    def test_unknown_stage_cannot_create_arbitrary_repository_tree(self):
        self.project(self.alice)
        with self.assertRaisesRegex(ml.LibraryError, "invalid_stage"):
            self.alice.process(self.request(self.alice, stage="Secret"))

    def test_nested_project_collision_cannot_overwrite(self):
        entries = {"Design/parent/project.lua": ("100644", "abc", 10)}
        with self.assertRaises(ml.LibraryError):
            self.alice.unique_target(entries, "Design/parent/arena", uuid.uuid4().hex)

    def test_retargeting_state_directory_is_rejected(self):
        with self.assertRaisesRegex(ml.LibraryError, "state_mismatch"):
            ml.Library(self.alice.data, self.alice.state, str(self.remote), "other", "Alice", "a@b", ["Design"], local_test_remote=True)

    def test_existing_worktree_is_not_used_as_helper_storage(self):
        with self.assertRaisesRegex(ml.LibraryError, "unsafe_repository"):
            ml.Library(self.alice.data, self.alice.projects / "state", str(self.remote), "main", "Alice", "a@b", ["Design"], local_test_remote=True)

    def test_case_aliased_directories_are_rejected(self):
        original = self.alice.git
        output = b"100644 blob abc 1\tDesign/arena/project.lua\0" + b"100644 blob def 1\tdesign/other/project.lua\0"
        with patch.object(self.alice, "git", side_effect=lambda *a, **kw: output if a[0] == "ls-tree" else original(*a, **kw)):
            with self.assertRaisesRegex(ml.LibraryError, "case_collision"):
                self.alice.tree("ignored")

    def test_symlink_mode_rejected_without_checkout(self):
        output = b"120000 blob abc 12\tDesign/arena/project.lua\0"
        with patch.object(self.alice, "git", return_value=output), self.assertRaisesRegex(ml.LibraryError, "unsafe_link"):
            self.alice.tree("ignored")

    def test_single_helper_lock(self):
        path = self.alice.bridge / "service.lock"
        with ml.exclusive_lock(path):
            with self.assertRaisesRegex(ml.LibraryError, "already_running"):
                with ml.exclusive_lock(path):
                    self.fail("Second helper acquired the same queue")

    def test_remote_history_rewrite_stops_without_advancing_cached_ref(self):
        self.project(self.alice)
        self.alice.process(self.request(self.alice))
        cached = self.alice.fetch()
        # Deliberately rewrite ONLY the disposable test remote back to its seed.
        git(self.seed, "push", "--force", str(self.remote), "main")
        with self.assertRaisesRegex(ml.LibraryError, "history_rewritten"):
            self.alice.fetch()
        self.assertEqual(cached, self.alice.git("rev-parse", "refs/remotes/library").decode().strip())

    def test_configured_stage_case_alias_fails_before_push(self):
        self.project(self.alice)
        self.alice.process(self.request(self.alice))
        self.project(self.bob, "other")
        self.bob.stages = ["01 design pass"]
        with self.assertRaisesRegex(ml.LibraryError, "case_collision"):
            self.bob.process(self.request(self.bob, source="other", stage="01 design pass"))
        self.assertEqual("2", git(self.remote, "rev-list", "--count", "main"))

    def test_invalid_manifest_fails_before_push(self):
        source = self.project(self.alice)
        (source / "project.lua").write_text("return {}", encoding="utf-8")
        with self.assertRaisesRegex(ml.LibraryError, "missing_project"):
            self.alice.process(self.request(self.alice))
        self.assertEqual("1", git(self.remote, "rev-list", "--count", "main"))

    def test_source_modification_during_snapshot_fails_before_push(self):
        source = self.project(self.alice) / "heightmap.png"
        original = Path.read_bytes
        changed = False

        def change_after_read(path):
            nonlocal changed
            raw = original(path)
            if path == source and not changed:
                changed = True
                path.write_bytes(b"changed during save")
            return raw

        with patch.object(Path, "read_bytes", change_after_read):
            with self.assertRaisesRegex(ml.LibraryError, "source_changed"):
                self.alice.process(self.request(self.alice))
        self.assertEqual("1", git(self.remote, "rev-list", "--count", "main"))

    def test_remote_lfs_pointer_is_not_installed_as_a_complete_project(self):
        folder = self.seed / "Design" / "lfs-map"
        folder.mkdir(parents=True)
        (folder / "project.lua").write_bytes(MANIFEST)
        (folder / "heightmap.png").write_bytes(ml.LFS_HEADER + b"\noid sha256:123\nsize 1024\n")
        git(self.seed, "add", ".")
        git(self.seed, "commit", "-m", "LFS pointer test fixture")
        git(self.seed, "push", str(self.remote), "main")
        result = self.alice.refresh()
        with self.assertRaisesRegex(ml.LibraryError, "lfs_unsupported"):
            self.alice.process(self.request(self.alice, "download", "Design/lfs-map", revision=result["revision"]))
        self.assertEqual([], list(self.alice.projects.iterdir()))

    def test_live_mailbox_reports_and_acknowledges_a_pull(self):
        stop = threading.Event()
        errors = []

        def serve():
            try:
                self.alice.serve(stop)
            except Exception as error:
                errors.append(error)

        thread = threading.Thread(target=serve, daemon=True)
        thread.start()
        request = self.request(self.alice, "pull")
        try:
            ml.atomic_json(self.alice.bridge / "request.json", request)
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                try:
                    status = ml.read_json(self.alice.bridge / "status.json")
                except (FileNotFoundError, PermissionError):
                    status = {}
                if (status.get("code") == "pulled" and not status.get("busy")
                        and not (self.alice.bridge / "request.json").exists()):
                    break
                if errors:
                    raise errors[0]
                stop.wait(0.02)
            else:
                self.fail("Helper did not acknowledge mailbox request")
            self.assertEqual(request["id"], status["request_id"])
            self.assertTrue((self.alice.bridge / "catalog.json").exists())
        finally:
            stop.set()
            thread.join(timeout=10)
        self.assertFalse(thread.is_alive())
        self.assertEqual([], errors)
        self.assertEqual(0, ml.read_json(self.alice.bridge / "status.json")["heartbeat"])



class ShaderLibraryTests(unittest.TestCase):
    """Shader distribution: a per-file diff, an allowlist, and no deletions."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.origin = self.root / "origin"
        self.data = self.root / "data"
        self.state = self.root / "state"
        self.data.mkdir()
        self.origin.mkdir()
        git(self.origin, "init", "-b", "main")
        git(self.origin, "config", "user.name", "Test")
        git(self.origin, "config", "user.email", "test@example.invalid")
        (self.origin / ".gitattributes").write_text("* -text\n", encoding="utf-8")
        self.payload = {
            "LuaUI/Widgets/dev_tileset_terrain.lua": b"-- shader 0.30\nreturn 1\n",
            "LuaUI/Widgets/tileset_dev/tilesets/teizer.lua": b"return {}\n",
            "LuaUI/Widgets/tileset_dev/mask.png": b"\x89PNG\r\n\x1a\n" + b"x" * 32,
        }
        self.publish("0.30", 12)

    def publish(self, shader_version, build):
        for relative, blob in self.payload.items():
            target = self.origin / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(blob)
        manifest = {
            "version": 1, "shader_version": shader_version, "build": build,
            "released": "2026-09-09", "brush_versions": ["1.14"], "install_root": "write-dir",
            "files": [{"path": relative, "size": len(blob),
                       "sha256": hashlib.sha256(blob).hexdigest()}
                      for relative, blob in sorted(self.payload.items())],
        }
        (self.origin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        git(self.origin, "add", "-A")
        git(self.origin, "commit", "-m", "build %d" % build)

    def library(self):
        return ml.ShaderLibrary(self.data, self.state, self.origin.as_uri(), "main",
                                local_test_remote=True)

    def test_first_check_reports_everything_missing(self):
        report = self.library().check()
        self.assertEqual(report["code"], "update")
        self.assertEqual(report["changed"], len(self.payload))
        self.assertEqual(report["shader_version"], "0.30")
        self.assertEqual(report["build"], 12)
        self.assertEqual(report["brush_versions"], ["1.14"])

    def test_sync_installs_then_settles(self):
        library = self.library()
        self.assertEqual(library.sync()["synced_files"], len(self.payload))
        for relative, blob in self.payload.items():
            self.assertEqual((self.data / relative).read_bytes(), blob)
        self.assertEqual(library.check()["changed"], 0)
        self.assertEqual(library.check()["code"], "synced")

    def test_only_changed_files_transfer(self):
        library = self.library()
        library.sync()
        changed = b"-- shader 0.31\nreturn 2\n"
        self.payload["LuaUI/Widgets/dev_tileset_terrain.lua"] = changed
        self.publish("0.31", 13)
        report = library.check()
        self.assertEqual(report["changed"], 1)
        self.assertEqual(report["bytes"], len(changed))
        self.assertEqual(library.sync()["synced_files"], 1)
        self.assertEqual((self.data / "LuaUI/Widgets/dev_tileset_terrain.lua").read_bytes(), changed)

    def test_sync_never_deletes(self):
        library = self.library()
        library.sync()
        stray = self.data / "LuaUI/Widgets/tileset_dev/local_notes.md"
        stray.write_bytes(b"mine\n")
        library.sync()
        self.assertTrue(stray.exists())

    def test_corrupt_manifest_hash_is_refused(self):
        document = json.loads((self.origin / "manifest.json").read_text(encoding="utf-8"))
        document["files"][0]["sha256"] = "0" * 64
        (self.origin / "manifest.json").write_text(json.dumps(document), encoding="utf-8")
        git(self.origin, "add", "-A")
        git(self.origin, "commit", "-m", "bad hash")
        # The file is genuinely absent, so a write is planned and the blob then fails its hash.
        with self.assertRaises(ml.LibraryError):
            self.library().sync()

    def test_write_targets_are_an_allowlist(self):
        for bad in ("../escape.lua", "LuaUI/Widgets/gui_options.lua", "manifest.json",
                    "LuaUI/Widgets/tileset_dev/../../x.lua", "LuaUI/Widgets/tileset_dev/run.exe",
                    "LuaUI/Widgets/tileset_dev/.hidden.lua"):
            with self.assertRaises(ml.LibraryError, msg=bad):
                ml.shader_path(bad)
        for good in ("LuaUI/Widgets/dev_tileset_terrain.lua",
                     "LuaUI/Widgets/tileset_dev/tilesets/teizer.lua",
                     "LuaUI/Widgets/tileset_dev/acg_grass001_diff.dds"):
            self.assertEqual(ml.shader_path(good), good)

    def test_manifest_may_not_name_a_file_outside_the_tree(self):
        document = json.loads((self.origin / "manifest.json").read_text(encoding="utf-8"))
        document["files"].append({"path": "LuaUI/Widgets/tileset_dev/ghost.lua",
                                  "size": 3, "sha256": "a" * 64})
        (self.origin / "manifest.json").write_text(json.dumps(document), encoding="utf-8")
        git(self.origin, "add", "-A")
        git(self.origin, "commit", "-m", "ghost entry")
        with self.assertRaises(ml.LibraryError):
            self.library().check()


class ShaderMailboxTests(unittest.TestCase):
    """The shader operations as the game actually reaches them."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = self.root / "data"
        (self.data / "MapProjects").mkdir(parents=True)
        maps = self.root / "maps"
        maps.mkdir()
        git(maps, "init", "-b", "main")
        git(maps, "config", "user.name", "Test")
        git(maps, "config", "user.email", "test@example.invalid")
        (maps / "README.md").write_text("fixture\n", encoding="utf-8")
        git(maps, "add", "-A")
        git(maps, "commit", "-m", "seed")
        shader = self.root / "shader"
        shader.mkdir()
        git(shader, "init", "-b", "main")
        git(shader, "config", "user.name", "Test")
        git(shader, "config", "user.email", "test@example.invalid")
        (shader / ".gitattributes").write_text("* -text\n", encoding="utf-8")
        self.blob = b"-- shader 0.40\n"
        self.installed = self.data / "LuaUI/Widgets/dev_tileset_terrain.lua"
        target = shader / "LuaUI/Widgets/dev_tileset_terrain.lua"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(self.blob)
        (shader / "manifest.json").write_text(json.dumps({
            "version": 1, "shader_version": "0.40", "build": 20, "released": "2026-09-09",
            "brush_versions": ["1.14"], "install_root": "write-dir",
            "files": [{"path": "LuaUI/Widgets/dev_tileset_terrain.lua", "size": len(self.blob),
                       "sha256": hashlib.sha256(self.blob).hexdigest()}],
        }), encoding="utf-8")
        git(shader, "add", "-A")
        git(shader, "commit", "-m", "build 20")
        self.library = ml.Library(self.data, self.root / "state", maps.as_uri(), "main",
                                  "Tester", "test@example.invalid", ["01 Design pass"], True,
                                  local_test_remote=True)
        self.library.shader = ml.ShaderLibrary(self.data, self.root / "shaderstate",
                                               shader.as_uri(), "main", local_test_remote=True)

    def request(self, operation, identifier):
        return self.library.process({"version": 1, "id": identifier, "session": self.library.session,
                                     "operation": operation, "source": "", "stage": "", "revision": ""})

    def test_check_then_sync(self):
        report = self.request("shader_check", "a" * 24)
        self.assertEqual(report["code"], "shader_update")
        self.assertEqual(report["shader"]["shader_version"], "0.40")
        self.assertEqual(report["shader"]["changed"], 1)
        report = self.request("shader_sync", "b" * 24)
        self.assertEqual(report["code"], "shader_synced")
        self.assertEqual(self.installed.read_bytes(), self.blob)

    def test_repeat_request_is_re_examined(self):
        # Project requests are idempotent by id. Shader requests describe disk
        # state, which moves on its own, so a replay must look again.
        self.request("shader_sync", "b" * 24)
        self.installed.unlink()
        self.request("shader_sync", "b" * 24)
        self.assertTrue(self.installed.exists())

    def test_unconfigured_helper_refuses(self):
        self.library.shader = None
        with self.assertRaises(ml.LibraryError) as caught:
            self.request("shader_check", "c" * 24)
        self.assertEqual(str(caught.exception), "shader_not_configured")

if __name__ == "__main__":
    unittest.main()