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

unit PsBDD.FeatureWriter;

{
  Format independent implementation of IPsBDDFeatureDocumentWriter.

  The writer owns a list of IPsBDDDocument (Markdown, HTML, ...). It opens and
  closes them and writes the feature, the requirement and the scenarios to
  the documents whose audience applies:

    - WriteFeature and WriteRequirement go to the documents whose audience is
      in Audiences.
    - BeginScenario goes to the documents whose audience is in the audiences
      of the scenario, or in Audiences when none are given. Two documents
      with the same audience, for example Markdown and HTML, both receive it.

  Create it in the DUnitX SetupFixture method and close it in
  TearDownFixture. See the header of the PsBDD.Framework unit for an example.
}

interface

uses
  System.SysUtils, System.Generics.Collections,
  PsBDD.Framework;

type
  /// <summary>
  ///   Owns the output documents of a feature and writes to the documents
  ///   whose audience applies.
  /// </summary>
  TPsBDDFeatureDocumentWriter = class(TInterfacedObject, IPsBDDFeatureDocumentWriter)
  private
    FDocuments: TList<IPsBDDDocument>;
    FIsOpen: Boolean;
    FTitle: string;
    FDescription: string;
    FRequirementReference: string;
    FRequirementText: string;
    FAudiences: TPsBDDAudiences;
    FStatus: TPsBDDFeatureStatus;
    function DocumentsFor(const AAudiences: TPsBDDAudiences): TArray<IPsBDDDocument>;
    function GetTitle: string;
    procedure SetTitle(const AValue: string);
    function GetDescription: string;
    procedure SetDescription(const AValue: string);
    function GetRequirementReference: string;
    procedure SetRequirementReference(const AValue: string);
    function GetRequirementText: string;
    procedure SetRequirementText(const AValue: string);
    function GetAudiences: TPsBDDAudiences;
    procedure SetAudiences(const AValue: TPsBDDAudiences);
    function GetStatus: TPsBDDFeatureStatus;
    procedure SetStatus(AValue: TPsBDDFeatureStatus);
  public
    /// <summary>
    ///   Creates a writer for a feature. Audiences starts as every audience,
    ///   so set it to limit the documents the feature is written to.
    /// </summary>
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    ///   Adds an output document. A document added after Open is opened
    ///   straight away.
    /// </summary>
    procedure AddDocument(const ADocument: IPsBDDDocument);

    /// <summary>Opens every added document.</summary>
    procedure Open;

    /// <summary>
    ///   Saves and closes every added document. Every document is closed
    ///   even when one fails, the errors are then raised together. Safe to
    ///   call more than once.
    /// </summary>
    procedure Close;

    procedure WriteFeature;
    procedure WriteRequirement;
    function BeginScenario(const ATitle: string;
      AAudiences: TPsBDDAudiences = []): IPsBDDScenarioDocumentWriter;

    property Title: string read GetTitle write SetTitle;
    property Description: string read GetDescription write SetDescription;
    property RequirementReference: string
      read GetRequirementReference write SetRequirementReference;
    property RequirementText: string
      read GetRequirementText write SetRequirementText;
    property Audiences: TPsBDDAudiences read GetAudiences write SetAudiences;
    property Status: TPsBDDFeatureStatus read GetStatus write SetStatus;
  end;

implementation

type
  /// <summary>
  ///   Writes the steps and the status of one scenario to the documents
  ///   that were selected for it when the scenario began.
  /// </summary>
  TPsBDDScenarioDocumentWriter = class(TInterfacedObject,
    IPsBDDScenarioDocumentWriter)
  private
    FDocuments: TArray<IPsBDDDocument>;
    procedure WriteStep(AKind: TPsBDDStepKind; const ADescription: string);
  public
    constructor Create(const ADocuments: TArray<IPsBDDDocument>);

    procedure WriteGiven(const ADescription: string);
    procedure WriteWhen(const ADescription: string);
    procedure WriteThen(const ADescription: string);
    procedure WriteAnd(const ADescription: string);
    procedure WriteBut(const ADescription: string);
    procedure WriteStatus(AStatus: TPsBDDScenarioStatus; const AMessage: string);
  end;

{ TPsBDDScenarioDocumentWriter }

constructor TPsBDDScenarioDocumentWriter.Create(
  const ADocuments: TArray<IPsBDDDocument>);
begin
  inherited Create;
  FDocuments := ADocuments;
end;

procedure TPsBDDScenarioDocumentWriter.WriteStep(AKind: TPsBDDStepKind;
  const ADescription: string);
var
  LDocument: IPsBDDDocument;
begin
  for LDocument in FDocuments do
    LDocument.WriteStep(AKind, ADescription);
end;

procedure TPsBDDScenarioDocumentWriter.WriteGiven(const ADescription: string);
begin
  WriteStep(skGiven, ADescription);
end;

procedure TPsBDDScenarioDocumentWriter.WriteWhen(const ADescription: string);
begin
  WriteStep(skWhen, ADescription);
end;

procedure TPsBDDScenarioDocumentWriter.WriteThen(const ADescription: string);
begin
  WriteStep(skThen, ADescription);
end;

procedure TPsBDDScenarioDocumentWriter.WriteAnd(const ADescription: string);
begin
  WriteStep(skAnd, ADescription);
end;

