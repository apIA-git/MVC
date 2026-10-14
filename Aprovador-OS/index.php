<?php
/*
 * Aprovador-OS - pagina do cliente para aprovar ou recusar uma OS.
 *
 * Link (e-mail do envio, U_CNSAPR "ENV"): https://www.apia.com.br/Aprovador-OS/?t=<token>
 *
 * Camada FINA: nao le nem grava no banco. So mostra a tela e repassa ao
 * Protheus, que fica na rede interna (o cliente nao alcanca o REST direto):
 *   - abrir o link  -> GET  /rest/CNSAAPROVA?token=          (U_CNSAPR "CNS")
 *   - enviar        -> POST /rest/CNSAAPROVA?token=&decisao=APR|REC&motivo=
 *                      (U_CNSAPR "APR"/"REC", origem W; IP do cliente no X-Forwarded-For)
 * Toda a regra (validade, ultima linha da SZA, OS ja decidida, gravacao na
 * SZ1/SZA, e-mails) e do U_CNSAPR (CNSA004).
 *
 * Respostas do Protheus: 200 ok · 404 link invalido/expirado/usado · 409 OS ja decidida
 * · sem resposta/401/5xx = sistema indisponivel (o link continua valendo).
 * Configuracao (URL e usuario de servico do REST) em config.php - fora do git.
 */

date_default_timezone_set('America/Sao_Paulo');
header('Content-Type: text/html; charset=utf-8');
header('X-Robots-Tag: noindex, nofollow');
header('Referrer-Policy: no-referrer');

require __DIR__ . '/config.php';   // REST_BASE, REST_USUARIO, REST_SENHA, TELEFONE_APIA

/** Valor de um array ou o padrao (PHP 5.3 nao tem o operador ??). */
function v($lista, $chave, $padrao = '')
{
    return (is_array($lista) && isset($lista[$chave])) ? $lista[$chave] : $padrao;
}

function h($s)
{
    return htmlspecialchars((string) $s, ENT_QUOTES, 'UTF-8');
}

/** Texto do Protheus em UTF-8 (se vier CP1252, converte). */
function txt($s)
{
    $s = trim((string) $s);
    return ($s === '' || mb_check_encoding($s, 'UTF-8')) ? $s : mb_convert_encoding($s, 'UTF-8', 'Windows-1252');
}

/** IP do cliente (atras de proxy vem no X-Forwarded-For). */
function ipCliente()
{
    $ip = v($_SERVER, 'REMOTE_ADDR');
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ip = trim(current(explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'])));
    }
    return filter_var($ip, FILTER_VALIDATE_IP) ? $ip : '';
}

/** Chamada ao REST do Protheus (rede interna). Devolve [status HTTP, json decodificado]. */
function protheus($metodo, $rota, array $params)
{
    $cabecalho = "Authorization: Basic " . base64_encode(REST_USUARIO . ':' . REST_SENHA) . "\r\n"
               . "Accept: application/json\r\n"
               . "Content-Length: 0\r\n";
    if (ipCliente() !== '') {
        $cabecalho .= "X-Forwarded-For: " . ipCliente() . "\r\n";
    }
    $ctx = stream_context_create(array(
        'http' => array('method' => $metodo, 'header' => $cabecalho, 'ignore_errors' => true, 'timeout' => 30),
        // Certificado interno do appserver (10.0.0.3) - mesma rede, sem validacao de cadeia.
        'ssl'  => array('verify_peer' => false, 'verify_peer_name' => false),
    ));
    $corpo = @file_get_contents(REST_BASE . $rota . '?' . http_build_query($params), false, $ctx);
    $status = 0;
    if (isset($http_response_header[0]) && preg_match('#\s(\d{3})\s?#', $http_response_header[0], $m)) {
        $status = (int) $m[1];
    }
    // Corpo do Protheus pode vir em CP1252 (acento invalido em UTF-8 faz o json_decode falhar).
    $json = json_decode(txt($corpo), true);
    return array($status, is_array($json) ? $json : array());
}

// ------------------------------------------------------------------ fluxo

$token = strtolower(trim((string) ($_SERVER['REQUEST_METHOD'] === 'POST' ? v($_POST, 't') : v($_GET, 't'))));
$tela  = 'exp';
$erro  = '';
$os    = array();
$form  = array('resposta' => '', 'obs' => '');

if (preg_match('/^[0-9a-f]{64}$/', $token)) {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $form['resposta'] = (string) v($_POST, 'resposta');
        $form['obs']      = trim((string) v($_POST, 'obs'));

        if ($form['resposta'] !== 'APR' && $form['resposta'] !== 'REC') {
            $erro = 'Escolha se aprova ou não aprova a OS.';
        } elseif ($form['resposta'] === 'REC' && $form['obs'] === '') {
            $erro = 'Conte o motivo ou as mudanças necessárias.';
        } elseif (mb_strlen($form['obs']) > 240) {
            $erro = 'A observação pode ter até 240 caracteres.';
        } else {
            list($st, $resp) = protheus('POST', '/rest/CNSAAPROVA', array(
                'token' => $token, 'decisao' => $form['resposta'], 'motivo' => $form['obs'],
            ));
            if ($st === 200) {
                $tela = 'ok';
            } elseif ($st === 409) {
                $tela = 'ja';
            } elseif ($st === 404) {
                $tela = 'exp';
            } else {
                $erro = txt(v($resp, 'erro')) ?: 'Não foi possível registrar sua resposta. Tente novamente em instantes.';
            }
        }
    }

    // Dados da OS (formulario de novo, em caso de erro, ou primeira abertura).
    if ($tela !== 'ok' && ($_SERVER['REQUEST_METHOD'] !== 'POST' || $erro !== '')) {
        list($st, $os) = protheus('GET', '/rest/CNSAAPROVA', array('token' => $token));
        if ($st === 200) {
            $tela = 'form';
        } elseif ($st === 409) {
            $tela = 'ja';
        } elseif ($st === 404 || $st === 400) {
            $tela = 'exp';
        } else {
            $tela = 'fora';   // Protheus fora do ar / usuario de servico invalido: nao dizer que o link venceu
        }
    }
}
?>
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

