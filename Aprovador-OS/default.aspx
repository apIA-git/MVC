<%@ Page Language="C#" ValidateRequest="false" EnableViewState="false" EnableSessionState="false" ResponseEncoding="utf-8" %>
<%@ Import Namespace="System.Net" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Assembly Name="System.Web.Extensions, Version=4.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" %>
<script runat="server">
/*
 * Aprovador-OS - pagina do cliente para aprovar ou recusar uma OS (ASP.NET, sem PHP).
 *
 * Link (e-mail do envio, U_CNSAPR "ENV"): https://www.apia.com.br/aprovador-os/?t=<token>
 *
 * Camada FINA: nao le nem grava no banco. So mostra a tela e repassa ao
 * Protheus, que fica na rede interna (o cliente nao alcanca o REST direto):
 *   - abrir o link  -> GET  /rest/CNSAAPROVA?token=          (U_CNSAPR "CNS")
 *   - enviar        -> POST /rest/CNSAAPROVA?token=&decisao=APR|REC&motivo=
 *                      (U_CNSAPR "APR"/"REC", origem W; IP do cliente no X-Forwarded-For)
 * Toda a regra (validade, ultima linha da SZA, OS ja decidida, gravacao, e-mails)
 * e do U_CNSAPR (CNSA004).
 *
 * Respostas do Protheus: 200 ok - 404 link invalido/expirado/usado - 409 OS ja decidida
 * - sem resposta/401/5xx = sistema indisponivel (o link continua valendo).
 * REST_BASE/TELEFONE_APIA no web.config; usuario de servico (REST_USUARIO/REST_SENHA)
 * em config.local.config - so no servidor, fora do git (o IIS nao entrega .config).
 */

protected string Tela = "exp";
protected string Erro = "";
protected string Token = "";
protected string Resposta = "";
protected string Obs = "";
protected Dictionary<string, object> Os = new Dictionary<string, object>();

protected string Cfg(string chave)
{
    return ConfigurationManager.AppSettings[chave] ?? "";
}

protected string H(object valor)
{
    return HttpUtility.HtmlEncode(valor == null ? "" : valor.ToString().Trim());
}

protected string Campo(string chave)
{
    object v;
    return Os != null && Os.TryGetValue(chave, out v) && v != null ? v.ToString().Trim() : "";
}

/** IP do cliente (atras de proxy vem no X-Forwarded-For). */
protected string IpCliente()
{
    string ip = Request.ServerVariables["REMOTE_ADDR"] ?? "";
    string fwd = Request.Headers["X-Forwarded-For"];
    if (!string.IsNullOrEmpty(fwd)) ip = fwd.Split(',')[0].Trim();
    IPAddress ok;
    return IPAddress.TryParse(ip, out ok) ? ip : "";
}

/** Chamada ao REST do Protheus (rede interna). Devolve o status HTTP e o JSON lido. */
protected int Protheus(string metodo, Dictionary<string, string> parametros, out Dictionary<string, object> json)
{
    json = new Dictionary<string, object>();
    var query = new StringBuilder();
    foreach (var p in parametros)
        query.Append(query.Length == 0 ? "?" : "&").Append(Uri.EscapeDataString(p.Key)).Append('=').Append(Uri.EscapeDataString(p.Value ?? ""));

    ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
    // Certificado interno do appserver (10.0.0.3) - mesma rede, sem validacao de cadeia.
    ServicePointManager.ServerCertificateValidationCallback = delegate { return true; };

    var req = (HttpWebRequest)WebRequest.Create(Cfg("REST_BASE") + "/rest/CNSAAPROVA" + query);
    req.Method = metodo;
    req.Timeout = 30000;
    req.Accept = "application/json";
    req.Headers["Authorization"] = "Basic " + Convert.ToBase64String(Encoding.UTF8.GetBytes(Cfg("REST_USUARIO") + ":" + Cfg("REST_SENHA")));
    if (IpCliente() != "") req.Headers["X-Forwarded-For"] = IpCliente();
    if (metodo == "POST") req.ContentLength = 0;

    HttpWebResponse resp = null;
    try { resp = (HttpWebResponse)req.GetResponse(); }
    catch (WebException e) { resp = e.Response as HttpWebResponse; }
    if (resp == null) return 0;

    using (resp)
    using (var ms = new System.IO.MemoryStream())
    {
        resp.GetResponseStream().CopyTo(ms);
        json = LerJson(ms.ToArray());
        return (int)resp.StatusCode;
    }
}

