#!/usr/bin/env python3
"""Decide whether a pull request made type checking worse, and report on it.

emmylua_check is not deterministic. Run it twice over an unchanged tree and a
couple of percent of its findings move, because it diagnoses files concurrently
off one shared analysis and the inference-dependent diagnostics come out
order-dependent (EmmyLuaLs/emmylua-analyzer-rust#1091).

So "worse" cannot be read off one run against one run. Each side is analysed
several times and the two are compared as multisets of findings. Each direction
is read at the smallest figure the runs will support:

    added     ->  fewest head appearances  minus  most base appearances
    resolved  ->  fewest base appearances  minus  most head appearances

Read any other way round, the wobble becomes harvestable -- as a charge against
an author who wrote nothing, or as credit for the same. A pull request that
changed nothing nets exactly zero.

Findings are keyed on (severity, code, path, message) rather than on position,
so that inserting a line above a finding does not present it as new, and base
paths are moved through the pull request's renames for the same reason.

Three rules all must be passing:

    errors    any new error, anywhere in the repo
    added     net new warnings on the lines it wrote, per thousand changed
              lines. Net: warnings it resolved pay for warnings it introduced.
    total     every warning remaining in the files that were changed, reduced by
              the target warning rate on lines removed, and increased by it on
              lines added so files that come with warning debt are maintainable.

Warnings are ranked by how near they are to the change. The lines changed, then
the rest of the files it touched, then everywhere else. The annotation budget
spends itself down that order. In scope always sorts ahead of out of scope.

A line rewritten in place is one changed line, not one added and one removed.
"""

import argparse
import collections
import json
import os
import sys

ERROR, WARNING = 1, 2
SEVERITY_NAME = {1: "error", 2: "warning", 3: "info", 4: "hint"}
ANNOTATION_CAP = 10
TABLE_CAP = 50

# How near a finding sits to the change.
HUNK, FILE, TREE = 0, 1, 2

# The CI Results comment trims anything past its slice, cutting a table mid-row.
# So the report renders twice, and the compact one carries only what blocked.
COMPACT_TABLE_CAP = 10
COMPACT_CODE_CAP = 10
COMPACT_MESSAGE_CAP = 100


def broken(detail):
    """A report we cannot read is a CI defect, not a finding. Say which."""
    print(
        "::error title=Type check is broken::%s This is a CI defect, not a problem "
        "with this PR; fix emmylua_compare.py or its pinned emmylua_check." % detail
    )
    sys.exit(1)


def load(path, root):
    """Reduce one report to {finding: count} and {finding: [positions]}.

    Nothing here trusts the report's shape. emmylua_check writing something
    unexpected has to arrive as a defect annotation, the way every other
    breakage in this workflow does, and not as a traceback that reads to the
    author like their own pull request broke.
    """
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            report = json.load(handle)
    except (OSError, ValueError) as err:
        broken("%s could not be read as Json (%s)." % (path, err))

    if not isinstance(report, list):
        broken(
            "%s holds a Json %s where the report should be a list of files."
            % (path, type(report).__name__)
        )

    root = root.replace("\\", "/").rstrip("/") + "/"
    counts = collections.Counter()
    places = collections.defaultdict(list)

    for entry in report:
        if not isinstance(entry, dict):
            broken(
                "%s lists a %s where a file object belongs."
                % (path, type(entry).__name__)
            )
        rel = entry.get("file")
        if not isinstance(rel, str):
            broken("A file in %s carries no string path (got %r)." % (path, rel))
        rel = rel.replace("\\", "/")
        rel = rel[len(root) :] if rel.startswith(root) else rel.lstrip("./")

        # A file with nothing wrong may carry null rather than an empty list.
        found = entry.get("diagnostics") or []
        if not isinstance(found, list):
            broken(
                "The diagnostics for %s in %s are a %s, not a list."
                % (rel, path, type(found).__name__)
            )

        for finding in found:
            if not isinstance(finding, dict):
                broken(
                    "A diagnostic for %s in %s is a %s, not an object."
                    % (rel, path, type(finding).__name__)
                )
            try:
                severity = int(finding.get("severity", ERROR))
            except (TypeError, ValueError):
                broken(
                    "A diagnostic for %s in %s has a non-numeric severity (%r), so "
                    "there is no telling what blocks."
                    % (rel, path, finding.get("severity"))
                )
            key = (
                severity,
                str(finding.get("code", "unknown")),
                rel,
                " ".join(str(finding.get("message", "")).split()),
            )
            # A position we cannot read is not worth failing over: it costs the
            # finding its line number and nothing else, so it lands at the top
            # of the file rather than taking the whole check down with it.
            where = finding.get("range")
            start = where.get("start") if isinstance(where, dict) else None
            start = start if isinstance(start, dict) else {}
            line, col = start.get("line", 0), start.get("character", 0)
            counts[key] += 1
            places[key].append(
                (
                    line + 1 if isinstance(line, int) else 1,
                    col + 1 if isinstance(col, int) else 1,
                )
            )

    return counts, places


