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
  
var
  DM: TDM;

function DeCryptStr(aStr: Pchar; aKey: Pchar): Pchar;stdcall;external 'DESCrypt.dll';//����
function ShowOptionForm(const pCaption,pTabSheetCaption,pItemInfo,pInifile:Pchar):boolean;stdcall;external 'OptionSetForm.dll';

function MakeFtpConn:boolean;
procedure FTP_DownloadDir(IdFTP:TIdFtp;RemoteDir,LocalDir:string);
  
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

{ ��������Ŀ¼��������������Ŀ¼

  ���� ChangeDir(Root) ����Ŀ¼

  Ȼ�󴴽�����Ŀ¼ + RemoteDir

  Ȼ���� list �õ�����Ŀ¼��

  ѭ���ж�,���� RemoteDir Ŀ¼�ڲ�

  �����Ŀ¼�����ڹ顣���� get ���ļ�������Ŀ¼���� get �������ļ��󷵻���һ��Ŀ¼

  ��List��ȡ����Ϣ������ѭ��
 }
procedure FTP_DownloadDir(IdFTP:TIdFtp;RemoteDir,LocalDir:string);
var
  i,DirCount : integer;
  Name:string;
begin
  if not DirectoryExists(LocalDir + RemoteDir) then ForceDirectories(LocalDir + RemoteDir);

  idFTP.ChangeDir(RemoteDir);

  try
    idFTP.List(nil);
  except
    on E:Exception do
    begin
      MESSAGEDLG('��FTP����������listʱ����:'+E.Message,mtError,[mbOK],0);
      exit;
    end;
  end;
  //ListBox1.Items.Assign(LS);

  DirCount := idFTP.DirectoryListing.Count;

  if DirCount <= 0 then
  begin
    idFTP.ChangeDirUp;
    try
      idFTP.List(nil);
    except
      on E:Exception do
      begin
        MESSAGEDLG('��FTP����������listʱ����:'+E.Message,mtError,[mbOK],0);
        exit;
      end;
    end;
  end;

  for i := 0 to DirCount - 1 do
  begin
    if DirCount <> idFTP.DirectoryListing.Count then
    begin
      repeat
        idFTP.ChangeDirUp;
        try
          idFTP.List(nil);
        except
          on E:Exception do
          begin
            MESSAGEDLG('��FTP����������listʱ����:'+E.Message,mtError,[mbOK],0);
            exit;
          end;
        end;
      until DirCount = idFTP.DirectoryListing.Count ;
    end;

    Name := dm.IdFTP1.DirectoryListing.Items[i].FileName;
    
    if idFTP.DirectoryListing[i].ItemType = ditDirectory then
    begin
      FTP_DownloadDir(idFTP,Name,LocalDir + RemoteDir + '\');
    end else
    begin
      idFTP.Get(Name,LocalDir + RemoteDir + '\' +Name,true,false);

      if i = DirCount - 1 then
      begin
        idFTP.ChangeDirUp;
        try
          idFTP.List(nil);
        except
          on E:Exception do
          begin
            MESSAGEDLG('��FTP����������listʱ����:'+E.Message,mtError,[mbOK],0);
            exit;
          end;
        end;
      end;
    end;
  end;
end;

end.
