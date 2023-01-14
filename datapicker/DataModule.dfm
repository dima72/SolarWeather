object DataMod: TDataMod
  Height = 364
  Width = 551
  object FDConnection: TFDConnection
    LoginPrompt = False
    Left = 48
    Top = 24
  end
  object FDQuery: TFDQuery
    Connection = FDConnection
    Left = 136
    Top = 24
  end
  object RESTClient: TRESTClient
    BaseURL = 'https://services.swpc.noaa.gov'
    Params = <>
    SynchronizedEvents = False
    Left = 48
    Top = 88
  end
  object RESTRequest: TRESTRequest
    Client = RESTClient
    Params = <>
    Resource = 'text/3-day-geomag-forecast.txt'
    Response = RESTResponse
    SynchronizedEvents = False
    Left = 144
    Top = 96
  end
  object RESTResponse: TRESTResponse
    Left = 232
    Top = 96
  end
end
