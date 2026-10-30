# ConverterRefactor: a PsBDD demo

This is a refactor of the `converter` utility from
[*TMS Software Hands-On with Delphi, Book 1*](https://github.com/holgerflick/handson1)
by **Dr. Holger Flick** (the `XData-LLC\converter` project in that
repository). All rights to the original remain with its author.

The utility reads the fixed-width Florida corporation files `cordata0.txt` …
`cordata9.txt` (Windows code page) from a folder you choose. It writes each
one as a tab-separated `cordataN.txt.csv` for loading into a database.

## What the refactor shows

The original is one form with its logic in `OnClick` handlers. Here it is
rebuilt step by step, test first:

| Unit | Role |
|---|---|
| `AppController` | Startup: single instance check, container, main window |
| `Main.Int` | `IMainViewModel`, `IMainModel` |
| `Main.View` | The form (`TFrmMain`): actions, the folder box, progress |
| `Main.ViewModel` | `TMainViewModel`: converts a file, reports progress through a Spring `Event<T>` |
| `Main.Model` | `TMainModel`, a data module whose query defines the fixed-width layout |
| `Main.Registration` | `TMainFactory` and the Spring4D registration of the feature |
| `Dialogs.Int`, `Dialogs.FolderDialog`, `Dialogs.Registration` | The folder dialog as an injected service |

Tests, in `Tests\`:

* **`ConverterTests`**: 39 DUnitX unit tests for the View, ViewModel, Model
  and factory, with fakes (`Main.Fakes`) and Spring4D `Mock<T>`. It runs in
  TestInsight from the IDE.
* **`ConverterFeatures`**: the PsBDD scenarios, in a console runner. They
  create the real main window through the container, without showing it, and
  press its buttons:
  * *Selecting the source folder* (`Converter.Feature.Tests`)
  * *Starting the converter the first time* and *Starting the converter a
    second time* (`SingleInstance.Feature.Tests`)

The scenarios write `Tests\BDDOutput\`:
* one stand-alone document per feature (`ConverterWindow.md`,
  `SingleInstance.md`)
* the combined `AllFeatures.md` and `AllFeatures.html`, which start with the
  preamble in `Tests\Preamble.md` / `.html`.

The runner sets `TPsBDDRun.RunStart := rsArchive`, so each run keeps the
previous combined documents with their date.

## Requirements

* Delphi 12 or later (tested with Delphi 13), with FireDAC and DUnitX
* [Spring4D](https://bitbucket.org/sglienke/spring4d) (container, `Event<T>`, mocks)
* [TMS VCL UI Pack](https://www.tmssoftware.com/site/tmsvcluipack.asp) (`TAdvEditBtn`, `TFolderDialog`), as in the original
* The PsBDD units, in this repository's `Source` folder. The feature project references them there.
* Optional: [TestInsight](https://bitbucket.org/sglienke/testinsight) for the unit tests in the IDE

## Build and run

Open `ConverterRefactor.groupproj`. It holds the app (`CSVConvert`) and both
test projects. Set *Run > Parameters* to `--exit:Pause` to keep a console
runner open.

From the command line, `Tests\build.ps1` builds and runs both test projects.
First edit the paths at its top (`$bds`, `$tms`, `$spring`) to match your
installation:

```
.\build.ps1                    build and run both
.\build.ps1 -Project Features  only the PsBDD scenarios
.\build.ps1 -NoRun             build only
```

Close any running `CSVConvert.exe` first: the single-instance scenarios use
real windows.

`Tests\Data\cordata0.txt` is a small test file. It was made from a few rows of
the anonymised SQL dump in the original repository, plus some edge cases.
