import gleam/int
import gleam/list
import gleam/option.{type Option}
import sgleam/fill
import sgleam/image
import sgleam/key
import sgleam/mworld.{type Player}

const largura_tela = 800

const altura_tela = 600

const deslocamento = 5

const q_x = 400

const q_y = 300

// ---------------------------------------------------------------------------
// Tipos (os do trab(1).gleam)
// ---------------------------------------------------------------------------

pub type Vetor {
  Vetor(x: Float, y: Float)
}

pub type Estado {
  // Abertura
  Lobby(jogadores: List(Player), segundos: Option(Int))
  // Partida
  Jogando(campos: List(Jogador), tique: Int, seed: Int)
  // Resultado
  FimDeJogo(status: List(Jogador))
}

pub type Jogador {
  Campo(
    jogador: Player,
    pos: Vetor,
    vida: Int,
    pontos: Int,
    recarga: Int,
    objetos: List(TipoObjeto),
    tiros: List(Tiro),
  )
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

// ---------------------------------------------------------------------------
// Estado inicial
// ---------------------------------------------------------------------------

// Cada jogador da partida ganha o seu próprio campo, no centro da tela
fn novo_campo(jogador: Player) -> Jogador {
  Campo(
    jogador: jogador,
    pos: Vetor(int.to_float(q_x), int.to_float(q_y)),
    vida: 100,
    pontos: 0,
    recarga: 0,
    objetos: [],
    tiros: [],
  )
}

fn inicial(jogadores: List(Player)) -> Estado {
  Jogando(campos: list.map(jogadores, novo_campo), tique: 0, seed: 0)
}

// ---------------------------------------------------------------------------
// Desenho
// ---------------------------------------------------------------------------

fn fundo() -> image.Image {
  image.rectangle(largura_tela, altura_tela, fill.black)
}

// Jogador 1 é azul, os demais são vermelhos
fn triangulo(p: Player) -> image.Image {
  case mworld.player_index(p) {
    1 -> image.triangle(40, fill.blue)
    _ -> image.triangle(40, fill.red)
  }
}

fn eh_do_jogador(c: Jogador, player: Player) -> Bool {
  mworld.player_index(c.jogador) == mworld.player_index(player)
}

// Cada jogador enxerga só o próprio campo
pub fn desenhar(estado: Estado, player: Player) -> image.Image {
  case estado {
    Jogando(campos, _, _) ->
      case list.find(campos, fn(c) { eh_do_jogador(c, player) }) {
        Ok(c) ->
          fundo()
          |> image.place_imagef(c.pos.x, c.pos.y, triangulo(c.jogador))
        Error(_) -> fundo()
      }
    _ -> fundo()
  }
}

// ---------------------------------------------------------------------------
// Movimento
// ---------------------------------------------------------------------------

fn mover(c: Jogador, dx: Float, dy: Float) -> Jogador {
  Campo(..c, pos: Vetor(c.pos.x +. dx, c.pos.y +. dy))
}

// Setas
pub fn move(c: Jogador, tecla: key.Event) -> Jogador {
  let d = int.to_float(deslocamento)
  case tecla {
    key.ArrowLeft -> mover(c, 0.0 -. d, 0.0)
    key.ArrowRight -> mover(c, d, 0.0)
    key.ArrowUp -> mover(c, 0.0, 0.0 -. d)
    key.ArrowDown -> mover(c, 0.0, d)
    _ -> c
  }
}

// WASD
pub fn move_wasd(c: Jogador, tecla: key.Event) -> Jogador {
  let d = int.to_float(deslocamento)
  case tecla {
    key.Char("a") | key.Char("A") -> mover(c, 0.0 -. d, 0.0)
    key.Char("d") | key.Char("D") -> mover(c, d, 0.0)
    key.Char("w") | key.Char("W") -> mover(c, 0.0, 0.0 -. d)
    key.Char("s") | key.Char("S") -> mover(c, 0.0, d)
    _ -> c
  }
}

// Handler de teclado do mworld: move só o campo de quem apertou a tecla.
// Cada jogador está no próprio computador, então vale WASD ou setas.
pub fn tecla(estado: Estado, player: Player, evento: key.Event) -> Estado {
  case estado {
    Jogando(campos, tique, seed) -> {
      let campos =
        list.map(campos, fn(c) {
          case eh_do_jogador(c, player) {
            True -> move(move_wasd(c, evento), evento)
            False -> c
          }
        })
      Jogando(campos, tique, seed)
    }
    _ -> estado
  }
}

// ---------------------------------------------------------------------------
// Jogo
// ---------------------------------------------------------------------------

pub fn smain() {
  mworld.create_from(
    fn(_, jogadores) { inicial(jogadores) },
    min: 2,
    max: 2,
    to_image: desenhar,
  )
  |> mworld.on_key_down(tecla)
}
