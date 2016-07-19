unit UDM;

interface

uses
  SysUtils, Classes,IniFiles,Forms, IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, IdFTP,IdFTPList,Dialogs;

type
  TDM = class(TDataModule)
    IdFTP1: TIdFTP;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

const
  CryptStr='lc';
  gcRemoteDir='YkSoft';
  
var
  DM: TDM;

function DeCryptStr(aStr: Pchar; aKey: Pchar): Pchar;stdcall;external 'DESCrypt.dll';//解密
function ShowOptionForm(const pCaption,pTabSheetCaption,pItemInfo,pInifile:Pchar):boolean;stdcall;external 'OptionSetForm.dll';

function MakeFtpConn:boolean;
procedure FTP_DownloadDir(AIdFTP:TIdFtp;ARemoteDir,ALocalDir:string);
  
implementation

{$R *.dfm}

procedure TDM.DataModuleCreate(Sender: TObject);
begin
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
  tmpLocalDir,tmpLocalDir2:string;
begin
  if ALocalDir[length(ALocalDir)]<>'\' then tmpLocalDir2:=ALocalDir+'\' else tmpLocalDir2:=ALocalDir;

  AIdFTP.ChangeDir(ARemoteDir);

  try
    AIdFTP.List(nil);
  except
    on E:Exception do
    begin
      MESSAGEDLG('对FTP服务器内容list时报错:'+E.Message,mtError,[mbOK],0);
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
        MESSAGEDLG('对FTP服务器内容list时报错:'+E.Message,mtError,[mbOK],0);
        exit;
      end;
    end;
  end;

  for i := 0 to DirCount - 1 do
  begin
    if DirCount <> AIdFTP.DirectoryListing.Count then
    begin
      repeat
        AIdFTP.ChangeDirUp;
        try
          AIdFTP.List(nil);
        except
          on E:Exception do
          begin
            MESSAGEDLG('对FTP服务器内容list时报错:'+E.Message,mtError,[mbOK],0);
            exit;
          end;
        end;
      until DirCount = AIdFTP.DirectoryListing.Count ;
    end;

    DirOrFileName := dm.IdFTP1.DirectoryListing.Items[i].FileName;
    
    if AIdFTP.DirectoryListing[i].ItemType = ditDirectory then
    begin
      FTP_DownloadDir(AIdFTP,DirOrFileName,tmpLocalDir2+ARemoteDir+'\');
    end else
    begin
      //使下载到的文件、文件夹与下载程序在同一级目录
      tmpLocalDir:=tmpLocalDir2+ARemoteDir+'\';
      tmpLocalDir:=StringReplace(tmpLocalDir,'\'+gcRemoteDir+'\','\',[rfIgnoreCase]);
      if not DirectoryExists(tmpLocalDir) then ForceDirectories(tmpLocalDir);
      
      //使下载到的文件、文件夹在下载程序的下级目录
      //if not DirectoryExists(LocalDir + RemoteDir) then ForceDirectories(LocalDir + RemoteDir);

      AIdFTP.Get(DirOrFileName,tmpLocalDir+DirOrFileName,true,false);

      if i = DirCount - 1 then
      begin
        AIdFTP.ChangeDirUp;
        try
          AIdFTP.List(nil);
        except
          on E:Exception do
          begin
            MESSAGEDLG('对FTP服务器内容list时报错:'+E.Message,mtError,[mbOK],0);
            exit;
          end;
        end;
      end;
    end;
  end;
end;

end.