procedure TPsBDDScenarioDocumentWriter.WriteBut(const ADescription: string);
begin
  WriteStep(skBut, ADescription);
end;

procedure TPsBDDScenarioDocumentWriter.WriteStatus(AStatus: TPsBDDScenarioStatus;
  const AMessage: string);
var
  LDocument: IPsBDDDocument;
begin
  for LDocument in FDocuments do
    LDocument.WriteScenarioStatus(AStatus, AMessage);
end;

{ TPsBDDFeatureDocumentWriter }

constructor TPsBDDFeatureDocumentWriter.Create;
begin
  inherited Create;
  FDocuments := TList<IPsBDDDocument>.Create;
  FAudiences := [Low(TPsBDDAudience)..High(TPsBDDAudience)];
end;

destructor TPsBDDFeatureDocumentWriter.Destroy;
begin
  // Safety net when Close was not called. Errors are not raised from a
  // destructor. Call Close explicitly to see them.
  try
    Close;
  except
  end;
  FDocuments.Free;
  inherited;
end;

function TPsBDDFeatureDocumentWriter.DocumentsFor(
  const AAudiences: TPsBDDAudiences): TArray<IPsBDDDocument>;
var
  LDocument: IPsBDDDocument;
  LCount: Integer;
begin
  // Size for every document, then trim to the ones that matched
  SetLength(Result, FDocuments.Count);
  LCount := 0;
  for LDocument in FDocuments do
    if LDocument.Target.Audience in AAudiences then
    begin
      Result[LCount] := LDocument;
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

procedure TPsBDDFeatureDocumentWriter.AddDocument(const ADocument: IPsBDDDocument);
begin
  if ADocument = nil then
    Exit;
  FDocuments.Add(ADocument);
  if FIsOpen then
    ADocument.Open;
end;

procedure TPsBDDFeatureDocumentWriter.Open;
var
  LDocument: IPsBDDDocument;
begin
  for LDocument in FDocuments do
    LDocument.Open;
  FIsOpen := True;
end;

procedure TPsBDDFeatureDocumentWriter.Close;
var
  LDocument: IPsBDDDocument;
  LErrors: string;
begin
  for LDocument in FDocuments do
  begin
    try
      LDocument.Close;
    except
      on E: Exception do
      begin
        if LErrors <> '' then
          LErrors := LErrors + sLineBreak;
        LErrors := LErrors + E.Message;
      end;
    end;
  end;
  FIsOpen := False;
  if LErrors <> '' then
    raise Exception.Create(LErrors);
end;

procedure TPsBDDFeatureDocumentWriter.WriteFeature;
var
  LDocument: IPsBDDDocument;
begin
  for LDocument in DocumentsFor(FAudiences) do
    LDocument.WriteFeature(FTitle, FDescription, FStatus);
end;

procedure TPsBDDFeatureDocumentWriter.WriteRequirement;
var
  LDocument: IPsBDDDocument;
begin
  for LDocument in DocumentsFor(FAudiences) do
    LDocument.WriteRequirement(FRequirementReference, FRequirementText);
end;

function TPsBDDFeatureDocumentWriter.BeginScenario(const ATitle: string;
  AAudiences: TPsBDDAudiences): IPsBDDScenarioDocumentWriter;
var
  LDocuments: TArray<IPsBDDDocument>;
  LDocument: IPsBDDDocument;
begin
  // No audiences given: the scenario applies to the audiences of the feature
  if AAudiences = [] then
    AAudiences := FAudiences;

  LDocuments := DocumentsFor(AAudiences);
  for LDocument in LDocuments do
    LDocument.WriteScenario(ATitle);
  Result := TPsBDDScenarioDocumentWriter.Create(LDocuments);
end;

function TPsBDDFeatureDocumentWriter.GetTitle: string;
begin
  Result := FTitle;
end;

procedure TPsBDDFeatureDocumentWriter.SetTitle(const AValue: string);
begin
  FTitle := AValue;
end;

function TPsBDDFeatureDocumentWriter.GetDescription: string;
begin
  Result := FDescription;
end;

procedure TPsBDDFeatureDocumentWriter.SetDescription(const AValue: string);
begin
  FDescription := AValue;
end;

function TPsBDDFeatureDocumentWriter.GetRequirementReference: string;
begin
  Result := FRequirementReference;
end;

procedure TPsBDDFeatureDocumentWriter.SetRequirementReference(const AValue: string);
begin
  FRequirementReference := AValue;
end;

function TPsBDDFeatureDocumentWriter.GetRequirementText: string;
begin
  Result := FRequirementText;
end;

procedure TPsBDDFeatureDocumentWriter.SetRequirementText(const AValue: string);
begin
  FRequirementText := AValue;
end;

function TPsBDDFeatureDocumentWriter.GetAudiences: TPsBDDAudiences;
begin
  Result := FAudiences;
end;

procedure TPsBDDFeatureDocumentWriter.SetAudiences(const AValue: TPsBDDAudiences);
begin
  FAudiences := AValue;
end;

function TPsBDDFeatureDocumentWriter.GetStatus: TPsBDDFeatureStatus;
begin
  Result := FStatus;
end;

procedure TPsBDDFeatureDocumentWriter.SetStatus(AValue: TPsBDDFeatureStatus);
begin
  FStatus := AValue;
end;

end.
