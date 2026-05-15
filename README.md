# Zedia Engine

Game engine educational em C com bindings Lua e renderização OpenGL 2.

## O que é

Engine simples criada para aprendizado de desenvolvimento de games. Roda em 640x480 e usa Lua para scripting. O objetivo é entender como uma engine básica funciona por dentro: loop de jogo, input, rendering.

## API Lua

### Funções de Desenho

```lua
rect(x, y, w, h)  -- Desenha retângulo branco
png(x, y, "arquivo.png")  -- Desenha imagem PNG
```

### Callbacks

```lua
function tick()
    -- Called ~60 vezes por segundo
end

function key(nome, pressed)
    -- Called quando uma tecla é pressionada/solta
    -- nome: "up", "down", "left", "right", "space", etc.
end

function gamepad_button(nome, pressed)
    -- Callback opcional para gamepad
    -- nome: "a", "b", "x", "y", "dpup", "dpdown", etc.
end

function gamepad_axis(nome, valor)
    -- Eixos do controle: "lx", "ly", "rx", "ry", "lt", "rt"
end
```

## Compilação

```bash
cmake -B build -H.
make -C build
```

## Execução

```bash
./build/bin/engine <script.lua>
```

Exemplos incluídos:

- `rect.lua` - exemplo mínimo
- `pong.lua` - jogo completo
- `dvd.lua` - screensaver com imagem
- `doom.lua` - raycaster simples
- `gamepad.lua` - exemplo com controle

Para o `dvd.lua`, é necessário um arquivo `dvd.png` no diretório de execução.

## Flags

```bash
./build/bin/engine --fps pong.lua
./build/bin/engine --vsync --title "Minha Janela" pong.lua
```

## Dependências

O CMake baixa automaticamente: glfw, glad, lua, klib, spng.

No Linux (Debian/Ubuntu):
```bash
sudo apt-get install cmake build-essential pkg-config \
  libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
  libgl1-mesa-dev libasound2-dev zlib1g-dev
```

## Testes

```bash
ctest --test-dir build --output-on-failure
```

## Documentação

Se tiver Doxygen instalado:
```bash
cmake --build build --target docs
```

Saída em `docs/api/html/index.html`.