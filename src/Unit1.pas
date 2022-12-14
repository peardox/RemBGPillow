unit Unit1;

{$DEFINE USEGPUIFPRESENT}

  interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, PythonEngine,
  FMX.PythonGUIInputOutput, PyEnvironment, PyEnvironment.Embeddable,
  PyEnvironment.Embeddable.Res, PyEnvironment.Embeddable.Res.Python39,
  FMX.Memo.Types, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo,
  FMX.Layouts, System.Threading, System.IOUtils,
  PyPackage, PyCommon, RemBG, Pillow, PyTorch, PyModule, PSUtil, FMX.StdCtrls,
  FMX.Objects, FMX.TabControl;

type
  TForm1 = class(TForm)
    PyEmbed: TPyEmbeddedResEnvironment39;
    PyEng: TPythonEngine;
    PyIO: TPythonGUIInputOutput;
    PSUtil: TPSUtil;
    Torch: TPyTorch;
    Pillow: TPillow;
    RemBG: TRemBG;
    OpenDialog: TOpenDialog;
    Layout2: TLayout;
    btnTest: TButton;
    btnImage: TButton;
    SaveDialog: TSaveDialog;
    Button1: TButton;
    TabControl1: TTabControl;
    TabItem1: TTabItem;
    TabItem2: TTabItem;
    mmLog: TMemo;
    Image1: TImage;
    procedure FormCreate(Sender: TObject);
    procedure PackageBeforeInstall(Sender: TObject);
    procedure PackageAfterInstall(Sender: TObject);
    procedure PackageInstallError(Sender: TObject; AException: Exception; var AAbort: Boolean);
    procedure PackageAfterImport(Sender: TObject);
    procedure PackageBeforeImport(Sender: TObject);
    procedure PackageBeforeUnInstall(Sender: TObject);
    procedure PackageAfterUnInstall(Sender: TObject);
    procedure PackageUnInstallError(Sender: TObject; AException: Exception; var AAbort: Boolean);
    procedure PackageAddExtraUrl(APackage: TPyManagedPackage; const AUrl: string);
    procedure btnTestClick(Sender: TObject);
    procedure btnImageClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormActivate(Sender: TObject);
  private
    { Private declarations }
    FTask: ITask;
    Code: TStringlist;
    CalledSystemSetup: Boolean;
    procedure Log(const AMsg: String);
    procedure SetupPackage(APackage: TPyManagedPackage);
    procedure SetupSystem;
    procedure ThreadedSetup;
    procedure GraphicToPython;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

const
  pyver = '3.9';
  pypath = 'python';
  appname = 'RemBGPillow';

function ImageToPyBytes(ABitmap : TBitmap) : Variant;

implementation

uses
  VarPyth,
  Math,
  PyPackage.Manager.Pip,
  PyPackage.Manager.Defs.Pip;

{$R *.fmx}

procedure TForm1.FormActivate(Sender: TObject);
begin
  if not CalledSystemSetup then
    begin
      mmLog.Lines.Add('Calling SystemSetup');
      CalledSystemSetup := True;
      SetupSystem;
      mmLog.Lines.Add('Back from SystemSetup');
    end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Code := TStringlist.Create;
  Code.LoadFromFile('D:\src\RemBGPillow\src\code.py');
  btnTest.Enabled := False;
  btnImage.Enabled := False;
  CalledSystemSetup := False;
end;

function ImageToPyBytes(ABitmap : TBitmap) : Variant;
var
  _stream : TMemoryStream;
  _bytes : PPyObject;
begin
  _stream := TMemoryStream.Create();
  try
    ABitmap.SaveToStream(_stream);
    Form1.mmLog.Lines.Add('Bytes = ' + _stream.Size.ToString);
    _bytes := GetPythonEngine.PyBytes_FromStringAndSize(_stream.Memory, _stream.Size);
    Result := VarPythonCreate(_bytes);
    GetPythonEngine.Py_DECREF(_bytes);
  finally
    _stream.Free;
  end;
end;

