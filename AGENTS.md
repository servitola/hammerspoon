# servitola/hammerspoon — the owner's Hammerspoon build

This checkout is where changes to the app itself are made. The app runs every hotkey,
event tap, keyboard layer (BirmanLayer) and window rule on the owner's Mac: a regression
here breaks the whole keyboard, silently, until someone notices. Treat every change as one
that can lock the owner out of his own machine.

Upstream is `Hammerspoon/hammerspoon` (`upstream`), the fork is `servitola/hammerspoon`
(`origin`). `main` = upstream `master` + our patches, rebased weekly by the
`hammerspoon-sync` job in `~/projects/forks` (`jobs/hammerspoon/sync.sh`), which builds,
notarizes, publishes to `servitola/tap` and installs. Patches meant for upstream also live
on their own branch off `upstream/master` (e.g. `fix/xcode26-warnings`).

There is one checkout: `/Volumes/SanDisk/projects/hammerspoon`, reached as
`~/projects/hammerspoon` (symlink). The weekly job builds in this same directory, rebasing
and resetting `main` — so commit work before Sunday 06:30; the job skips a run while the
tree is dirty or `HEAD` is not `main`, and says so in the «⏱ Cron (Mac)» topic. A new
patch goes onto `main` here, then `git push origin main --force-with-lease`.

## The rule: verify against the reference, not from memory

Nothing about Hammerspoon's API, behaviour or build is answered from memory. Before a
change, and again before calling it done, check every detail it touches against
`.reference/` and the source. The model's training data mixes releases and invents
signatures; the docs here are generated from this exact checkout.

`zsh fork/fetch-reference.sh` rebuilds `.reference/` (git-excluded, ~50 MB, 20 s). Run it
after every rebase and whenever `.reference/FETCHED` names a commit other than HEAD.

| Path | What | Use it for |
| --- | --- | --- |
| `.reference/api/markdown/hs.*.md` | API reference of THIS checkout, one file per module | every function, method, constant, parameter and return value |
| `.reference/api/docs.json`, `html/` | same, machine-readable / browsable | grep across modules |
| `.reference/site/getting-started.md`, `faq.html`, `_posts/` | hammerspoon.org guides and release notes | intended usage, behaviour changes between releases |
| `.reference/wiki/` | GitHub wiki: coroutines, known issues, LuaRocks, samples | threading/coroutine rules, known breakage |
| `.reference/spoons/Source/`, `spoons/docs/` | every official Spoon + its docs | how Spoons use the API in practice, what a change would break |
| `.reference/issues-open.json`, `prs-open.json` | open upstream issues and PRs | is this already reported / already being fixed upstream |
| `CONTRIBUTING.md`, `SPOONS.md`, `scripts/docs/README.md` | upstream's own rules | docstring format, tests, extension layout |
| `LuaSkin/lua-5.4.7/doc/manual.html` | Lua 5.4 reference manual | Lua semantics; LuaSkin embeds 5.4.7 |

## Checklist for every change

1. **Find the contract.** Read the module's `.reference/api/markdown/hs.<module>.md` and its
   source (`extensions/<module>/`). List every documented behaviour the change touches.
2. **Check upstream first.** Search `issues-open.json` / `prs-open.json` and
   `git log upstream/master -- <path>`. Do not fork-patch what upstream has a PR for.
3. **Keep the documented API intact.** A changed signature, return value, default or error
   path is a breaking change for every Spoon and for `~/projects/dotfiles/hammerspoon/`.
   `grep -rn` both before changing anything public.
4. **Docstrings are part of the change.** `---` (Lua) / `///` (ObjC) in upstream's format:
   `Parameters:` and `Returns:` always present, `* None` when empty. Lint must be clean:
   `uv run --with-requirements requirements.txt python3 scripts/docs/bin/build_docs.py -l -o /tmp Hammerspoon extensions/`
   (empty `annotations.json` = clean).
5. **Build with warnings as errors on.** Never pass `GCC_TREAT_WARNINGS_AS_ERRORS=NO`:
   `xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release -configuration Release -destination platform=macOS -derivedDataPath build/dd CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= CLANG_ENABLE_CODE_COVERAGE=NO CLANG_COVERAGE_MAPPING=NO build`
6. **Tests.** Upstream requires a test for every extension change: `Hammerspoon Tests/HS<module>.m`
   + `extensions/<module>/test_<module>.lua` (CONTRIBUTING.md, "Testing"). The test host is a
   second app with the same bundle id `org.hammerspoon.Hammerspoon` as the live one: it shares
   its preferences and fights it for the IPC port. Run the suite only with the owner's say-so
   and the live app quit. Not yet run on this machine.
7. **Live check on the owner's config.** After install: Hammerspoon console clean on reload,
   the hotkeys and BirmanLayer of `~/projects/dotfiles/hammerspoon/` work. A build that
   compiles but was not exercised is not done.
8. **Upstream-bound patches** go on a branch off `upstream/master` and also onto `main`; a PR
   is opened only on the owner's explicit go-ahead.

## Build gotchas learned here

- Xcode 26.6 fails upstream master: LuaSkin and extensions use `-Weverything -Werror`, and
  each clang release adds groups (`fix/xcode26-warnings`). Expect this on every Xcode update.
- `CFBundleShortVersionString` comes from `git describe --tags`
  (`scripts/update_version_build_numbers.sh`). Our release tags `v1.1.1-YYYYMMDD.sha` must
  never exist locally: `remote.origin.tagOpt --no-tags`, delete them if a fetch brings one.
- A plain `build` stamps `get-task-allow` on the `hs` CLI and notarization rejects the app;
  the job passes `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`.
- A plain `build` also honours the scheme's "Gather coverage" (upstream's `archive` does
  not): the product comes out instrumented and every `hs` call drops a `default.profraw` in
  its cwd. Both `CLANG_ENABLE_CODE_COVERAGE=NO` and `CLANG_COVERAGE_MAPPING=NO` are needed —
  the first alone leaves Sentry's Swift code and the link lines instrumented. The job refuses
  to install a bundle where `grep -rl __llvm_prf` finds anything.
- Signing must stay Developer ID `NZNV266K59`: Accessibility and Input Monitoring are pinned
  to it. A differently signed build loses both grants and with them every hotkey.
