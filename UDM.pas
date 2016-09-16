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
  gcRemoteRootDir='YkSoft';
  gcVersionInfoFile='VersionInfo.xml';
  
var
  DM: TDM;
  giDirOrFileNo:integer;
  gslFileVersion:TStrings;

function DeCryptStr(aStr: Pchar; aKey: Pchar): Pchar;stdcall;external 'DESCrypt.dll';//����
function ShowOptionForm(const pCaption,pTabSheetCaption,pItemInfo,pInifile:Pchar):boolean;stdcall;external 'OptionSetForm.dll';
function GetVersionLY(const AFileName:pchar):pchar;stdcall;external 'LYFunction.dll';
procedure WriteLog(const ALogStr: Pchar);stdcall;external 'LYFunction.dll';

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
  Host := Ini.ReadString('����FTP������', 'Host', '');
  Port := Ini.ReadInteger('����FTP������', 'Port', 21);
  ifAnonymous:=ini.ReadBool('����FTP������','�����û�',false);
  Username := Ini.ReadString('����FTP������', '�û�', '');
  Password := Ini.ReadString('����FTP������', '����', '107DFC967CDCFAAF');
  Ini.Free;
  //======����password
  pInStr:=pchar(password);
  pDeStr:=DeCryptStr(pInStr,Pchar(CryptStr));
  setlength(password,length(pDeStr));
  for i :=1  to length(pDeStr) do password[i]:=pDeStr[i-1];
  //==========

  if ifAnonymous then Username:='anonymous';

  try
    dm.IdFTP1.Disconnect;
    //dm.IdFTP1.Passive:=true;//True��ʾ����ģʽ��false��ʾ����ģʽ.Ĭ��Ϊfalse//IdFTP.List����ʱ������Ҫ����Ϊtrue
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
        '�����û�'+#2+'CheckListBox'+#2+#2+'0'+#2+'���ø�ģʽ,���û�������������д'+#2+#3+
        '�û�'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '����'+#2+'Edit'+#2+#2+'0'+#2+#2+'1';
    if ShowOptionForm('����FTP������','����FTP������',Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
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
  ExeFile := Ini.ReadString('Interface', 'ִ���ļ�', '');
  Ini.Free;

  if FileExists(ExeFile) then
  begin
    if ShellExecute(Application.Handle, 'Open', Pchar(ExeFile), '', '', SW_ShowNormal)>32 then
      result:=true
    else MessageDlg(ExeFile+'��ʧ��!',mtError,[mbOK],0);
  end;

  if not result then
  begin
    ss:='ִ���ļ�'+#2+'File'+#2+#2+'0'+#2+'��ʾ������Ӧ��ִ�еĳ���'+#2+#3;
    if ShowOptionForm('����','Interface',Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
      goto labReadIni else application.Terminate;
  end;
end;

{===============================
  ��������Ŀ¼��������������Ŀ¼
  ���� ChangeDir(Root) ����Ŀ¼
  Ȼ�󴴽�����Ŀ¼ + RemoteDir
  Ȼ���� list �õ�����Ŀ¼��
  ѭ���ж�,���� RemoteDir Ŀ¼�ڲ�
  �����Ŀ¼�����ڹ顣���� get ���ļ�������Ŀ¼���� get �������ļ��󷵻���һ��Ŀ¼
  ��List��ȡ����Ϣ������ѭ��
================================}
procedure FTP_DownloadDir(AIdFTP:TIdFtp;ARemoteDir,ALocalDir:string);
var
  i,DirCount : integer;
  DirOrFileName:string;
  //tmpLocalDir:string;
  tmpLocalDir2:string;

  function ifDownLoad(AAIdFTP:TIdFtp;AALocalFile:string):boolean;
  var
    keyName:string;
  begin
    result:=true;

    keyName:=copy(AALocalFile,pos('\'+gcRemoteRootDir+'\',AALocalFile),MaxInt);
    keyName:=StringReplace(keyName,'\'+gcRemoteRootDir+'\','',[rfIgnoreCase]);

    if SameText(keyName,'VersionInfo.xml') then
    begin
      result:=false;
      exit;
    end;

    if not FileExists(AALocalFile) then exit;

    if not SameText(ExtractFileExt(AALocalFile),'.exe') and not SameText(ExtractFileExt(AALocalFile),'.dll') then exit;

    //xml��δ���ø�exe��dll
    if gslFileVersion.IndexOfName(keyName)<0 then
    begin
      result:=false;
      exit;
    end;

    //�汾����ͬ
    if SameText(gslFileVersion.Values[keyName],strpas(GetVersionLY(pchar(AALocalFile)))) then
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
      MESSAGEDLG('��FTP������Ŀ¼['+AIdFTP.RetrieveCurrentDir+']listʱ����:'+E.Message,mtError,[mbOK],0);
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
        MESSAGEDLG('��FTP������Ŀ¼['+AIdFTP.RetrieveCurrentDir+']listʱ����:'+E.Message,mtError,[mbOK],0);
        exit;
      end;
    end;
  end;

  for i := 0 to DirCount - 1 do
  begin
    //������չʾ
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
            MESSAGEDLG('��FTP������Ŀ¼['+AIdFTP.RetrieveCurrentDir+']listʱ����:'+E.Message,mtError,[mbOK],0);
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
      {//ʹ���ص����ļ����ļ��������س�����ͬһ��Ŀ¼
      //����ͬһ��Ŀ¼��DESCrypt.dll��OptionSetForm.dll��LYFunction.dll�޷�����
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
            MESSAGEDLG('�����ļ�����:'+E.Message,mtError,[mbOK],0);
          end;
        end;
      end;//}

      //ʹ���ص����ļ����ļ��������س�����¼�Ŀ¼
      if ifDownLoad(AIdFTP,tmpLocalDir2+ARemoteDir+'\'+DirOrFileName) then
      begin
        if not DirectoryExists(tmpLocalDir2+ARemoteDir) then ForceDirectories(tmpLocalDir2+ARemoteDir);
        try
          AIdFTP.Get(DirOrFileName,tmpLocalDir2+ARemoteDir+'\'+DirOrFileName,true,false);
          WriteLog(pchar('�ļ�['+tmpLocalDir2+ARemoteDir+'\'+DirOrFileName+']���سɹ�'));
        except
          on E:Exception do
          begin
            MESSAGEDLG('�����ļ�['+tmpLocalDir2+ARemoteDir+'\'+DirOrFileName+']����:'+E.Message,mtError,[mbOK],0);
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
            MESSAGEDLG('��FTP������Ŀ¼['+AIdFTP.RetrieveCurrentDir+']listʱ����:'+E.Message,mtError,[mbOK],0);
            exit;
          end;
        end;
      end;
    end;
  end;
end;

end.
