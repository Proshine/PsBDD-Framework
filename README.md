# PsBDD

**Given / When / Then scenarios for DUnitX, written up as living documents.**

PsBDD lets you write DUnitX tests as readable BDD scenarios. Each run writes
every feature and scenario, with its result, to Markdown and HTML documents,
and optionally to PDF. Developers, testers, business readers and acceptance
sign-off can each get their own document.

```pascal
procedure TCustomerListFeature.CustomerIsFoundInTheList;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(
    FFeatureWriter.BeginScenario('Customer is found in the list'));
  Scenario
    .Given(AListWithSmithAndJones, 'a customer list with "Smith" and "Jones"')
    .When(SearchForSmith, 'the clerk searches for "Smith"')
    .&Then(TheCustomerIsFound, 'the customer is found')
    .&And(ExactlyOneMatch, 'exactly one match is returned');
end;
```

DUnitX reports pass and fail as usual, and PsBDD writes the scenario to the documents:

```markdown
## Scenario 1: Customer is found in the list

* **Given** a customer list with "Smith" and "Jones"
* **When** the clerk searches for "Smith"
* **Then** the customer is found
  * **And** exactly one match is returned

**Status:** Passed
```

## Features

* **Plain DUnitX.** Fixtures, runners, TestInsight and loggers work as before.
  Each step is a private method of your fixture.
* **Failures are documented.** A failing step stops the scenario, and its
  message is written to the document (in red in HTML and PDF). DUnitX still
  reports the failure.
* **Teardown** cleans up after a scenario like a `finally` block, even when a
  step fails.
* **Features and requirements:** title, story, life-cycle status and the
  requirement each feature satisfies (`REQ#014`).
* **Markdown and HTML documents**, either stand-alone or combined. Combined
  documents number their headings, keep a table of contents and grow with every
  feature of a run. The HTML page has light and dark themes and prints cleanly.
* **Audiences:** developer, tester, business and acceptance. A feature or
  scenario goes only to the documents meant for it.
* **Run history:** append each run, overwrite, or archive the previous
  document with its date.
* **Preamble:** your own introduction at the top of a combined document.
* **PDF (optional add-on):** after the run, the combined Markdown becomes a
  PDF with a cover page, a linked contents page, page numbers and coloured
  results. This needs TMS FNC Core.
* **RTL only.** The core needs no third-party libraries.

## Requirements

* Delphi 12 or later (the source uses multiline string literals). Tested with
  Delphi 13.
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
| [Docs/UserGuide.md](Docs/UserGuide.md) | The developer guide: scenarios, documents, audiences, test runs, PDF, pitfalls and the API reference |
| [Docs/PsBDDCustomerListWalkthrough.html](Docs/PsBDDCustomerListWalkthrough.html) | A step-by-step walkthrough, from a feature in plain words to a fixture and the documents it writes. Each line of code is linked to the output it produces. |
| [Docs/PsBDDSimpleTestUML.html](Docs/PsBDDSimpleTestUML.html) | UML activity and sequence diagrams of one test run, from the project file to the saved document |
| [Docs/Samples/CustomerListExample.md](Docs/Samples/CustomerListExample.md), [.html](Docs/Samples/CustomerListExample.html), [.pdf](Docs/Samples/CustomerListExample.pdf) | Sample output: one combined document in all three formats, with the preamble it starts with |

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

* View, ViewModel and Model behind interfaces, wired by a Spring4D container
  that is registered per feature.
* Dialogs behind injected services, replaced in tests by fakes and by Spring4D
  `Mock<T>`.
* 39 DUnitX unit tests for the View, ViewModel, Model and factory.
* 3 PsBDD feature scenarios that drive the real window end to end, created but
  never shown. For example: *the Select folder button is pressed, then the
  chosen folder is shown and Convert is enabled*.
* Each feature writes its own stand-alone document, plus combined Markdown and
  HTML documents with a preamble. Each run archives the previous one.

The demo also needs [Spring4D](https://bitbucket.org/sglienke/spring4d),
FireDAC and the [TMS VCL UI Pack](https://www.tmssoftware.com/site/tmsvcluipack.asp),
because the original uses them. See the
[demo's README](Demos/ConverterRefactor/README.md) to build and run it.

All rights to the original converter remain with Dr. Holger Flick. Thanks to
him for the book and its example code.

## Repository layout

```
Source/                      the framework (four units)
AddOns/TMSPDF/Source/        optional PDF conversion (TMS FNC Core)
Docs/                        developer guide, walkthrough and UML diagrams
Docs/Samples/                sample output, and the preamble used for it
Tests/                       the framework's own tests (91, console runner)
AddOns/TMSPDF/Tests/         the PDF add-on's tests (14)
Demos/ConverterRefactor/     the demo application and its tests
```

## Running the framework's tests

From `Tests\`, with Delphi 13's command-line compiler:

```
dcc32 -B -Q -NSSystem;Winapi -U"C:\Program Files (x86)\Embarcadero\Studio\37.0\lib\win32\release" -NUdcu -E. PsBDDTestRunner.dpr
PsBDDTestRunner.exe
```

The PDF add-on has its own runner in `AddOns\TMSPDF\Tests\`
(`PsBDDTMSPDFTestRunner.dpr`), which also needs TMS FNC Core on the search path.

## License

PsBDD is released under the [MIT License](LICENSE.md).
Copyright © 2026 Proshine Window Cleaning.
