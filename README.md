# PsBDD

**Test your Delphi app through its real UI, let failing tests tell you what to
build next, and get the documentation for free. Built for solo developers, on
plain DUnitX.**

Big teams have QA, UI-test labs, CI/CD pipelines and each other. You have
yourself, a form full of `OnClick` handlers and a spec in your head that you'll
have forgotten in six months. And with nobody to ask what you're working on,
it's easy to spend the afternoon on something that was never the job.

PsBDD gives one developer the closest thing to all of that, with no extra tools
or infrastructure.

```pascal
Scenario
  .Given(TheConverterWindowIsOpen, 'the converter window is open')
  .When(TheSelectFolderButtonIsPressed, 'the Select folder button is pressed')
  .&Then(TheFolderDialogAsksForAFolder, 'the folder dialog asks for a folder')
  .&And(TheChosenFolderIsShown, 'the chosen folder is shown in the folder box');
```

**Every step starts as a failure:**

```pascal
procedure TConverterFeature.TheFolderDialogAsksForAFolder;
begin
  Assert.Fail('TheFolderDialogAsksForAFolder not implemented yet');
end;
```

**Run it, and the first failure is your next job:**

```markdown
* **Given** the converter window is open
* **When** the Select folder button is pressed
* **Then** the folder dialog asks for a folder

**Status:** Failed - TheFolderDialogAsksForAFolder not implemented yet
```

## What you get

* **A roadmap that keeps you on course.** One failing step, one job. The chain
  stops there, so what's further along can't distract you. Get a better idea
  halfway through? Write it down as a new scenario and get back to the red step.
  When the scenario goes green, you're finished, and you know it.
* **UI tests without a UI test lab.** Scenarios create your real form without
  showing it and press its real buttons. They run unattended, from a console.
* **Decoupling you can't put off.** A test can't get past a modal dialog or
  logic buried in a form. You feel the coupling on the first step, and you pull
  it out behind an interface.
* **Documents for your future self.** Every run writes what the feature should
  do and whether it still does. When you come back to debug or extend it, start
  there.

PsBDD doesn't replace design or check how your screens look. It keeps you moving
and leaves a record behind.

