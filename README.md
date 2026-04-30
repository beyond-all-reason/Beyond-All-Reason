# Beyond All Reason

![Discord](https://img.shields.io/discord/225695362004811776)

Open source RTS game built on top of the [Recoil Engine](https://github.com/beyond-all-reason/RecoilEngine).

## Download & Play

- **Download:** https://www.beyondallreason.info/download
- **Guides:** https://www.beyondallreason.info/guides

## Development

All development tooling lives in [**BAR-Devtools**](https://github.com/beyond-all-reason/BAR-Devtools) — type checking, formatting, linting, testing, doc generation, and local server setup in one repo.

```bash
git clone https://github.com/beyond-all-reason/BAR-Devtools.git
cd BAR-Devtools
just setup::init
```

See the [BAR-Devtools README](https://github.com/beyond-all-reason/BAR-Devtools#readme) for full instructions.

### Running a dev copy of the game

1. Install BAR via the [launcher](https://www.beyondallreason.info/download#How-To-Install) (or use an existing install).

2. Find the install directory — open the launcher and click "Open install directory". On Windows this is typically `AppData/Local/Programs/Beyond-All-Reason/data`.

3. Create the empty file `devmode.txt` in the install directory.

4. Clone this repo into the `games` subdirectory with a `.sdd` suffix:

```bash
cd <BAR-install-dir>/data/games
git clone --recurse-submodules https://github.com/beyond-all-reason/Beyond-All-Reason.git BAR.sdd
```

5. Launch the game from the launcher, go to `Settings > Developer > Singleplayer`, and select `Beyond All Reason Dev`.

The game will now use the Lua code from your `BAR.sdd` directory. Edit, reload, iterate.

More on the `.sdd` directory structure: [Spring Engine docs](https://springrts.com/wiki/Gamedev:Structure).
