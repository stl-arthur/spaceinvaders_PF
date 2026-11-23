import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import sgleam/fill
import sgleam/image
import sgleam/key
import sgleam/mworld.{type Player}

const largura_tela = 800

const altura_tela = 600

// limite para que quando a nave encoste na borda ela não fique pela metade
const margem = 20.0

// pixels por tick (o mundo roda a 28 ticks por segundo por padrão)
const deslocamento = 5

const q_x = 400

const q_y = 300

// 1 / raiz de 2: evita que a diagonal seja mais rápida que as outras direções
const diagonal = 0.7

// um orbe novo a cada 15 segundos (15 * 28 ticks por segundo)
const intervalo_spawn = 420

// borda esquerda/direita para o x do orbe (Int). A `margem` Float acima é da nave
const margem_orb = 20

const raio_orb = 10

// y fixo onde todo orbe nasce: logo acima da tela (use 0.0 para nascer na borda)
const y_inicial = -10.0

// pixels por tick que o orbe desce (menor que o `deslocamento` do jogador)
const velocidade_orb = 2.0

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
  Jogando(
    jogadores: List(Jogador),
    tique: Int,
    seed: Int,
    objetos: List(Objeto),
  )
  // Resultado
  FimDeJogo(status: List(Jogador))
}

// Teclas de direção que o jogador está segurando agora
pub type Entrada {
  Entrada(cima: Bool, baixo: Bool, esquerda: Bool, direita: Bool)
}

pub type Jogador {
  Jogador(
    jogador: Player,
    pos: Vetor,
    // Vidas: lista de 3 booleans (True=viva, False=perdida)
    vidas: List(Bool),
    // Pontuação visível na tela
    pontos: Int,
    recarga: Int,
    objetos: List(Objeto),
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

fn novo_jogador(jogador: Player) -> Jogador {
  Jogador(
    jogador: jogador,
    pos: Vetor(int.to_float(q_x), int.to_float(q_y)),

    // 3 vidas iniciais disponíveis
    vidas: [True, True, True],

    // Pontuação inicial
    pontos: 0,
    recarga: 0,
    objetos: [],
    tiros: [],
    entrada: Entrada(False, False, False, False),
    angulo: 0,
  )
}

// A seed não pode ser 0 (o gerador ficaria preso em 0)
fn inicial(jogadores: List(Player)) -> Estado {
  Jogando(
    jogadores: list.map(jogadores, novo_jogador),
    tique: 0,
    seed: 12_345,
    objetos: [],
  )
}

// ---------------------------------------------------------------------------
// Geração aleatória (determinística, usa a seed do estado)
// ---------------------------------------------------------------------------

fn proximo(seed: Int) -> Int {
  { seed * 16_807 } % 2_147_483_647
}

// Devolve um orbe verde ou vermelho com x aleatório, y fixo no alto e descendo,
// mais a nova seed
fn gera_orb(seed: Int) -> #(Objeto, Int) {
  let s1 = proximo(seed)
  let s2 = proximo(s1)
  let x = margem_orb + s1 % { largura_tela - 2 * margem_orb }
  let tipo = case s2 % 2 {
    0 -> OrbVerde
    _ -> OrbVermelho
  }
  #(
    Objeto(tipo, Vetor(int.to_float(x), y_inicial), Vetor(0.0, velocidade_orb)),
    s2,
  )
}

// Os orbes não colidem com a borda: atravessam a tela e somem depois de sair
fn move_objeto(o: Objeto) -> Objeto {
  Objeto(..o, pos: Vetor(o.pos.x +. o.vel.x, o.pos.y +. o.vel.y))
}

fn ainda_visivel(o: Objeto) -> Bool {
  o.pos.y <. int.to_float(altura_tela + raio_orb)
}

// ---------------------------------------------------------------------------
// Desenho auxiliares
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

// Desenha um círculo representando uma vida.
// True = vida disponível (verde), False = vida perdida (cinza)
fn vida_para_imagem(vida: Bool) -> image.Image {
  case vida {
    True -> image.circle(5, fill.green)
    False -> image.circle(5, fill.gray)
  }
}

// Converte a lista de vidas (3 booleans) em uma imagem horizontal de círculos.
// Usa place_imagef para posicionar cada círculo separadamente.
fn vidas_imagem(vidas: List(Bool)) -> image.Image {
  // Assume-se que vidas sempre tem exatamente 3 elementos (inicializado como [True, True, True])
  case vidas {
    [v1, v2, v3] ->
      image.place_imagef(
        image.place_imagef(
          image.place_imagef(
            image.empty,
            0.0,
            0.0,
            vida_para_imagem(v1),
          ),
          12.0,
          0.0,
          vida_para_imagem(v2),
        ),
        24.0,
        0.0,
        vida_para_imagem(v3),
      )
    _ -> image.empty
  }
}

