unit DataModule;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.ConsoleUI.Wait,
  FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, Data.DB,
  FireDAC.Comp.DataSet, FireDAC.Comp.Client, FireDAC.Phys.MySQL,
  FireDAC.Phys.MySQLDef, System.Inifiles, REST.Types, REST.Client,
  Data.Bind.Components, Data.Bind.ObjectScope, System.DateUtils, System.StrUtils;

type
  TDataMod = class(TDataModule)
    FDConnection: TFDConnection;
    FDQuery: TFDQuery;
    RESTClient: TRESTClient;
    RESTRequest: TRESTRequest;
    RESTResponse: TRESTResponse;
  private
    { Private declarations }
  public
    procedure DoWork;
    procedure InsertForecastValue(p_Year : string; p_Month : string; p_Day : string; p_Hour : string; p_Val : string);

    { Public declarations }
  end;

  procedure CheckError(p_Yes : Boolean; p_Message : string);
  procedure InitLog;
  procedure Log(p_Message : string);
  function Fetch(var AInput: string; ADelim: String): string;

var
  DataMod: TDataMod;
  logFile : TextFile;
  g_AppPath : string;
  g_LogFileName : string;
implementation

{%CLASSGROUP 'System.Classes.TPersistent'}

{$R *.dfm}

procedure CheckError(p_Yes : Boolean; p_Message : string);
begin
   if not p_Yes then raise Exception.Create(p_Message);
end;

procedure InitLog;
var
 a_AlternateLogFile : string;
begin
  try
    a_AlternateLogFile := FormatDateTime('YYYY-MM-DD-hh-mm-ss', Now);
    g_AppPath :=
    ExcludeTrailingPathDelimiter(
      StringReplace(ExtractFilePath(paramstr(0)), '"', '', [rfReplaceAll]));
    g_LogFileName := g_AppPath + '\datapicker_log.txt';
    AssignFile(logFile, g_LogFileName);
    if FileExists(g_LogFileName) then Append(logFile) else ReWrite(logFile);
  except on E: Exception do
  begin
    WriteLn(E.ClassName + ' : ' + E.Message);
    g_LogFileName := g_AppPath + '\datapicker_log'+a_AlternateLogFile+'.txt';
    AssignFile(logFile, g_LogFileName);
    if FileExists(g_LogFileName) then Append(logFile) else ReWrite(logFile);
    Log('Problem with datapicker_log. Opening alternative file');
  end;
  end;
end;

procedure Log(p_Message : string);
begin
  Writeln(logFile, DateTimeToStr(Now) + ' ' + p_Message);
  Writeln(DateTimeToStr(Now) + ' ' + p_Message);
end;

function Fetch(var AInput: string; ADelim: String): string;
var
  LPos: Integer;
begin
  LPos := Pos(ADelim, AInput);
  if LPos = 0 then
  begin
    Result := AInput;
    AInput := '';
    Exit;
  end;
  Result := Copy(AInput, 1, LPos - 1);
  AInput := Copy(AInput, LPos + Length(ADelim), Length(AInput));
end;

procedure TDataMod.InsertForecastValue(p_Year : string; p_Month : string; p_Day : string; p_Hour : string; p_Val : string);
var
  a_ForecastDate : string;
  a_ForecastDt : TDateTime;
  a_MonthIndex : Integer;
