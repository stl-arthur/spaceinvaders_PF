import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option}
import sgleam/fill
import sgleam/image
import sgleam/key
import sgleam/mworld.{type Player}
import sgleam/style
import sgleam/xplace
import sgleam/yplace

const largura_tela = 800

const altura_tela = 600

// limite para que quando a nave encoste na borda ela não fique pela metade
const margem = 20.0

// pixels por tick (o mundo roda a 28 ticks por segundo por padrão)
const deslocamento = 5

const q_x = 400

const q_y = 300

// opacidade do outro jogador na tela de cada jogador

const opacidade_f = 0.35

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

// um asteroide novo a cada 0.5 segundos (0.5 * 28 ticks por segundo)
const intervalo_ast = 14

// borda esquerda/direita para o x do asteroide (Int)
const margem_ast = 20

const altura_geodo = 20

const largura_geodo = 20

// (estas duas não estavam no arquivo, mas o código as usa; ajuste se quiser)
const altura_destroco = 18

const largura_destroco = 18

// pixels por tick que o asteroide desce (maior que o 'deslocamento' do jogador)
const velocidade_ast = 7

// Cada posição é uma vida: True = disponível, False = perdida
const vidas_iniciais = [True, True, True]

// distância do HUD até as bordas da tela
const margem_hud = 10

const tamanho_texto = 16

const raio_vida = 7

// --- colisões e tiros ---

// raio usado na colisão do triângulo do jogador (lado 40 => ~16 de raio útil)
const raio_jogador = 16.0

const raio_tiro = 4

// pixels por tick (maior que o deslocamento do jogador e dos objetos)
const velocidade_tiro = 10.0

// ticks de espera entre dois tiros (8 ticks ~ 0,3 s)
const intervalo_tiro = 8

// 30 segundos * 28 ticks por segundo
const duracao_efeito = 840

const pontos_asteroide = 50

// pontos do asteroide enquanto o oponente está sob o efeito do orbe vermelho
const pontos_asteroide_reduzido = 25

const pontos_inimigo = 100

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

// Teclas que o jogador está segurando agora
pub type Entrada {
  Entrada(
    cima: Bool,
    baixo: Bool,
    esquerda: Bool,
    direita: Bool,
    atirar: Bool,
  )
}

pub type Jogador {
  Jogador(
    jogador: Player,
    pos: Vetor,
    // lista de vidas: True = disponível, False = perdida
    vidas: List(Bool),
    pontos: Int,
    // ticks que faltam para poder atirar de novo
    recarga: Int,
    objetos: List(Objeto),
    // tiros deste jogador que ainda estão na tela (a lista indica o dono)
    tiros: List(Tiro),
    // novos: teclas seguradas e ângulo do triângulo
    // (graus, sentido anti-horário; 0 = apontando para cima)
    entrada: Entrada,
    angulo: Int,
    // ticks restantes do efeito do orbe vermelho (0 = sem efeito)
    efeito: Int,
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
    vidas: vidas_iniciais,
    pontos: 0,
    recarga: 0,
    objetos: [],
    tiros: [],
    entrada: Entrada(False, False, False, False, False),
    angulo: 0,
    efeito: 0,
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

fn gera_a_cada(
  intervalo: Int,
  tique: Int,
  seed: Int,
  objetos: List(Objeto),
  gera: fn(Int) -> #(Objeto, Int),
) -> #(List(Objeto), Int) {
  case tique % intervalo == 0 {
    True -> {
      let #(o, seed) = gera(seed)
      #([o, ..objetos], seed)
    }
    False -> #(objetos, seed)
  }
}

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
  let tamanho = case o.tipo {
    Geodo -> altura_geodo
    Destroco -> altura_destroco
    _ -> raio_orb
  }
  o.pos.y <. int.to_float(altura_tela + tamanho)
}

fn gera_ast(seed: Int) -> #(Objeto, Int) {
  let s1 = proximo(seed)
  let s2 = proximo(s1)
  let x = margem_ast + s1 % { largura_tela - 2 * margem_ast }
  let tipo = case s2 % 2 {
    0 -> Geodo
    _ -> Destroco
  }
  #(
    Objeto(
      tipo,
      Vetor(int.to_float(x), y_inicial),
      Vetor(0.0, int.to_float(velocidade_ast)),
    ),
    s2,
  )
}

