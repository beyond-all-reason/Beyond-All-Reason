# PULL REQUEST (PR) GUIDELINES

## Naming convention
- Give your PR a descriptive title that indicates what it is addressing.
- Vague titles such as quality of life patch are not acceptable.
- Individual commits within the PR must each have appropriate titles and descriptions.

## Commits merging
- Each PR should address a single feature or bug.
- Small PRs are much easier to review and merge, large PRs are time consuming to review.
- When a change needs to be reverted, if the PR also includes other changes, they will be reverted too, even though we want to keep them.
> Example: A balance change that changes only unit stats in 100+ files is perfectly fine to bundle into a single PR.

> Example: A single PR that includes balance changes to a unit stats in a single file, and a change to unrelated widget behaviour, is not fine.

- When multiple features need to be added to the game at the same time, merge individual feature PRs into a staging branch, then merge that branch into master when ready.
- You are free to add as many commits as you want to a PR.
- PRs are merged using the squash and merge strategy.
- This keeps the git history clean, and makes it easier to analyze and investigate code history.
- The default merge message is all the individual commit names, delete these and provide a proper summary.
- Only push code you want to merge.
- Use git stash to store your unrelated or unwanted changes temporarily without committing them.
