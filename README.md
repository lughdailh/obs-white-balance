# OBS White Balance

Filtre de vídeo per a macOS que captura un fotograma, permet clicar una
referència blanca o gris neutra i desa una correcció RGB fixa. No revisa la
imatge ni modifica el calibratge contínuament.

## Ús

1. Desactiva el balanç de blancs automàtic de la càmera.
2. Posa una carta blanca o gris neutra sota la il·luminació real.
3. Afegeix **White Balance** als filtres d'efecte de la càmera.
4. Prem **Captura la referència…**, clica una zona uniforme i prem
   **Calibrate**.
5. Retira la carta i grava. El calibratge queda fix i desat amb l'escena.

Per ometre la correcció s'utilitza el botó de l'ull que OBS ja ofereix a tots
els filtres.

## Compilació

Requereix macOS, Xcode, CMake, Git i OBS Studio. La primera versió apunta a OBS
30.2.3 en Apple Silicon:

```sh
chmod +x scripts/fetch-obs-source.sh
./scripts/fetch-obs-source.sh 30.2.3
cmake -S . -B build -DOBS_SOURCE_DIR="$PWD/.deps/obs-studio"
cmake --build build
ctest --test-dir build --output-on-failure
```

El resultat és `build/obs-white-balance.plugin`. Amb OBS tancat:

```sh
mkdir -p "$HOME/Library/Application Support/obs-studio/plugins"
cp -R build/obs-white-balance.plugin \
  "$HOME/Library/Application Support/obs-studio/plugins/"
```

La versió 0.1 accepta fonts asíncrones com les càmeres, fa calibratge d'un sol
punt i no està signada ni notaritzada. La detecció d'una carta de colors
completa, el calibratge simultani de càmeres i Windows queden per a versions
posteriors.

També es genera/distribueix el paquet Apple Silicon
`dist/obs-white-balance-0.1.0-macos-arm64.zip`. El paquet d'aquesta versió té
signatura ad hoc per a proves locals, però no una signatura Developer ID ni
notarització d'Apple.

La versió compilada també es pot descarregar des de les
[releases de GitHub](https://github.com/lughdailh/obs-white-balance/releases).

## Llicència

Aquest projecte és programari lliure sota la llicència
`GPL-2.0-or-later`, compatible amb OBS Studio. Consulta `LICENSE`.