// ---------------------------------------------------------------------------
// HUD: nome, pontos e vidas de cada jogador
// Estas funções só LEEM os dados do Jogador (nome, pontos, vidas) e montam
// imagens. Quem altera vidas e pontos é a lógica do jogo, não o desenho.
// ---------------------------------------------------------------------------

fn espaco() -> image.Image {
  image.rectangle(4, 1, fill.none)
}

// Uma vida: verde se disponível (True), cinza se perdida (False)
fn imagem_vida(disponivel: Bool) -> image.Image {
  case disponivel {
    True -> image.circle(raio_vida, fill.green)
    False -> image.circle(raio_vida, fill.dimgray)
  }
}

// Uma bolinha por posição da lista, na mesma ordem
fn imagem_vidas(vidas: List(Bool)) -> image.Image {
  list.fold(vidas, image.rectangle(1, 1, fill.none), fn(acc, disponivel) {
    acc
    |> image.beside(espaco())
    |> image.beside(imagem_vida(disponivel))
  })
}

fn texto(conteudo: String) -> image.Image {
  image.text(conteudo, tamanho_texto, fill.white)
}

// Bloco de um jogador: nome, pontos e vidas, alinhados à esquerda
fn imagem_hud(j: Jogador) -> image.Image {
  texto(mworld.player_nickname(j.jogador))
  |> image.above_align(xplace.Left, texto("Pontos: " <> int.to_string(j.pontos)))
  |> image.above_align(xplace.Left, imagem_vidas(j.vidas))
}

// Jogador 1 no canto superior esquerdo, os demais no superior direito
fn posiciona_hud(
  img: image.Image,
  hud: image.Image,
  indice: Int,
) -> image.Image {
  let topo = int.to_float(margem_hud)
  case indice {
    1 ->
      image.place_image_alignf(img, topo, topo, xplace.Left, yplace.Top, hud)
    _ ->
      image.place_image_alignf(
        img,
        int.to_float(largura_tela - margem_hud),
        topo,
        xplace.Right,
        yplace.Top,
        hud,
      )
  }
}

fn com_hud(base: image.Image, jogadores: List(Jogador)) -> image.Image {
  list.fold(jogadores, base, fn(img, j) {
    posiciona_hud(img, imagem_hud(j), mworld.player_index(j.jogador))
  })
}

// ---------------------------------------------------------------------------
// Desenho
// ---------------------------------------------------------------------------

fn fundo() -> image.Image {
  image.rectangle(largura_tela, altura_tela, fill.black)
}

// Jogador 1 é azul, os demais são vermelhos
fn triangulo(p: Player, opacidade: Float) -> image.Image {
  let cor = case mworld.player_index(p) {
    1 -> fill.blue
    _ -> fill.red
  }
  image.triangle(40, style.join([cor, fill.opacityf(opacidade)]))
}

fn nave(c: Jogador, opacidade: Float) -> image.Image {
  image.rotate(triangulo(c.jogador, opacidade), c.angulo)
}

fn eh_do_jogador(c: Jogador, player: Player) -> Bool {
  mworld.player_index(c.jogador) == mworld.player_index(player)
}

fn imagem_objeto(o: Objeto) -> image.Image {
  case o.tipo {
    OrbVerde -> image.circle(raio_orb, fill.green)
    OrbVermelho -> image.circle(raio_orb, fill.red)
    Geodo -> image.rectangle(largura_geodo, altura_geodo, fill.brown)
    Destroco -> image.rectangle(largura_destroco, altura_destroco, fill.grey)
    Inimigo -> image.rectangle(30, 20, fill.red)
  }
}

fn com_objetos(base: image.Image, objetos: List(Objeto)) -> image.Image {
  list.fold(objetos, base, fn(img, o) {
    image.place_imagef(img, o.pos.x, o.pos.y, imagem_objeto(o))
  })
}

// O tiro tem a cor do triângulo de quem atirou
fn imagem_tiro(p: Player) -> image.Image {
  case mworld.player_index(p) {
    1 -> image.circle(raio_tiro, fill.blue)
    _ -> image.circle(raio_tiro, fill.red)
  }
}

