# Spec Instructions — busted unit tests

This file covers everything under `spec/`. Read it before adding or changing a spec, a builder, or
`spec/spec_helper.lua`. Subsystem conventions that sit on top of these rules live with their subsystem, currently
`luarules/mission_api/mission-api-instructions.md`.

The rules here exist because a spec is read far more often than it is written, and usually by someone who did not
write it and is trying to work out whether a red test means their change is wrong.

## The gates that judge a spec

The gate table, the pinned versions and the handoff rule live in `.github/agents.md` under "Before You Hand Work
Over". Three things about those gates are specific to `spec/` and are easy to get wrong.

Two exemption lists apply here and they do not agree with each other. `.styluaignore` exempts nothing under `spec/`,
so every spec and every builder is format-gated. `.emmyrc.json` exempts `spec/spec_helper.lua` and
`spec/builders/**` from type checking, and nothing else. So a builder is formatted but never type-checked, while the
spec beside it is both. Never assume a sibling directory carries the same exemptions as yours.

Because the builders are unchecked, a mistake in one surfaces as a confusing type warning in each spec that uses it
rather than as an error where the mistake is. When warnings appear in a spec you did not expect to touch types,
suspect the builder first.

Do not read an absent check as a passing one. `gh pr checks <n>` lists which gates actually ran, and a gate that
never fired looks exactly like one that passed. Run the suite yourself before you hand anything over, particularly
for work based on a long-lived branch, where a spec can go stale for days without anyone seeing red.

## What a spec has to be

**Readable without a tour.** Someone looking at one failing assertion must be able to decide whether the expected
value is right by reading the spec file and at most one helper. If understanding your test means opening three
builders and a subsystem helper, inline the fixture instead.

**Indented with tabs.** The repo uses tabs and StyLua enforces them on every line you write. A space-indented spec
fails the format gate on almost every line of the file, which buries whatever else the check found.

**Honest about what it proves.** A new test must fail against the commit before yours and pass against yours. If it
passes both, it is asserting something nobody changed, and it will go stale without anyone noticing.

**About behavior the code actually promises.** Read the implementation before you write the assertion. A test that
invents a rule the module never implemented is worse than no test, because it fails later for a reason that has
nothing to do with the change that tripped it, and the person who hits it has no way to tell which side is wrong.

**Self-consistent.** Before adding a case, read the neighbouring cases in the same file. Two tests in one spec that
imply contradictory rules mean at least one of them is wrong.

## What a spec must not do

Do not re-implement production logic inside the test harness. A builder that mirrors a production module is a second
copy that drifts, and every spec that trusts it inherits the drift. Call the production module instead. A comment of
the form `Mirrors <production file>` in anything under `spec/builders/` is a defect, not documentation.

Do not assert only that a stub was called. `assert.equal(1, #calls.doThing)` passes when `doThing` does nothing. Wire
the real module into the mock and assert the state it should have produced.

Do not import the whole builder barrel. Require the builders you use by path rather than including
`spec/builders/index.lua`, which pulls in every builder on every spec file that touches it.

Do not mix setup conventions inside one directory. Whatever a `spec/<subsystem>/` directory does, hand-assigned
globals, a subsystem helper, or a builder, every spec in it does the same thing, so that fixing one teaches you how
to fix the next.

Do not write specs for behavior that is not implemented. Open an issue instead. A green suite is supposed to mean
the code works.

## How much to write

New logic arrives with tests, changed logic has its tests updated, and a bug fix gets a test that fails without it.
That mandate has no upper bound in it, so apply one yourself.

Specs that add more than twice the lines of the implementation they cover need a sentence in the pull request saying
why. Sometimes the answer is good, because a validation layer really does need a case per rule. More often it means
the same machinery is being driven from several directions, and two specs are covering one behavior.

Test infrastructure changes, meaning `spec/builders/` and `spec/spec_helper.lua`, land in their own pull request
ahead of the feature that needs them. They are the files every other spec depends on, and they are impossible to
review inside a large feature diff.

## Where specs live

Specs mirror the source tree under `spec/` and are named `*_spec.lua`. `.busted` sets `pattern = "_spec"` and
`ROOT = spec/`, and puts `common/`, `luarules/`, `luaui/` and `spec/` on `package.path`, so require modules by their
repository-relative path.

`spec/spec_helper.lua` mocks the engine surface, currently `Spring`, `LOG`, `GG` and `unpack`. Extend it rather than
re-mocking per file, and keep in mind that it is excluded from type checking, so mistakes in it surface as confusing
type warnings in the specs that use it rather than as errors in the helper.
