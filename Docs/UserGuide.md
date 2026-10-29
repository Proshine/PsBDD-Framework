# PsBDD Developer Guide

PsBDD adds Given / When / Then scenarios to [DUnitX](https://github.com/VSoftTechnologies/DUnitX)
tests and writes every scenario, with its result, to Markdown or HTML
documents for developers, testers, business readers or acceptance sign-off.

You write ordinary DUnitX fixtures. Each test method describes one scenario
as a readable chain of steps, and each step runs a method of your fixture:

```pascal
Scenario
  .Given(AnEmptyCustomerList, 'an empty customer list')
  .When(ACustomerIsAdded, 'the clerk adds "Smith"')
  .&Then(TheCustomerIsInTheList, 'the list holds "Smith"');
```

DUnitX reports pass or fail as usual. PsBDD also writes this to a document:

```markdown
## Scenario: Customer can be added

* **Given** an empty customer list
* **When** the clerk adds "Smith"
* **Then** the list holds "Smith"

**Status:** Passed
```

## Contents

1. [Requirements and installation](#1-requirements-and-installation)
2. [Quick start](#2-quick-start)
3. [Writing scenarios](#3-writing-scenarios)
4. [Features and requirements](#4-features-and-requirements)
5. [Documents](#5-documents)
6. [Audiences](#6-audiences)
7. [Test runs: append, overwrite or archive](#7-test-runs-append-overwrite-or-archive)
8. [PDF and other conversions after the run](#8-pdf-and-other-conversions-after-the-run)
9. [Rules and pitfalls](#9-rules-and-pitfalls)
10. [Reference](#10-reference)

---

## 1. Requirements and installation

* Delphi 12 or later (the source uses multiline string literals). Tested with
  Delphi 13.
* DUnitX, which ships with Delphi.
* Only the RTL. No other libraries are needed.

PsBDD is four units:

| Unit | Holds |
|---|---|
| `PsBDD.Framework` | The types, the interfaces, `TPsBDDScenario` and `TPsBDDRun` |
| `PsBDD.FeatureWriter` | `TPsBDDFeatureDocumentWriter`, which sends each write to the right documents |
| `PsBDD.MarkdownDocument` | `TPsBDDMarkdownDocument`, the Markdown output |
| `PsBDD.HTMLDocument` | `TPsBDDHTMLDocument`, the HTML output |

They are in the repository's `Source` folder. Add that folder to your test
project's search path or the Delphi library path, or add the units to the
project. You only need the document units you use.

---

## 2. Quick start

A complete fixture with one feature and one scenario:

```pascal
unit Customer.Feature.Tests;

interface

uses
  DUnitX.TestFramework,
  PsBDD.Framework;

type
  [TestFixture]
  TCustomerFeature = class
  private
    FFeatureWriter: IPsBDDFeatureDocumentWriter;
    FCustomers: TArray<string>;

    // Steps
    procedure AnEmptyCustomerList;
    procedure ACustomerIsAdded;
    procedure TheCustomerIsInTheList;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure CustomerCanBeAdded;
  end;

implementation

uses
  PsBDD.FeatureWriter, PsBDD.MarkdownDocument;

procedure TCustomerFeature.SetupFixture;
begin
  FFeatureWriter := TPsBDDFeatureDocumentWriter.Create;
  FFeatureWriter.Title := 'Customer list';
  FFeatureWriter.Description := 'Clerks keep a list of customers.';
  FFeatureWriter.Status := fsInDevelopment;
  FFeatureWriter.AddDocument(
    TPsBDDMarkdownDocument.Create('C:\Docs\CustomerList.md', auTester, True));
  FFeatureWriter.Open;
  FFeatureWriter.WriteFeature;
end;

procedure TCustomerFeature.TearDownFixture;
begin
  FFeatureWriter.Close;   // saves the document
  FFeatureWriter := nil;
end;

procedure TCustomerFeature.CustomerCanBeAdded;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(
    FFeatureWriter.BeginScenario('Customer can be added'));
  Scenario
    .Given(AnEmptyCustomerList, 'an empty customer list')
    .When(ACustomerIsAdded, 'the clerk adds "Smith"')
    .&Then(TheCustomerIsInTheList, 'the list holds "Smith"');
end;

procedure TCustomerFeature.AnEmptyCustomerList;
begin
  FCustomers := nil;
end;

procedure TCustomerFeature.ACustomerIsAdded;
begin
  FCustomers := FCustomers + ['Smith'];
end;

procedure TCustomerFeature.TheCustomerIsInTheList;
begin
  Assert.AreEqual(1, Length(FCustomers));
  Assert.AreEqual('Smith', FCustomers[0]);
end;

initialization
  TDUnitX.RegisterTestFixture(TCustomerFeature);

end.
```

Run the tests. `C:\Docs\CustomerList.md` now holds:

```markdown
# Feature: Customer list

**Run:** 2026-10-28 09:15:42

**Status:** In Development

Clerks keep a list of customers.

## Scenario: Customer can be added

* **Given** an empty customer list
* **When** the clerk adds "Smith"
* **Then** the list holds "Smith"

**Status:** Passed
```

The pattern is always the same:

| Where | What |
|---|---|
| `SetupFixture` | Create the feature writer, describe the feature, add documents, `Open`, `WriteFeature` |
| Each `[Test]` method | One scenario: `TPsBDDScenario.Create(FFeatureWriter.BeginScenario(...))` and the chain of steps |
| Private methods | The step code: set up, act, assert |
| `TearDownFixture` | `Close`, which saves the documents |

---

## 3. Writing scenarios

### Steps

Every step takes a method to run and the text to write to the document:

| Step | Use it for |
|---|---|
| `.Given` | The starting state |
| `.When` | The action being tested |
| `.&Then` | The expected outcome (assertions) |
| `.&And` | One more Given, When or Then |
| `.But` | A contrasting outcome, often a negative check |

`Then` and `And` are reserved words in Delphi, so they are written `.&Then`
and `.&And`. `But` needs no `&`.

```pascal
Scenario
  .Given(AListWithSmithAndJones, 'a customer list with "Smith" and "Jones"')
  .When(SearchForSmith, 'the clerk searches for "Smith"')
  .&Then(TheCustomerIsFound, 'the customer is found')
  .&And(ExactlyOneMatch, 'exactly one match is returned')
  .But(TheListIsUnchanged, 'the customer list still holds 2 customers');
```

`And` and `But` are indented under the step they continue:

```markdown
* **Given** a customer list with "Smith" and "Jones"
* **When** the clerk searches for "Smith"
* **Then** the customer is found
  * **And** exactly one match is returned
  * **But** the customer list still holds 2 customers
```

### Step methods

Write each step as a private procedure of the fixture, with no parameters and
no return value. Name it after what it does, so the test method reads like
the scenario itself:

```pascal
  private
    FTotal: Integer;
    procedure ATotalOfZero;
    procedure FiveIsAdded;
    procedure TheTotalIsFive;
...

procedure TTotalFeature.TotalIsAdded;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(FFeatureWriter.BeginScenario('Total is added'));
  Scenario
    .Given(ATotalOfZero, 'a total of 0')
    .When(FiveIsAdded, '5 is added')
    .&Then(TheTotalIsFive, 'the total is 5');
end;

procedure TTotalFeature.ATotalOfZero;
begin
  FTotal := 0;
end;

procedure TTotalFeature.FiveIsAdded;
begin
  FTotal := FTotal + 5;
end;

procedure TTotalFeature.TheTotalIsFive;
begin
  Assert.AreEqual(5, FTotal, 'The total is wrong');
end;
```

* The test method holds only the chain, so the intent of the scenario is
  visible at a glance. The details live in the step methods.
* Steps share state through private fields of the fixture.
* Use DUnitX's `Assert` in the Then steps as in any other test.
* A step method can be reused by several scenarios of the fixture.

The step parameter is a `TProc`, so an anonymous method also compiles. Avoid
it: the code of every step inside the chain buries the Given / When / Then
lines the scenario is meant to show.

### When a step fails

A step fails when it raises an exception, such as a failed `Assert`. Then:

1. The remaining steps of the chain do not run.
2. The exception is raised again, so DUnitX reports the test as failed.
3. The document shows every step up to and including the failing one,
   followed by the failure message. For a Then step that runs
   `Assert.IsTrue(Found, 'Smith was not found')`:

```markdown
* **Given** a customer list with "Smith" and "Jones"
* **When** the clerk searches for "Smith"
* **Then** the customer is found

**Status:** Failed - Condition is False when True expected. Smith was not found
```

Give your asserts a message: it ends up in the document and tells the reader
what went wrong.

### Cleaning up: Teardown

Use `.Teardown` for cleanup the steps need, such as freeing objects or
deleting files. It runs when the scenario ends, even when a step failed, like
a `finally` block. It is not written to the document.

**Call `.Teardown` first, before `.Given`.** A failing step stops the chain,
so a `.Teardown` placed after it would never be registered.

```pascal
procedure TOrderFeature.OrderCanBeSaved;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(
    FFeatureWriter.BeginScenario('Order can be saved'));
  Scenario
    .Teardown(DeleteTheTestOrder)        // first
    .Given(ANewOrder, 'a new order')
    .When(TheOrderIsSaved, 'the order is saved')
    .&Then(TheOrderCanBeLoaded, 'the order can be loaded again');
end;

procedure TOrderFeature.DeleteTheTestOrder;
begin
  FreeAndNil(FOrder);
  if TFile.Exists(FOrderFile) then
    TFile.Delete(FOrderFile);
end;
```

A scenario has one teardown. If the teardown itself raises an exception, the
scenario is written as failed with `Teardown failed: <message>`. Write
teardowns so they don't fail, for example by checking before freeing or
deleting.

---

## 4. Features and requirements

A fixture describes one feature. Set its properties in `SetupFixture`:

```pascal
const
  CUSTOMER_DESCRIPTION = '''
    As a clerk
    I want to check whether a customer is in the customer list
    So that I do not create the same customer twice
    ''';

procedure TCustomerFeature.SetupFixture;
begin
  FFeatureWriter := TPsBDDFeatureDocumentWriter.Create;
  FFeatureWriter.Title := 'Customer list';
  FFeatureWriter.Description := CUSTOMER_DESCRIPTION;
  FFeatureWriter.Status := fsInDevelopment;
  FFeatureWriter.RequirementReference := 'REQ#014';
  FFeatureWriter.RequirementText :=
    'The system shall report whether a customer is in the customer list.';
  FFeatureWriter.AddDocument(
    TPsBDDMarkdownDocument.Create('C:\Docs\CustomerList.md', auTester, True));
  FFeatureWriter.Open;
  FFeatureWriter.WriteFeature;
  FFeatureWriter.WriteRequirement;
end;
```

* `WriteFeature` writes the title, the time of the run, the status and the
  description.
* `WriteRequirement` writes the requirement as a quote. Leave
  `RequirementReference` empty to write the text alone. Skip the call when the
  feature has no requirement.
* Multiline descriptions keep their line breaks. A multiline string literal
  (`'''`) is the easiest way to write them.

```markdown
# Feature: Customer list

**Run:** 2026-10-28 09:15:42

**Status:** In Development

As a clerk  
I want to check whether a customer is in the customer list  
So that I do not create the same customer twice

> **REQ#014:** The system shall report whether a customer is in the customer list.
```

The feature status is one of:

| Value | Written as |
|---|---|
| `fsProposed` | Proposed |
| `fsInDevelopment` | In Development |
| `fsImplemented` | Implemented |
| `fsAccepted` | Accepted |
| `fsDeprecated` | Deprecated |

Titles, descriptions and step texts are escaped, so characters such as `*`,
`_` or `#` appear as typed and don't change the formatting.

---

## 5. Documents

PsBDD writes Markdown and HTML. Both document classes take the same
parameters and work the same way:

```pascal
TPsBDDMarkdownDocument.Create(Path, Audience, StandAlone)
TPsBDDHTMLDocument.Create(Path, Audience, StandAlone)
```

| Parameter | Meaning |
|---|---|
| `Path` | The `.md` or `.html` file. Missing folders are created when it is saved. |
| `Audience` | Who the document is for. See [Audiences](#6-audiences). |
| `StandAlone` | `True`: one feature per file. `False`: many features in one file. |

A document is saved by `Close`, and only when something was written to it.
Files are UTF-8 without a byte order mark.

### Stand-alone documents (`True`)

Each fixture writes its own file, which is replaced every time the tests run.
Headings are plain:

```pascal
FFeatureWriter.AddDocument(
  TPsBDDMarkdownDocument.Create('C:\Docs\CustomerList.md', auTester, True));
```

```markdown
# Feature: Customer list
## Scenario: Customer can be added
```

Use this when you want one document per feature.

### Combined documents (`False`)

Many fixtures write to the same file, which collects every feature in one
document. Headings are numbered so each one is unique, and a table of
contents is kept at the top:

```pascal
// In every fixture that belongs in the combined document
FFeatureWriter.AddDocument(
  TPsBDDMarkdownDocument.Create('C:\Docs\AllFeatures.md', auTester, False));
```

```markdown
# Table of Contents

[BDD-TOC-START]: #

- [Feature 1: Customer list](#feature-1-customer-list)
  - [Scenario 1: Customer is found in the list](#scenario-1-customer-is-found-in-the-list)
  - [Scenario 2: Unknown customer is not found](#scenario-2-unknown-customer-is-not-found)
- [Feature 2: Orders](#feature-2-orders)
  - [Scenario 3: Order can be saved](#scenario-3-order-can-be-saved)

[BDD-TOC-END]: #

# Feature 1: Customer list
...
```

The `[BDD-TOC-START]` and `[BDD-TOC-END]` lines are hidden markers that
Markdown readers don't show. You can move the table of contents elsewhere in
the file, or add your own text before or after it: PsBDD finds it again by
its markers. Don't remove the markers.

By default each test run is added to the end of the combined document, so it
grows into a dated history of runs. To start it fresh every run, see
[Test runs](#7-test-runs-append-overwrite-or-archive).

### Preamble: introducing a combined document

A combined document can start with a preamble that says what it is about:
the application the features are for, its purpose, its audience, contacts.
Write it yourself, in the same format as the document, and register it
once in the project file:

```pascal
TPsBDDRun.AddPreamble('C:\Docs\AllFeatures.md', 'C:\Docs\Preamble.md');
TPsBDDRun.AddPreamble('C:\Docs\AllFeatures.html', 'C:\Docs\Preamble.html');
```

* `Preamble.md` is ordinary Markdown.
* `Preamble.html` is the content of the page body: headings, paragraphs,
  images. PsBDD supplies the rest of the page and its style sheet, and puts
  your HTML in a `<div class="preamble">` as it is.
* It is copied to the top of the document, above the table of contents,
  when the document is created: on the first run, and on every run that
  `rsOverwrite` or `rsArchive` starts afresh. A run that adds to the
  document doesn't repeat it.
* **It is optional.** Until the preamble file exists, documents are written
  without one, so you can register it early and write it when the
  application is settled. Edit it at any time; the next new document uses
  the new text.
* Stand-alone documents have no preamble.

Printed from a browser, the HTML preamble is a cover page of its own, and in
the [PDF](#8-pdf-and-other-conversions-after-the-run) it is the cover page.

### HTML documents

`TPsBDDHTMLDocument` writes the same content as one HTML page with its own
style sheet. It opens in any browser, can be mailed or published as it is,
and follows the reader's light or dark setting. Passed scenarios are green,
failed ones red.

```pascal
uses
  PsBDD.HTMLDocument;

FFeatureWriter.AddDocument(
  TPsBDDHTMLDocument.Create('C:\Docs\AllFeatures.html', auBusiness, False));
```

```html
<h2 id="scenario-1">Scenario 1: Customer is found in the list</h2>
<p class="step"><strong>Given</strong> a customer list with &quot;Smith&quot; and &quot;Jones&quot;</p>
<p class="step"><strong>When</strong> the clerk searches for &quot;Smith&quot;</p>
<p class="step"><strong>Then</strong> the customer is found</p>
<p class="step nested"><strong>And</strong> exactly one match is returned</p>
<p class="status passed"><strong>Status:</strong> Passed</p>
```

Stand-alone and combined work as for Markdown. A new page takes its title from
the file name. In a combined page:

* Features and scenarios are numbered and get the ids `feature-1`,
  `scenario-1`, ... that the table of contents links to.
* The table of contents is kept between `<!-- BDD-TOC-START -->` and
  `<!-- BDD-TOC-END -->`, at the top of the body.
* New content goes in front of `<!-- BDD-CONTENT-END -->`, at the end of the
  body.

These are HTML comments, which browsers don't show. You can add your own
content to the page, and move the table of contents, as long as the markers
stay. An existing page without them, for example one you wrote yourself, gets
them added to its body the first time PsBDD writes to it.

[`Samples/CustomerListExample.html`](Samples/CustomerListExample.html) is a sample page.

### Several documents at once

A feature writer can hold any number of documents, in any mix of formats.
Each write goes to every document whose audience applies:

```pascal
FFeatureWriter.AddDocument(
  TPsBDDMarkdownDocument.Create('C:\Docs\Features\CustomerList.md', auTester, True));
FFeatureWriter.AddDocument(
  TPsBDDMarkdownDocument.Create('C:\Docs\AllFeatures.md', auTester, False));
FFeatureWriter.AddDocument(
  TPsBDDHTMLDocument.Create('C:\Docs\AllFeatures.html', auBusiness, False));
```

---

## 6. Audiences

Every document has one audience. Features and scenarios have a set of
audiences. A document receives a feature or scenario only when its audience
is in that set.

| Audience | Intended for |
|---|---|
| `auDeveloper` | Developers: technical scenarios, edge cases |
| `auTester` | Testers: everything they need to verify |
| `auBusiness` | Business readers: the behaviour users see |
| `auAcceptance` | Requirement acceptance and sign-off |

The feature's `Audiences` starts as all four. Narrow it to limit which
documents receive the feature:

```pascal
FFeatureWriter.Audiences := [auTester, auBusiness];
FFeatureWriter.AddDocument(
  TPsBDDMarkdownDocument.Create('C:\Docs\Business.md', auBusiness, False));
FFeatureWriter.AddDocument(
  TPsBDDMarkdownDocument.Create('C:\Docs\Tests.md', auTester, False));
```

A scenario uses the feature's audiences unless `BeginScenario` is given its
own. This keeps technical scenarios out of the business document:

```pascal
// Business.md and Tests.md
Scenario := TPsBDDScenario.Create(
  FFeatureWriter.BeginScenario('Customer can be added'));

// Tests.md only
Scenario := TPsBDDScenario.Create(
  FFeatureWriter.BeginScenario('Name longer than 50 characters is rejected',
    [auTester]));
```

---

## 7. Test runs: append, overwrite or archive

`TPsBDDRun.RunStart` decides what happens to an existing **combined**
document the first time it is opened in a test run:

| Value | Effect |
|---|---|
| `rsAppend` (default) | The run is added to the end of the existing document. |
| `rsOverwrite` | The existing document is deleted and a new one is started. |
| `rsArchive` | The existing document is renamed with its last write time, for example `AllFeatures_2026-10-27_143012.md`, and a new one is started. |

Every later fixture in the same run adds to what the first one started, so
the new document holds every feature of the run. If the archive name is
taken, `_2`, `_3`, ... is added.

**Set it once, in the project file, before the runner executes:**

```pascal
program MyProject.Tests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  PsBDD.Framework,
  Customer.Feature.Tests in 'Customer.Feature.Tests.pas',
  Order.Feature.Tests in 'Order.Feature.Tests.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
begin
  TPsBDDRun.RunStart := rsArchive;

  Runner := TDUnitX.CreateRunner;
  Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
  Results := Runner.Execute;
  if not Results.AllPassed then
    ExitCode := 1;
end.
```

A test run is the test process. The same file is recognised however its path
is written, ignoring case. Stand-alone documents are not affected: they
replace their file every time anyway.

---

## 8. PDF and other conversions after the run

Some outputs can only be made once every fixture has written its documents,
for example a PDF of the combined Markdown document. These are
*conversions*: register them with `TPsBDDRun.AddConversion` before the runner
executes, and perform them with `TPsBDDRun.PerformConversions` after it.

### PDF with TMS FNC Core (optional add-on)

`AddOns\TMSPDF\Source\PsBDD.TMSPDF.pas` converts a Markdown document written by
PsBDD to PDF, using the PDF library of
[TMS FNC Core](https://www.tmssoftware.com/site/tmsfnccore.asp). Only
projects that use this unit need TMS FNC Core. The rest of PsBDD, and its
tests, don't.

The fixtures don't change: they keep writing Markdown. The project file adds
the conversion:

```pascal
uses
  ...
  PsBDD.Framework,
  PsBDD.TMSPDF;

begin
  TPsBDDRun.RunStart := rsArchive;
  TPsBDDRun.AddPreamble('C:\Docs\AllFeatures.md', 'C:\Docs\Preamble.md');
  TPsBDDRun.AddConversion(TPsBDDTMSPDFConversion.Create(
    'C:\Docs\AllFeatures.md', 'C:\Docs\AllFeatures.pdf',
    'Customer features', 'Proshine Window Cleaning'));

  Runner := TDUnitX.CreateRunner;
  Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
  try
    Results := Runner.Execute;
  finally
    TPsBDDRun.PerformConversions;   // after every fixture has closed its documents
  end;
  if not Results.AllPassed then
    ExitCode := 1;
end.
```

`TPsBDDTMSPDFConversion.Create(MarkdownPath, PdfPath, Title, Author)`:

* **Title** is shown in the page header and stored in the document
  information. Leave it empty to use the name of the Markdown file.
* **Author** is stored in the document information. It is optional.

The PDF has:

* the title in the header of every page and the page number in the footer
* features and scenarios as headings, the run time and feature status in
  grey, and requirements in a shaded box
* indented steps, with **And** and **But** indented further
* the scenario status in green when passed, red when failed, with the
  failure message
* for a combined document, a table of contents page first, where each entry
  links to the page of its heading
* the [preamble](#preamble-introducing-a-combined-document), when there is
  one, on a cover page before the table of contents

Text the converter doesn't recognise, for example text you added to the
Markdown by hand, is kept as a plain paragraph. Simple Markdown formatting in it, such as in a preamble, is kept: **bold**, *italic*, `code` and list items. The PDF is replaced on every
run. [`Samples/CustomerListExample.pdf`](Samples/CustomerListExample.pdf) is a sample.

Add `AddOns\TMSPDF\Source` and the TMS FNC Core units to the project's search path, for example
`...\TMS Setup\Products\tms.fnc.core\packages\d13\Win32\Release`.

### How conversions run

* They run in the order they were added.
* Every conversion runs even when another one fails. The errors are then
  raised together, each starting with what the conversion does, for example
  `AllFeatures.md to AllFeatures.pdf: ...`.
* `PerformConversions` forgets the conversions it ran, so calling it twice
  is safe.
* Put it in a `finally` block, so the PDF is still made when the runner
  raises.
* It must be called explicitly. It can't run by itself when the program
  ends: by then the units a conversion uses, such as TMS FNC Core, may
  already be finalized.

### Writing your own conversion

Implement `IPsBDDConversion` from `PsBDD.Framework`: `Convert` does the work
and raises on failure, and `Description` says what it does.

```pascal
type
  TCopyToShareConversion = class(TInterfacedObject, IPsBDDConversion)
  private
    FSource, FTarget: string;
    function GetDescription: string;
  public
    constructor Create(const ASource, ATarget: string);
    procedure Convert;
  end;

function TCopyToShareConversion.GetDescription: string;
begin
  Result := 'Copy ' + ExtractFileName(FSource) + ' to ' + FTarget;
end;

procedure TCopyToShareConversion.Convert;
begin
  TFile.Copy(FSource, FTarget, True);
end;
```

---

## 9. Rules and pitfalls

**One scenario per test method, held in a local variable.** The scenario's
status is written when the scenario is released, at the end of the test
method. Declare it as `Scenario: IPsBDDScenario`, a local variable of the
interface type, and build only one scenario in each method.

**Call `Teardown` first.** See [Cleaning up](#cleaning-up-teardown).

**Call `Close` in `TearDownFixture`.** `Close` saves the documents. If a
document cannot be saved, `Close` raises the error after closing the others.
The writer also closes itself when it is freed, but then errors are not
reported.

**Open before writing.** Writing to a document that was not opened raises
`EInvalidOperation`. `FFeatureWriter.Open` opens every document added before
it, and a document added after `Open` is opened straight away.

**Steps assert, so DUnitX sees the result.** PsBDD doesn't replace DUnitX: a
step that doesn't assert or raise can't fail.

**Keep the console open from the IDE.** Set *Run → Parameters* to
`--exit:Pause` and let the project file read it:

```pascal
begin
  TDUnitX.CheckCommandLine;
  Runner := TDUnitX.CreateRunner;
  ...
  Results := Runner.Execute;
  if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
  begin
    Write('Done. Press <Enter> to quit.');
    Readln;
  end;
end.
```

---

## 10. Reference

### `IPsBDDFeatureDocumentWriter`

Create with `TPsBDDFeatureDocumentWriter.Create`.

| Member | Description |
|---|---|
| `Title` | The feature title |
| `Description` | The feature description, multiline allowed |
| `Status` | `TPsBDDFeatureStatus`, `fsProposed` by default |
| `RequirementReference` | For example `REQ#014`. Optional. |
| `RequirementText` | The requirement the feature satisfies |
| `Audiences` | `TPsBDDAudiences`, all audiences by default |
| `AddDocument(Document)` | Adds an output document |
| `Open` | Opens every document |
| `WriteFeature` | Writes title, run time, status and description |
| `WriteRequirement` | Writes the requirement |
| `BeginScenario(Title, [Audiences])` | Writes the scenario heading and returns its writer, for `TPsBDDScenario.Create` |
| `Close` | Saves and closes every document. Safe to call twice. |

### `IPsBDDScenario`

Create with `TPsBDDScenario.Create(FFeatureWriter.BeginScenario(...))`.

| Member | Description |
|---|---|
| `Given(Action, Text)` | Starting state |
| `When(Action, Text)` | The action |
| `&Then(Action, Text)` | Expected outcome |
| `&And(Action, Text)` | Continues the previous step |
| `But(Action, Text)` | Contrasting outcome |
| `Teardown(Action)` | Cleanup, runs when the scenario ends. Call first. |

`Action` is a private procedure of the fixture with no parameters (a
`TProc`). It may be `nil` to document a step that has no code.

### `TPsBDDMarkdownDocument`

| Member | Description |
|---|---|
| `Create(Path, Audience, StandAlone)` | A Markdown document. `StandAlone = False` makes a combined document. |

### `TPsBDDHTMLDocument`

| Member | Description |
|---|---|
| `Create(Path, Audience, StandAlone)` | An HTML page. `StandAlone = False` makes a combined page. |

### `TPsBDDRun`

| Member | Description |
|---|---|
| `RunStart` | `rsAppend`, `rsOverwrite` or `rsArchive`. Set once in the project file. |
| `AddPreamble(DocumentPath, PreamblePath)` | Registers the optional preamble of a combined document, written at its top when the document is created. |
| `AddConversion(Conversion)` | Registers an `IPsBDDConversion` to perform when the run is finished. |
| `PerformConversions` | Performs the registered conversions in order and forgets them. Raises the errors together. Call after `Runner.Execute`, in a `finally` block. |
| `Reset` | Forgets the documents opened so far and the registered conversions and preambles, as if a new run started. For testing PsBDD itself. |

### `IPsBDDConversion`

| Member | Description |
|---|---|
| `Convert` | Performs the conversion. Raises an exception when it fails. |
| `Description` | What the conversion does, for example `AllFeatures.md to AllFeatures.pdf`. Starts its error message. |

### `TPsBDDTMSPDFConversion` (add-on, needs TMS FNC Core)

| Member | Description |
|---|---|
| `Create(MarkdownPath, PdfPath, [Title], [Author])` | Converts a PsBDD Markdown document to PDF. Raises `EFileNotFoundException` when the Markdown document doesn't exist. |

### Writing another output format

To write another format while the tests run, implement `IPsBDDDocument` (in
`PsBDD.Framework`) and add your document with `AddDocument`, the same way as
the Markdown and HTML documents. `TPsBDDHTMLDocument` and
`TPsBDDMarkdownDocument` are the examples to follow.
A document that collects many features should call
`TPsBDDRun.BeginDocument(Path)` in its `Open`, before it loads the existing
file, so it follows `RunStart` too.

---

PsBDD is released under the MIT License. See [LICENSE.md](../LICENSE.md).
Copyright (c) 2026 Proshine Window Cleaning.