// Tiros de todos os jogadores (o mundo é compartilhado)
fn com_tiros(base: image.Image, jogadores: List(Jogador)) -> image.Image {
  list.fold(jogadores, base, fn(img, j) {
    list.fold(j.tiros, img, fn(img2, t) {
      image.place_imagef(img2, t.pos.x, t.pos.y, imagem_tiro(j.jogador))
    })
  })
}

fn desenha_nave(cena: image.Image, c: Jogador, opacidade: Float) -> image.Image {
  image.place_imagef(cena, c.pos.x, c.pos.y, nave(c, opacidade))
}

pub fn desenhar(estado: Estado, player: Player) -> image.Image {
  case estado {
    Jogando(jogadores, _, _, objetos) -> {
      let outros = list.filter(jogadores, fn(c) { !eh_do_jogador(c, player) })
      let meus = list.filter(jogadores, fn(c) { eh_do_jogador(c, player) })
      let cena =
        list.fold(
          outros,
          com_tiros(com_objetos(fundo(), objetos), jogadores),
          fn(cena, c) { desenha_nave(cena, c, opacidade_f) },
        )

      list.fold(meus, cena, fn(cena, c) { desenha_nave(cena, c, 1.0) })
      |> com_hud(jogadores)
    }
    _ -> fundo()
  }
}

// ---------------------------------------------------------------------------
// Teclas: guardam quais teclas estão seguradas
// ---------------------------------------------------------------------------

// Jogador 1: W A S D e espaço. Jogador 2: W A S D e espaço.
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
    #(1, key.Char(" ")) -> Entrada(..e, atirar: valor)
    #(2, key.Char("w")) | #(2, key.Char("W")) -> Entrada(..e, cima: valor)
    #(2, key.Char("s")) | #(2, key.Char("S")) -> Entrada(..e, baixo: valor)
    #(2, key.Char("a")) | #(2, key.Char("A")) -> Entrada(..e, esquerda: valor)
    #(2, key.Char("d")) | #(2, key.Char("D")) -> Entrada(..e, direita: valor)
    #(2, key.Char(" ")) -> Entrada(..e, atirar: valor)
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

pub fn limita(v: Float, min: Float, max: Float) -> Float {
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

// ---------------------------------------------------------------------------
// Vidas: funções puras que só trocam um elemento da lista
// ---------------------------------------------------------------------------

// Troca o primeiro elemento igual a `de` por `para`; sem `de`, não muda nada
fn troca_primeiro(lista: List(Bool), de: Bool, para: Bool) -> List(Bool) {
  case lista {
    [] -> []
    [x, ..resto] if x == de -> [para, ..resto]
    [x, ..resto] -> [x, ..troca_primeiro(resto, de, para)]
  }
}

// Perde a última vida disponível (da direita para a esquerda)
pub fn perde_vida(j: Jogador) -> Jogador {
  let vidas =
    j.vidas
    |> list.reverse
    |> troca_primeiro(True, False)
    |> list.reverse
  Jogador(..j, vidas: vidas)
}

// Recupera a primeira vida perdida (da esquerda para a direita)
pub fn ganha_vida(j: Jogador) -> Jogador {
  Jogador(..j, vidas: troca_primeiro(j.vidas, False, True))
}

// ---------------------------------------------------------------------------
// Tiros
// ---------------------------------------------------------------------------

// Inverso de `angulo_da_direcao`: (sx, sy) para onde o triângulo aponta
fn direcao_do_angulo(angulo: Int) -> #(Int, Int) {
  case angulo {
    0 -> #(0, -1)
    45 -> #(-1, -1)
    90 -> #(-1, 0)
    135 -> #(-1, 1)
    180 -> #(0, 1)
    225 -> #(1, 1)
    270 -> #(1, 0)
    315 -> #(1, -1)
    _ -> #(0, -1)
  }
}

// O tiro nasce na ponta do triângulo e segue a direção em que ele está virado
fn novo_tiro(c: Jogador) -> Tiro {
  let #(sx, sy) = direcao_do_angulo(c.angulo)
  let fator = case sx != 0 && sy != 0 {
    True -> diagonal
    False -> 1.0
  }
  let dx = int.to_float(sx) *. fator
  let dy = int.to_float(sy) *. fator
  Tiro(
    pos: Vetor(c.pos.x +. dx *. raio_jogador, c.pos.y +. dy *. raio_jogador),
    vel: Vetor(dx *. velocidade_tiro, dy *. velocidade_tiro),
  )
}

