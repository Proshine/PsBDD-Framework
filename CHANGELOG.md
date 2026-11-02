# Changelog

PsBDD uses `major.minor.patch` version numbers. While the version is below 1.0,
a minor release can include breaking changes, and they are listed here. The
current version is also in the `PSBDD_VERSION` constant in `PsBDD.Framework`.

## 0.1.0 - 2026-11-01

The first numbered version.

### Breaking changes

* **A step can no longer be `nil`.** An unfinished step must never show as
  passed, and a `nil` step used to run nothing and pass.
  * A literal `nil`, such as `.Given(nil, 'a customer')`, no longer compiles. It
    stops with `E2251 Ambiguous overloaded call`.
  * A `TProc` variable that holds `nil` still compiles, but the step now raises
    `EInvalidOpException` when it runs, and the scenario is written as failed.
  * **To update:** give the step a private procedure. If it isn't written yet,
    start it with `Assert.Fail('<StepName> not implemented yet')`.
  * `Teardown(nil)` is still allowed.
* **Custom `IPsBDDScenario` implementations need five more methods.** `Given`,
  `When`, `&Then`, `&And` and `But` each gained an overload taking
  `TPsBDDStepCannotBeNil`. Fixtures that only call a scenario don't change.

### Added

* `PSBDD_VERSION` constant.

### Changed

* The framework no longer uses multiline string literals, so it no longer needs
  Delphi 12. It is tested with Delphi 13 only, and reports from earlier versions
  are welcome.

### Included in this version

* Given / When / Then scenarios on DUnitX, with teardown.
* Markdown and HTML documents, stand-alone or combined.
* Audiences, requirements, run history (append, overwrite or archive) and
  preambles.
* Conversions after the run, and the optional PDF add-on (needs TMS FNC Core).