procedure TForm1.SetupSystem;
begin
  PyEng.IO := PyIO;
  PyIO.Output := mmLog;
  PyEng.RedirectIO := True;
  PyEng.AutoLoad := False;
  PyEmbed.PythonEngine := PyEng;
  PyEmbed.PythonVersion := pyver;
  // MacOSX with X64 CPU
  {$IF DEFINED(MACOS64) AND DEFINED(CPUX64)}
  PyEmbed.EnvironmentPath := IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             System.IOUtils.TPath.GetHomePath) +
                             'Library') +
                             appname) +
                             pypath;
  // MacOSX with ARM64 CPU (M1 etc)
  {$ELSEIF DEFINED(MACOS64) AND DEFINED(CPUARM64)}
  PyEmbed.EnvironmentPath := IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             System.IOUtils.TPath.GetHomePath) +
                             'Library') +
                             appname) +
                             pypath;
  // Windows X64 CPU
  {$ELSEIF DEFINED(WIN64)}
  PyEmbed.EnvironmentPath := IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             System.IOUtils.TPath.GetHomePath) +
                             appname) +
                             pypath;
  // Windows 32 bit
  {$ELSEIF DEFINED(WIN32)}
  PyEmbed.EnvironmentPath := IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             System.IOUtils.TPath.GetHomePath) +
                             appname  + '-32')+
                             pypath;
  // Linux X64 CPU
  {$ELSEIF DEFINED(LINUX64)}
  PyEmbed.EnvironmentPath := IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             System.IOUtils.TPath.GetHomePath) +
                             appname) +
                             pypath;
  // Android (64 CPU)Not presently working)
  {$ELSEIF DEFINED(ANDROID)}
  PyEmbed.EnvironmentPath := IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             System.IOUtils.TPath.GetHomePath) +
                             appname) +
                             pypath;
  {$ELSE}
  raise Exception.Create('Need to set PyEmbed.EnvironmentPath for this build');
  {$ENDIF}
  // Create Pillow
  SetupPackage(Pillow);

  // Create RemBG
  SetupPackage(RemBG);

  // Create PSUtil
  {$IFNDEF MACOS64}
  SetupPackage(PSUtil);
  {$ENDIF}

  // Create Torch
  SetupPackage(Torch);
  {$IF DEFINED(USEGPUIFPRESENT) AND NOT DEFINED(USEMACOS64)}
  PackageAddExtraUrl(Torch, 'https://download.pytorch.org/whl/cu116');
  {$ENDIF}

  Log('Python path = ' + PyEmbed.EnvironmentPath);
  //  Call Setup
  FTask := TTask.Run(ThreadedSetup);

end;

procedure TForm1.ThreadedSetup;
begin
  try
    if PyEmbed.Setup(PyEmbed.PythonVersion) then
      begin
        try
          FTask.CheckCanceled();
          TThread.Synchronize(nil, procedure() begin
            var act: Boolean := PyEmbed.Activate(PyEmbed.PythonVersion);
            if act then
              begin
              Log('Python Activated');
                FTask.CheckCanceled();

                Pillow.Install();
                FTask.CheckCanceled();

                RemBG.Install();
                FTask.CheckCanceled();

                {$IFNDEF MACOS64}
                PSUtil.Install();
                FTask.CheckCanceled();
                {$ENDIF}

                Torch.Install();
                FTask.CheckCanceled();

                TThread.Queue(nil, procedure() begin
                  try
                    MaskFPUExceptions(true);
                    try
                      Pillow.Import();
                      RemBG.Import();
                      {$IFNDEF MACOS64}
                      PSUtil.Import();
                      {$ENDIF}
                      Torch.Import();
                    finally
                      MaskFPUExceptions(false);
                    end;
                  finally
                    btnTest.Enabled := True;
                    btnImage.Enabled := True;
                  end;
                  Log('All done!');
                end);

              end
            else
              Log('Python Activation failed');
          end);
        except
          on E: Exception do begin
            TThread.Queue(nil, procedure() begin
              ShowMessage('Something went terribly wrong');
            end);
          end;
        end;
    end;
  except
    on E: Exception do begin
      TThread.Queue(nil, procedure() begin
        ShowMessage('Something went terribly wrong');
      end);
    end;
  end;
end;

procedure TForm1.Log(const AMsg: String);
begin
  if TThread.CurrentThread.ThreadID <> MainThreadID then
    TThread.Synchronize(nil,
      procedure()
      begin
        mmLog.Lines.Add('* ' + AMsg);
        mmLog.GoToTextEnd;
        mmLog.Repaint;
      end
      )
  else
    begin
      mmLog.Lines.Add(AMsg);
      mmLog.GoToTextEnd;
      mmLog.Repaint;
    end;
end;

procedure TForm1.PackageAddExtraUrl(APackage: TPyManagedPackage; const AUrl: string);
var
  popts: TPyPackageManagerDefsPip;
begin
  popts := TPyPackageManagerDefsPip(APackage.Managers.Pip);
  popts.InstallOptions.ExtraIndexUrl := AUrl;
end;

