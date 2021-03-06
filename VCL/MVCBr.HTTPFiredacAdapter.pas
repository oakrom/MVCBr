unit MVCBr.HTTPFiredacAdapter;

interface

uses System.Classes, System.SysUtils,
  System.JSON,
  System.Generics.Collections, Data.DB,
  MVCBr.HTTPRestClient,
  IdHTTP;

type

  THTTPFireDACAdapter = class(TComponent)
  private
    FJsonValue: TJsonValue;
    FDataset: TDataset;
    FResponseJSON: THTTPRestClient;
    FRootElement: string;
    procedure SetDataset(const Value: TDataset);
    procedure SetActive(const Value: boolean);
    procedure SetResponseJSON(const Value: THTTPRestClient);
    procedure SetRootElement(const Value: string);
    function GetActive: boolean;
    procedure Notification(AComponent: TComponent;
      AOperation: TOperation); override;

  public
    function Execute: boolean;
    class procedure FillDatasetFromJSONValue(ARootElement: string;
      ADataset: TDataset; AJson: TJsonValue; AUseReflect: boolean); virtual;
    procedure CreateDatasetFromJson(AJson: string);
  published
    Property Active: boolean read GetActive write SetActive;
    Property Dataset: TDataset read FDataset write SetDataset;
    Property ResponseJSON: THTTPRestClient read FResponseJSON
      write SetResponseJSON;
    Property RootElement: string read FRootElement write SetRootElement;
  end;

implementation

uses FireDac.Comp.Client, FireDac.Comp.Dataset, Data.FireDACJSONReflect,
  REST.Response.Adapter;

{ TIdHTTPDataSetAdapter }

procedure THTTPFireDACAdapter.CreateDatasetFromJson(AJson: string);
begin
  Assert(assigned(FDataset), 'N�o atribuiu o Dataset');
  if (AJson <> '') and (AJson <> FResponseJSON.Content) then
  begin
    if assigned(FJsonValue) then
      FJsonValue.DisposeOf;
    FJsonValue := nil;
  end;
  if AJson = '' then
    AJson := FResponseJSON.Content;
  Assert(AJson <> '', 'N�o h� representa��o JSON para processar');

  if not assigned(FJsonValue) then
    FJsonValue := TJsonObject.ParseJSONValue(AJson) as TJsonObject;
  Assert(assigned(FJsonValue), 'N�o � uma representa��o JSON v�lida');
  FillDatasetFromJSONValue(FRootElement, FDataset, FJsonValue, true);
end;

function THTTPFireDACAdapter.Execute: boolean;
begin
  if assigned(FJsonValue) then
    FJsonValue.DisposeOf;
  FJsonValue := nil;

  result := false;
  if assigned(FResponseJSON) then
    result := FResponseJSON.Execute(
      procedure
      begin
        if assigned(FDataset) then
          CreateDatasetFromJson('');
      end);
end;

class procedure THTTPFireDACAdapter.FillDatasetFromJSONValue
  (ARootElement: string; ADataset: TDataset; AJson: TJsonValue;
AUseReflect: boolean);
var
  Adpter: TCustomJSONDataSetAdapter;
  ji: TJsonPair;
  achei: boolean;
  jo: TJsonObject;
  jv: TJsonObject;
  procedure LoadWithReflect(Const AJson: TJsonObject; achou: integer);
  var
    LDataSets: TFDJSONDatasets;
    memDs: TFDMemTable;
  begin
    LDataSets := TFDJSONDatasets.create;
    TFDJSONInterceptor.JSONObjectToDataSets(AJson, LDataSets);

    if ADataset.InheritsFrom(TFDMemTable) then
    begin // � um FdMemTable
      TFDMemTable(ADataset).AppendData
        (TFDJSONDataSetsReader.GetListValue(LDataSets, achou));
    end
    else
    begin
      // cria um MemTable de passagem
      memDs := TFDMemTable.create(nil);
      try
        TFDMemTable(memDs).AppendData
          (TFDJSONDataSetsReader.GetListValue(LDataSets, achou));
        TFDDataset(ADataset).Close;
        TFDDataset(ADataset).CachedUpdates := true;
        TFDDataset(ADataset).Data := memDs.Data;
        TFDDataset(ADataset).CancelUpdates;
      finally
        memDs.DisposeOf;
      end;
    end;

  end;

var
  achou, i: integer;
begin
  Adpter := TCustomJSONDataSetAdapter.create(nil);
  try
    achou := 0;
    i := 0;
    jv := nil;
    jo := AJson as TJsonObject;
    for ji in jo do
    begin
      if sametext(ji.JsonString.Value, ARootElement) then
      begin
        achou := i;
        jv := TJsonObject.create(ji);
        break;
      end;
      inc(i);
    end;

    if not assigned(jv) then
      jv := AJson as TJsonObject;
    Adpter.Dataset := ADataset;
    if not AUseReflect then
      Adpter.UpdateDataSet(jv)
    else
      LoadWithReflect(jv, achou);
  finally
    Adpter.DisposeOf;
  end;
end;

function THTTPFireDACAdapter.GetActive: boolean;
begin
  if assigned(FDataset) then
    result := FDataset.Active;
end;

procedure THTTPFireDACAdapter.Notification(AComponent: TComponent;
AOperation: TOperation);
begin
  if (AOperation = TOperation.opRemove) then
  begin
    if AComponent = FResponseJSON then
      FResponseJSON := nil;
    if AComponent = FDataset then
      FDataset := nil;
  end;
  inherited;

end;

procedure THTTPFireDACAdapter.SetActive(const Value: boolean);
begin
  if assigned(FDataset) then
    FDataset.Active := Value;
end;

procedure THTTPFireDACAdapter.SetDataset(const Value: TDataset);
begin
  FDataset := Value;
end;

procedure THTTPFireDACAdapter.SetResponseJSON(const Value: THTTPRestClient);
begin
  FResponseJSON := Value;
end;

procedure THTTPFireDACAdapter.SetRootElement(const Value: string);
begin
  FRootElement := Value;
end;

end.
