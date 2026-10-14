<?php
/*
 * Configuracao da pagina Aprovador-OS.
 *
 * COMO CRIAR O config.php (so no servidor, uma vez):
 *   1. Nesta pasta (\\10.0.0.3\SistemasWeb\Mais_Aplicacoes\Aprovador-OS),
 *      copie este arquivo e renomeie a copia para  config.php
 *      (confira que nao ficou "config.php.txt" - mostre as extensoes no Explorer).
 *   2. Abra o config.php no Bloco de Notas e preencha:
 *        REST_USUARIO = 'Aprovador de OS'   (login do usuario de servico no Protheus)
 *        REST_SENHA   = a senha desse usuario
 *      REST_BASE e TELEFONE_APIA ja vem certos.
 *   3. Salve. Nao copie o config.php para outro lugar nem para o git.
 *
 * O config.php fica fora do git (tem a senha). O usuario de servico nao abre
 * telas e so consegue usar o /CNSAAPROVA (os demais endpoints recusam com 403).
 * Se a senha mudar no Protheus, atualize aqui.
 */

define('REST_BASE', 'https://10.0.0.3:8624');   // REST do Protheus (rede interna)
define('REST_USUARIO', '');
define('REST_SENHA', '');
define('TELEFONE_APIA', '(24) 2103-7474');
