# Relatório: joystick / gamepad no macOS

## Sintoma

Controles aparecem em testes no **navegador** (ex.: páginas que usam a Gamepad API), mas o binário `engine` não imprime logs de joystick e `gamepad.lua` não reage.

## Causa principal (documentada no GLFW)

No backend Cocoa do GLFW 3.4, ao registrar um dispositivo HID, o código chama `IOHIDDeviceCopyMatchingElements`. O próprio GLFW comenta que **no macOS 13 (Ventura) em diante isso pode falhar se o aplicativo não tiver permissão de monitoramento de entrada**; nesse caso o callback retorna **sem** registrar o joystick — `glfwJoystickPresent` permanece falso para sempre.

O **navegador** não passa pelo mesmo caminho de IOKit que um processo nativo no Terminal; por isso um pode “ver” o controle e o outro não.

Referência no código-fonte do GLFW (submódulo após build): `cocoa_joystick.m`, trecho ao redor de `IOHIDDeviceCopyMatchingElements` e o comentário sobre Ventura.

## O que fazer no sistema

1. Abra **Ajustes do Sistema** → **Privacidade e Segurança** → **Monitoramento de Entrada** (*Input Monitoring*).
2. Ative ou adicione o programa que **executa** o `engine`:
   - **Terminal** ou **iTerm2**, se você roda `./build/bin/engine` no terminal;
   - **Cursor** (ou **VS Code**), se o binário é iniciado pelo IDE;
   - Opcionalmente adicione o caminho absoluto do binário, por exemplo  
     `/caminho/para/sistemas-2/build/bin/engine`.
3. **Feche e reabra** o Terminal ou o IDE após mudar a permissão.
4. Execute de novo: `./build/bin/engine gamepad.lua`  
   - Com permissão correta, deve aparecer no stderr algo como  
     `joystick already present: jid=0 name=... gamepad=yes` (ou `no`).

Se ainda aparecer `gamepad=no`, o hardware está visível ao GLFW como joystick bruto, mas **não** há mapeamento “Standard Gamepad”. Aí é outro tópico: `glfwUpdateGamepadMappings` com string SDL2 ou uso de controle com mapeamento embutido no GLFW.

## Mudanças feitas no projeto

- `joystick_register_callbacks()` passou a ser chamado **depois** de criar a janela e do contexto OpenGL, com **dois** `glfwPollEvents()` no macOS, para alinhar com o ciclo de eventos Cocoa antes de enumerar dispositivos.
- Se nenhum joystick for encontrado no macOS, o engine emite um **LOGW** explicando a permissão *Input Monitoring* (antes o processo podia ficar totalmente silencioso).

## Verificação rápida

```sh
./build/bin/engine gamepad.lua 2>&1 | head -20
```

Procure linhas `[INFO]` com `joystick` ou `[WARN]` com `GLFW nao enumerou`.