begin
  CheckError(Trim(p_Year) <> '', 'p_Year is empty');
  CheckError(Trim(p_Month) <> '', 'p_Month is empty');
  CheckError(Trim(p_Day) <> '', 'p_Day is empty');
  CheckError(Trim(p_Hour) <> '', 'p_Hour is empty');
  CheckError(Trim(p_Val) <> '', 'p_Val is empty');
  a_MonthIndex := IndexText(p_Month,FormatSettings.ShortMonthNames);
  CheckError(a_MonthIndex <> -1, 'Month index not found for month:' + p_Month);
  a_MonthIndex := a_MonthIndex +1;
  a_ForecastDt := EncodeDateTime(StrToInt(p_Year), a_MonthIndex, StrToInt(p_Day),
    StrToInt(p_Hour), 0, 0, 0);
  a_ForecastDate := FormatDateTime('YYYY-MM-DD hh:mm:ss', a_ForecastDt);

  FDQuery.SQL.Text := 'INSERT INTO `'+FDConnection.Params.Database+'`.`magn24` '+
  ' (`FORECAST_DATE`, `FORECAST_VAL`) VALUES ('''+a_ForecastDate+''', '+p_Val+') ' +
  ' ON DUPLICATE KEY UPDATE `FORECAST_DATE` = '''+a_ForecastDate+''', `FORECAST_VAL` = '+p_Val+';';
  FDQuery.ExecSQL;
end;


procedure TDataMod.DoWork;
var
  a_IniFileName, a_Content, a_DatesRange, a_DatesColumns, a_Row, a_FieldVal, a_Hour,
    a_Day1, a_Day2, a_Day3, a_Month1, a_Month2, a_Month3, a_Year, a_ServiceActivity : string;
  a_IniFile : TIniFile;
  a_ConnectionParamsSL, a_ForecastSL, a_TimeRangeSL, a_Vals_1_SL, a_Vals_2_SL, a_Vals_3_SL : TStringList;
  I, J, a_RecordsProcessed : Integer;
begin
  a_IniFile := Nil;
  a_ConnectionParamsSL := Nil;
  a_IniFileName := g_AppPath + '\datapicker.ini';
  CheckError(FileExists(a_IniFileName), 'Ini file '+g_AppPath+' - not found');
  a_IniFile := TIniFile.Create(a_IniFileName);
  a_ConnectionParamsSL := TStringList.Create;
  try
    Log('Ini reading connection params');
    a_IniFile.ReadSectionValues('DatabaseConnection', a_ConnectionParamsSL);
    CheckError(a_ConnectionParamsSL.Count > 0, 'Ini connection params not found in DatabaseConnection section');
    FDConnection.Params.AddStrings(a_ConnectionParamsSL);
    FDConnection.Connected := True;
    Log('Connected to Database: ' + FDConnection.Params.Database);

    FDQuery.SQL.Text := 'CHECK TABLE `magn24`';
    FDQuery.Open;
    if FDQuery.FieldByName('Msg_text').AsString <> 'OK' then
    begin
      Log('Creating table magn24');
      FDQuery.SQL.Text :=
      ' CREATE TABLE `'+FDConnection.Params.Database+'`.`magn24` ( '+
      ' `ID` INT NOT NULL AUTO_INCREMENT, '+
      ' `FORECAST_DATE` DATETIME NOT NULL, '+
      ' `FORECAST_VAL` FLOAT NOT NULL, '+
      ' PRIMARY KEY (`ID`), '+
      ' UNIQUE KEY `FORECAST_DATE_UNIQUE` (`FORECAST_DATE`));';
      FDQuery.ExecSQL;
      FDQuery.SQL.Text := 'CHECK TABLE `magn24`';
      FDQuery.Open;
      CheckError(FDQuery.FieldByName('Msg_text').AsString = 'OK', 'Table magn24 not found in the database');
      Log('Table magn24 created');
    end;


    RESTRequest.Method := rmGET;
    Log('Executing HTTP GET request:' + RESTClient.BaseURL + '/' + RESTRequest.Resource);
    RESTRequest.Execute;
    a_Content := RESTResponse.Content;
    {Log('------------Responce Content------------');
    Log(a_Content);
    Log('-----------------------------------------');
    }
    I := Pos('Not Available', a_Content);
    J := Length(a_Content);
    if J - I = Length('Not Available') then //if 'Not Available' is at the end of data
    begin
      if FileExists(g_AppPath + '\local_forecast.txt') then
      begin
        Log('http forecast not available, Loading ' + g_AppPath + '\local_forecast.txt');

        with TStringList.Create do
        begin
          LoadFromFile(g_AppPath + '\local_forecast.txt');
          a_Content := Text;
          Free;
        end;
      end;
    end;


    Fetch(a_Content, ':Issued:');
    a_Content := Trim(a_Content);
    a_Year := Trim(Fetch(a_Content, ' '));

    Fetch(a_Content, 'NOAA Geomagnetic Activity Probabilities');

    a_ServiceActivity := Trim(Fetch(a_Content, 'NOAA Kp index forecast'));
    Log('NOAA Geomagnetic Activity Probabilities'+#13#10 + a_ServiceActivity);

    a_ForecastSL := TStringList.Create;
    a_TimeRangeSL := TStringList.Create;
    a_Vals_1_SL := TStringList.Create;
    a_Vals_2_SL := TStringList.Create;
    a_Vals_3_SL := TStringList.Create;
    a_RecordsProcessed := 0;
    try
      a_ForecastSL.Text := a_Content;
      a_DatesRange := Trim(a_ForecastSL.Strings[0]);
      CheckError(a_DatesRange.Length <> Length('00-03UT        1.67      1.67      2.33'), 'Dates Range header length error');
      a_ForecastSL.Delete(0);
      a_DatesColumns := Trim(a_ForecastSL.Strings[0]);
      CheckError(a_DatesColumns.Length <> Length('00-03UT        1.67      1.67      2.33'), 'Dates Columns length error');
      a_ForecastSL.Delete(0);

      a_Month1 := Fetch(a_DatesColumns, ' ');
      a_Day1 := Fetch(a_DatesColumns, ' ');
      a_DatesColumns := Trim(a_DatesColumns);

      a_Month2 := Fetch(a_DatesColumns, ' ');
      a_Day2 := Fetch(a_DatesColumns, ' ');
      a_DatesColumns := Trim(a_DatesColumns);

      a_Month3 := Fetch(a_DatesColumns, ' ');
      a_Day3 := Fetch(a_DatesColumns, ' ');
      a_DatesColumns := Trim(a_DatesColumns);


      if (Trim(a_ForecastSL.Text) = 'Not Available') or (Trim(a_ForecastSL.Text) = '') then
        CheckError(false, 'Service Data not available');
      a_TimeRangeSL.Text := a_ForecastSL.Text;
      for I := 0 to a_TimeRangeSL.Count-1 do
      begin
        a_Row := a_TimeRangeSL.Strings[I];
        a_TimeRangeSL.Strings[I] := Trim(Fetch(a_Row, ' '));
      end;

      a_Vals_1_SL.Text := a_ForecastSL.Text;
      for I := 0 to a_Vals_1_SL.Count-1 do
      begin
        a_Row := a_Vals_1_SL.Strings[I];
        Fetch(a_Row, ' ');
        a_Row := Trim(a_Row);
        a_FieldVal := Fetch(a_Row, ' ');
        a_Vals_1_SL.Strings[I] := a_FieldVal;
        a_Hour := a_TimeRangeSL.Strings[I];
        a_Hour := Trim(Fetch(a_Hour, '-'));
        Log('Month: ' + a_Month1 +' Day: ' + a_Day1 + ' Hour: ' + a_Hour + ' Val: ' +  a_FieldVal);
        InsertForecastValue(a_Year, a_Month1, a_Day1, a_Hour, a_FieldVal);
        Inc(a_RecordsProcessed);
      end;

      a_Vals_2_SL.Text := a_ForecastSL.Text;
      for I := 0 to a_Vals_2_SL.Count-1 do
      begin
        a_Row := a_Vals_2_SL.Strings[I];
        Fetch(a_Row, ' ');
        a_Row := Trim(a_Row);

        Fetch(a_Row, ' ');
        a_Row := Trim(a_Row);

        a_FieldVal := Fetch(a_Row, ' ');
        a_Vals_2_SL.Strings[I] := a_FieldVal;

        a_Hour := a_TimeRangeSL.Strings[I];
        a_Hour := Trim(Fetch(a_Hour, '-'));
        Log('Month: ' + a_Month2 +' Day: ' + a_Day2 + ' Hour: ' + a_Hour + ' Val: ' +  a_FieldVal);
        InsertForecastValue(a_Year, a_Month2, a_Day2, a_Hour, a_FieldVal);
        Inc(a_RecordsProcessed);
      end;


      a_Vals_3_SL.Text := a_ForecastSL.Text;
      for I := 0 to a_Vals_3_SL.Count-1 do
      begin
        a_Row := a_Vals_3_SL.Strings[I];
        Fetch(a_Row, ' ');
        a_Row := Trim(a_Row);

        Fetch(a_Row, ' ');
        a_Row := Trim(a_Row);

        Fetch(a_Row, ' ');
        a_Row := Trim(a_Row);

        a_FieldVal := Fetch(a_Row, ' ');
        a_Vals_3_SL.Strings[I] := a_FieldVal;

        a_Hour := a_TimeRangeSL.Strings[I];
        a_Hour := Trim(Fetch(a_Hour, '-'));

        Log('Month: ' + a_Month3 +' Day: ' + a_Day3 + ' Hour: ' + a_Hour + ' Val: ' +  a_FieldVal);
        InsertForecastValue(a_Year, a_Month3, a_Day3, a_Hour, a_FieldVal);
        Inc(a_RecordsProcessed);
      end;

    finally
      a_Vals_3_SL.Free;
      a_Vals_2_SL.Free;
      a_Vals_1_SL.Free;
      a_TimeRangeSL.Free;
      a_ForecastSL.Free;
    end;

    FDConnection.Connected := False;
    Log('processed :' + IntToStr(a_RecordsProcessed) + ' records');

    Log('Disconnected of Database');
  finally
    if Assigned(a_IniFile) then
      a_IniFile.Free;
    if Assigned(a_ConnectionParamsSL) then
      a_ConnectionParamsSL.Free;
  end;
end;

end.
