program datapicker;
 {copyrights@Sapunovo.com}
{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils, System.SyncObjs,
  DataModule in 'DataModule.pas' {DataMod: TDataModule};
var
  AppplicationID : string;
  RunOnceMutex : TMutex;
  n : Integer;
begin
  try
    WriteLn('Checking for running instance');
    AppplicationID := '{79F8A46A-464A-4A60-B2D1-6F1E4376E891}';
    RunOnceMutex := TMutex.Create(nil, true, AppplicationID);
    if RunOnceMutex.WaitFor(1000) = wrTimeout then
    begin
      WriteLn('the application already running, please wait 20s');
      ExitCode := -1;
      Exit;
    end;
    RunOnceMutex.Acquire;
  except on E: Exception do
    WriteLn(E.ClassName + ' : ' + E.Message);
  end;
  InitLog;
  Log('Start');
  try
    // checks if application is already running
    DataMod := TDataMod.Create(Nil);
    try
      try
        DataMod.DoWork;
      except on E: Exception do
        Log(E.ClassName + ' : ' + E.Message);
      end;
    finally
      DataMod.Free;
      Log('Sleep 20s');
      Sleep(20000);
      RunOnceMutex.Release;
      RunOnceMutex.Free;
    end;
  except on E: Exception do
    Log(E.ClassName + ' : ' + E.Message);
  end;
  Log('End of work. Unloaded');
  CloseFile(logFile);
  ExitCode := 0;
end.
