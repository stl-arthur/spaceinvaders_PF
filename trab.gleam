import gleam/float
import sgleam/fill
import sgleam/image
import sgleam/key
import sgleam/world

const largura_tela = 800

const altura_tela = 600

const deslocamento = 5.0

pub type Vetor {
  Vetor(x: Float, y: Float)
}

pub type Estado {
  // Abertura
  Menu
  Lobby(eu_pronto: Bool, oponente_pronto: Bool)
  Contagem(segundos: Int)
  // Partida
  Jogando(partida: Partida)
  Pausado(partida: Partida)
  // Resultado
  FimDeJogo(pontos_eu: Int, pontos_oponente: Int)
}

pub type Partida {
  Partida(
    eu: Jogador,
    oponente: Jogador,
    objetos: List(Objeto),
    tiros: List(Tiro),
  )
}

pub type Jogador {
  Jogador(pos: Vetor, vida: Int, pontos: Int, sob_efeito: Bool)
}

pub type TipoObjeto {
  Geodo
  Destroco
  Inimigo
  OrbVerde
  OrbVermelho
}

pub type Objeto {
  Objeto(tipo: TipoObjeto, pos: Vetor, vel: Vetor)
}

pub type Tiro {
  Tiro(pos: Vetor, vel: Vetor)
}

/// Teste ovni
fn cena_ovni(tick: Int) -> image.Image {
  let ovni =
    image.circle(10, fill.green)
    |> image.overlay(image.rectangle(40, 4, fill.green))
  image.empty_scene(100, 80) |> image.place_image(50, tick, ovni)
}

pub fn smain() {
  world.animation(cena_ovni)
}

// oponente: setas
pub fn move(q: Jogador, tecla: key.Event) -> Jogador {
  case tecla {
    key.ArrowLeft -> Jogador(..q, pos: Vetor(..q.pos, x: q.pos.x -. deslocamento))
    key.ArrowRight ->
      Jogador(..q, pos: Vetor(..q.pos, x: q.pos.x +. deslocamento))
    key.ArrowUp -> Jogador(..q, pos: Vetor(..q.pos, y: q.pos.y -. deslocamento))
    key.ArrowDown ->
      Jogador(..q, pos: Vetor(..q.pos, y: q.pos.y +. deslocamento))
    _ -> q
  }
}

// eu: WASD
pub fn move_wasd(q: Jogador, tecla: key.Event) -> Jogador {
  case tecla {
    key.Char("a") | key.Char("A") ->
      Jogador(..q, pos: Vetor(..q.pos, x: q.pos.x -. deslocamento))
    key.Char("d") | key.Char("D") ->
      Jogador(..q, pos: Vetor(..q.pos, x: q.pos.x +. deslocamento))
    key.Char("w") | key.Char("W") ->
      Jogador(..q, pos: Vetor(..q.pos, y: q.pos.y -. deslocamento))
    key.Char("s") | key.Char("S") ->
      Jogador(..q, pos: Vetor(..q.pos, y: q.pos.y +. deslocamento))
    _ -> q
  }
}

// recebe a Partida inteira, que é o estado do world
pub fn tecla(p: Partida, evento: key.Event) -> Partida {
  Partida(..p, eu: move_wasd(p.eu, evento), oponente: move(p.oponente, evento))
}

/// Estado inicial do Game:
fn inicial() -> Partida {
  Partida(
    eu: Jogador(pos: Vetor(250.0, 300.0), vida: 100, pontos: 0, sob_efeito: False),
    oponente: Jogador(
      pos: Vetor(550.0, 300.0),
      vida: 100,
      pontos: 0,
      sob_efeito: False,
    ),
    objetos: [],
    tiros: [],
  )
}

fn desenhar(p: Partida) -> image.Image {
  image.rectangle(largura_tela, altura_tela, fill.black)
  |> image.place_image(
    float.round(p.eu.pos.x),
    float.round(p.eu.pos.y),
    image.triangle(40, fill.blue),
  )
  |> image.place_image(
    float.round(p.oponente.pos.x),
    float.round(p.oponente.pos.y),
    image.triangle(40, fill.red),
  )
}
