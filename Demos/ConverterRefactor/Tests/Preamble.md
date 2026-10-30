# CSV Converter

**Feature documentation, written by the converter's BDD feature tests.**

## The application

The CSV Converter turns the Florida corporate data files `cordata0.txt` to
`cordata9.txt` into files that MariaDB can import. The source files are
fixed-width text in a Windows code page. Each one is converted to a
tab-separated file next to it, named `cordataN.txt.csv`.

The user chooses the folder that holds the data files and starts the
conversion. Only one converter runs at a time: starting it again brings the
open one back to the front.

## The design

The converter began as the `converter` example of Holger Flick's
*Hands On Delphi*. This version rebuilds it step by step in an MVVM design:

* The **View** is the form. It shows what the **ViewModel** tells it and
  passes on what the user does.
* The **ViewModel** holds the logic, behind an interface, so it can be tested
  without the form.
* The **Model** is a data module that holds the data and its field
  definitions.
* Everything the user is asked or told, such as choosing a folder, goes
  through a service interface, so the tests can stand in for the user.
* A Spring4D container wires each feature together in its own registration
  unit.

## This document

Each feature below was written as Given / When / Then scenarios before the
code that makes them pass, and is run by the `ConverterFeatures` test project
against the real application window.

* Each feature shows when it was last run and where it is in its life cycle,
  from *Proposed* to *Accepted*.
* Each scenario shows whether it **Passed** or **Failed**, with the reason
  when it failed.

It is written for the developers and testers of the converter.
