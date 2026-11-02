# PsBDD Developer Guide

PsBDD is a way of working for solo Delphi developers, built on
[DUnitX](https://github.com/VSoftTechnologies/DUnitX). Failing Given / When / Then
steps tell you what to build next, scenarios test your real forms without showing
them, and every run writes what the feature should do, and whether it still does,
to Markdown or HTML documents.

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
3. [Working with PsBDD](#3-working-with-psbdd)
4. [Testing the real window without showing it](#4-testing-the-real-window-without-showing-it)
5. [Writing scenarios](#5-writing-scenarios)
6. [Features and requirements](#6-features-and-requirements)
7. [Documents](#7-documents)
8. [Audiences](#8-audiences)
9. [Test runs: append, overwrite or archive](#9-test-runs-append-overwrite-or-archive)
10. [PDF and other conversions after the run](#10-pdf-and-other-conversions-after-the-run)
11. [Rules and pitfalls](#11-rules-and-pitfalls)
12. [Reference](#12-reference)

---

## 1. Requirements and installation

* Tested with Delphi 13. The framework avoids multiline string literals, so it
  should also compile on earlier versions, but that hasn't been tested.
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
  // Arrange: put the code under test in a known state.
  // A real feature would create it here, e.g. FCustomerList := TCustomerList.Create;
  FCustomers := nil;
end;

procedure TCustomerFeature.ACustomerIsAdded;
begin
  // Act: exercise the entity under test. Here an array stands in for it;
  // in your project this calls your own code, e.g. FCustomerList.Add('Smith');
  FCustomers := FCustomers + ['Smith'];
end;

procedure TCustomerFeature.TheCustomerIsInTheList;
begin
  // Assert: check what the code under test now reports
  Assert.AreEqual(1, Length(FCustomers));
  Assert.AreEqual('Smith', FCustomers[0]);
end;

initialization
  TDUnitX.RegisterTestFixture(TCustomerFeature);

end.
```

The array `FCustomers: TArray<string>` stands in for your application's code, which
keeps the example self-contained. In your own fixtures the steps
call the code you are testing; the ConverterRefactor demo shows that with a
real ViewModel and View. The steps are shown finished here. In real work each
one starts as a failure, as [the next chapter](#3-working-with-psbdd) explains.

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

## 3. Working with PsBDD

When you work alone, nobody asks what you're doing today, and nobody signs off
when it's done. The failing step does both jobs.

### The failing step is your roadmap

1. **Write the scenario** in the user's words, before the code that makes it pass.
2. **Start every step as a failure** that names itself:

   ```pascal
   procedure TConverterFeature.TheFolderDialogAsksForAFolder;
   begin
     Assert.Fail('TheFolderDialogAsksForAFolder not implemented yet');
   end;
   ```

3. **Run it.** A failing step stops the chain, so the first unfinished step is
   the one that fails, and it's the only job you have:

   ```markdown
   * **Given** the converter window is open
   * **When** the Select folder button is pressed
   * **Then** the folder dialog asks for a folder

   **Status:** Failed - TheFolderDialogAsksForAFolder not implemented yet
   ```

4. **Make that one step pass**, with unit tests for the code underneath it.
5. **Run it again.** The next unfinished step is your next job.
6. **Stop when the scenario is green.** That's your definition of done.

The document shows the steps up to the failure. The test method shows the whole
plan, so that's where to look for what comes next.

### Staying on course

The tool can't stop you drifting, but it makes drifting visible: the step you
were working on is still red. When a better idea turns up halfway through a step,
write it down as a new scenario, or just its title, and go back to the red step.

Writing the scenario first doesn't do your thinking for you. Decide the design
before you start, and think about what happens when things go wrong. Those
unhappy paths need scenarios of their own, because nothing will prompt you for
them.

### Scenarios say what, unit tests prove how

Keep the scenario about behaviour. The first Given is the place to be careful,
because a real feature can need a lot underneath it: a table, a query, a Model, a
ViewModel and a container registration. None of that belongs in the scenario.

```gherkin
Given a pool has a recurring filter service
```

That line stays true whichever query component you choose. Treat it as a question:
what has to exist for this to be true? The answers become your development tasks
and your unit tests. The scenario records what the feature must do, and the unit
tests prove how you made it happen.

### Deciding what to fake

A scenario can run anything from the whole application to just the form, so each
one needs a decision about where to stop. A good default is to keep everything you
own real and fake only what's at the edge of the application: anything that needs
a person, is slow or unavailable, or changes between runs.

Persistence is the hard case, because the SQL, field mappings and rules are your
code too, and they can be wrong:

| Where you cut | What it proves | What it costs |
|---|---|---|
| A test copy of a real database | The whole chain, including the SQL | Setup, slower runs, resetting data between scenarios |
| An in-memory dataset | The logic and the data flow | Nothing about the SQL or the schema |
| A fake Model | View and ViewModel behaviour | Nothing below the ViewModel |

If a scenario stops above the database, something else has to prove what's below
it, or every scenario can be green with a broken query. The scenario text stays
the same wherever you cut, so you can start with a fake and move the cut later.

A **Passed** status doesn't say what was faked. If it matters, say so in the
feature description, for your future self.

### Coming back to the code

The documents are written for the day you return to a feature to debug or extend
it. Find the feature and read its scenarios: they say what it should do, and the
status says whether it still does. To get from a scenario to its code, search your
test units for its title, which is the text passed to `BeginScenario`.

---

## 4. Testing the real window without showing it

Full UI test automation drives the running application the way a user does,
usually on dedicated machines and often with paid tools. That's hard to justify
when you work alone. PsBDD scenarios offer a cheaper option, a kind of poor man's
UI test: no extra tools or build machines, and it runs from a console like any
other DUnitX test.

### The seam: create the form, but don't show it

Have a factory or DI container return the form **created and fully wired, but not
shown**. The application calls `Show`. The test doesn't, and presses the buttons
in code. From the demo, using Spring4D:

```pascal
procedure TConverterFeature.TheConverterWindowIsOpen;
begin
  // Created and wired the way the application does it, but not shown.
  // The folder dialog is a fake, so no one has to choose a folder.
  FFolderDialog := TFakeFolderDialogService.Create(CHOSEN_FOLDER);
  FFolderDialogService := FFolderDialog;
  FContainer := TContainer.Create;
  FContainer.RegisterInstance<IFolderDialogService>(FFolderDialogService);
  RegisterMain(FContainer);
  FContainer.Build;
  FMainView := FContainer.Resolve<TForm>('MainView');
end;
```

The container isn't the point, and PsBDD doesn't need one. Any code that builds
the form without showing it works the same way.

### Anything modal goes behind a service

A `ShowMessage` or a real dialog waits for a person, so a step that reaches one
never finishes. This is where the pressure to decouple comes from: the step you
need to pass can't pass until the dialog is out of the form. Put it behind an
interface, and let the test supply a fake:

```pascal
IFolderDialogService = interface(IInvokable)
  function SelectFolder(const aTitle, aInitialFolder: string): string;
end;
```

Add a service only when a step needs it. As the logic moves out of the form for
the same reason, it can get ordinary unit tests in a ViewModel or Model.

### Press buttons through their actions

With a `TAction` behind each button, one press tests the wiring, the enabled rule
and the behaviour together, along the route a user's click takes:

```pascal
View.btnConvert.Click;   // goes through the action link
```

Call `Click`, not the `OnClick` event. Calling `OnClick` directly can skip the
action's enabled check, so a test could pass with a disabled button. A button
with no action fires even when it's disabled, so it doesn't get this protection.

Some controls have no `Action` property, such as the button of a `TAdvEditBtn`.
Its handler calls `actSelectFolder.Execute` itself, and the test presses it through
`OnClickBtn`.

### What this tests, and what it doesn't

| Checked | Not checked |
|---|---|
| The form loads with its real DFM and wiring | How it looks: layout, DPI, painting, themes |
| Button and action handlers do the right thing | Real mouse and keyboard input, focus, tab order |
| Control values and enabled states | Whether a control is visible or can be reached by a user |
| View, ViewModel and Model working together | Real dialogs, which are faked |
| What the user is asked or told, through fake services | Anything that depends on the message loop or real timing |

A scenario can press a button that's hidden behind another control and still pass,
so keep a short manual check of the screens before a release. If your application
outgrows that, add real UI automation on top. These scenarios stay useful underneath
it.

### Things to watch

* **There's no message loop in a test,** so idle action updates don't fire. In the
  demo, the folder box's `OnChange` calls `actConvert.Update` itself.
* **Mind who owns the form.** `Application.CreateForm` sets `Application.MainForm`,
  and `Application` owns the form. Freeing the form clears `MainForm`. Free it in
  the scenario's teardown, and never through the container in application code.
* **Some scenarios need real windows.** The demo's single-instance scenarios do,
  and they fail if `CSVConvert.exe` is already running.
* **Move the logic out anyway.** Driving a form is an integration test. Scenarios
  exercise the window, and unit tests cover the logic behind it.

---

## 5. Writing scenarios

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

### Same scenario, different values

Steps take no parameters, so when comparable scenarios differ only in their
values, pass the values through DUnitX's `[TestCase]` and hold them in fields for
the steps to read. Each `[TestCase]` runs the test method once:

```pascal
  private
    FTotal, FStart, FAmount, FExpected: Integer;
    procedure ABalanceOfStart;
    procedure TheAmountIsAdded;
    procedure TheTotalIsCorrect;
  public
    [TestCase('Empty balance', 'Empty balance,0,5,5')]
    [TestCase('Existing balance', 'Existing balance,10,5,15')]
    procedure AddingAnAmountToABalance(const ACase: string;
      AStart, AAmount, AExpected: Integer);
...

procedure TBalanceFeature.AddingAnAmountToABalance(const ACase: string;
  AStart, AAmount, AExpected: Integer);
var
  Scenario: IPsBDDScenario;
begin
  FStart := AStart;
  FAmount := AAmount;
  FExpected := AExpected;

  Scenario := TPsBDDScenario.Create(FFeatureWriter.BeginScenario(
    Format('Adding an amount to a balance: %s', [ACase])));
  Scenario
    .Given(ABalanceOfStart, Format('a balance of %d', [AStart]))
    .When(TheAmountIsAdded, Format('%d is added', [AAmount]))
    .&Then(TheTotalIsCorrect, Format('the total is %d', [AExpected]));
end;

procedure TBalanceFeature.ABalanceOfStart;
begin
  FTotal := FStart;
end;

procedure TBalanceFeature.TheAmountIsAdded;
begin
  FTotal := FTotal + FAmount;
end;

procedure TBalanceFeature.TheTotalIsCorrect;
begin
  Assert.AreEqual(FExpected, FTotal, 'The total is wrong');
end;
```

The scenario title stays the same for every case and adds the name of the case.
DUnitX doesn't pass a test case's name to the method, so it's repeated as the first
value. The steps show the values with `Format`. Each case appears in the document
as its own scenario:

```markdown
## Scenario: Adding an amount to a balance: Empty balance

* **Given** a balance of 0
* **When** 5 is added
* **Then** the total is 5

**Status:** Passed

## Scenario: Adding an amount to a balance: Existing balance

* **Given** a balance of 10
* **When** 5 is added
* **Then** the total is 15

**Status:** Passed
```

Set the fields first, before the chain. When a few values each mean something, a
named step reads better, such as `AnExpiredCustomer`, which can call a shared
private method with the value it needs.

### Every step needs a method

A step without code must never show as passed, so PsBDD doesn't allow one. A
step that isn't implemented yet starts by failing, and says which step it is:

```pascal
procedure TCustomerFeature.TheCustomerIsInTheList;
begin
  Assert.Fail('TheCustomerIsInTheList not implemented yet');
end;
```

* A literal `nil` doesn't compile. `.Given(nil, 'a customer')` stops the build
  with `E2251 Ambiguous overloaded call to 'Given'`. The related methods the
  compiler lists include `TPsBDDStepCannotBeNil`, the type that exists to cause
  this error.
* A `TProc` variable that holds `nil` compiles, because the compiler can't see
  its value. The step then fails when it runs, with the message
  `This step has no method to run`, and the scenario is written as failed.

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

A scenario has one teardown, and registering a second raises
`EInvalidOpException`. If the teardown itself raises an exception, the scenario
is written as failed with `Teardown failed: <message>`, but **DUnitX doesn't see
that failure**: the test can pass while the document says it failed. Write
teardowns so they don't fail, for example by checking before freeing or
deleting.

---

## 6. Features and requirements

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
* Multiline descriptions keep their line breaks. On Delphi 12 and later, a
  multiline string literal (`'''`) is the easiest way to write them, as above.
  On earlier versions, join the lines with `sLineBreak`:
  `'As a clerk' + sLineBreak + 'I want ...'`.

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

## 7. Documents

PsBDD writes Markdown and HTML. Both document classes take the same
parameters and work the same way:

```pascal
TPsBDDMarkdownDocument.Create(Path, Audience, StandAlone)
TPsBDDHTMLDocument.Create(Path, Audience, StandAlone)
```

| Parameter | Meaning |
|---|---|
| `Path` | The `.md` or `.html` file. Missing folders are created when it is saved. |
| `Audience` | Who the document is for. See [Audiences](#8-audiences). |
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
[Test runs](#9-test-runs-append-overwrite-or-archive).

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
the [PDF](#10-pdf-and-other-conversions-after-the-run) it is the cover page.

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

## 8. Audiences

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

Working alone, one document with one audience is usually all you need, and you
can skip this chapter. Audiences matter once others read your documents.

A scenario uses the feature's audiences unless `BeginScenario` is given its
own. Audiences given there aren't limited by the feature's, so a document outside
the feature's audiences gets the scenario without its feature heading. Giving a
scenario its own audiences keeps technical scenarios out of the business document:

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

## 9. Test runs: append, overwrite or archive

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

## 10. PDF and other conversions after the run

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
  raises. Its errors leave that block too, so any code after it, such as setting
  `ExitCode`, doesn't run. Catch them there if your project file needs to go on.
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

## 11. Rules and pitfalls

**One scenario per test method, held in a local variable.** The scenario's
status is written when the scenario is released, at the end of the test
method. Declare it as `Scenario: IPsBDDScenario`, a local variable of the
interface type, and build only one scenario in each method. A scenario with no
steps gets its heading but no status.

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

## 12. Reference

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
`TProc`). It can't be `nil`. See [Every step needs a method](#every-step-needs-a-method).
Each step method also has an overload taking `TPsBDDStepCannotBeNil`, which
only exists to reject `nil` when compiling. You never use it yourself.

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
file, so it follows `RunStart` too, and `TPsBDDRun.PreambleFor(Path)` when it
creates a new file, so it gets its preamble.

---

PsBDD is released under the MIT License. See [LICENSE.md](../LICENSE.md).
Copyright (c) 2026 Proshine Window Cleaning.