def read_records(path, width):
    """Fixed-width records of NUL-separated fields.

    A contributor can add a Lua file whose path holds a tab or a newline, so
    every sidecar this script reads is NUL-separated, the way changed.txt is.
    NUL is the one byte a path cannot contain, which is what makes it the only
    safe separator here. Anything else silently splits a path in two and hands
    its hunks to whatever file shares the prefix.
    """
    if not path or not os.path.exists(path):
        return []
    with open(path, encoding="utf-8", errors="replace") as handle:
        fields = handle.read().split("\0")
    if fields and fields[-1] == "":
        fields.pop()
    if len(fields) % width:
        broken(
            "%s holds %d NUL-separated field(s), which is not a whole number of "
            "%d-field records." % (path, len(fields), width)
        )
    return [tuple(fields[i : i + width]) for i in range(0, len(fields), width)]


def read_renames(path):
    """git diff --name-status -z writes status, old path, new path."""
    return {old: new for _, old, new in read_records(path, 3) if old and new}


def read_hunks(path):
    """The head-side line ranges the pull request wrote, per file."""
    ranges = collections.defaultdict(list)
    for file, start, end in read_records(path, 3):
        if not file:
            continue
        try:
            ranges[file].append((int(start), int(end)))
        except ValueError:
            broken(
                "%s carries a hunk range for %s that is not a pair of numbers "
                "(%r, %r)." % (path, file, start, end)
            )
    return ranges


def scope_of(path, line, changed, hunks):
    """Which ring a finding sits in: the lines written, the file, or elsewhere."""
    if path not in changed:
        return TREE
    # With no ranges supplied nothing resolves to HUNK and every finding in a
    # changed file lands on FILE, which is the scope this check had before.
    if any(start <= line <= end for start, end in hunks.get(path, ())):
        return HUNK
    return FILE


def apply_renames(counts, renames):
    """Move base findings onto their head paths, so a rename reads as no change."""
    if not renames:
        return counts
    moved = collections.Counter()
    for (severity, code, path, message), n in counts.items():
        moved[(severity, code, renames.get(path, path), message)] += n
    return moved