**See it working:** the [ConverterRefactor demo](Demos/ConverterRefactor) takes a
single-form utility and rebuilds it this way. To try it yourself, follow the
[quick start](Docs/UserGuide.md#2-quick-start), then read
[how to work with PsBDD](Docs/UserGuide.md#3-working-with-psbdd).

## How it fits together

| Layer | Answers | Written as |
|---|---|---|
| **Scenario** | *What* should the feature do? | Given / When / Then steps in the user's words |
| **Unit tests** | *How* is that made true? | Ordinary DUnitX tests of your ViewModels, Models and rules |
| **Document** | *What did I build, and does it still work?* | Written by every run, in Markdown or HTML |

Scenarios stay about behaviour, so "Given a pool has a recurring filter service"
stays true whichever query component you chose. The tables, queries and container
registrations needed to make it true belong in the unit tests below it.

## Also included

* **Plain DUnitX.** Fixtures, runners, TestInsight and loggers work as before.
* **No unfinished step can pass.** A `nil` step doesn't compile.
* **Teardown** cleans up after a scenario like a `finally` block, even when a
  step fails.
* **Requirements:** a feature can carry a title, a story, a life-cycle status and
  the requirement it satisfies (`REQ#014`).
* **Combined documents:** every feature in one file, with numbered headings and
  a table of contents. HTML has light and dark themes and prints cleanly.
* **Run history:** append each run, overwrite, or archive the previous document
  with its date.
* **Preamble:** your own introduction at the top of a combined document.
* **PDF (optional add-on):** a cover page, a linked contents page, page numbers
  and coloured results. This needs TMS FNC Core.
* **Audiences:** if others read your documents, each one can get only the
  features and scenarios meant for developers, testers, business or acceptance.
* **RTL only.** The core needs no third-party libraries.

## Requirements

* Tested with Delphi 13. The framework avoids multiline string literals, so it
  should also compile on earlier versions, but that hasn't been tested. If you
  try one, please report how it goes.
* DUnitX, which ships with Delphi.
* For the PDF add-on only: [TMS FNC Core](https://www.tmssoftware.com/site/tmsfnccore.asp).

## Getting started

Add the `Source` folder to your test project's search path or to the Delphi
library path. For PDF output, also add `AddOns\TMSPDF\Source`. Then follow the
[quick start](Docs/UserGuide.md#2-quick-start) in the developer guide.

| Unit | Holds |
|---|---|
| `PsBDD.Framework` | The types, the interfaces, `TPsBDDScenario` and `TPsBDDRun` |
| `PsBDD.FeatureWriter` | `TPsBDDFeatureDocumentWriter`, which sends each write to the right documents |
| `PsBDD.MarkdownDocument` | `TPsBDDMarkdownDocument`, the Markdown output |
| `PsBDD.HTMLDocument` | `TPsBDDHTMLDocument`, the HTML output |
| `PsBDD.TMSPDF` (in `AddOns\TMSPDF\Source`) | `TPsBDDTMSPDFConversion`, Markdown to PDF (needs TMS FNC Core) |

## Documentation

| Document | What it is |
|---|---|
| [Docs/UserGuide.md](Docs/UserGuide.md) | The developer guide: the way of working, testing through the real window, scenarios, documents, test runs, PDF, pitfalls and the API reference |
| [Docs/PsBDDCustomerListWalkthrough.html](Docs/PsBDDCustomerListWalkthrough.html) | A step-by-step walkthrough, from a feature in plain words to a fixture and the documents it writes. Each line of code is linked to the output it produces. |
| [Docs/PsBDDSimpleTestUML.html](Docs/PsBDDSimpleTestUML.html) | UML activity and sequence diagrams of one test run, from the project file to the saved document |
| [Docs/Samples/CustomerListExample.md](Docs/Samples/CustomerListExample.md), [.html](Docs/Samples/CustomerListExample.html), [.pdf](Docs/Samples/CustomerListExample.pdf) | Sample output: one combined document in all three formats, with the preamble it starts with |
| [CHANGELOG.md](CHANGELOG.md) | What changed in each version, with breaking changes called out. The current version is 0.1.0. |

GitHub shows `.html` files as source. To see the pages, download them and open
them in a browser.

## Demo: ConverterRefactor

[`Demos/ConverterRefactor`](Demos/ConverterRefactor) shows PsBDD in a real
VCL application. It is a refactor of a simple utility from
[*TMS Software Hands-On with Delphi, Book 1*](https://github.com/holgerflick/handson1)
by **Dr. Holger Flick**. The utility, the `converter` project in that
repository's `XData-LLC` folder, turns the fixed-width Florida corporation
files (`cordata0.txt` … `cordata9.txt`) into tab-separated files for a database.

The demo takes the single-form original, with all its code in `OnClick`
handlers, and rebuilds it test first as MVVM:

* 3 PsBDD feature scenarios drive the real window end to end, created but never
  shown. For example: *the Select folder button is pressed, then the folder
  dialog asks for a folder and the chosen folder is shown*.
* That scenario couldn't run with a real folder dialog waiting for someone to
  click it, so the dialog moved behind an injected service.
* 39 DUnitX unit tests cover the View, ViewModel, Model and factory, with fakes
  and Spring4D `Mock<T>`.
* View, ViewModel and Model sit behind interfaces, wired by a Spring4D container
  that is registered per feature.
* Each feature writes its own stand-alone document, plus combined Markdown and
  HTML documents with a preamble. Each run archives the previous one.

The demo also needs [Spring4D](https://bitbucket.org/sglienke/spring4d),
FireDAC and the [TMS VCL UI Pack](https://www.tmssoftware.com/site/tmsvcluipack.asp),
because the original uses them. See the
[demo's README](Demos/ConverterRefactor/README.md) to build and run it.

Thanks to Dr. Flick for the book and its example code, and for permission to
publish this demo.

## Repository layout

```
Source/                      the framework (four units)
AddOns/TMSPDF/Source/        optional PDF conversion (TMS FNC Core)
Docs/                        developer guide, walkthrough and UML diagrams
Docs/Samples/                sample output, and the preamble used for it
Tests/                       the framework's own tests (92, console runner)
AddOns/TMSPDF/Tests/         the PDF add-on's tests (14)
Demos/ConverterRefactor/     the demo application and its tests
```

## Running the framework's tests

Run these from a **Command Prompt** in `Tests\`, not PowerShell, which splits the
arguments at the semicolons. `dcc32` is Delphi's command-line compiler. The path
is for Delphi 13, so change `37.0` for another version.

```
mkdir dcu
dcc32 -B -Q -NSSystem;Winapi -U"C:\Program Files (x86)\Embarcadero\Studio\37.0\lib\win32\release" -NUdcu -E. PsBDDTestRunner.dpr
PsBDDTestRunner.exe
```

The PDF add-on has its own runner. Run these in `AddOns\TMSPDF\Tests\`, with
`<Studio>` as your Delphi folder and `<FNC>` as the folder holding the TMS FNC
Core units, for example
`%LOCALAPPDATA%\TMS Setup\Products\tms.fnc.core\packages\d13\Win32\Release`:

```
mkdir dcu
dcc32 -B -Q -NSSystem;Winapi;Vcl;Vcl.Imaging -U"<Studio>\lib\win32\release;<FNC>" -R"<Studio>\lib\win32\release;<FNC>" -NUdcu -E. PsBDDTMSPDFTestRunner.dpr
PsBDDTMSPDFTestRunner.exe
```

## License

PsBDD is released under the [MIT License](LICENSE.md).
Copyright © 2026 Proshine Window Cleaning.

`Demos/ConverterRefactor` is derived from Dr. Holger Flick's `converter` example
and is published with his permission. All rights to the original remain with
him, and the MIT License doesn't cover his original code. Check with him before
reusing that part of the demo.
