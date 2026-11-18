# Contributing

Thanks for your interest in improving `flutter_a11y_guidelines`. The bar for a
change is whether it makes a guideline's verdict more faithful to what a user
of assistive technology, or a user with low vision, actually meets. Bug fixes,
cases a guideline misjudges, and clearer docs are all welcome.

## Before a large change

Open an issue describing the problem first, especially for a new guideline or
a change to what an existing one measures. A short discussion up front saves
rework.

## Running the checks

These are the checks CI runs on every push and pull request, on the Flutter
release `.github/workflows/ci.yml` pins:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Conventions

- **Tests ship with the change.** A bug fix or a feature includes a test in the
  same pull request. A test that guards a failure mode says which one.
- **Every rejecting case has a passing twin.** A guideline that rejects
  everything satisfies every known-bad fixture, so each one sits beside a
  known-good fixture of the same shape.
- **Real rendering over hand-built inputs.** Tests pump real widgets and
  measure what was painted; nothing stands in for the render or semantics
  tree.
- **Pin dependencies exactly.** Action references, the Flutter release CI runs
  on, and dev dependencies are exact versions, so a resolver cannot move them.
  A version written inline in a workflow carries a `# renovate:` comment above
  it saying what the literal is.
- **Comments explain why, not what.**
- **Keep tracked text ASCII.** Use plain hyphens and words instead of Unicode
  punctuation or decorative symbols.

## Compatibility

The exported names, constructor parameters, and what each guideline accepts
and rejects are the contract. Before 1.0.0, a change to any of them is a minor
version, and its release notes say how to move. Making a guideline stricter is
such a change, since it can fail a test suite that passed.

## Submitting

Keep each pull request focused on one change, make sure the checks pass, and
describe the why in the pull request body. CI must be green before merge.

## Releasing

A patch or minor release needs no approval: whoever cuts it follows the steps
below in order, on a `main` commit whose required checks have passed. A major
version, a 1.0, or a minor before 1.0 that changes an interface consumers use
needs the maintainer's explicit approval before its tag is pushed.

Every release gets a fixed `vMAJOR.MINOR.PATCH` tag. The repository blocks
updates and deletions of those tags, and publishing the GitHub Release makes
the tag immutable.

1. Bump `version` in `pubspec.yaml`, add the `CHANGELOG.md` entry, and merge
   that to `main`.
2. Tag the merge commit `vMAJOR.MINOR.PATCH` and push the tag.
3. Publish it with `gh release create vMAJOR.MINOR.PATCH`, with the changelog
   entry as its notes.

## License

By submitting a contribution for inclusion in this project, you agree that it
is licensed under the MIT and Apache-2.0 licenses, as the README's License
section describes, without any additional terms or conditions.
