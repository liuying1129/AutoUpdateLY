object DM: TDM
  OldCreateOrder = False
  OnCreate = DataModuleCreate
  Left = 192
  Top = 122
  Height = 220
  Width = 316
  object IdFTP1: TIdFTP
    MaxLineAction = maException
    ReadTimeout = 0
    Passive = True
    ProxySettings.ProxyType = fpcmNone
    ProxySettings.Port = 0
    Left = 48
    Top = 24
  end
  object IdAntiFreeze1: TIdAntiFreeze
    IdleTimeOut = 50
    OnlyWhenIdle = False
    Left = 168
    Top = 24
  end
end