/** Corpo do Protheus pode vir em UTF-8 ou CP1252 (acento invalido em UTF-8 quebraria o JSON). */
protected Dictionary<string, object> LerJson(byte[] bytes)
{
    string texto;
    try { texto = new UTF8Encoding(false, true).GetString(bytes); }
    catch (DecoderFallbackException) { texto = Encoding.GetEncoding(1252).GetString(bytes); }
    try { return new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(texto) ?? new Dictionary<string, object>(); }
    catch { return new Dictionary<string, object>(); }
}

protected void Page_Load(object sender, EventArgs e)
{
    Response.AddHeader("X-Robots-Tag", "noindex, nofollow");
    Response.AddHeader("Referrer-Policy", "no-referrer");

    bool post = Request.HttpMethod == "POST";
    Token = ((post ? Request.Form["t"] : Request.QueryString["t"]) ?? "").Trim().ToLowerInvariant();
    if (!Regex.IsMatch(Token, "^[0-9a-f]{64}$")) return;

    Dictionary<string, object> resp;
    int st;
    if (post)
    {
        Resposta = Request.Form["resposta"] ?? "";
        Obs = (Request.Form["obs"] ?? "").Trim();

        if (Resposta != "APR" && Resposta != "REC") Erro = "Escolha se aprova ou não aprova a OS.";
        else if (Resposta == "REC" && Obs == "") Erro = "Conte o motivo ou as mudanças necessárias.";
        else if (Obs.Length > 240) Erro = "A observação pode ter até 240 caracteres.";
        else
        {
            st = Protheus("POST", new Dictionary<string, string> { { "token", Token }, { "decisao", Resposta }, { "motivo", Obs } }, out resp);
            if (st == 200) { Tela = "ok"; return; }
            if (st == 409) { Tela = "ja"; return; }
            if (st == 404) { Tela = "exp"; return; }
            object msg;
            Erro = resp.TryGetValue("erro", out msg) && msg != null && msg.ToString().Trim() != ""
                ? msg.ToString().Trim()
                : "Não foi possível registrar sua resposta. Tente novamente em instantes.";
        }
    }

    // Dados da OS (primeira abertura ou formulario de novo, em caso de erro).
    st = Protheus("GET", new Dictionary<string, string> { { "token", Token } }, out resp);
    Os = resp;
    if (st == 200) Tela = "form";
    else if (st == 409) Tela = "ja";
    else if (st == 404 || st == 400) Tela = "exp";
    else Tela = "fora";   // Protheus fora do ar / usuario de servico invalido: nao dizer que o link venceu
}
</script>
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Aprovação de OS - Ápia</title>
<link rel="stylesheet" href="estilo.css">
</head>
<body>
<div class="cartao">
  <header>
    <img src="https://www.apia.com.br/apia_cs/logo-apia-completa.png" alt="Ápia Consultoria e Sistemas">
    <span>Aprovação de Ordem de Serviço</span>
  </header>

