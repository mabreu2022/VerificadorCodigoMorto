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

  TEstatisticaUnit = record
    NomeUnit: string;
    Total: Integer;
    NaoUtilizados: Integer;
    ClassesInativas: Integer;
  end;

  TEstatisticas = TArray<TEstatisticaUnit>;

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
var palavra: string;
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
var tipo: string;
begin
  if Length(F.OnlyKinds) = 0 then Exit(True);
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

procedure FinalizarHtml(Log: TStrings; const Estatisticas: TEstatisticas);
var
  Estat: TEstatisticaUnit;
begin
  Log.Add('</table>');

  Log.Add('<h2>📊 Estatísticas por Unit</h2>');
  Log.Add('<canvas id="graficoResumo" height="150"></canvas>');
  Log.Add('<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>');
  Log.Add('<script>');
  Log.Add('const ctx = document.getElementById("graficoResumo").getContext("2d");');
  Log.Add('new Chart(ctx, { type: "bar", data: { labels: [');
  for Estat in Estatisticas do
    Log.Add('"' + Estat.NomeUnit + '",');
  Log.Add('], datasets: [{ label: "Código Morto (%)", data: [');
  for Estat in Estatisticas do
    if Estat.Total > 0 then
      Log.Add(Format('%.2f,', [Estat.NaoUtilizados * 100 / Estat.Total]))
    else
      Log.Add('0,');
  Log.Add('], backgroundColor: "#e67e22" }] },');
  Log.Add('options: { scales: { y: { beginAtZero: true, max: 100 } } } });');
  Log.Add('</script>');

  Log.Add('<p>Gerado em: ' + DateTimeToStr(Now) + '</p>');
  Log.Add('</body></html>');
end;

procedure GerarArquivoAjuda;
var
  HelpFile: TStringList;
begin
  HelpFile := TStringList.Create;
  try
    HelpFile.Text :=
      '<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">' +
      '<title>Ajuda – Verificador de Código Morto</title>' +
      '<style>body { font-family: Arial; margin: 40px; line-height: 1.6; }' +
      'table { border-collapse: collapse; width: 100%; } th, td { border: 1px solid #ccc; padding: 8px; }' +
      'th { background-color: #f2f2f2; } code { background-color: #f8f8f8; padding: 2px 6px; }</style></head><body>' +
      '<h1>🛠️ Verificador de Código Morto – Ajuda</h1><pre><code>VerificadorCodigoMorto.exe &lt;diretório&gt; [opções]</code></pre>' +
      '<table><tr><th>Parâmetro</th><th>Descrição</th></tr>' +
      '<tr><td><code>&lt;diretório&gt;</code></td><td>Diretório onde os arquivos serão analisados.</td></tr>' +
      '<tr><td><code>--only=a,b</code></td><td>Filtra tipos como procedure, const, etc.</td></tr>' +
      '<tr><td><code>--ignore=a,b</code></td><td>Ignora linhas contendo essas palavras.</td></tr>' +
      '<tr><td><code>--exclude=a,b</code></td><td>Ignora símbolos com nomes correspondentes.</td></tr>' +
      '<tr><td><code>--help</code></td><td>Exibe esta ajuda em HTML.</td></tr>' +
      '</table><footer><p>Desenvolvido por Mauricio</p></footer></body></html>';
    HelpFile.SaveToFile('help.html', TEncoding.UTF8);
    ShellExecute(0, 'open', PChar('help.html'), nil, nil, SW_SHOWNORMAL);
  finally
    HelpFile.Free;
  end;
end;

procedure AnalisarUnit(const Arquivo: string; const Filtro: TOpcoesFiltro;
  var Erros: Integer; HtmlLog: TStrings; var Estatisticas: TEstatisticas);
var
  Linhas: TStringList;
  i, j: Integer;
  Linha, Simbolo, Resto, Kind: string;
  TotalSimbolos, SimbolosNaoUtilizados, ClassesMortas: Integer;
  Estat: TEstatisticaUnit;
begin
  TotalSimbolos := 0;
  SimbolosNaoUtilizados := 0;
  ClassesMortas := 0;

  Linhas := TStringList.Create;
  try
    Linhas.LoadFromFile(Arquivo);

    for i := 0 to Linhas.Count - 1 do
    begin
      Linha := Trim(Linhas[i]);

      if StartsText('procedure ', Linha) then Kind := 'procedure'
      else if StartsText('function ', Linha) then Kind := 'function'
      else if StartsText('const ', Linha) then Kind := 'const'
      else if StartsText('var ', Linha) then Kind := 'var'
      else if StartsText('type ', Linha) and ContainsText(Linha.ToLower, '= class') then Kind := 'class'
      else if StartsText('type ', Linha) then Kind := 'type'
      else
        Continue;

      Resto := Copy(Linha, Pos(' ', Linha) + 1, MaxInt);
      if Pos('=', Resto) > 0 then
        Simbolo := Trim(Copy(Resto, 1, Pos('=', Resto) - 1))
      else if Pos(':', Resto) > 0 then
        Simbolo := Trim(Copy(Resto, 1, Pos(':', Resto) - 1))
      else if Pos('(', Resto) > 0 then
        Simbolo := Trim(Copy(Resto, 1, Pos('(', Resto) - 1))
      else
        Simbolo := Trim(Resto);

      Inc(TotalSimbolos);
      if not TipoPermitido(Kind, Filtro) then Continue;
      if DeveIgnorar(Linha, Simbolo, Filtro) then Continue;

      for j := 0 to Linhas.Count - 1 do
        if (j <> i) and ContainsText(LowerCase(Linhas[j]), LowerCase(Simbolo)) then
          Exit;
                                   Inc(Erros);
      Inc(SimbolosNaoUtilizados);
      if Kind = 'class' then
        Inc(ClassesMortas);

      Writeln(Format('⚠️  [%s] Linha %d: %s %s não utilizado.', [
        ExtractFileName(Arquivo), i + 1, Kind, Simbolo
      ]));
      HtmlLog.Add(Format('<tr><td>%s</td><td>%d</td><td>%s %s</td></tr>', [
        ExtractFileName(Arquivo), i + 1, Kind, Simbolo
      ]));
    end;

    Estat.NomeUnit := ExtractFileName(Arquivo);
    Estat.Total := TotalSimbolos;
    Estat.NaoUtilizados := SimbolosNaoUtilizados;
    Estat.ClassesInativas := ClassesMortas;
    Estatisticas := Estatisticas + [Estat];
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
  Estatisticas: TEstatisticas;
begin
  try
    if (ParamCount = 1) and SameText(ParamStr(1), '--help') then
    begin
      GerarArquivoAjuda;
      Halt(0);
    end;

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
      Estatisticas := [];
      IniciarHtml(HtmlLog);

      for Arquivo in Arquivos do
        AnalisarUnit(Arquivo, Filtro, Erros, HtmlLog, Estatisticas);

      FinalizarHtml(HtmlLog, Estatisticas);
      HtmlLog.SaveToFile('relatorio_codigo_morto.html', TEncoding.UTF8);

      if Erros > 0 then
      begin
        Writeln;
        Writeln('⛔ Foram encontrados ', Erros, ' símbolo(s) não utilizado(s).');
        Writeln('📝 Relatório salvo como: relatorio_codigo_morto.html');
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
