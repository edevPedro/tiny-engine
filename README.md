# 🖥️ Desenvolvedor de Sistemas 2

> 🎯 **Candidato a contratação deve criar uma game engine em C**, implementando desde a API em **Lua** até a camada de renderização gráfica **OpenGL 2**.

## 🎮 Requisitos da Engine

A engine deve possuir **2 funções de desenho** e **2 callbacks**.

### 📐 Funções de desenho

| Função               | Descrição                             |
| :------------------- | :------------------------------------ |
| `rect(x, y, w, h)`   | Desenha um retângulo sólido branco 🟦 |
| `png(x, y, src)`     | Desenha uma imagem 🖼️                 |

### 🔁 Callbacks

| Callback                                 | Descrição                                      |
| :--------------------------------------- | :--------------------------------------------- |
| `function tick() end`                    | Chamada cerca de **60 vezes por segundo** ⏱️    |
| `function key(name, pressed) end`        | Chamada quando uma tecla é pressionada/solta ⌨️ |

---

## 🛠️ Como executar o projeto

Já existe um [`CMakeLists.txt`](CMakeLists.txt) que baixa automaticamente a maior parte das dependências via CMake:  
_(`glad`, `glfw`, `spng`, `lua`, `klib`)_. O **zlib** é resolvido com `find_package(ZLIB)` (pacote de desenvolvimento do sistema; ver checklist abaixo).

Você deve copiá-lo, e criar seu código fonte na pasta `src/` para seu projeto e executar o comando de preparação:

```
cmake -Bbuild -H.
```

Após isso, você deve compilar o binário.

```
make -C build
```

E executar um dos jogos de exemplo

```
./build/bin/engine pong.lua
```

Exemplo com gamepad:

```
./build/bin/engine gamepad.lua
```

### Checklist de entrega

Use esta lista para validar o projeto antes de enviar o repositório (especialmente em **Linux**, alvo obrigatório do desafio).

**1. Ferramentas e biblioteca do sistema**

- Compilador C, `make` e `cmake` (por exemplo, no Debian/Ubuntu: `build-essential`, `cmake`).
- **zlib de desenvolvimento**: o `CMakeLists.txt` usa `find_package(ZLIB REQUIRED)`. O CMake **não** baixa o zlib; instale o pacote do sistema (ex.: Debian/Ubuntu: `zlib1g-dev`; Fedora: `zlib-devel`).
- Conexão com a internet na **primeira** configuração do CMake: `FetchContent` baixa `glfw`, `glad`, `lua`, `klib` e `spng`.

**2. Build e testes (a partir da raiz do repositório)**

```
cmake -B build -H.
cmake --build build
ctest --test-dir build --output-on-failure
```

**3. Executar cada exemplo**

Execute sempre a partir do diretório em que está o script (e os assets), em geral a **raiz do clone**:

| Script        | Comando                          | Observação |
| :------------ | :------------------------------- | :--------- |
| `pong.lua`    | `./build/bin/engine pong.lua`    | Só `rect`; não precisa de arquivo extra. |
| `rect.lua`    | `./build/bin/engine rect.lua`    | Mínimo; só `rect`. |
| `dvd.lua`     | `./build/bin/engine dvd.lua`     | Exige **`dvd.png`** no diretório de trabalho atual (não está versionado no repositório; use qualquer PNG com esse nome para testar). |
| `doom.lua`    | `./build/bin/engine doom.lua`    | Raycaster; usa `rectc` e teclado; não usa `png`. |
| `gamepad.lua` | `./build/bin/engine gamepad.lua` | Opcional; exige controle mapeado pelo GLFW e, para o logo, o mesmo **`dvd.png`** se quiser ver a imagem. |

**4. Flags úteis (diferencial)**

```
./build/bin/engine --fps pong.lua
./build/bin/engine --vsync --title "Pong" pong.lua
```

**5. Memória (opcional, Linux)**

Para reforçar a regra “sem vazamentos”, após compilar com símbolos de depuração: `valgrind --leak-check=full ./build/bin/engine --max-frames 120 rect.lua`.

**6. macOS — controle não aparece no `engine`**

No Safari/Chrome o gamepad pode funcionar, mas o GLFW usa IOKit: no **macOS 13+** pode ser necessário conceder **Input Monitoring** (Monitoramento de Entrada) ao Terminal, ao Cursor ou ao binário `build/bin/engine`. Detalhes: [`docs/RELATORIO_MACOS_JOYSTICK.md`](docs/RELATORIO_MACOS_JOYSTICK.md).

### Testes unitarios

```
ctest --test-dir build --output-on-failure
```

### Suporte a gamepad

A engine suporta callbacks opcionais para controle:

| Callback                                    | Descricao |
| :------------------------------------------ | :-------- |
| `function gamepad_button(name, pressed) end` | Evento de botao (A, B, dpad, etc.) |
| `function gamepad_axis(name, value) end`      | Mudanca de eixo analogico (`lx`, `ly`, `rx`, `ry`, `lt`, `rt`) |

> O gamepad monitorado por padrao e o `GLFW_JOYSTICK_1`.

### Gerar documentacao API (Doxygen)

Se o Doxygen estiver instalado no sistema:

```
cmake --build build --target docs
```

Saida HTML esperada:

`docs/api/html/index.html`

### Regras Técnicas

 * Deve rodar em 640x480.
 * Utilizar OpenGL 2 moderno.
 * O Código deve estar otimizado e limpo.
 * A Engine deve suportar rodar no linux.
 * Todos os jogos de exemplo devem funcionar.
 * Gerenciamento de memória seguro, sem vazamentos.

### Linux

Este projeto possui CI Linux em `.github/workflows/linux-ci.yml` que valida:

* Configuracao e compilacao com CMake em `ubuntu-latest`.
* Execucao de testes unitarios com `ctest`.
* Smoke run dos scripts `rect.lua`, `pong.lua`, `dvd.lua`, `gamepad.lua` e `doom.lua`.

Dependencias esperadas no Linux (Debian/Ubuntu):

```
sudo apt-get update
sudo apt-get install -y \
  cmake build-essential pkg-config \
  libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
  libgl1-mesa-dev libasound2-dev
```

Build e testes:

```
cmake -S . -B build
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

### Diferenciais :sparkles:

 * Adicionar testes unitários.
 * Adicionar flags extras como `--fps` e outras.
 * Adicionar suporte a gamepad (controle de videogame).
 * Utilização de doxygen para documentação.

---

_encaminhe o link de seu repositório no github para o rh._
_o tempo esperado para o desafio é de uma semana!_

:raising_hand_man: Boa sorte!
