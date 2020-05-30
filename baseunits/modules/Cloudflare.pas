unit Cloudflare;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uBaseUnit, XQueryEngineHTML, httpsendthread, synautil,
  synacode, JSUtils, RegExpr, dateutils;

type

  { TCFProps }

  TCFProps = class
  public
    websitemodule: TObject;
    CS: TRTLCriticalSection;
    constructor Create(awebsitemodule: TObject);
    destructor Destroy; override;
  end;

function CFRequest(const AHTTP: THTTPSendThread; const Method, AURL: String; const Response: TObject; const CFProps: TCFProps): Boolean;

implementation

{$R Cloudflare.rc}

uses WebsiteModules, MultiLog;

const
  MIN_WAIT_TIME = 5000;
  PRELUDE_SCRIPT_NAME = 'CLOUDFLARE_PRELUDE';

function LoadPreludeScript: String;
var
  stream: TResourceStream;
begin
  Result := '';
  stream := nil;
  try
    stream := TResourceStream.Create(HINSTANCE, PRELUDE_SCRIPT_NAME, MAKEINTRESOURCE(10));
    Result := StreamToString(stream);
  finally
    if Assigned(stream) then
       FreeAndNil(stream);
  end;
end;

function AntiBotActive(const AHTTP: THTTPSendThread): Boolean;
var
  s: String;
begin
  Result := False;
  if AHTTP = nil then Exit;
  if AHTTP.ResultCode < 500 then Exit;
  if Pos('text/html', AHTTP.Headers.Values['Content-Type']) = 0 then Exit;
  s := StreamToString(AHTTP.Document);
  Result := Pos('name="jschl_vc"',s) <> 0;
  s := '';
end;

function JSGetAnsweredURL(const Source, URL: String; var OMethod, OURL, opostdata: String;
  var OSleepTime: Integer): Boolean;
var
  meth, surl, r, rname, jschl_vc, pass,
    jschl_answer, preludeScript, script, payload: String;
  v: IXQValue;
begin
  Result := False;
  if (Source = '') or (URL = '') then Exit;

  meth := '';
  surl := '';
  jschl_vc := '';
  pass := '';
  jschl_answer := '';

  with TXQueryEngineHTML.Create(Source) do
    try
      meth := UpperCase(XPathString('//form[@id="challenge-form"]/@method'));
      surl := XPathString('//form[@id="challenge-form"]/@action');
      r := XPathString('//input[@name="s" or @name="r"]/@value');
      rname := XPathString('//input[@name="s" or @name="r"]/@name');
      jschl_vc := XPathString('//input[@name="jschl_vc"]/@value');
      pass := XPathString('//input[@name="pass"]/@value');
      script := XPathString('//script');

      if (meth = '') or (surl = '') or (r = '') or (jschl_vc = '') or (pass = '') then Exit;

      preludeScript := LoadPreludeScript();
      preludeScript := Format(preludeScript, [ DefaultUserAgent, URL ]);
      for v in XPath('//*[@id and contains(., "[]")]') do begin
        preludeScript += Format('$$e["%s"] = { innerHTML: "%s" };' + LineEnding,
            [ v.toNode.getAttribute('id'),
              ReplaceString(v.toNode.innerHTML, '"', '\"') ]);
      end;
    finally
      Free;
    end;

  script := preludeScript + script + LineEnding + 'JSON.stringify($$e);';
  script := ExecJS(script);

  with TXQueryEngineHTML.Create(script) do
    try
      OSleepTime := StrToIntDef(XPathString('json(*).timeout'), MIN_WAIT_TIME);
      jschl_answer := XPathString('json(*).jschl-answer.value');
    finally
      Free;
    end;

  if jschl_answer = '' then Exit;

  payload := Format('%s=%s&jschl_vc=%s&pass=%s&jschl_answer=%s',
                    [ rname, EncodeURLElement(r), EncodeURLElement(jschl_vc),
                      EncodeURLElement(pass), EncodeURLElement(jschl_answer) ]);

  if CompareText(meth, 'POST') = 0 then
  begin
    OURL := surl;
    opostdata := payload;
  end
  else begin
    OURL := surl + '?' + payload;
    opostdata := '';
  end;

  OMethod := meth;
  Result := True;
