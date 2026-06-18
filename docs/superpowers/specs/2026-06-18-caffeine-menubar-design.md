# Caffeine para macOS — App de Menubar

**Data:** 2026-06-18
**Status:** Design aprovado, aguardando revisão do spec

## Objetivo

Criar um app nativo de menubar para macOS que gerencia o comando `caffeinate`,
oferecendo timers predefinidos para manter o Mac acordado — equivalente ao
app "Caffeine" do Linux (ícone de xícara na bandeja com timer de 15min, 30min,
1h, Infinite e Settings).

## Contexto

- Diretório do projeto: `/Users/felipe/Projetos/Pessoal/caffeine` (novo, vazio).
- Ambiente: macOS 26.5, Swift 6.3.2 via **Command Line Tools** (sem Xcode completo).
- Implicação: build via **Swift Package Manager** + empacotamento manual em `.app`.

## Decisões de design

| Decisão | Escolha |
|---|---|
| Linguagem/stack | Swift nativo |
| UI da menubar | AppKit `NSStatusItem` + `NSMenu` (mais robusto que SwiftUI `MenuBarExtra` sem Xcode completo) |
| Mecanismo de keep-awake | Subprocess `caffeinate` (gerenciado via `Foundation.Process`) |
| Modo caffeinate | **Configurável** nas Settings: "Só a tela" (`-d`) ou "Tela + sistema" (`-di`) |
| Presets de timer | 15 min, 30 min, 1 h, Infinite |
| Ícone de estado | Alterna entre inativo/ativo (SF Symbols, ex. `cup.and.saucer` / `cup.and.saucer.fill`) |
| Contagem regressiva | Visível no topo do menu quando um timer está ativo |
| Iniciar no login | `SMAppService.mainApp` (macOS 13+) |
| Persistência | `UserDefaults` (modo escolhido, preferências) |

## Funcionalidades

1. **Timers predefinidos** — 15min, 30min, 1h, Infinite. Ao escolher, o app
   inicia o `caffeinate` com as flags do modo + `-t <segundos>` (exceto Infinite,
   que roda sem `-t`). Item ativo recebe checkmark.
2. **Ícone muda de estado** — reflete visualmente se está ativo ou não.
3. **Iniciar com o sistema** — toggle nas Settings via `SMAppService`.
4. **Contagem regressiva visível** — item no topo do menu mostra o tempo restante,
   atualizado a cada segundo.
5. **Ligar/desligar manual** — clicar no preset ativo (ou item de desligar) encerra
   o `caffeinate`.

## Arquitetura

### Componentes

- **`AppDelegate`** — ciclo de vida (LSUIElement, sem Dock), cria o `NSStatusItem`,
  garante encerramento do `caffeinate` no `Quit`.
- **`CaffeineController`** — núcleo testável. Liga/desliga o subprocess `caffeinate`,
  monta as flags a partir do modo, gerencia o `Timer` de duração e expõe estado
  (`isActive`, `remainingSeconds`, `activePreset`). Mata processo anterior antes de
  iniciar um novo. Notifica observadores em mudanças de estado.
- **`MenuBuilder`** — constrói/atualiza o `NSMenu`: contagem regressiva (quando ativo),
  presets com checkmark, Settings, Quit.
- **`StatusItemController`** — gerencia o `NSStatusItem` e troca o ícone conforme estado.
- **`SettingsWindowController`** — janela AppKit: seletor de modo (tela / tela+sistema),
  toggle "Iniciar no login".
- **`Preferences`** — wrapper de `UserDefaults` para o modo e demais preferências.

### Modelo de dados

```swift
enum CaffeinatePreset {
    case minutes15, minutes30, hour1, infinite
    var seconds: Int? // nil para infinite
    var title: String
}

enum CaffeinateMode {
    case displayOnly   // caffeinate -d
    case displaySystem // caffeinate -di
    var flags: [String]
}
```

### Fluxo

1. Clique no ícone → abre o `NSMenu` (reconstruído com estado atual).
2. Escolher preset → `CaffeineController.start(preset:)`:
   - encerra `caffeinate` anterior se houver;
   - inicia `Process` com `caffeinate <flags> [-t <segundos>]`;
   - agenda `Timer` de 1s para atualizar `remainingSeconds`;
   - notifica → ícone vira "ativo", menu mostra contagem e checkmark.
3. Expiração do timer **ou** clique no preset ativo **ou** item de desligar →
   `CaffeineController.stop()`: encerra `Process`, zera estado, ícone volta a inativo.
4. `Quit` → `stop()` antes de `NSApp.terminate`.

### Empacotamento

- Estrutura SPM: `Package.swift` com um executable target.
- Script `build.sh` que:
  1. `swift build -c release`;
  2. monta a árvore `Caffeine.app/Contents/{MacOS,Resources}`;
  3. copia o binário e um `Info.plist` (com `LSUIElement = true`, bundle id,
     ícone) para o bundle.
- Resultado: `Caffeine.app` arrastável para `/Applications`.

## Tratamento de erros

- Falha ao iniciar `caffeinate` (binário ausente / erro de `Process`): log + estado
  permanece inativo; item de menu indica falha de forma discreta.
- Processo morto externamente: o handler de término do `Process` zera o estado.
- Múltiplos cliques rápidos: `start` sempre encerra o anterior antes de iniciar (idempotente).

## Testes

- **`CaffeineControllerTests`** (`swift test`): cálculo de flags por modo, transições
  de estado (start/stop/expira), cálculo de `remainingSeconds`, idempotência do start.
  Subprocess abstraído atrás de um protocolo para permitir um fake nos testes.
- Camada AppKit (menu, ícone, janela) validada manualmente rodando o `.app`.

## Fora de escopo (YAGNI)

- Durações totalmente customizáveis pelo usuário (além dos 4 presets) — pode vir depois.
- Atalhos globais de teclado.
- Notificações ao expirar.
- Auto-update / assinatura/notarização para distribuição pública.
