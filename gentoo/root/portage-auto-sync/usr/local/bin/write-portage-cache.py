#!/usr/bin/env python3
"""
write-portage-cache.py

Roda 'emerge --pretend' e grava um cache JSON com os pacotes que seriam
merged de verdade (respeitando dependência real, slot, USE, etc — não é
mais aproximação via eix). Pensado pra ser chamado pelo Timer B, DEPOIS
de 'emerge --sync' já ter rodado.

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

VERSION_FULL_RE = re.compile(
    r'^\d+(?:\.\d+)*[a-z]?(?:_(?:alpha|beta|pre|rc|p)\d*)*(?:-r\d+)?$'
)
LINE_RE = re.compile(r'^\[ebuild(?P<flags>[^\]]*)\]\s+(?P<rest>.+)$')


def split_name_version(pkg_part: str):
    """pkg_part = 'name-version' (sem categoria/repo/slot). Retorna (name, version)."""
    segments = pkg_part.split('-')
    for i in range(len(segments) - 1, 0, -1):
        candidate = '-'.join(segments[i:])
        if VERSION_FULL_RE.match(candidate):
            return '-'.join(segments[:i]), candidate
    return pkg_part, None


def split_leading_bracket(s: str):
    s = s.lstrip()
    if s.startswith('['):
        end = s.index(']')
        return s[1:end], s[end + 1:].lstrip()
    return None, s


def strip_slot_repo(atom_part: str) -> str:
    if '::' in atom_part:
        atom_part = atom_part.split('::', 1)[0]
    if ':' in atom_part:
        atom_part = atom_part.split(':', 1)[0]
    return atom_part


def parse_emerge_line(line: str):
    m = LINE_RE.match(line)
    if not m:
        return None
    flags_raw = m.group('flags')
    rest = m.group('rest')

    if ' ' not in rest:
        return None
    new_atom, rest = rest.split(None, 1)
    old_atom, _rest = split_leading_bracket(rest)

    flags_clean = re.sub(r'\s+', '', flags_raw)

    if '/' not in new_atom:
        return None
    cat, pkg_part = new_atom.split('/', 1)
    pkg_part = strip_slot_repo(pkg_part)
    name, new_version = split_name_version(pkg_part)
    if new_version is None:
        return None
    full_name = f"{cat}/{name}"

    old_version = None
    if old_atom:
        stripped = strip_slot_repo(old_atom)
        old_version = stripped if VERSION_FULL_RE.match(stripped) else split_name_version(stripped)[1]

    if old_version:
        return f"[{flags_clean}] {full_name}: {old_version} -> {new_version}"
    return f"[{flags_clean}] {full_name}: {new_version}"


def run_emerge_pretend() -> str:
    result = subprocess.run(
        [
            "emerge", "--pretend", "--update", "--newuse",
            "--deep", "--color=n", "--nospinner", "@world",
        ],
        capture_output=True,
        text=True,
    )
    # NOTA: comportamento assumido, ainda nao confirmado em execucao real:
    # --pretend deveria sempre retornar exit 0 quando a resolucao de
    # dependencia teve sucesso, independente de "Total: 0 packages" ou
    # "Total: N packages" - o exit code so deveria refletir erro de
    # resolucao (atom invalido, blocker nao resolvido, etc), nao a
    # quantidade de pacotes encontrados. Precisa validar isso rodando
    # de proposito num momento com 0 pendencias.
    if result.returncode != 0:
        raise RuntimeError(
            f"emerge --pretend falhou (exit {result.returncode}): "
            f"{result.stderr.strip()[-500:]}"
        )
    return result.stdout


def build_cache(emerge_output: str) -> dict:
    packages = []
    for line in emerge_output.splitlines():
        parsed = parse_emerge_line(line)
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

    emerge_output = run_emerge_pretend()
    cache = build_cache(emerge_output)

    with open(out_path, "w") as f:
        json.dump(cache, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Cache escrito em {out_path} ({cache['count']} pacote(s))")


if __name__ == "__main__":
    main()