end;

function CFJS(const AHTTP: THTTPSendThread; AURL: String; const cfprops: TCFProps): Boolean;
var
  m, u, h,postdata: String;
  st, sc, counter, maxretry: Integer;
begin
  Result := False;
  if AHTTP = nil then Exit;
  counter := 0;
  maxretry := AHTTP.RetryCount;
  AHTTP.RetryCount := 0;
  m:='POST';
  u:='';
  h:=StringReplace(AppendURLDelim(GetHostURL(AURL)),'http://','https://',[rfIgnoreCase]);
  postdata:='';
  st:=MIN_WAIT_TIME;
  // retry to solve until max retry count in connection setting
  while True do
  begin
    Inc(counter);
    if JSGetAnsweredURL(StreamToString(AHTTP.Document), h, m, u,postdata, st) then
      if (m <> '') and (u <> '') then
      begin
        AHTTP.Reset;
        if m='POST' then
        begin
          writestrtostream(ahttp.document,postdata);
          ahttp.mimetype:='application/x-www-form-urlencoded';
        end;
        AHTTP.Headers.Values['Referer'] := ' ' + AURL;
        if st < MIN_WAIT_TIME then st := MIN_WAIT_TIME;
        sc := 0;
        while sc < st do begin
          if AHTTP.ThreadTerminated then Break;
          Inc(sc, 250);
          Sleep(250);
        end;
        AHTTP.FollowRedirection := False;
        AHTTP.HTTPRequest(m, FillHost(h, u));
        Result := AHTTP.Cookies.Values['cf_clearance']<>'';
        if AHTTP.ResultCode=403 then
           Logger.SendError('cloudflare bypass failed, probably asking for captcha! '+AURL);
        AHTTP.FollowRedirection := True;
      end;
    // update retry count in case user change it in the middle of process
    if AHTTP.RetryCount <> 0 then
    begin
      maxretry := AHTTP.RetryCount;
      AHTTP.RetryCount := 0;
    end;
    if Result then begin
      // if success force replace protocol to https for rooturl in modulecontainer
      with TModuleContainer(cfprops.websitemodule) do
        if Pos('http://',RootURL)=1 then
          RootURL:=stringreplace(RootURL,'http://','https://',[rfIgnoreCase]);
      Break;
    end;
    if AHTTP.ThreadTerminated then Break;
    if (maxretry > -1) and (maxretry <= counter) then Break;
    AHTTP.Reset;
    AHTTP.HTTPRequest('GET', AURL);
  end;
  AHTTP.RetryCount := maxretry;
end;

function CFRequest(const AHTTP: THTTPSendThread; const Method, AURL: String; const Response: TObject; const CFProps: TCFProps): Boolean;
begin
  Result := False;
  if AHTTP = nil then Exit;
  AHTTP.AllowServerErrorResponse := True;
  Result := AHTTP.HTTPRequest(Method, AURL);
  if AntiBotActive(AHTTP) then begin
    if TryEnterCriticalsection(CFProps.CS) > 0 then
      try
        Result := CFJS(AHTTP, AURL, CFProps);
      finally
        LeaveCriticalsection(CFProps.CS);
      end
    else begin
      if not AHTTP.ThreadTerminated then
        Result := AHTTP.HTTPRequest(Method, AURL);
    end;
  end;
  if Assigned(Response) then
    if Response is TStringList then
      TStringList(Response).LoadFromStream(AHTTP.Document)
    else
    if Response is TStream then
      AHTTP.Document.SaveToStream(TStream(Response));
end;

{ TCFProps }

constructor TCFProps.Create(awebsitemodule: TObject);
begin
  websitemodule:=awebsitemodule;
  InitCriticalSection(CS);
end;

destructor TCFProps.Destroy;
begin
  DoneCriticalsection(CS);
  inherited Destroy;
end;

end.
