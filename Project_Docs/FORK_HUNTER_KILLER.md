# Forking to GitHub: `hunter-killer`

This project does **not** rename or move source files (see [.cursor/rules/AGENTS.md](../.cursor/rules/AGENTS.md)). Publish a sibling repo with the same tree.

## Option A: New empty repository

1. On GitHub, create an empty repository named `hunter-killer` (no README if you want a clean first push).
2. From your local `dodge-the-creeps` checkout (this folder), add the new remote and push:

```bash
git remote add hunter-killer https://github.com/<your-account>/hunter-killer.git
git push hunter-killer HEAD:main
```

Use your default branch name if it is not `main` (e.g. `master`).

3. To work in Cursor on a **separate working tree**, clone beside this repo (respects `.gitignore` automatically):

```bash
cd ..
git clone https://github.com/<your-account>/hunter-killer.git
```

Open the cloned `hunter-killer` folder as its own workspace when you want to work only on that line of development.

## Option B: GitHub “Fork” button

If `dodge-the-creeps` is already on GitHub under your account or an org, use **Fork** → rename the fork to `hunter-killer` if desired. Clone the fork URL the same way as in step 3 above.

## Notes

- Never `git add -f` ignored build artifacts or `user://` paths unless you intend to.
- After cloning, run Godot once so imported assets (e.g. `*.import`) match your machine if anything is missing.
