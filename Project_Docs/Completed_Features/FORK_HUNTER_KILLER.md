# Publishing **Hunter Killer** as an independent mirror (`hunter-killer`)

**Status:** Historical / completed policy doc (lives under `Project_Docs/Completed_Features/`; see [.cursor/rules/AGENTS.md](../../.cursor/rules/AGENTS.md) on treating completed feature docs).

This project follows [.cursor/rules/AGENTS.md](../../.cursor/rules/AGENTS.md): **do not rename or move existing source files** as part of the fork workflow. You publish a **separate GitHub repository** with the same tree; ongoing product work happens only in that repo.

## Decisions (locked in for this fork)

| Topic | Choice |
|--------|--------|
| Relationship to `dodge-the-creeps` | **Independent mirror** — same commit tree at first push; **no** ongoing sync requirement. Changes in `hunter-killer` do not flow back into `dodge-the-creeps`. |
| `dodge-the-creeps` (GitHub + local) | **Leave as-is.** Keep the repo and a local checkout for **POC / basic experiments** or refinement later; it is **not** required to archive, retag, or delete anything. |
| `hunter-killer` | **All future product development** happens here (GitHub + your active local clone). |
| GitHub | New **empty** repo `hunter-killer` under your **personal** account; **first push** defines history (no upstream repo yet). |
| Product naming | **Display:** Hunter Killer · **Repo / package / slug:** `hunter-killer` |
| Company / author (single source in code) | Edit **[`product_brand.gd`](../../product_brand.gd)** (`ProductBrand.COMPANY`, `ProductBrand.AUTHOR`, `ProductBrand.GAME_TITLE`) only — other scripts should reference these constants (e.g. [`main.gd`](../../main.gd) startup log). README / export UI can repeat the same strings until you add a doc generator. |
| Licensing / commercial intent | **Third-party:** honor every asset license (e.g. Godot **MIT** — keep required attribution; fonts and other packs per their files). **Your** original source, design, and original art: **proprietary / all rights reserved** intent for commercial release — add root **`LICENSE`** + **`NOTICE`** (or equivalent) in `hunter-killer` when you are ready to ship; this doc does not supply legal text. |
| CI/CD | **None** today — no migration steps. |

## Two local folders (recommended layout)

Goal: run **Dodge the Creeps** and **Hunter Killer** side by side **without Git or Godot fighting** over one tree.

1. Keep this checkout where it is today, e.g. `…/Git_Proj/dodge-the-creeps`, with `origin` = the **dodge-the-creeps** GitHub remote only. Use it for POCs on the old line.

2. After the **first push** to `hunter-killer` (see below), create a **sibling** directory (same parent folder):

```bash
cd ..
git clone https://github.com/<your-account>/hunter-killer.git
```

That yields `…/Git_Proj/hunter-killer` next to `…/Git_Proj/dodge-the-creeps`.

3. Open **one workspace at a time** in Cursor/Godot per folder (`dodge-the-creeps` vs `hunter-killer`). Each clone has its own `.git/`, its own `res://` import cache under `.godot/`, and its own `user://` — no path conflicts.

4. Do **not** point both clones at the same remote URL for day-to-day pushes: `dodge-the-creeps` → `origin` = old repo; `hunter-killer` → `origin` = new repo. Avoid adding the `hunter-killer` remote to the old folder unless you intentionally push snapshots from there again.

## One-time publish (mirror first push)

1. On GitHub (personal account), create an **empty** repository named `hunter-killer` (no README / no license if you want a single clean root commit from your tree).

2. From the machine checkout you are pushing **from** (often `dodge-the-creeps` first, before the sibling clone exists), add the new remote and push your current branch:

```bash
git remote add hunter-killer https://github.com/<your-account>/hunter-killer.git
git branch --show-current
git push -u hunter-killer HEAD:main
```

Use `main` only if that is your current branch name; otherwise push to the same name on the remote (e.g. `HEAD:master`) or rename locally first so the default branch on GitHub matches your workflow.

3. On GitHub, confirm default branch, visibility, and that the tree matches what you expect.

4. Run the **two local folders** clone step above so `…/hunter-killer` is your daily driver; keep `…/dodge-the-creeps` for POC.

5. Run Godot once in the **hunter-killer** clone so imported assets (e.g. `*.import`) match the machine if anything is missing.

## What we are **not** doing here

- **GitHub “Fork” button** linking to an upstream Dodge-the-Creeps repo — that model is for **contributing back** with a fork graph. Your goal is a **standalone** product line; use the **empty repo + push** flow above.
- **Renaming the `dodge-the-creeps` folder on disk** — not required for the mirror. Optional: after you trust the `hunter-killer` clone, you can stop opening the old folder; the sibling layout above already avoids conflicts.

## Rebranding checklist (after the first push)

Do these in the **`hunter-killer` clone** (and on `main` going forward), without renaming file paths:

- **[`product_brand.gd`](../../product_brand.gd)** — single source for **sellmeyoursoul Enterprises**, **Mike Townsend**, **Hunter Killer**; change only here for code-facing strings.
- **[`project.godot`](../../project.godot)** — keep `application/config/name` aligned with `ProductBrand.GAME_TITLE` (currently **Hunter Killer**).
- **Root `README.md`** — if absent, add one: game title, how to run, copyright line using the same names as `ProductBrand`; third-party section pointing to bundled licenses (e.g. [fonts/LICENSE.txt](../../fonts/LICENSE.txt)).
- **`LICENSE` / `NOTICE`** — add when you formalize release: your proprietary statement + Godot MIT and other third-party notices as required.
- **`Project_Docs/*.md`** — many headers still say “Dodge the Creeps”; update titles and `{projectHome}/dodge-the-creeps` examples to **Hunter Killer** / `hunter-killer` where they describe **this** product (skip or mark historical docs under `Completed_Features/` if you treat them as archive-only per team policy).
- **Export / store metadata** — when you add `export_presets.cfg`, set product **name** and **vendor** to match `ProductBrand` as Godot’s UI allows.

Internal references (`res://…`, class names, autoload paths) stay as they are unless you intentionally schedule a refactor (out of scope for “fork doc” only).

## Hygiene

- Never `git add -f` ignored build artifacts or `user://` paths unless you intend to.
- Do not commit secrets (API keys, local paths) into `hunter-killer`.

---

## Open items (when you ship or rebrand docs)

1. **Exact `LICENSE` / `NOTICE` text** for commercial build — have counsel review once third-party list is complete.
2. **README / docs** — bulk-replace “Dodge the Creeps” where it refers to the **current** product (optional incremental pass).
