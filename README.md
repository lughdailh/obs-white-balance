# OBS White Balance

Filtre de vídeo per a macOS i Windows. Permet clicar una referència blanca o
gris neutra directament sobre el preview viu d'OBS i desa una correcció RGB
fixa. No revisa la imatge ni modifica el calibratge contínuament.

## Ús

1. Desactiva el balanç de blancs automàtic de la càmera.
2. Posa una carta blanca o gris neutra sota la il·luminació real.
3. Afegeix **White Balance** als filtres d'efecte de la càmera.
4. Prem **Tria un color neutre…**.
5. Amb el comptagotes, clica una zona uniforme de la carta directament sobre el
   preview viu d'OBS. A Windows pots cancel·lar-lo amb `Esc`.
6. Retira la carta i grava. El calibratge queda fix i desat amb l'escena.

Per ometre la correcció s'utilitza el botó de l'ull que OBS ja ofereix a tots
els filtres.

## Compilació

La versió 0.2.2 es compila contra OBS Studio 31.1.1 amb la infraestructura de
compilació oficial del seu template de plugins.

macOS (binari universal Intel i Apple Silicon):

```sh
.github/scripts/build-macos --config Release
.github/scripts/package-macos --config Release
```

Windows x64, des de PowerShell:

```powershell
.\.github\scripts\Build-Windows.ps1 -Target x64 -Configuration Release
.\.github\scripts\Package-Windows.ps1 -Target x64 -Configuration Release
```

Per executar només les proves després de compilar:

```sh
ctest --test-dir build_macos -C Release --output-on-failure
```

GitHub Actions genera automàticament:

- `obs-white-balance-0.2.2-macos-universal.tar.xz`
- `obs-white-balance-0.2.2-windows-x64.zip`

Els paquets públics no estan signats ni notaritzats. El filtre fa calibratge
d'un sol punt; la detecció automàtica d'una carta de colors completa queda fora
de la versió 0.2.2.

La versió compilada també es pot descarregar des de les
[releases de GitHub](https://github.com/lughdailh/obs-white-balance/releases).

## Llicència

Aquest projecte és programari lliure sota la llicència
`GPL-2.0-or-later`, compatible amb OBS Studio. Consulta `LICENSE`.