<?php if ($tela === 'form'): ?>
  <form class="corpo" method="post" action="index.php">
    <input type="hidden" name="t" value="<?php echo h($token) ?>">
    <h1>OS <?php echo h(txt(v($os, 'os'))) ?></h1>
    <p class="sub"><?php echo h(txt(v($os, 'cliente'))) ?></p>

    <?php if ($erro !== ''): ?><div class="erro"><?php echo h($erro) ?></div><?php endif; ?>

    <div class="grade">
      <div><b>Data</b><?php echo h(txt(v($os, 'data'))) ?></div>
      <div><b>Horário</b><?php echo h(txt(v($os, 'horario'))) ?></div>
      <div><b>Total de horas</b><?php echo h(txt(v($os, 'horas'))) ?></div>
      <div><b>Analista</b><?php echo h(txt(v($os, 'analista'))) ?></div>
      <?php if (trim((string) (v($os, 'projeto'))) !== ''): ?><div><b>Projeto</b><?php echo h(txt($os['projeto'])) ?></div><?php endif; ?>
      <?php if (!empty($os['chamados'])): ?>
        <div><b>Chamados</b><?php echo implode('<br>', array_map(function ($c) { return h(txt($c)); }, (array) $os['chamados'])) ?></div>
      <?php endif; ?>
    </div>

    <?php if (trim((string) (v($os, 'descricao'))) !== ''): ?>
    <div class="bloco">
      <span class="titulo">Serviço executado</span>
      <div class="servico"><?php echo h(txt($os['descricao'])) ?></div>
    </div>
    <?php endif; ?>

    <div class="bloco">
      <span class="titulo">Sua resposta *</span>
      <div class="opcoes">
        <label class="opcao aprova"><input type="radio" name="resposta" value="APR" required <?php echo $form['resposta'] === 'APR' ? 'checked' : '' ?>> ✔ Aprovo esta OS</label>
        <label class="opcao recusa"><input type="radio" name="resposta" value="REC" <?php echo $form['resposta'] === 'REC' ? 'checked' : '' ?>> ✖ Não aprovo</label>
      </div>
    </div>

    <div class="bloco">
      <label class="titulo" for="obs">Observação / mudanças <span class="obrig">(obrigatória se não aprovar)</span></label>
      <textarea id="obs" name="obs" maxlength="240" placeholder="Ex.: as horas foram 3h e não 3,5h"><?php echo h($form['obs']) ?></textarea>
      <div class="contador"><span id="cont"><?php echo mb_strlen($form['obs']) ?></span>/240</div>
    </div>

    <button type="submit" class="botao">Enviar resposta</button>
  </form>

<?php elseif ($tela === 'ok'): ?>
  <div class="estado">
    <div class="icone">✅</div>
    <h1>Obrigado!</h1>
    <p class="sub">Sua resposta foi registrada em <?php echo h(date('d/m/Y \à\s H:i')) ?>.<br>
    A Ápia já foi avisada.</p>
  </div>

<?php elseif ($tela === 'ja'): ?>
  <div class="estado">
    <div class="icone">ℹ️</div>
    <h1>Esta OS já foi respondida</h1>
    <p class="sub">Para dúvidas, fale com a Ápia: <?php echo h(TELEFONE_APIA) ?>.</p>
  </div>

<?php elseif ($tela === 'fora'): ?>
  <div class="estado">
    <div class="icone">🔧</div>
    <h1>Sistema indisponível no momento</h1>
    <p class="sub">Seu link continua valendo. Tente novamente mais tarde.<br>
    Se precisar, fale com a Ápia: <?php echo h(TELEFONE_APIA) ?>.</p>
  </div>

<?php else: ?>
  <div class="estado">
    <div class="icone">⏱️</div>
    <h1>Link inválido ou expirado</h1>
    <p class="sub">O link de aprovação vale por tempo limitado após o envio da OS.<br>
    Peça um novo envio à Ápia: <?php echo h(TELEFONE_APIA) ?>.</p>
  </div>
<?php endif; ?>

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
