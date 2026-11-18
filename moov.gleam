import gleam/int
import gleam/list
import gleam/option.{type Option}
import sgleam/fill
import sgleam/image
import sgleam/key
import sgleam/mworld.{type Player}

const largura_tela = 800

const altura_tela = 600

// pixels por tick (o mundo roda a 28 ticks por segundo por padrão)
const deslocamento = 5

const q_x = 400

const q_y = 300

// 1 / raiz de 2: evita que a diagonal seja mais rápida que as outras direções
const diagonal = 0.7

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

// Teclas de direção que o jogador está segurando agora
pub type Entrada {
  Entrada(cima: Bool, baixo: Bool, esquerda: Bool, direita: Bool)
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
    // novos: teclas seguradas e ângulo do triângulo
    // (graus, sentido anti-horário; 0 = apontando para cima)
    entrada: Entrada,
    angulo: Int,
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

fn novo_campo(jogador: Player) -> Jogador {
  Campo(
    jogador: jogador,
    pos: Vetor(int.to_float(q_x), int.to_float(q_y)),
    vida: 100,
    pontos: 0,
    recarga: 0,
    objetos: [],
    tiros: [],
    entrada: Entrada(False, False, False, False),
    angulo: 0,
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

// Cada jogador enxerga só o próprio campo; o triângulo gira conforme a direção
pub fn desenhar(estado: Estado, player: Player) -> image.Image {
  case estado {
    Jogando(campos, _, _) ->
      case list.find(campos, fn(c) { eh_do_jogador(c, player) }) {
        Ok(c) ->
          fundo()
          |> image.place_imagef(
            c.pos.x,
            c.pos.y,
            image.rotate(triangulo(c.jogador), c.angulo),
          )
        Error(_) -> fundo()
      }
    _ -> fundo()
  }
}

// ---------------------------------------------------------------------------
// Teclas: guardam quais direções estão seguradas
// ---------------------------------------------------------------------------

// Jogador 1: W A S D. Jogador 2: setas.
fn atualiza_entrada(
  e: Entrada,
  indice: Int,
  evento: key.Event,
  valor: Bool,
) -> Entrada {
  case #(indice, evento) {
    #(1, key.Char("w")) | #(1, key.Char("W")) -> Entrada(..e, cima: valor)
    #(1, key.Char("s")) | #(1, key.Char("S")) -> Entrada(..e, baixo: valor)
    #(1, key.Char("a")) | #(1, key.Char("A")) -> Entrada(..e, esquerda: valor)
    #(1, key.Char("d")) | #(1, key.Char("D")) -> Entrada(..e, direita: valor)
    #(2, key.Char("w")) | #(2, key.Char("W")) -> Entrada(..e, cima: valor)
    #(2, key.Char("s")) | #(2, key.Char("S")) -> Entrada(..e, baixo: valor)
    #(2, key.Char("a")) | #(2, key.Char("A")) -> Entrada(..e, esquerda: valor)
    #(2, key.Char("d")) | #(2, key.Char("D")) -> Entrada(..e, direita: valor)
    _ -> e
  }
}

fn muda_tecla(
  estado: Estado,
  player: Player,
  evento: key.Event,
  valor: Bool,
) -> Estado {
  case estado {
    Jogando(campos, tique, seed) -> {
      let indice = mworld.player_index(player)
      let campos =
        list.map(campos, fn(c) {
          case eh_do_jogador(c, player) {
            True ->
              Campo(
                ..c,
                entrada: atualiza_entrada(c.entrada, indice, evento, valor),
              )
            False -> c
          }
        })
      Jogando(campos, tique, seed)
    }
    _ -> estado
  }
}

pub fn tecla_pressionada(
  estado: Estado,
  player: Player,
  evento: key.Event,
) -> Estado {
  muda_tecla(estado, player, evento, True)
}

pub fn tecla_solta(estado: Estado, player: Player, evento: key.Event) -> Estado {
  muda_tecla(estado, player, evento, False)
}

// ---------------------------------------------------------------------------
// Movimento (a cada tick)
// ---------------------------------------------------------------------------

// -1, 0 ou 1 conforme as teclas do eixo. Duas teclas opostas se anulam.
fn eixo(menos: Bool, mais: Bool) -> Int {
  case menos, mais {
    True, False -> -1
    False, True -> 1
    _, _ -> 0
  }
}

// Ângulo anti-horário (graus) do triângulo, que por padrão aponta para cima.
// sx: -1 esquerda, 1 direita. sy: -1 cima, 1 baixo.
fn angulo_da_direcao(sx: Int, sy: Int) -> Int {
  case sx, sy {
    0, -1 -> 0
    -1, -1 -> 45
    -1, 0 -> 90
    -1, 1 -> 135
    0, 1 -> 180
    1, 1 -> 225
    1, 0 -> 270
    1, -1 -> 315
    _, _ -> 0
  }
}

fn passo(c: Jogador) -> Jogador {
  let sx = eixo(c.entrada.esquerda, c.entrada.direita)
  let sy = eixo(c.entrada.cima, c.entrada.baixo)
  case sx == 0 && sy == 0 {
    // parado: mantém posição e a última orientação
    True -> c
    False -> {
      let d = int.to_float(deslocamento)
      let velocidade = case sx != 0 && sy != 0 {
        True -> d *. diagonal
        False -> d
      }
      Campo(
        ..c,
        pos: Vetor(
          c.pos.x +. int.to_float(sx) *. velocidade,
          c.pos.y +. int.to_float(sy) *. velocidade,
        ),
        angulo: angulo_da_direcao(sx, sy),
      )
    }
  }
}

pub fn tick(estado: Estado) -> Estado {
  case estado {
    Jogando(campos, tique, seed) -> Jogando(list.map(campos, passo), tique, seed)
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
  |> mworld.on_key_down(tecla_pressionada)
  |> mworld.on_key_up(tecla_solta)
  |> mworld.on_tick(tick)
}


/// criar geração aleatória de power ups. 