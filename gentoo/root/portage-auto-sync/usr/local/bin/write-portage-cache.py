#!/usr/bin/env python3
"""
write-portage-cache.py

Roda 'eix -cu', faz parse da saída e grava um cache JSON com os pacotes
que têm atualização disponível. Pensado pra ser chamado pelo Timer B,
DEPOIS de 'emerge --sync' e 'eix-update' já terem rodado.

Uso:
    write-portage-cache.py [caminho-de-saida]

Se caminho-de-saida não for passado, usa $CACHE_DIRECTORY/status.json
(CACHE_DIRECTORY é injetado automaticamente pelo systemd quando a unit
tem CacheDirectory= configurado).
"""
import json
import os
import re
import subprocess
import sys
from datetime import datetime

# "[U?]" acontece com pacotes de slot versionado (ex: sys-kernel/*-sources)
# onde o eix tem incerteza na comparação - sem o "?" opcional aqui essas
# linhas eram silenciosamente descartadas (nunca apareciam no cache).
LINE_RE = re.compile(r'^\[U\??\] (\S+) \((.*)\): (.*)$')
TOKEN_RE = re.compile(r'^([^\s(){}@^]+)(?:\(([^)]*)\))?')
# "(~)" na frente da versão = só disponível em ~arch (testing/unstable),
# precisaria de package.accept_keywords pra instalar.
UNSTABLE_PREFIX_RE = re.compile(r'^\(~\)')


def parse_token(tok: str):
    is_testing = bool(UNSTABLE_PREFIX_RE.match(tok))
    tok = UNSTABLE_PREFIX_RE.sub('', tok)
    m = TOKEN_RE.match(tok)
    if m is None:
        # Formato de token não reconhecido - não derruba o resto do
        # parsing, só esse token específico fica de fora da comparação.
        return None, None, False
    version = m.group(1)
    slot = m.group(2) if m.group(2) else "0"
    primary_slot = slot.split('/')[0]
    return version, primary_slot, is_testing


def parse_line(line: str):
    m = LINE_RE.match(line)
    if not m:
        return None
    pkg, body, _desc = m.groups()
    if ' -> ' not in body:
        return None
    installed_str, available_str = body.split(' -> ', 1)
    inst_version, inst_slot, _ = parse_token(installed_str)
    if inst_version is None:
        return f"{pkg}: (versao instalada em formato nao reconhecido)"

    avail_tokens = available_str.split()

    matched_version = None
    matched_testing = False
    for tok in avail_tokens:
        v, s, testing = parse_token(tok)
        if v is None:
            continue
        if s == inst_slot:
            matched_version = v
            matched_testing = testing
            break

    if matched_version is None:
        # Nenhuma slot igual à instalada encontrada nos disponíveis.
        return f"{pkg}: {inst_version} (new slot)"

    if matched_version == inst_version:
        return f"{pkg}: {inst_version} (new slot)"

    suffix = " (~testing)" if matched_testing else ""
    return f"{pkg}: {inst_version} -> {matched_version}{suffix}"


def run_eix_u() -> str:
    result = subprocess.run(
        ["eix", "-cu"],
        capture_output=True,
        text=True,
    )
    if result.returncode not in (0, 1):
        raise RuntimeError(
            f"eix -cu falhou (exit {result.returncode}): {result.stderr.strip()}"
        )
    return result.stdout


def build_cache(eix_output: str) -> dict:
    packages = []
    for line in eix_output.splitlines():
        parsed = parse_line(line)
        if parsed is not None:
            packages.append(parsed)
    packages.sort()

    return {
        "count": len(packages),
        "updated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "packages": packages,
    }


def main():
    if len(sys.argv) > 1:
        out_path = sys.argv[1]
    else:
        cache_dir = os.environ.get("CACHE_DIRECTORY")
        if not cache_dir:
            print(
                "Erro: nenhum caminho de saída passado e $CACHE_DIRECTORY "
                "não está definido.",
                file=sys.stderr,
            )
            sys.exit(1)
        out_path = os.path.join(cache_dir, "status.json")

    eix_output = run_eix_u()
    cache = build_cache(eix_output)

    with open(out_path, "w") as f:
        json.dump(cache, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Cache escrito em {out_path} ({cache['count']} pacote(s))")


if __name__ == "__main__":
    main()
