(*****************************************************************************
MIT License

Copyright (c) 2026 Proshine Window Cleaning (proshinewindowcleaning@gmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
******************************************************************************)

unit PsBDD.Conversion.Tests;

{
  DUnitX tests for the conversions of TPsBDDRun: AddConversion and
  PerformConversions.

  Fake conversions record each call in a log, and can fail with a given
  message. No files are written. Every test starts with no conversions and
  forgets them afterwards.
}

interface

uses
  System.SysUtils, System.Classes,
  DUnitX.TestFramework,
  PsBDD.Framework;

type
  [TestFixture]
  TPsBDDConversionTests = class
  private
    FLog: TStringList;
    procedure ExpectLog(const AExpected: array of string);
    procedure AddConversion(const ADescription: string;
      const AError: string = '');
    procedure PerformTheConversions;
    function PerformAndCatch: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure NoConversions_DoesNothing;
    [Test]
    procedure PerformConversions_RunsEveryConversionInOrder;
    [Test]
    procedure PerformConversions_CalledTwice_RunsEachConversionOnce;
    [Test]
    procedure FailingConversion_TheOthersStillRun;
    [Test]
    procedure FailingConversions_AreRaisedTogetherWithTheirDescriptions;
    [Test]
    procedure FailedConversion_IsNotTriedAgain;
    [Test]
    procedure AddNilConversion_IsIgnored;
    [Test]
    procedure Reset_ForgetsTheConversions;
  end;

implementation

const
  FIRST = 'First.md to First.pdf';
  SECOND = 'Second.md to Second.pdf';
  THIRD = 'Third.md to Third.pdf';
  DISK_FULL = 'disk full';
  NO_FONT = 'font not found';

type
  /// <summary>
  ///   Records each Convert in a log. Raises AError when it is set.
  /// </summary>
  TFakeConversion = class(TInterfacedObject, IPsBDDConversion)
  private
    FDescription: string;
    FError: string;
    FLog: TStrings;
  public
    constructor Create(const ADescription, AError: string; ALog: TStrings);
    function GetDescription: string;
    procedure Convert;
  end;

{ TFakeConversion }

constructor TFakeConversion.Create(const ADescription, AError: string;
  ALog: TStrings);
begin
  inherited Create;
  FDescription := ADescription;
  FError := AError;
  FLog := ALog;
end;

function TFakeConversion.GetDescription: string;
begin
  Result := FDescription;
end;

procedure TFakeConversion.Convert;
begin
  FLog.Add(FDescription);
  if FError <> '' then
    raise Exception.Create(FError);
end;

{ TPsBDDConversionTests }

procedure TPsBDDConversionTests.Setup;
begin
  FLog := TStringList.Create;
  TPsBDDRun.Reset;
end;

procedure TPsBDDConversionTests.TearDown;
begin
  TPsBDDRun.Reset;
  FreeAndNil(FLog);
end;

procedure TPsBDDConversionTests.ExpectLog(const AExpected: array of string);
begin
  Assert.AreEqual(string.Join(sLineBreak, AExpected),
    string.Join(sLineBreak, FLog.ToStringArray));
end;

procedure TPsBDDConversionTests.AddConversion(const ADescription: string;
  const AError: string);
begin
  TPsBDDRun.AddConversion(TFakeConversion.Create(ADescription, AError, FLog));
end;

procedure TPsBDDConversionTests.PerformTheConversions;
begin
  TPsBDDRun.PerformConversions;
end;

// Performs the conversions and returns the message of the error they raised,
// or '' when none was raised
function TPsBDDConversionTests.PerformAndCatch: string;
begin
  Result := '';
  try
    TPsBDDRun.PerformConversions;
  except
    on E: Exception do
      Result := E.Message;
  end;
end;

procedure TPsBDDConversionTests.NoConversions_DoesNothing;
begin
  Assert.WillNotRaiseAny(PerformTheConversions);

  ExpectLog([]);
end;

procedure TPsBDDConversionTests.PerformConversions_RunsEveryConversionInOrder;
begin
  AddConversion(FIRST);
  AddConversion(SECOND);
  AddConversion(THIRD);

  TPsBDDRun.PerformConversions;

  ExpectLog([FIRST, SECOND, THIRD]);
end;

procedure TPsBDDConversionTests.PerformConversions_CalledTwice_RunsEachConversionOnce;
begin
  AddConversion(FIRST);

  TPsBDDRun.PerformConversions;
  TPsBDDRun.PerformConversions;

  ExpectLog([FIRST]);
end;

procedure TPsBDDConversionTests.FailingConversion_TheOthersStillRun;
begin
  AddConversion(FIRST);
  AddConversion(SECOND, DISK_FULL);
  AddConversion(THIRD);

  Assert.WillRaise(PerformTheConversions, Exception);

  ExpectLog([FIRST, SECOND, THIRD]);
end;

procedure TPsBDDConversionTests.FailingConversions_AreRaisedTogetherWithTheirDescriptions;
begin
  AddConversion(FIRST, DISK_FULL);
  AddConversion(SECOND);
  AddConversion(THIRD, NO_FONT);

  Assert.AreEqual(
    FIRST + ': ' + DISK_FULL + sLineBreak + THIRD + ': ' + NO_FONT,
    PerformAndCatch);
end;

procedure TPsBDDConversionTests.FailedConversion_IsNotTriedAgain;
begin
  AddConversion(FIRST, DISK_FULL);
  PerformAndCatch;

  Assert.AreEqual('', PerformAndCatch);
  ExpectLog([FIRST]);
end;

procedure TPsBDDConversionTests.AddNilConversion_IsIgnored;
begin
  TPsBDDRun.AddConversion(nil);
  AddConversion(FIRST);

  Assert.WillNotRaiseAny(PerformTheConversions);

  ExpectLog([FIRST]);
end;

procedure TPsBDDConversionTests.Reset_ForgetsTheConversions;
begin
  AddConversion(FIRST);

  TPsBDDRun.Reset;
  TPsBDDRun.PerformConversions;

  ExpectLog([]);
end;

initialization
  TDUnitX.RegisterTestFixture(TPsBDDConversionTests);

end.
