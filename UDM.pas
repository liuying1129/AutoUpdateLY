unit UDM;

interface

uses
  SysUtils, Classes,IniFiles,Forms, IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, IdFTP,IdFTPList,Dialogs,ShellAPI,
  Windows,IdAntiFreezeBase, IdAntiFreeze;

type
  TDM = class(TDataModule)
    IdFTP1: TIdFTP;
    IdAntiFreeze1: TIdAntiFreeze;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

const
  CryptStr='lc';
  gcRemoteDir='YkSoft';
  gcVersionInfoFile='VersionInfo.xml';
  
var
  DM: TDM;
  giDirOrFileNo:integer;
  gslFileVersion:TStrings;

function DeCryptStr(aStr: Pchar; aKey: Pchar): Pchar;stdcall;external 'DESCrypt.dll';//解密
function ShowOptionForm(const pCaption,pTabSheetCaption,pItemInfo,pInifile:Pchar):boolean;stdcall;external 'OptionSetForm.dll';
function GetVersionLY(const AFileName:pchar):pchar;stdcall;external 'LYFunction.dll';

function MakeFtpConn:boolean;
function MakeExeFile:boolean;
procedure FTP_DownloadDir(AIdFTP:TIdFtp;ARemoteDir,ALocalDir:string);
  
implementation

uses UfrmMain;

{$R *.dfm}

procedure TDM.DataModuleCreate(Sender: TObject);
begin
  gslFileVersion:=TStringList.Create;

  MakeFtpConn;
end;

function MakeFtpConn:boolean;
var
  ss: string;
  Ini: tinifile;
  Host,Username,Password:String;
  ifAnonymous:boolean;

  pInStr,pDeStr:Pchar;
  i,Port:integer;
  Label labReadIni;
