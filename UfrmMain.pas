unit UfrmMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ComCtrls,Inifiles,StrUtils, Gauges,
  XMLIntf,XMLDoc, ExtCtrls;

type
  TfrmMain = class(TForm)
    ProgressBar1: TGauge;
    Image1: TImage;
    Label1: TLabel;
    Timer1: TTimer;
    procedure Timer1Timer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses UDM;

{$R *.dfm}

procedure TfrmMain.Timer1Timer(Sender: TObject);
Var
  j:integer;
  Save_Cursor:TCursor;
  ss:TStringStream;
  XMLDocument:IXMLDocument;
  XMLNode:IXMLNode;
  sVersion:string;
begin
  (Sender as TTimer).Enabled:=false;

  Save_Cursor := Screen.Cursor;
  Screen.Cursor := crHourGlass;    { Show hourglass cursor }

  try
    dm.IdFTP1.ChangeDir(gcRemoteRootDir);
  except
    on E:Exception do
    begin
      MESSAGEDLG('定位远程根目录['+gcRemoteRootDir+']时报错:'+E.Message,mtError,[mbOK],0);
      application.Terminate;
    end;
  end;
  
  ss:=TStringStream.Create('');
  try
    dm.IdFTP1.Get(gcVersionInfoFile,ss);//无此文件会抛出异常
  except
    on E:Exception do
    begin
      ss.Free;
      MESSAGEDLG('下载版本信息文件['+gcVersionInfoFile+']到Stream报错:'+E.Message,mtError,[mbOK],0);
      application.Terminate;
    end;
  end;
  XMLDocument:=TXMLDocument.Create(nil);
  try
    XMLDocument.LoadFromStream(ss);//不规范的XML会抛出异常
  except
    on E:Exception do
    begin
      ss.Free;
      MESSAGEDLG('版本信息文件['+gcVersionInfoFile+']LoadFromStream报错:'+E.Message,mtError,[mbOK],0);
      application.Terminate;
    end;
  end;
  for j :=0  to XMLDocument.DocumentElement.ChildNodes.Count-1 do
  begin
    XMLNode:=XMLDocument.DocumentElement.ChildNodes[j];

    if not SameText(XMLNode.NodeName,'file') then continue;

    //属性名称是大小写敏感，故XML中必须写成name、version
    if XMLNode.Attributes['name']=null then continue;//该节点无name属性时
    if XMLNode.Attributes['name']='' then continue;
    if XMLNode.Attributes['version']=null then//该节点无version属性时
      sVersion:='' else sVersion:=XMLNode.Attributes['version'];

    gslFileVersion.Add(XMLNode.Attributes['name']+'='+sVersion);
  end;
  ss.free;

  ProgressBar1.MaxValue:=gslFileVersion.Count;//进度条设置

  dm.IdFTP1.ChangeDir('\');//定位到FTP根目录
  FTP_DownloadDir(dm.IdFTP1,gcRemoteRootDir,ExtractFilePath(Application.Exename));

  ProgressBar1.Progress:=ProgressBar1.MaxValue;//进度条展示

  Screen.Cursor := Save_Cursor;  { Always restore to normal }
  
  MakeExeFile;

  if gbIfRestartComputer then MESSAGEDLG('强烈建议重新启动电脑',mtWarning,[mbOK],0);

  application.Terminate;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Timer1.Interval:=300;
  Timer1.Enabled:=true;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  gslFileVersion.Free;
end;

end.