<% if (Tela == "form") { %>
  <form class="corpo" method="post" action="default.aspx">
    <input type="hidden" name="t" value="<%= H(Token) %>">
    <h1>OS <%= H(Campo("os")) %></h1>
    <p class="sub"><%= H(Campo("cliente")) %></p>

    <% if (Erro != "") { %><div class="erro"><%= H(Erro) %></div><% } %>

    <div class="grade">
      <div><b>Data</b><%= H(Campo("data")) %></div>
      <div><b>Horário</b><%= H(Campo("horario").Replace(" as ", " às ")) %></div>
      <div><b>Total de horas</b><%= H(Campo("horas")) %></div>
      <div><b>Analista</b><%= H(Campo("analista")) %></div>
      <% if (Campo("projeto") != "") { %><div><b>Projeto</b><%= H(Campo("projeto")) %></div><% } %>
      <% var chamados = Os.ContainsKey("chamados") ? Os["chamados"] as System.Collections.IEnumerable : null;
         if (chamados != null && !(chamados is string)) {
           var lista = new List<string>(); foreach (var c in chamados) lista.Add(H(c));
           if (lista.Count > 0) { %><div><b>Chamados</b><%= string.Join("<br>", lista) %></div><% } } %>
    </div>

    <% if (Campo("descricao") != "") { %>
    <div class="bloco">
      <span class="titulo">Serviço executado</span>
      <div class="servico"><%= H(Campo("descricao")) %></div>
    </div>
    <% } %>

    <div class="bloco">
      <span class="titulo">Sua resposta *</span>
      <div class="opcoes">
        <label class="opcao aprova"><input type="radio" name="resposta" value="APR" required <%= Resposta == "APR" ? "checked" : "" %>> ✔ Aprovo esta OS</label>
        <label class="opcao recusa"><input type="radio" name="resposta" value="REC" <%= Resposta == "REC" ? "checked" : "" %>> ✖ Não aprovo</label>
      </div>
    </div>

    <div class="bloco">
      <label class="titulo" for="obs">Observação / mudanças <span class="obrig">(obrigatória se não aprovar)</span></label>
      <textarea id="obs" name="obs" maxlength="240" placeholder="Ex.: as horas foram 3h e não 3,5h"><%= H(Obs) %></textarea>
      <div class="contador"><span id="cont"><%= Obs.Length %></span>/240</div>
    </div>

    <button type="submit" class="botao">Enviar resposta</button>
  </form>

<% } else if (Tela == "ok") { %>
  <div class="estado">
    <div class="icone">✅</div>
    <h1>Obrigado!</h1>
    <p class="sub">Sua resposta foi registrada em <%= DateTime.Now.ToString("dd/MM/yyyy 'às' HH:mm") %>.<br>
    A Ápia já foi avisada.</p>
  </div>

<% } else if (Tela == "ja") { %>
  <div class="estado">
    <div class="icone">ℹ️</div>
    <h1>Esta OS já foi respondida</h1>
    <p class="sub">Para dúvidas, fale com a Ápia: <%= H(Cfg("TELEFONE_APIA")) %> ou <a href="mailto:<%= H(Cfg("EMAIL_APIA")) %>"><%= H(Cfg("EMAIL_APIA")) %></a>.</p>
  </div>

<% } else if (Tela == "fora") { %>
  <div class="estado">
    <div class="icone">🔧</div>
    <h1>Sistema indisponível no momento</h1>
    <p class="sub">Seu link continua valendo. Tente novamente mais tarde.<br>
    Se precisar, fale com a Ápia: <%= H(Cfg("TELEFONE_APIA")) %> ou <a href="mailto:<%= H(Cfg("EMAIL_APIA")) %>"><%= H(Cfg("EMAIL_APIA")) %></a>.</p>
  </div>

<% } else { %>
  <div class="estado">
    <div class="icone">⏱️</div>
    <h1>Link inválido ou expirado</h1>
    <p class="sub">O link de aprovação vale por tempo limitado após o envio da OS.<br>
    Peça um novo envio à Ápia: <%= H(Cfg("TELEFONE_APIA")) %> ou <a href="mailto:<%= H(Cfg("EMAIL_APIA")) %>"><%= H(Cfg("EMAIL_APIA")) %></a>.</p>
  </div>
<% } %>

  <div class="rodape">Ápia Consultoria e Sistemas · esta página não pede senha nem dados de pagamento</div>
</div>

<script>
  var obs = document.getElementById('obs');
  if (obs) {
    obs.oninput = function () { document.getElementById('cont').textContent = obs.value.length; };
  }
</script>
</body>
</html>
