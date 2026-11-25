# Development

## Tests

The tests run the addon on Lua 5.1, the version WoW uses, against a small fake client (`tests/wow_mock.lua`): a damage meter, a key with its criteria, and group members with their buffs, which each test sets. Secret values are simulated by a wrapper Lua cannot compare or compute with, as the client refuses to. The window is built and refreshed on frames that accept any call: that checks its code runs, with plain and secret values, not how it looks, which is checked in game (README, "Check in game"). They need Python with [lupa](https://pypi.org/project/lupa/) 2.0 or later; Python 3.12 works, and is what CI uses.

```powershell
py install 3.12
py -V:3.12 -m pip install "lupa>=2.0"
py -V:3.12 tests/run.py
```

## Continuous integration

`.github/workflows/ci.yml` runs the test suite on every push to `main`, on pull requests and by hand. It deploys nothing. Releases go through CurseForge, below.

## Publishing on CurseForge

`.pkgmeta` describes the package: a `MythicEssentials` folder holding the `.toc`, the files it lists and `Media/`, the same as `install.ps1`. As for the other Essentials, a CurseForge webhook on the GitHub repository packages each tag; the tag name becomes the version (`@project-version@` in the `.toc`), and a tag containing `alpha` or `beta` publishes an alpha or beta.

## Files

| File | Role |
| --- | --- |
| `MythicEssentials.toc` | The addon's description and the files it loads |
| `Core.lua` | Events, saved data, secret values, formatting, `/mye` command, addon compartment |
| `Meter.lua` | The group's damage, from the game's damage meter |
| `Keystone.lua` | The running key: timer, chests, forces, bosses |
| `Consumables.lua` | Who has no flask or no food |
| `UI/Window.lua` | The window and its layout |
| `UI/MinimapButton.lua` | The minimap icon |
| `Locales.lua`, `Locales/` | Language selection and translations (English is the key and the fallback) |
| `Media/` | Textures: `Icon.tga`, the addon's icon in the addon list and on the minimap |
| `art/` | Source images, left out of the package: `icon.svg` (CC0) and `icon.png`, 512 x 512, also the CurseForge project icon |
| `install.ps1` | Copies the addon into a local WoW install |
| `tests/` | Fake client and tests |
| `docs/` | This documentation |
| `.github/workflows/` | Continuous integration |

## The icon

A violet keystone marked with a plus, inside a gold timer ring with two chest marks, drawn for this project and dedicated to the public domain (CC0 1.0), as its source `art/icon.svg` says. `art/icon.png` is that drawing at 512 x 512 on a transparent background, rendered with headless Chrome (`--headless --screenshot --default-background-color=00000000 --window-size=512,512` on a page holding only the image).

The client reads TGA (and BLP) textures, with sides a power of two. After changing `art/icon.png`, rebuild `Media/Icon.tga`, an uncompressed 32-bit TGA of 64 x 64, with Pillow:

```powershell
py -V:3.12 -c "from PIL import Image; Image.open('art/icon.png').convert('RGBA').resize((64, 64), Image.LANCZOS).save('Media/Icon.tga')"
```

Then restart WoW: a texture file new to the addon folder is only found at launch. On CurseForge, upload `art/icon.png` as the project icon.