procedure TForm1.PackageBeforeInstall(Sender: TObject);
begin
  Log('Installing ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageAfterInstall(Sender: TObject);
begin
  Log('Installed ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageInstallError(Sender: TObject; AException: Exception; var AAbort: Boolean);
begin
  Log('Error for ' + TPyPackage(Sender).PyModuleName + ' : ' + AException.Message);
end;

procedure TForm1.PackageBeforeUnInstall(Sender: TObject);
begin
  Log('UnInstalling ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageAfterUnInstall(Sender: TObject);
begin
  Log('UnInstalled ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageUnInstallError(Sender: TObject; AException: Exception; var AAbort: Boolean);
begin
  Log('Error for ' + TPyPackage(Sender).PyModuleName + ' : ' + AException.Message);
end;

procedure TForm1.PackageBeforeImport(Sender: TObject);
begin
  Log('Importing ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageAfterImport(Sender: TObject);
begin
  Log('Imported ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.SetupPackage(APackage: TPyManagedPackage);
begin
  APackage.PythonEngine := PyEng;
  APackage.PyEnvironment := PyEmbed;

  APackage.AutoImport := False;
  APackage.AutoInstall := False;

  APackage.BeforeInstall := PackageBeforeInstall;
  APackage.AfterInstall := PackageAfterInstall;
  APackage.OnInstallError := PackageInstallError;
  APackage.BeforeImport := PackageBeforeImport;
  APackage.AfterImport := PackageAfterImport;
  APackage.BeforeUnInstall := PackageBeforeUnInstall;
  APackage.AfterUnInstall := PackageAfterUnInstall;
  APackage.OnUnInstallError := PackageUnInstallError;
end;

procedure TForm1.btnImageClick(Sender: TObject);
var
  LBitmap: TBitmap;
  bsize, image_in, image_out: Variant;
begin
  if not Pillow.IsImported then
    begin
      ShowMessage('Failed to import Pillow');
      Exit;
    end;
  try
//    if OpenDialog.Execute then
      begin
        OpenDialog.FileName := 'D:\src\RemBGPillow\src\image68.jpg';
        Log('Reading in ' + OpenDialog.FileName);
        LBitmap := TBitmap.Create;
        LBitmap.LoadFromFile(OpenDialog.FileName);
//        bsize := (205, 256);
//        image_in := Pillow.PIL.Image.open(ImageToPyBytes(LBitmap));
        image_in := Pillow.PIL.Image.frombytes(mode := 'RGB', data := ImageToPyBytes(LBitmap));
        Log('Removing background from ' + OpenDialog.FileName);
        image_in := RemBG.rembg.remove(image_in);
        if SaveDialog.Execute then
          begin
            Log('Saving as ' + SaveDialog.FileName);
            image_in.save(SaveDialog.FileName);
          end;
      end;
  except
    on E: Exception do
      begin
        Log('Unhandled Exception');
        Log('Class : ' + E.ClassName);
        Log('Error : ' + E.Message);
      end;
  end;
end;

procedure TForm1.btnTestClick(Sender: TObject);
var
  I: Integer;
begin
  var gpu_count: Variant := Torch.torch.cuda.device_count();
  Log('Torch returned gpu_count = ' + gpu_count);
  if gpu_count > 0 then
    begin
      for I := 0 to gpu_count - 1 do
        begin
          var gpu_props: Variant := Torch.torch.cuda.get_device_properties(i);

          Log('Torch returned Name = ' + gpu_props.name);
          Log('Torch returned CudaMajor = ' + gpu_props.major);
          Log('Torch returned CudaMajor = ' + gpu_props.minor);
          Log('Torch returned Memory = ' + gpu_props.total_memory);
          Log('Torch returned CUs = ' + gpu_props.multi_processor_count);
        end;
    end;
  {$IFNDEF MACOS64}
  var cpu_cores: Variant := PSUtil.psutil.cpu_count(False);
  var cpu_threads: Variant := PSUtil.psutil.cpu_count(True);
  var cpu_freq: Variant := PSUtil.psutil.cpu_freq();
  var virtual_memory: Variant := PSUtil.psutil.virtual_memory();

  Log('PSUtil returned cpu_cores = ' + cpu_cores);
  Log('PSUtil returned cpu_threads = ' + cpu_threads);
  Log('PSUtil returned cpu_freq = ' + cpu_freq.current);
  Log('PSUtil returned total_memory = ' + virtual_memory.total);
  Log('PSUtil returned available_memory = ' + virtual_memory.available);
  {$ENDIF}
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  GraphicToPython;
end;

procedure TForm1.GraphicToPython;
var
  _im : Variant;
  _stream : TMemoryStream;
  _dib : Variant;
  pargs: PPyObject;
  presult :PPyObject;
  P : PAnsiChar;
  Len : NativeInt;
begin
  Image1.Bitmap.LoadFromFile('d:\src\RemBGPillow\src\image68.jpg');
  PyEng.ExecStrings(Code);
  _im := MainModule.ProcessImage(ImageToPyBytes(Image1.Bitmap));

    // We have to call PyString_AsStringAndSize because the image may contain zeros
    with GetPythonEngine do begin
      pargs := MakePyTuple([ExtractPythonObjectFrom(_im)]);
      try
        presult := PyEval_CallObjectWithKeywords(
            ExtractPythonObjectFrom(MainModule.ImageToBytes), pargs, nil);
        try
          if PyBytes_AsStringAndSize(presult, P, Len) < 0 then begin
            ShowMessage('This does not work and needs fixing');
            Abort;
          end;

          _stream := TMemoryStream.Create();
          try
            _stream.Write(P^, Len);
            _stream.Position := 0;
            Image1.Bitmap.LoadFromStream(_stream);
          finally
            _stream.Free;
          end;
        finally
          Py_XDECREF(pResult);
        end;
      finally
        Py_DECREF(pargs);
      end;
    end;
end;

end.