fn move_tiro(t: Tiro) -> Tiro {
  Tiro(..t, pos: Vetor(t.pos.x +. t.vel.x, t.pos.y +. t.vel.y))
}

fn dentro_da_tela(t: Tiro) -> Bool {
  t.pos.x >=. 0.0
  && t.pos.x <=. int.to_float(largura_tela)
  && t.pos.y >=. 0.0
  && t.pos.y <=. int.to_float(altura_tela)
}

// Avança os tiros que já existem (e descarta os que saíram da tela) e depois
// atira, se a tecla estiver segurada e a recarga zerada. Munição infinita.
// A tecla segurada é só uma flag, então o repeat do teclado não duplica tiros.
fn atualiza_tiros(c: Jogador) -> Jogador {
  let tiros =
    c.tiros
    |> list.map(move_tiro)
    |> list.filter(dentro_da_tela)
  case c.entrada.atirar && c.recarga == 0 {
    True ->
      Jogador(..c, tiros: [novo_tiro(c), ..tiros], recarga: intervalo_tiro)
    False -> Jogador(..c, tiros: tiros, recarga: int.max(0, c.recarga - 1))
  }
}

fn atualiza_efeito(c: Jogador) -> Jogador {
  Jogador(..c, efeito: int.max(0, c.efeito - 1))
}

// ---------------------------------------------------------------------------
// Colisões
// ---------------------------------------------------------------------------

// Dois círculos se tocam quando a distância entre os centros é no máximo a
// soma dos raios (comparando os quadrados, sem tirar raiz)
fn colide(a: Vetor, ra: Float, b: Vetor, rb: Float) -> Bool {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  let r = ra +. rb
  dx *. dx +. dy *. dy <=. r *. r
}

// Raio de colisão de cada objeto: metade do maior lado do que é desenhado
fn raio_objeto(tipo: TipoObjeto) -> Float {
  case tipo {
    Geodo -> int.to_float(largura_geodo) /. 2.0
    Destroco -> int.to_float(largura_destroco) /. 2.0
    Inimigo -> 15.0
    OrbVerde | OrbVermelho -> int.to_float(raio_orb)
  }
}

fn raio_do_tiro() -> Float {
  int.to_float(raio_tiro)
}

fn eh_outro(a: Jogador, b: Jogador) -> Bool {
  mworld.player_index(a.jogador) != mworld.player_index(b.jogador)
}

// O que o contato com um objeto faz com o jogador
fn efeito_do_contato(j: Jogador, tipo: TipoObjeto) -> Jogador {
  case tipo {
    OrbVerde -> ganha_vida(j)
    OrbVermelho -> Jogador(..j, efeito: duracao_efeito)
    Geodo | Destroco | Inimigo -> perde_vida(j)
  }
}

// Todo objeto tocado pelo jogador é consumido. Assim, uma mesma colisão nunca
// desconta (ou devolve) vida em ticks seguidos.
fn jogador_contra_objetos(
  j: Jogador,
  objetos: List(Objeto),
) -> #(Jogador, List(Objeto)) {
  let #(j, restantes) =
    list.fold(objetos, #(j, []), fn(acc, o) {
      let #(j, restantes) = acc
      case colide(j.pos, raio_jogador, o.pos, raio_objeto(o.tipo)) {
        True -> #(efeito_do_contato(j, o.tipo), restantes)
        False -> #(j, [o, ..restantes])
      }
    })
  #(j, list.reverse(restantes))
}

// Os jogadores são processados em sequência, e o objeto consumido por um
// deixa de existir para o próximo.
fn colisoes_jogadores(
  jogadores: List(Jogador),
  objetos: List(Objeto),
) -> #(List(Jogador), List(Objeto)) {
  let #(feitos, objetos) =
    list.fold(jogadores, #([], objetos), fn(acc, j) {
      let #(feitos, objs) = acc
      let #(j, objs) = jogador_contra_objetos(j, objs)
      #([j, ..feitos], objs)
    })
  #(list.reverse(feitos), objetos)
}