def escape(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def escape_property(text):
    return escape(text).replace(",", "%2C").replace(":", "%3A")


def plural(n):
    return "" if n == 1 else "s"


def group_by_code(findings):
    grouped = collections.defaultdict(list)
    for finding in findings:
        grouped[finding["code"]].append(finding)
    return grouped


def wobble(runs):
    """How many findings the runs of one side disagreed with each other about."""
    return sum(
        1
        for key in set().union(*runs)
        if min(run[key] for run in runs) != max(run[key] for run in runs)
    )


def write_summary(
    path,
    args,
    pools,
    budget,
    reasons,
    unstable,
    any_untouched,
    ripple=0,
    standing=(),
    detail="full",
):
    errors, warnings, others = pools
    new_total = len(errors) + len(warnings) + len(others)
    compact = detail == "compact"
    table_cap = COMPACT_TABLE_CAP if compact else TABLE_CAP

    if not args.compared:
        headline = "Type check: %d finding%s in the whole tree" % (
            new_total,
            plural(new_total),
        )
    elif reasons:
        headline = "Type check: " + ", ".join(reasons)
    elif not budget["total_judged"]:
        # No lines in the changed files, so the total rule has no denominator
        # and did not run. Saying "within 0" would read as a ceiling it met.
        headline = (
            "Type check: %d net new on changed lines, max %d; the changed files "
            "have no lines to measure a rate against"
            % (budget["net"], budget["added_allowance"])
        )
    else:
        headline = (
            "Type check: %d net new on changed lines, max %d; %d left in changed "
            "files, max %d"
            % (
                budget["net"],
                budget["added_allowance"],
                budget["total"],
                budget["total_allowance"],
            )
        )

    # The summary page is appended to, the comment's report is a file of its own.
    with open(path, "w" if compact else "a", encoding="utf-8") as out:
        out.write("### %s\n\n" % headline)
        if compact:
            if args.compared:
                out.write(
                    "New warnings on changed lines: %d added, %d resolved, %d net. "
                    "The max is %d.\n\n"
                    "Warnings left in changed files: %d remain, %d before this "
                    "change. The max is %d.\n\n"
                    % (
                        budget["added"],
                        budget["resolved"],
                        budget["net"],
                        budget["added_allowance"],
                        budget["total"],
                        budget["base_total"],
                        budget["total_allowance"],
                    )
                )
        elif args.compared:
            out.write(
                "New errors are blocking; existing errors are not (usually) blocking. "
                "Warnings on changed lines are judged using the entire file, "
                "against a maximum rate per thousand lines of code: "
                "%d added, %d resolved, for %d net. The max is %d.\n"
                % (
                    budget["added"],
                    budget["resolved"],
                    budget["net"],
                    budget["added_allowance"],
                )
            )
            if budget["total_judged"]:
                out.write(
                    "Warnings remaining in those files are judged the same way, "
                    "moved by the lines this change added and removed: "
                    "%d remain, %d before this change. The max is %d.\n\n"
                    % (
                        budget["total"],
                        budget["base_total"],
                        budget["total_allowance"],
                    )
                )
            else:
                out.write(
                    "Warnings remaining in those files are not judged: they hold no "
                    "lines to divide a rate by.\n\n"
                )
            if ripple:
                out.write(
                    "A further %d new warning%s landed in files this pull request did "
                    "not touch. Those are reported below but not budgeted: emmylua "
                    "re-infers its way through unrelated files when anything moves, "
                    "and holding an author to that is not useful. Errors are not "
                    "treated this way and never have been.\n\n"
                    % (ripple, plural(ripple))
                )
            out.write(
                "emmylua disagreed with itself about %d finding%s on this branch and %d "
                "on the base. Both directions are read at the smallest figure the runs "
                "will support, so that disagreement can be turned into neither a charge "
                "nor a credit, which is why the check runs more than once per side.\n"
                % (unstable["head"], plural(unstable["head"]), unstable["base"])
            )
        else:
            out.write(
                "Manual whole-tree run, with nothing to compare against. Reporting "
                "only -- this does not gate anything.\n"
            )

        # Grouped by code rather than lumped under a severity, because "1354
        # unnecessary-if" and "1 undefined-global" are two different
        # conversations and a flat list buries that.
        if new_total:
            counts = sorted(
                group_by_code(errors + warnings + others).items(),
                key=lambda kv: (kv[1][0]["severity"], -len(kv[1])),
            )
            shown = counts[:COMPACT_CODE_CAP] if compact else counts
            out.write("\n| Code | Severity | Count |\n| --- | --- | --- |\n")
            for code, findings in shown:
                out.write(
                    "| `%s` | %s | %d |\n"
                    % (
                        code,
                        SEVERITY_NAME.get(findings[0]["severity"], "?"),
                        len(findings),
                    )
                )
            if len(shown) < len(counts):
                out.write(
                    "\n_%d more code%s not shown._\n"
                    % (len(counts) - len(shown), plural(len(counts) - len(shown)))
                )

        if not args.compared:
            return

        # The total rule can fail a pull request that introduced nothing, so the
        # standing warnings are listed whenever it is the thing that failed --
        # otherwise its author is handed a number and nowhere to go. They are
        # not listed when it passes: they are not news, and there are thousands.
        over_total = (
            budget["total_judged"]
            and budget["total"] > budget["total_allowance"]
        )
        standing_section = (list(standing), "Warnings in the changed files")

        sections = [
            (errors, "New errors"),
            (warnings, "New warnings"),
            (others, "New info and hints"),
        ]
        if compact:
            # A table earns its bytes only when its own rule failed.
            sections = [(errors, "New errors")]
            if budget["net"] > budget["added_allowance"]:
                sections.append((warnings, "New warnings"))
        if over_total:
            sections.append(standing_section)

        for pool, title in sections:
            if not pool:
                continue
            out.write("\n#### %s (%d)\n\n" % (title, len(pool)))
            out.write("| Location | Code | Message |\n| --- | --- | --- |\n")
            for finding in pool[:table_cap]:
                message = finding["message"].replace("|", "\\|")
                if compact and len(message) > COMPACT_MESSAGE_CAP:
                    message = message[: COMPACT_MESSAGE_CAP - 1] + "…"
                # Errors are in scope wherever they are, so they are never
                # marked as though their address excused them.
                marked = (
                    finding["severity"] != ERROR
                    and not finding["changed"]
                    and not compact
                )
                out.write(
                    "| `%s:%d`%s | `%s` | %s |\n"
                    % (
                        finding["path"],
                        finding["line"],
                        " *" if marked else "",
                        finding["code"],
                        message,
                    )
                )
            if len(pool) > table_cap:
                out.write(
                    "\n_Showing %d of %d; the workflow log lists every one._\n"
                    % (table_cap, len(pool))
                )

        if over_total and not compact:
            out.write(
                "\n_Listed whether or not this pull request wrote them. The max "
                "already allows what was here before, so what is over it came from "
                "this change._\n"
            )

        if any_untouched and not compact:
            out.write(
                "\n_Rows marked `*` are in files this pull request did not touch. The "
                "change reached them through inference, which is exactly what a "
                "whole-tree comparison is for._\n"
            )


def main():
    parser = argparse.ArgumentParser()
    # Without a base there is nothing to compare against, so every finding is
    # reported as-is and nothing blocks. That is the manual whole-tree run.
    parser.add_argument("--base", nargs="+")
    parser.add_argument("--head", nargs="+", required=True)
    parser.add_argument("--base-root", default="")
    parser.add_argument("--head-root", required=True)
    parser.add_argument("--renames")
    parser.add_argument("--changed-files")
    # path<TAB>start<TAB>end, one head-side hunk per line. Without it the near
    # ring is empty and warnings are scoped to whole files, as they were before.
    parser.add_argument("--changed-hunks")
    # The denominator of each rule is the size of its own scope: the added rule
    # divides by the lines the diff touched, the total rule by the size of the
    # files it touched.
    parser.add_argument("--changed-lines", type=int, default=0)
    parser.add_argument("--changed-file-lines", type=int, default=0)
    parser.add_argument("--changed-file-lines-delta", type=int, default=0)
    parser.add_argument("--warn-added-per-kloc", type=float, required=True)
    parser.add_argument("--warn-total-per-kloc", type=float, required=True)
    # Errors are judged over the whole tree and blocked on there: there are
    # almost none left, and they do not move between runs. Warnings are a
    # different animal. A change to one widget can shift how emmylua infers its
    # way through an unrelated one, and it does so reproducibly, so repeat runs
    # do not catch it. Neither warning rule reaches outside the files the pull
    # request touched, so those land as ripple: reported, never charged.
    # Ripple is a warning idea only. An error is never excused by its address.
    parser.add_argument("--summary")
    # The compact rendering the CI Results comment pulls in as an artifact.
    parser.add_argument("--ci-report")
    args = parser.parse_args()
    args.runs = len(args.head)
    args.compared = bool(args.base)
    # A manual run has no base, so there is nothing it can have made worse and
    # nothing for it to gate. A pull request is compared, and a comparison gates.
    args.report_only = not args.compared

    renames = read_renames(args.renames)
    base_runs = [
        apply_renames(load(p, args.base_root)[0], renames) for p in (args.base or [])
    ]

    head_runs, head_places = [], {}
    for path in args.head:
        counts, places = load(path, args.head_root)
        head_runs.append(counts)
        head_places = places  # positions are quoted from whichever run came last

    # Four readings, not two: added is charged at its lowest and resolved is
    # credited at its lowest, so emmylua's disagreement with itself cannot be
    # turned into either a charge or a credit. See the module docstring.
    base_keys = set().union(*base_runs) if base_runs else set()
    head_keys = set().union(*head_runs)
    base_max = {k: max(r[k] for r in base_runs) for k in base_keys}
    base_min = {k: min(r[k] for r in base_runs) for k in base_keys}
    head_min = {k: min(r[k] for r in head_runs) for k in head_keys}
    head_max = {k: max(r[k] for r in head_runs) for k in head_keys}

    changed = set()
    if args.changed_files and os.path.exists(args.changed_files):
        with open(args.changed_files, encoding="utf-8", errors="replace") as handle:
            changed = {p for p in handle.read().split("\0") if p}
    hunks = read_hunks(args.changed_hunks)

    new = []
    for key, count in head_min.items():
        extra = count - base_max.get(key, 0)
        if extra <= 0:
            continue
        severity, code, path, message = key
        for line, col in sorted(head_places.get(key, []))[-extra:] or [(1, 1)]:
            scope = scope_of(path, line, changed, hunks)
            new.append(
                {
                    "severity": severity,
                    "code": code,
                    "path": path,
                    "message": message,
                    "line": line,
                    "col": col,
                    "scope": scope,
                    "changed": scope <= FILE,
                }
            )

    # Nearest first, everywhere a finding is listed: the lines this pull request
    # wrote, then the rest of the files it touched, then the ones it did not.
    # Those are the ones its author can act on without going hunting.
    new.sort(
        key=lambda f: (f["scope"], f["severity"], f["path"], f["line"], f["col"])
    )
    errors = [f for f in new if f["severity"] == ERROR]
    warnings = [f for f in new if f["severity"] == WARNING]
    others = [f for f in new if f["severity"] > WARNING]

    # Scope is a pull request idea. A manual run has no changed set, so every
    # finding reads as ripple and neither warning rule has anything to say.
    added = sum(1 for f in warnings if f["scope"] == HUNK)
    in_files = sum(1 for f in warnings if f["scope"] == FILE)
    ripple = len(warnings) - added - in_files

    # A resolved warning has no head position to place in a hunk, so credit is
    # scoped to the file. In practice a warning only leaves a file the pull
    # request touched because one of its hunks removed it.
    resolved = 0
    for key, count in base_min.items():
        severity, _, path, _ = key
        if severity != WARNING or path not in changed:
            continue
        gone = count - head_max.get(key, 0)
        if gone > 0:
            resolved += gone

    # Every warning the pull request leaves behind in the files it touched,
    # whether or not it put them there. This rule does not read the base at all.
    # They are listed as well as counted: this rule can fail a pull request that
    # introduced nothing, and a number on its own gives its author nowhere to go.
    standing = []
    for key, count in head_min.items():
        severity, code, path, message = key
        if severity != WARNING or path not in changed:
            continue
        # A key present in some head runs and absent from the last one reads as
        # zero here. Falling through to the no-position default would invent a
        # warning at line 1 and charge the total rule for the wobble that the
        # four readings above exist to keep out of the numbers.
        if count <= 0:
            continue
        for line, col in sorted(head_places.get(key, []))[:count] or [(1, 1)]:
            standing.append(
                {
                    "severity": severity,
                    "code": code,
                    "path": path,
                    "message": message,
                    "line": line,
                    "col": col,
                    "scope": scope_of(path, line, changed, hunks),
                    "changed": True,
                }
            )
    standing.sort(key=lambda f: (f["scope"], f["path"], f["line"], f["col"]))
    total = len(standing)

	# emmylua's "warning wobble" moves our counts in untouched files, which we
    # require to compare equal to themselves; there is no base to compare with,
    # so we keep them within the defect rate ceiling, same as a brand-new file.
    base_total = 0
    for key, count in base_min.items():
        severity, _, path, _ = key
        if severity == WARNING and path in changed and count > 0:
            base_total += count

    # A rate needs a denominator. Changed files with no lines to measure -- an
    # empty file added on its own -- would otherwise get a ceiling of zero and
    # fail on a warning they cannot be carrying, so the rule sits that one out.
    rate_ceiling = int(args.warn_total_per_kloc * args.changed_file_lines / 1000.0)
    delta_ceiling = int(
        args.warn_total_per_kloc * args.changed_file_lines_delta / 1000.0
    )
    budget = {
        "added": added,
        "resolved": resolved,
        "net": added - resolved,
        "added_allowance": int(args.warn_added_per_kloc * args.changed_lines / 1000.0),
        "total": total,
        "base_total": base_total,
        # NB: Here is the final statement of the blocking rule:
        "total_allowance": max(rate_ceiling, base_total + delta_ceiling),
        "total_judged": args.compared and args.changed_file_lines > 0,
    }

    reasons = []
    if errors:
        reasons.append("%d new type error%s" % (len(errors), plural(len(errors))))
    if args.compared and budget["net"] > budget["added_allowance"]:
        reasons.append(
            "%d net new warning%s on changed lines, max %d"
            % (budget["net"], plural(budget["net"]), budget["added_allowance"])
        )
    if budget["total_judged"] and budget["total"] > budget["total_allowance"]:
        reasons.append(
            "%d warning%s left in changed files, max %d"
            % (budget["total"], plural(budget["total"]), budget["total_allowance"])
        )

    print(
        "%d new finding(s): %d error(s), %d warning(s) -- %d on changed lines, %d "
        "elsewhere in changed files, %d ripple -- %d info/hint. "
        "Added: %d - %d resolved = %d net, allowance %d over %d changed line(s). "
        "Total: %d warning(s) left in the changed files, %d before this change, "
        "max %d over %d line(s), net growth %d. "
        "%d run(s) per side."
        % (
            len(new),
            len(errors),
            len(warnings),
            added,
            in_files,
            ripple,
            len(others),
            budget["added"],
            budget["resolved"],
            budget["net"],
            budget["added_allowance"],
            args.changed_lines,
            budget["total"],
            budget["base_total"],
            budget["total_allowance"],
            args.changed_file_lines,
            args.changed_file_lines_delta,
            args.runs,
        )
    )

    # Both pools are already sorted nearest first, so the cap spends itself on
    # the changed lines, then the changed files, then the ripple. Every error is
    # a candidate wherever it sits; a warning out of scope is still worth a
    # bubble once the ones in scope have taken what they need.
    for pool, kind in ((errors, "error"), (warnings, "warning")):
        shown = sorted(
            # github annotations are barely sorted; so we apply line and column:
            pool[:ANNOTATION_CAP], key=lambda f: (f["path"], f["line"], f["col"])
        )
        for finding in shown:
            print(
                "::%s file=%s,line=%d,col=%d,title=%s::%s"
                % (
                    kind,
                    escape_property(finding["path"]),
                    finding["line"],
                    finding["col"],
                    escape_property(finding["code"]),
                    escape(finding["message"]),
                )
            )
        if len(pool) > ANNOTATION_CAP:
            print(
                "::notice title=Type check::Only the first %d new %ss are annotated; "
                "the job summary lists every one." % (ANNOTATION_CAP, kind)
            )

    unstable = {
        "base": wobble(base_runs) if base_runs else 0,
        "head": wobble(head_runs),
    }

    # One collapsible fold per code. Uncapped: on a whole-tree run that is tens
    # of thousands of lines, which is readable folded and unreadable flat.
    for code, findings in sorted(
        group_by_code(new).items(), key=lambda kv: (kv[1][0]["severity"], -len(kv[1]))
    ):
        print(
            "::group::%s - %d finding%s" % (code, len(findings), plural(len(findings)))
        )
        for finding in findings:
            print(
                "%s:%d:%d: %s"
                % (finding["path"], finding["line"], finding["col"], finding["message"])
            )
        print("::endgroup::")

    # The whole standing set, when it is the thing that failed. Uncapped here,
    # the way the new findings are: the summary tables are the ones with a cap.
    if (
        standing
        and budget["total_judged"]
        and budget["total"] > budget["total_allowance"]
    ):
        print(
            "::group::warnings in the changed files - %d finding%s"
            % (len(standing), plural(len(standing)))
        )
        for finding in standing:
            print(
                "%s:%d:%d: %s: %s"
                % (
                    finding["path"],
                    finding["line"],
                    finding["col"],
                    finding["code"],
                    finding["message"],
                )
            )
        print("::endgroup::")

    # The same report, rendered for the job's own page and for the comment.
    for path, detail in ((args.summary, "full"), (args.ci_report, "compact")):
        if not path:
            continue
        write_summary(
            path,
            args,
            (errors, warnings, others),
            budget,
            reasons,
            unstable,
            args.compared
            and any(f["severity"] != ERROR and not f["changed"] for f in new),
            ripple,
            standing,
            detail,
        )

    return 1 if reasons and not args.report_only else 0


if __name__ == "__main__":
    sys.exit(main())
