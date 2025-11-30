# Beyond-All-Reason

![Discord](https://img.shields.io/discord/225695362004811776)

Open source RTS game built on top of the Recoil RTS Engine

## Where to download

https://www.beyondallreason.info/download

## How to play

https://www.beyondallreason.info/guides

## Development Quick Start

Beyond All Reason (BAR), consists of 2 primary components, the lobby (Chobby - https://github.com/beyond-all-reason/BYAR-Chobby) and the game code itself (this repository).

The game runs on top of the Recoil engine https://github.com/beyond-all-reason/spring.

In order to develop the game (this repository) you first need a working install of the lobby/launcher. There are 2 ways to do this:

1. [Download the full BAR application](https://www.beyondallreason.info/download#How-To-Install) from the website and run it. This is probably what you will have done if you have previously installed and played the game.

2. OR if you want to develop the lobby client, follow [the guide in the Chobby README](https://github.com/beyond-all-reason/BYAR-Chobby#developing-the-lobby). First download a [release of Chobby](https://github.com/beyond-all-reason/BYAR-Chobby/releases) and then launch Chobby, this will automatically download and install the engine and other dependencies.

Once you have a working install of BAR you need a local development copy of the game code to work with. This code will live in the BAR install directory.

1. To find the BAR install directory simply open the launcher (not full game) and click the "Open install directory" button. This is one of the 3 buttons (`Toggle log` and `Upload log` are the other 2). For Windows installs this might be your user's `AppData/Local/Programs/Beyond-All-Reason/data` directory.

2. In the BAR install directory create the empty file `devmode.txt`. E.g: `AppData/Local/Programs/Beyond-All-Reason/data/devmode.txt`

3. In the BAR install directory in the `data` folder in the `games` sub-directory (create `games` if it doesn't exist) clone the code for this repository into a directory with a name ending in `.sdd`. For example:

```
git clone --recurse-submodules https://github.com/beyond-all-reason/Beyond-All-Reason.git BAR.sdd
```

Ensure that you have the correct path by looking for the file `Beyond-All-Reason/data/games/BAR.sdd/modinfo.lua`

4. Now you have the game code launch the full game from the launcher as normal. Then go to `Settings > Developer > Singleplayer` and select `Beyond All Reason Dev`.

5. Now you can launch a match normally through the game UI. This match will use the dev copy of the LUA code which is in `BAR-install-directory/data/games/BAR.sdd`.

6. If developing Chobby also clone the code into the `games` directory. Follow the guide in the [Chobby README](https://github.com/beyond-all-reason/BYAR-Chobby#developing-the-lobby).

More on the `.sdd` directory to run raw LUA and the structure expected by Spring Engine is [documented here](https://springrts.com/wiki/Gamedev:Structure).

---

## Automated Testing

### Prereqs

**Lua 5.1**

_debian/linux_

```zsh
sudo apt install -y lua5.1
```

_windows_ (MSYS2 UCRT64)

```zsh
pacman -S --needed mingw-w64-ucrt-x86_64-lua51
```

_macOS_

```zsh
brew install lua@5.1
```

**Lux Package Manager**
Follow the [Lux Getting Started Guide](https://lux.lumen-labs.org/tutorial/getting-started/).

Or follow the Cargo instructions to manually build [on the Lux Github](https://github.com/lumen-oss/lux?tab=readme-ov-file#wrench-building-from-source)

### Install Project Packages

From the repo root (where `lux.toml` lives):

```zsh
lux --max-jobs=2 update
```
Note: in my testing `--max-jobs` was super specific to my machine and anything above that number would sometimes cause deadlocks.


### Running Tests

Run the full suite (via [Busted](https://lunarmodules.github.io/busted/)):

```zsh
# preferred for predictable CLI behavior
busted
```

Filter by tag:

```zsh
busted -t focus
```

Optionally, run through Lux’s wrapper:

```zsh
lx test
# run the emmylua type check
lx check
# or to drop into a shell so you can run `busted` manually
lx shell --test
busted
8 successes / 0 failures / 0 errors / 0 pending : 0.246881 seconds
```

See Lux [Guides](https://lux.lumen-labs.org/guides/formatting-linting) for more information.

Inspect objects inline while debugging:

```lua
print(VFS.Include("inspect.lua")(someObject))
```

### VS Code Test Switcher (optional)

This handy plugin lets you switch between the test and the code-being-tested just by tapping `Cmd+Shift+Y`.

VSCode Plugin: https://marketplace.visualstudio.com/items?itemName=bmalehorn.test-switcher

Then open **User Settings (JSON)** and add:

```json
"test-switcher.rules": [
    {
        "pattern": "spec/(.*)_spec\\.lua",
        "replacement": "$1.lua"
    },
    {
        "pattern": "spec/builder_specs/(.*)_spec\\.lua",
        "replacement": "spec/builders/$1.lua"
    },
    {
        "pattern": "spec/builders/(.*)\\.lua",
        "replacement": "spec/builder_specs/$1_spec.lua"
    },
    {
        "pattern": "(luarules|common|luaui|gamedata)/(.*)\\.lua",
        "replacement": "spec/$1/$2_spec.lua"
    }
],
```

=======
You can also inspect objects for more verbose output inline:

```lua
print(inspect(someObject))
```