// Procura o primeiro objeto tocado pelo tiro. Devolve ele e a lista sem ele.
fn tiro_contra_objetos(
  t: Tiro,
  objetos: List(Objeto),
) -> #(Result(Objeto, Nil), List(Objeto)) {
  case objetos {
    [] -> #(Error(Nil), [])
    [o, ..resto] ->
      case colide(t.pos, raio_do_tiro(), o.pos, raio_objeto(o.tipo)) {
        True -> #(Ok(o), resto)
        False -> {
          let #(achado, resto) = tiro_contra_objetos(t, resto)
          #(achado, [o, ..resto])
        }
      }
  }
}

fn pontos_do_asteroide(reduzido: Bool) -> Int {
  case reduzido {
    True -> pontos_asteroide_reduzido
    False -> pontos_asteroide
  }
}

// Resolve os tiros de um jogador:
// - orbe: o tiro some e o orbe continua
// - asteroide: o tiro some, o asteroide é destruído e o dono ganha pontos
// - inimigo: o tiro some, o inimigo é destruído e o dono ganha pontos
// - outro jogador: o tiro some, sem dano nem pontos
// - nada: o tiro continua
fn tiros_do_jogador(
  j: Jogador,
  jogadores: List(Jogador),
  objetos: List(Objeto),
) -> #(Jogador, List(Objeto)) {
  // o efeito do orbe vermelho de um oponente reduz os pontos de asteroide de j
  let reduzido = list.any(jogadores, fn(o) { eh_outro(o, j) && o.efeito > 0 })
  let #(vivos, objetos, ganho) =
    list.fold(j.tiros, #([], objetos, 0), fn(acc, t) {
      let #(vivos, objs, ganho) = acc
      case tiro_contra_objetos(t, objs) {
        #(Ok(o), sem_o) ->
          case o.tipo {
            OrbVerde | OrbVermelho -> #(vivos, objs, ganho)
            Inimigo -> #(vivos, sem_o, ganho + pontos_inimigo)
            Geodo | Destroco -> #(
              vivos,
              sem_o,
              ganho + pontos_do_asteroide(reduzido),
            )
          }
        #(Error(_), _) -> {
          let acertou_jogador =
            list.any(jogadores, fn(outro) {
              eh_outro(outro, j)
              && colide(t.pos, raio_do_tiro(), outro.pos, raio_jogador)
            })
          case acertou_jogador {
            True -> #(vivos, objs, ganho)
            False -> #([t, ..vivos], objs, ganho)
          }
        }
      }
    })
  #(
    Jogador(..j, tiros: list.reverse(vivos), pontos: j.pontos + ganho),
    objetos,
  )
}

// Cada tiro existe em uma única lista e cada objeto sai da lista ao ser
// atingido, então nada é pontuado duas vezes.
fn colisoes_tiros(
  jogadores: List(Jogador),
  objetos: List(Objeto),
) -> #(List(Jogador), List(Objeto)) {
  let #(feitos, objetos) =
    list.fold(jogadores, #([], objetos), fn(acc, j) {
      let #(feitos, objs) = acc
      let #(j, objs) = tiros_do_jogador(j, jogadores, objs)
      #([j, ..feitos], objs)
    })
  #(list.reverse(feitos), objetos)
}

// ---------------------------------------------------------------------------
// Atualização principal do tick
// ---------------------------------------------------------------------------

pub fn tick(estado: Estado) -> Estado {
  case estado {
    Jogando(jogadores, tique, seed, objetos) -> {
      let jogadores =
        jogadores
        |> list.map(passo)
        |> list.map(atualiza_tiros)
        |> list.map(atualiza_efeito)

      // Move objetos
      let objetos_mov =
        objetos
        |> list.map(move_objeto)
        |> list.filter(ainda_visivel)

      // Colisões: primeiro os tiros, depois o contato com os jogadores
      let #(jogadores, objetos_mov) = colisoes_tiros(jogadores, objetos_mov)
      let #(jogadores, objetos_mov) = colisoes_jogadores(jogadores, objetos_mov)

      // Gera asteroides e orbes
      let #(objetos_novos, seed) =
        gera_a_cada(intervalo_ast, tique, seed, objetos_mov, gera_ast)
      let #(objetos_finais, seed) =
        gera_a_cada(intervalo_spawn, tique, seed, objetos_novos, gera_orb)

      Jogando(jogadores, tique + 1, seed, objetos_finais)
    }
    _ -> estado
  }
}

// ---------------------------------------------------------------------------
// Jogo entry point
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