// Desenha o texto da pontuação
fn pontos_para_imagem(pontos: Int) -> image.Image {
  image.text(
    int.to_string(pontos),
    24,
    fill.black,
  )
}

// Desenha o texto do nome do jogador
fn nome_para_imagem(nome: String) -> image.Image {
  image.text(
    nome,
    20,
    fill.white,
  )
}

// ---------------------------------------------------------------------------
// Teclas: guardam quais direções estão seguradas
// ---------------------------------------------------------------------------

// Jogador 1: W A S D. Jogador 2: W A S D.
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
    Jogando(jogadores, tique, seed, objetos) -> {
      let indice = mworld.player_index(player)
      let jogadores =
        list.map(jogadores, fn(c) {
          case eh_do_jogador(c, player) {
            True ->
              Jogador(
                ..c,
                entrada: atualiza_entrada(c.entrada, indice, evento, valor),
              )
            False -> c
          }
        })
      Jogando(jogadores, tique, seed, objetos)
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

fn limita(v: Float, min: Float, max: Float) -> Float {
  float.max(min, float.min(v, max))
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
      let x = c.pos.x +. int.to_float(sx) *. velocidade
      let y = c.pos.y +. int.to_float(sy) *. velocidade
      Jogador(
        ..c,
        pos: Vetor(
          limita(x, margem, int.to_float(largura_tela) -. margem),
          limita(y, margem, int.to_float(altura_tela) -. margem),
        ),
        angulo: angulo_da_direcao(sx, sy),
      )
    }
  }
}

pub fn tick(estado: Estado) -> Estado {
  case estado {
    Jogando(jogadores, tique, seed, objetos) -> {
      let jogadores = list.map(jogadores, passo)
      let objetos =
        objetos
        |> list.map(move_objeto)
        |> list.filter(ainda_visivel)
      let tique = tique + 1
      case tique % intervalo_spawn == 0 {
        True -> {
          let #(orb, seed) = gera_orb(seed)
          Jogando(jogadores, tique, seed, [orb, ..objetos])
        }
        False -> Jogando(jogadores, tique, seed, objetos)
      }
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
  |> mworld.on_key_down(tecla_pressionada)
  |> mworld.on_key_up(tecla_solta)
  |> mworld.on_tick(tick)
}

// ---------------------------------------------------------------------------
// Exibição no canvas - cada jogador vê seu próprio painel
// ---------------------------------------------------------------------------

pub fn desenhar(estado: Estado, player: Player) -> image.Image {
  case estado {
    Jogando(jogadores, _, _, objetos) ->
      desenhar_jogador(jogadores, player, objetos)
    _ -> fundo()
  }
}

fn desenhar_jogador(
  jogadores: List(Jogador),
  player: Player,
  objetos: List(Objeto),
) -> image.Image {
  case list.find(jogadores, fn(c) { eh_do_jogador(c, player) }) {
    Ok(c) -> {
      // Base: fundo + orbs
      let base = com_objetos(fundo(), objetos)

      // Elementos de informação do jogador
      let img_nome = nome_para_imagem(mworld.player_nickname(player))
      let img_pontos = pontos_para_imagem(c.pontos)
      let img_vidas = vidas_imagem(c.vidas)

      // Posição relativa ao centro do jogador (pos.x, pos.y)
      // Nome: acima do centro
      let pos_nome_x = c.pos.x
      let pos_nome_y = c.pos.y -. 50.0

      // Vidas: à esquerda do nome
      let pos_vidas_x = c.pos.x -. 70.0
      let pos_vidas_y = c.pos.y -. 50.0

      // Pontos: à direita do nome
      let pos_pontos_x = c.pos.x +. 70.0
      let pos_pontos_y = c.pos.y -. 50.0

      // Composição: base + elementos sobrepostos com posições
      let com_vidas = image.place_imagef(
        base,
        pos_vidas_x,
        pos_vidas_y,
        img_vidas,
      )

      let com_pontos = image.place_imagef(
        com_vidas,
        pos_pontos_x,
        pos_pontos_y,
        img_pontos,
      )

      let resultado = image.place_imagef(
        com_pontos,
        pos_nome_x,
        pos_nome_y,
        img_nome,
      )

      resultado }
    Error(_) -> fundo()
  }
}