begin
  result:=false;

  labReadIni:
  Ini := tinifile.Create(ChangeFileExt(Application.ExeName,'.ini'));
  Host := Ini.ReadString('连接FTP服务器', 'Host', '');
  Port := Ini.ReadInteger('连接FTP服务器', 'Port', 21);
  ifAnonymous:=ini.ReadBool('连接FTP服务器','匿名用户',false);
  Username := Ini.ReadString('连接FTP服务器', '用户', '');
  Password := Ini.ReadString('连接FTP服务器', '口令', '107DFC967CDCFAAF');
  Ini.Free;
  //======解密password
  pInStr:=pchar(password);
  pDeStr:=DeCryptStr(pInStr,Pchar(CryptStr));
  setlength(password,length(pDeStr));
  for i :=1  to length(pDeStr) do password[i]:=pDeStr[i-1];
  //==========

  if ifAnonymous then Username:='anonymous';

  try
    dm.IdFTP1.Disconnect;
    //dm.IdFTP1.Passive:=true;//True表示主动模式；false表示被动模式.默认为false//IdFTP.List报错时可能需要设置为true
    dm.IdFTP1.Host:=Host;
    dm.IdFTP1.Port:=Port;
    dm.IdFTP1.Username:=Username;
    dm.IdFTP1.Password:=Password;
    dm.IdFTP1.Connect;
    result:=true;
  except
  end;
  if not result then
  begin
    ss:='Host'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        'Port'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '匿名用户'+#2+'CheckListBox'+#2+#2+'0'+#2+'启用该模式,则用户及口令无需填写'+#2+#3+
        '用户'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '口令'+#2+'Edit'+#2+#2+'0'+#2+#2+'1';
    if ShowOptionForm('连接FTP服务器','连接FTP服务器',Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
      goto labReadIni else application.Terminate;
  end;
end;

function MakeExeFile:boolean;
var
  ss: string;
  Ini: tinifile;
  ExeFile:String;
  Label labReadIni;
begin
  result:=false;

  labReadIni:
  Ini := tinifile.Create(ChangeFileExt(Application.ExeName,'.ini'));
  ExeFile := Ini.ReadString('Interface', '执行文件', '');
  Ini.Free;

  if FileExists(ExeFile) then
  begin
    if ShellExecute(Application.Handle, 'Open', Pchar(ExeFile), '', '', SW_ShowNormal)>32 then
      result:=true
    else MessageDlg(ExeFile+'打开失败!',mtError,[mbOK],0);
  end;

  if not result then
  begin
    ss:='执行文件'+#2+'File'+#2+#2+'0'+#2+'表示升级后应该执行的程序'+#2+#3;
    if ShowOptionForm('设置','Interface',Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
      goto labReadIni else application.Terminate;
  end;
end;

{===============================
  下载整个目录，并遍历所有子目录
  首先 ChangeDir(Root) 到根目录
  然后创建本地目录 + RemoteDir
  然后用 list 得到所有目录名
  循环判断,进入 RemoteDir 目录内部
  如果是目录继续第归。否则 get 该文件到本地目录，当 get 完所有文件后返回上一级目录
  用List再取得信息，继续循环
================================}
procedure FTP_DownloadDir(AIdFTP:TIdFtp;ARemoteDir,ALocalDir:string);
var
  i,DirCount : integer;
  DirOrFileName:string;
  //tmpLocalDir:string;
  tmpLocalDir2:string;

  function ifDownLoad(AAIdFTP:TIdFtp;AARemoteFile:string;AALocalFile:string):boolean;
  begin
    result:=true;

    if SameText(AARemoteFile,'VersionInfo.xml') then
    begin
      result:=false;
      exit;
    end;

    if not FileExists(AALocalFile) then exit;

    if not SameText(ExtractFileExt(AALocalFile),'.exe') and not SameText(ExtractFileExt(AALocalFile),'.dll') then exit;

    //xml中未配置该exe、dll
    if gslFileVersion.IndexOfName(AARemoteFile)<0 then
    begin
      result:=false;
      exit;
    end;

    //版本号相同
    if SameText(gslFileVersion.Values[AARemoteFile],strpas(GetVersionLY(pchar(AALocalFile)))) then
    begin
      result:=false;
      exit;
    end;
  end;
  
begin
  if ALocalDir[length(ALocalDir)]<>'\' then tmpLocalDir2:=ALocalDir+'\' else tmpLocalDir2:=ALocalDir;

  AIdFTP.ChangeDir(ARemoteDir);

  try
    AIdFTP.List(nil);
  except
    on E:Exception do
    begin
      MESSAGEDLG('对FTP服务器目录['+AIdFTP.RetrieveCurrentDir+']list时报错:'+E.Message,mtError,[mbOK],0);
      exit;
    end;
  end;

  DirCount := AIdFTP.DirectoryListing.Count;

  if DirCount <= 0 then
  begin
    AIdFTP.ChangeDirUp;
    try
      AIdFTP.List(nil);
    except
      on E:Exception do
      begin
        MESSAGEDLG('对FTP服务器目录['+AIdFTP.RetrieveCurrentDir+']list时报错:'+E.Message,mtError,[mbOK],0);
        exit;
      end;
    end;
  end;

  for i := 0 to DirCount - 1 do
  begin
    //进度条展示
    inc(giDirOrFileNo);
    frmMain.ProgressBar1.Progress:=giDirOrFileNo;
  
    if DirCount <> AIdFTP.DirectoryListing.Count then
    begin
      repeat
        AIdFTP.ChangeDirUp;
        try
          AIdFTP.List(nil);
        except
          on E:Exception do
          begin
            MESSAGEDLG('对FTP服务器目录['+AIdFTP.RetrieveCurrentDir+']list时报错:'+E.Message,mtError,[mbOK],0);
            exit;
          end;
        end;
      until DirCount = AIdFTP.DirectoryListing.Count ;
    end;

    DirOrFileName := AIdFTP.DirectoryListing.Items[i].FileName;
    
    if AIdFTP.DirectoryListing[i].ItemType = ditDirectory then
    begin
      FTP_DownloadDir(AIdFTP,DirOrFileName,tmpLocalDir2+ARemoteDir+'\');
    end else
    begin
      {//使下载到的文件、文件夹与下载程序在同一级目录
      //如在同一级目录，DESCrypt.dll、OptionSetForm.dll、LYFunction.dll无法更新
      if ifDownLoad(AIdFTP,DirOrFileName,tmpLocalDir+DirOrFileName) then
      begin
        tmpLocalDir:=tmpLocalDir2+ARemoteDir+'\';
        tmpLocalDir:=StringReplace(tmpLocalDir,'\'+gcRemoteDir+'\','\',[rfIgnoreCase]);
        if not DirectoryExists(tmpLocalDir) then ForceDirectories(tmpLocalDir);
        try
          //Showmessage(DirOrFileName);
          AIdFTP.Get(DirOrFileName,tmpLocalDir+DirOrFileName,true,false);
        except
          on E:Exception do
          begin
            MESSAGEDLG('下载文件报错:'+E.Message,mtError,[mbOK],0);
          end;
        end;
      end;//}

      //使下载到的文件、文件夹在下载程序的下级目录
      if ifDownLoad(AIdFTP,DirOrFileName,tmpLocalDir2+ARemoteDir+'\'+DirOrFileName) then
      begin
        if not DirectoryExists(tmpLocalDir2+ARemoteDir) then ForceDirectories(tmpLocalDir2+ARemoteDir);
        try
          //Showmessage(DirOrFileName);
          AIdFTP.Get(DirOrFileName,tmpLocalDir2+ARemoteDir+'\'+DirOrFileName,true,false);
        except
          on E:Exception do
          begin
            MESSAGEDLG('下载文件报错:'+E.Message,mtError,[mbOK],0);
          end;
        end;
      end;//}

      if i = DirCount - 1 then
      begin
        AIdFTP.ChangeDirUp;
        try
          AIdFTP.List(nil);
        except
          on E:Exception do
          begin
            MESSAGEDLG('对FTP服务器目录['+AIdFTP.RetrieveCurrentDir+']list时报错:'+E.Message,mtError,[mbOK],0);
            exit;
          end;
        end;
      end;
    end;
  end;
end;

end.
