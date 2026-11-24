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

// pixels por tick que o asteroide desce (maior que o 'deslocamento' do jogador)
const velocidade_ast = 7

// Cada posição é uma vida: True = disponível, False = perdida
const vidas_iniciais = [True, True, True]

// distância do HUD até as bordas da tela
const margem_hud = 10

const tamanho_texto = 16

const raio_vida = 7


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
    vidas: List(Bool),
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
    vidas: vidas_iniciais,
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

fn gera_a_cada(intervalo: Int, tique: Int, seed: Int, objetos: List(Objeto), gera: fn(Int) -> #(Objeto, Int),) -> #(List(Objeto), Int){
  case tique % intervalo == 0{
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
    Objeto(tipo, Vetor(int.to_float(x), y_inicial), Vetor(0.0, int.to_float(velocidade_ast))),
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

fn nave(c: Jogador, opacidade: Float) -> image.Image{
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
    _ -> image.circle(raio_orb, fill.white)
  }
}

fn com_objetos(base: image.Image, objetos: List(Objeto)) -> image.Image {
  list.fold(objetos, base, fn(img, o) {
    image.place_imagef(img, o.pos.x, o.pos.y, imagem_objeto(o))
  })
}


fn desenha_nave(cena: image.Image, c: Jogador, opacidade: Float) -> image.Image{
  image.place_imagef(cena, c.pos.x, c.pos.y, nave(c, opacidade))
}

pub fn desenhar(estado: Estado, player: Player) -> image.Image{
  case estado{
    Jogando(jogadores, _, _, objetos) -> {
      let outros = list.filter(jogadores, fn(c) { !eh_do_jogador(c, player)})
      let meus = list.filter(jogadores, fn(c) {eh_do_jogador(c, player)})
      let cena = 
        list.fold(outros, com_objetos(fundo(), objetos), fn(cena, c){
          desenha_nave(cena, c, opacidade_f)
        })
        
        list.fold(meus, cena, fn(cena, c) {desenha_nave(cena, c, 1.0)})
        |> com_hud(jogadores)
    }   
    _ -> fundo()
  }
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
// Detecção de colisão entre dois vetores
// ---------------------------------------------------------------------------

fn distancia(e1: Vetor, e2: Vetor) -> Float {
  let dx = e1.x - e2.x
  let dy = e1.y - e2.y
  Float.sqrt(dx *. dx + dy *. dy)
}

// Verifica se dois objetos colidem baseado em suas posições e tipos
fn colidiu(o1: Objeto, o2: Objeto) -> Bool {
  let dist = distancia(o1.pos, o2.pos)
  // Tamanhos de colisão aproximados
  let colisao = case (o1.tipo, o2.tipo) {
    (Geodo, _) -> 20.0
    (Destroco, _) -> 18.0
    (Inimigo, _) -> 22.0
    (OrbVerde, _) -> raio_orb + 12
    (OrbVermelho, _) -> raio_orb + 12
    (_, Geodo) -> 20.0
    (_, Destroco) -> 18.0
    (_, Inimigo) -> 22.0
    (_, OrbVerde) -> raio_orb + 12
    (_, OrbVermelho) -> raio_orb + 12
    (_, _) -> 25.0
  }
  dist < colisao
}

// ---------------------------------------------------------------------------
// Sistema de tiros
// ---------------------------------------------------------------------------

// Converte ângulo em vetor de direção
fn direcao_para_vetor(angulo: Int) -> Vetor {
  case angulo {
    0 -> Vetor(0, -1)   // cima
    45 -> Vetor(-1, -1) // cima-esquerda
    90 -> Vetor(-1, 0)  // esquerda
    135 -> Vetor(-1, 1) // baixo-esquerda
    180 -> Vetor(0, 1)  // baixo
    225 -> Vetor(1, 1)  // baixo-direita
    270 -> Vetor(1, 0)  // direita
    315 -> Vetor(1, -1) // cima-direita
    _ -> Vetor(0, -1)
  }
}

// Cria um tiro na posição do jogador na direção que ele está virado
fn criar_tiro(c: Jogador) -> Tiro {
  let dir = direcao_para_vetor(c.angulo)
  Tiro(
    pos: c.pos,
    vel: Vetor(dir.x *. 8.0, dir.y *. 8.0),
  )
}

// Move o tiro para frente
fn mover_tiro(t: Tiro) -> Tiro {
  Tiro(
    pos: Vetor(t.pos.x +. t.vel.x, t.pos.y +. t.vel.y),
    vel: t.vel,
  )
}

// Verifica se o tiro saiu da tela
fn fora_tela(t: Tiro) -> Bool {
  let pos = t.pos
  pos.x < 0.0 || pos.x > float(largura_tela) || pos.y < 0.0 || pos.y > float(altura_tela)
}

// Processa colisão de tiro com objetos
fn processar_colisao_tiro(
  tiro: Tiro,
  objetos: List(Objeto),
) -> #(List(Objeto), Bool, Int, Int) {
  // Verifica colisão com cada objeto
  let colidiu_algum = list.any(objetos, fn(obj) {
    colidiu(tiro, obj)
  })
  case colidiu_algum {
    True -> {
      // Tiro colidiu - verificar o que atingiu
      let tipo_atingido = case list.find(objetos, fn(o) { colidiu(tiro, o) }).map(fn(o) { o.tipo }).get_or_else(None)
      case tipo_atingido {
        OrbVerde -> #([], True, 0, 0)  // nada acontece com orb, tiro some
        OrbVermelho -> #([], True, 0, 0) // tiro some, efeito aplicado separately
        Geodo -> #([], True, 0, 0)     // tiro some
        Destroco -> #([], True, 0, 0)   // tiro some
        Inimigo -> #([], True, 0, 100) // shooter gets 100 points
        _ -> #([], True, 0, 0)
      }
    }
    False -> #(objetos, False, 0, 0)  // nada, tiro continua
  }
}

// ---------------------------------------------------------------------------
// Lógica de colisões e efeitos de orb
// -------------------------------------------------------------------------)

// Adiciona vida ao jogador (se ainda tiver espaço para 3 vidas)
fn adicionar_vida(j: Jogador) -> Jogador {
  let count_vidas = list.length(list.filter(j.vidas, fn(v) { v }))
  case count_vidas < 3 {
    True -> {
      // Encontra primeira posição False e torna True
      let idx = list.indexed_find(j.vidas, fn(i, v) { v == False })
      case idx {
        Some((_, pos)) -> {
          let atualizados = list.update(j.vidas, pos, fn(_) { True })
          Jogador(
            ..j,
            vidas: atualizados,
          )
        }
        None -> j
      }
    }
    False -> j  // Já tem 3 vidas
  }
}

// Aplica efeito de orb vermelho (30 ticks de duração)
fn efeito_orb_vermelho(j: Jogador) -> Jogador {
  case j.recarga {
    0 -> Jogador(
      ..j,
      recarga: 30,
    )
    _ -> {
      let nova_rec = j.recarga - 1
      Jogador(
        ..j,
        recarga: if nova_rec > 0 then nova_rec else 0,
      )
    }
  }
}

// Verifica se o efeito de orb vermelho está ativo
fn orb_vermelho_ativo(j: Jogador) -> Bool {
  j.recarga > 0
}

// Verifica colisão jogador-orb e aplica efeito
fn verificar_colisao_orb(j: Jogador, orb: Objeto) -> Jogador {
  let dist = distancia(j.pos, orb.pos)
  case orb.tipo {
    OrbVerde -> {
      // Recupera 1 vida
      adicionar_vida(j)
    }
    OrbVermelho -> {
      // Aplica efeito temporário de 30 ticks
      efeito_orb_vermelho(j)
    }
    _ -> j
  }
}

// Verifica colisão jogador-obstáculo e causa perda de vida
fn verificar_colisao_obstaculo(j: Jogador, obstaculo: Objeto) -> Jogador {
  // Perder 1 vida se colidir
  let vidas = j.vidas
  let count_vidas = list.length(list.filter(vidas, fn(v) { v }))
  case count_vidas > 0 {
    True -> {
      // Encontra primeira vida True e seta para False
      let idx = list.indexed_find(vidas, fn(i, v) { v == True })
      case idx {
        Some((_, pos)) -> {
          let atualizados = list.update(vidas, pos, fn(_) { False })
          Jogador(
            ..j,
            vidas: atualizados,
          )
        }
        None -> j
      }
    }
    False -> j  // Sem vidas, não faz nada
  }
}

// ---------------------------------------------------------------------------
// Processa colisões e tiros durante um tick
// ---------------------------------------------------------------------------

fn processar_colisoes_tick(
  jogadores: List(Jogador),
  objetos: List(Objeto),
  tiros: List(Tiro),
) -> #(List(Jogador), List(Objeto), List(Tiro)) {
  // Processa cada jogador para verificar colisões
  let jogadores_atualizados = list.map(jogadores, fn(j) {
    // Verifica colisão com obstáculos (Geodo, Inimigo)
    let colidiu_com_objeto = list.any(objetos, fn(obj) {
      case obj.tipo {
        Geodo -> colidiu(j.obj, obj)  // simplified - need proper player hitbox
        Inimigo -> colidiu(j.obj, obj)
        _ -> False
      }
    })
    
    // Verifica colisão com orbes
    let orb_verde = list.find(objetos, fn(o) { o.tipo == OrbVerde })
    let orb_vermelho = list.find(objetos, fn(o) { o.tipo == OrbVermelho })
    
    // Aplica efeito de orb verde (ganha vida)
    let com_vida = case orb_verde {
      Some(orb) -> verificar_colisao_orb(j, orb)
      None -> j
    }
    
    // Se colidiu com obstáculo, perder vida
    case colidiu_com_objeto {
      True -> {
        // Perder 1 vida (apenas uma vez por tick)
        let count_vidas = list.length(list.filter(com_vida.vidas, fn(v) { v }))
        case count_vidas > 0 {
          let idx = list.indexed_find(com_vida.vidas, fn(i, v) { v == True })
          case idx {
            Some((_, pos)) -> {
              let novos_vidas = list.update(com_vida.vidas, pos, fn(_) { False })
              Jogador(
                ..com_vida,
                vidas: novos_vidas,
              )
            }
            None -> com_vida
          }
        } else {
          com_vida
        }
      }
      False -> com_vida
    }
  })
  
  // Processa tiros: mover e verificar colisões
  let tiros_restantes = list.map(tiros, fn(tiro) {
    let tiro_movido = mover_tiro(tiro)
    case fora_tela(tiro_movido) {
      True -> #[]  // tiro saiu da tela, some
      False -> {
        // Verificar colisão com objetos
        let #(objs_restantes, _, pts_tiros, pts_inimigos) = processar_colisao_tiro(tiro_movido, objetos)
        #(tiro_movido, objs_restantes)
      }
    }
  })
  
  #(jogadores_atualizados, objetos, tiros_restantes)
}

