program VerificadorCodigoMorto;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.StrUtils,
  Winapi.ShellAPI,
  System.Types,
  Winapi.Windows;

type
  TOpcoesFiltro = record
    IgnoreVisibility: TArray<string>;
    OnlyKinds: TArray<string>;
    ExcludeNames: TArray<string>;
  end;

function ParseFiltro: TOpcoesFiltro;
var
  i: Integer;
  Param: string;
begin
  for i := 2 to ParamCount do
  begin
    Param := ParamStr(i);

    if Param.StartsWith('--ignore=') then
      Result.IgnoreVisibility := Param.Substring(9).Split([',']);

    if Param.StartsWith('--only=') then
      Result.OnlyKinds := Param.Substring(7).Split([',']);

    if Param.StartsWith('--exclude=') then
      Result.ExcludeNames := Param.Substring(10).Split([',']);
  end;
end;

function DeveIgnorar(Linha, Nome: string; const F: TOpcoesFiltro): Boolean;
var
  palavra: string;
begin
  Result := False;

  for palavra in F.IgnoreVisibility do
    if Linha.ToLower.Contains(palavra.ToLower) then
      Exit(True);

  for palavra in F.ExcludeNames do
    if Nome.ToLower.Contains(palavra.ToLower) then
      Exit(True);
end;

function TipoPermitido(const Kind: string; const F: TOpcoesFiltro): Boolean;
var
  tipo: string;
begin
  if Length(F.OnlyKinds) = 0 then
    Exit(True);

  for tipo in F.OnlyKinds do
    if tipo.ToLower = Kind.ToLower then
      Exit(True);

  Result := False;
end;

procedure IniciarHtml(Log: TStrings);
begin
  Log.Add('<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">');
  Log.Add('<title>Relatório de Código Morto</title>');
  Log.Add('<style>');
  Log.Add('body { font-family: Arial; margin: 40px; }');
  Log.Add('table { border-collapse: collapse; width: 100%; }');
  Log.Add('th, td { border: 1px solid #ccc; padding: 8px; }');
  Log.Add('th { background-color: #f2f2f2; }');
  Log.Add('</style></head><body>');
  Log.Add('<h1>⚠️ Relatório de Código Morto</h1>');
  Log.Add('<table><tr><th>Unit</th><th>Linha</th><th>Símbolo</th></tr>');
end;

procedure FinalizarHtml(Log: TStrings);
begin
  Log.Add('</table>');
  Log.Add('<p>Gerado em: ' + DateTimeToStr(Now) + '</p>');
  Log.Add('</body></html>');
end;

procedure AnalisarUnit(const Arquivo: string; const Filtro: TOpcoesFiltro; var Erros: Integer; HtmlLog: TStrings);
var
  Linhas: TStringList;
  i, j: Integer;
  Linha, Simbolo, Resto, Kind: string;
begin
  Linhas := TStringList.Create;
  try
    Linhas.LoadFromFile(Arquivo);

    for i := 0 to Linhas.Count - 1 do
    begin
      Linha := Trim(Linhas[i]);

      if StartsText('procedure ', Linha) or StartsText('function ', Linha) then
      begin
        if StartsText('procedure ', Linha) then Kind := 'procedure'
        else Kind := 'function';

        if not TipoPermitido(Kind, Filtro) then
          Continue;

        Resto := Copy(Linha, Pos(' ', Linha) + 1, MaxInt);
        if Pos('(', Resto) = 0 then Continue;
        Simbolo := Copy(Resto, 1, Pos('(', Resto) - 1);

        if DeveIgnorar(Linha, Simbolo, Filtro) then Continue;

        for j := 0 to Linhas.Count - 1 do
          if (j <> i) and ContainsText(LowerCase(Linhas[j]), LowerCase(Simbolo)) then
            Exit;

        Inc(Erros);
        Writeln(Format('⚠️  [%s] Linha %d: %s %s não utilizado.', [ExtractFileName(Arquivo), i + 1, Kind, Simbolo]));
        HtmlLog.Add(Format('<tr><td>%s</td><td>%d</td><td>%s %s</td></tr>', [
          ExtractFileName(Arquivo), i + 1, Kind, Simbolo
        ]));
      end;
    end;
  finally
    Linhas.Free;
  end;
end;

var
  Diretorio, Arquivo: string;
  Arquivos: TStringDynArray;
  HtmlLog: TStringList;
  Erros: Integer;
  Filtro: TOpcoesFiltro;
begin
  try
    if ParamCount < 1 then
    begin
      Writeln('❗ Uso: VerificadorCodigoMorto.exe <diretório> [--only=...] [--ignore=...] [--exclude=...]');
      Halt(1);
    end;

    Diretorio := ParamStr(1);
    Filtro := ParseFiltro;
    Arquivos := TDirectory.GetFiles(Diretorio, '*.pas', TSearchOption.soAllDirectories);

    HtmlLog := TStringList.Create;
    try
      Erros := 0;
      IniciarHtml(HtmlLog);

      for Arquivo in Arquivos do
        AnalisarUnit(Arquivo, Filtro, Erros, HtmlLog);

      FinalizarHtml(HtmlLog);
      HtmlLog.SaveToFile('relatorio_codigo_morto.html', TEncoding.UTF8);

      if Erros > 0 then
      begin
        Writeln;
        Writeln('⛔ Foram encontrados ', Erros, ' símbolos não utilizados.');
        Writeln('📝 Relatório salvo como: relatorio_codigo_morto.html');

        // Abre o HTML se houver erro
        ShellExecute(0, 'open', PChar('relatorio_codigo_morto.html'), nil, nil, SW_SHOWNORMAL);
        Halt(1);
      end
      else
      begin
        Writeln('✅ Nenhum código morto encontrado.');
        Halt(0);
      end;

    finally
      HtmlLog.Free;
    end;

  except
    on E: Exception do
    begin
      Writeln('Erro: ' + E.Message);
      Halt(1);
    end;
  end;
end.
