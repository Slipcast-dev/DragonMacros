# Contributing

[Русский](CONTRIBUTING.md) · [English](CONTRIBUTING.en.md)

Discussions and pull requests are welcome in Russian and English. Discuss large
changes in an issue first. Create a branch from `main` for fixes.

## Local checks

Requires macOS, Python 3, and Apple Command Line Tools (`xcode-select --install`).

```sh
git config core.hooksPath .githooks
sh -n build.sh test.sh test-interface.sh .githooks/pre-commit
python3 -m py_compile Icon/*.py
python3 -m unittest discover -s Icon -p 'test_*.py'
./test.sh
./test-interface.sh
./build.sh universal
codesign --verify --deep --strict .build/DragonMacros.app
```

Pillow is required only for the optional artwork preparation scripts:
`python3 -m pip install Pillow`. Ordinary builds use Python 3 and macOS tools.

Check app and URL actions, shortcut conflicts, pause, restart, styles, both languages,
and animation preferences. Record the checks actually performed in the pull request.
Offscreen UI checks verify rendering and animation contracts; real-window playback,
global shortcuts, and system dialogs still need interactive verification.

Do not commit personal `macros.json` files, secrets, certificates, `.build/`, `dist/`,
or local `.app` bundles. Avoid unrelated reformatting. Write comments and docstrings
in Russian and identifiers in English. Preserve macOS 11 compatibility.

Code and documentation are published under MIT. Only contribute materials you have
the right to distribute, and document artwork provenance. Report vulnerabilities
privately as described in [SECURITY.en.md](SECURITY.en.md).