// ---------------------------------------------------------------------------
// Atualização principal do tick
// ---------------------------------------------------------------------------

pub fn tick(estado: Estado) -> Estado {
  case estado {
    Jogando(jogadores, tique, seed, objetos) -> {
      let jogadores_atualizados = list.map(jogadores, passo)
      
      // Move objetos
      let objetos_mov =
        objetos
        |> list.map(move_objeto)
        |> list.filter(ainda_visivel)
      
      // Gera asteroides e orbes
      let #(objetos_novos, seed) = gera_a_cada(intervalo_ast, tique, seed, objetos_mov, gera_ast)
      let #(objetos_finais, seed) = gera_a_cada(intervalo_spawn, tique, seed, objetos_novos, gera_orb)
      
      // Processa colisões e tiros
      let #(jogadores_processados, objetos_processados, tiros_restantes) = 
        processar_colisoes_tick(jogadores_atualizados, objetos_mov, jogadores_atualizados |> list.map(fn(j) { j.tiros }))
      
      // Atualiza efeitos de orb vermelho
      let jogadores_com_efeito = list.map(jogadores_processados, efeito_orb_vermelho)
      
      let tique = tique + 1
      
      Jogando(jogadores_com_efeito, tique, seed, objetos_finais)
    }
    _ -> estado
  }
}

// ---------------------------------------------------------------------------
// Input handler para atirar (pressionar ESPAÇO)
// ---------------------------------------------------------------------------

fn tecla_tiro(
  estado: Estado,
  player: Player,
  evento: key.Event,
) -> Estado {
  case evento {
    key.Char(" ") -> {
      // Sempre pode atirar (munição infinita)
      let jogador_idx = mworld.player_index(player)
      let novos_jogadores = list.map(estado.jogadores, fn(j) {
        case mworld.player_index(j.jogador) == jogador_idx -> {
          let novos_tiros = j.tiros ++ [criar_tiro(j)]
          Jogador(
            ..j,
            tiros: novos_tiros,
          )
        }
        _ -> j
      })
      // Retorna novo estado (simplificação - precisaria copiar todo o estado)
      estado
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