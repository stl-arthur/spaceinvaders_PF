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

const margem_da_nave = 20.0
const velocidade_jogador = 5
const posicao_inicial_x = 400
const posicao_inicial_y = 300
const fator_diagonal = 0.7
const opacidade_do_oponente = 0.35
const raio_jogador = 16.0
const vidas_iniciais = [True, True, True]

const raio_tiro = 4
const velocidade_tiro = 10.0
const intervalo_tiro = 8

const pontos_asteroide = 50
const pontos_asteroide_reduzido = 25
const pontos_inimigo = 100
const duracao_efeito = 840

const y_de_nascimento = -10.0

const intervalo_orb = 420
const margem_orb = 20
const raio_orb = 10
const velocidade_orb = 2.0

const intervalo_asteroide = 14
const margem_asteroide = 20
const velocidade_asteroide = 7
const largura_geodo = 20
const altura_geodo = 20
const largura_destroco = 18
const altura_destroco = 18

const margem_hud = 10
const tamanho_texto = 16
const raio_vida = 7

pub type Vetor {
  Vetor(x: Float, y: Float)
}

pub type Estado {
  Lobby(jogadores: List(Player), segundos: Option(Int))
  Jogando(
    jogadores: List(Jogador),
    tique: Int,
    seed: Int,
    objetos: List(Objeto),
  )
  FimDeJogo(status: List(Jogador))
}

pub type Entrada {
  Entrada(cima: Bool, baixo: Bool, esquerda: Bool, direita: Bool, atirar: Bool)
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
    entrada: Entrada,
    angulo: Int,
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

fn novo_jogador(participante: Player) -> Jogador {
  Jogador(
    jogador: participante,
    pos: Vetor(int.to_float(posicao_inicial_x), int.to_float(posicao_inicial_y)),
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

fn inicial(participantes: List(Player)) -> Estado {
  Jogando(
    jogadores: list.map(participantes, novo_jogador),
    tique: 0,
    seed: 12_345,
    objetos: [],
  )
}

fn proximo_numero(semente: Int) -> Int {
  { semente * 16_807 } % 2_147_483_647
}

fn gera_a_cada(
  intervalo: Int,
  tique: Int,
  semente: Int,
  objetos: List(Objeto),
  gera_objeto: fn(Int) -> #(Objeto, Int),
) -> #(List(Objeto), Int) {
  case tique % intervalo == 0 {
    True -> {
      let #(novo_objeto, nova_semente) = gera_objeto(semente)
      #([novo_objeto, ..objetos], nova_semente)
    }
    False -> #(objetos, semente)
  }
}

fn gera_orb(semente: Int) -> #(Objeto, Int) {
  let sorteio_x = proximo_numero(semente)
  let sorteio_tipo = proximo_numero(sorteio_x)
  let x = margem_orb + sorteio_x % { largura_tela - 2 * margem_orb }
  let tipo = case sorteio_tipo % 2 {
    0 -> OrbVerde
    _ -> OrbVermelho
  }
  let posicao = Vetor(int.to_float(x), y_de_nascimento)
  let velocidade = Vetor(0.0, velocidade_orb)
  #(Objeto(tipo, posicao, velocidade), sorteio_tipo)
}

fn gera_asteroide(semente: Int) -> #(Objeto, Int) {
  let sorteio_x = proximo_numero(semente)
  let sorteio_tipo = proximo_numero(sorteio_x)
  let x = margem_asteroide + sorteio_x % { largura_tela - 2 * margem_asteroide }
  let tipo = case sorteio_tipo % 2 {
    0 -> Geodo
    _ -> Destroco
  }
  let posicao = Vetor(int.to_float(x), y_de_nascimento)
  let velocidade = Vetor(0.0, int.to_float(velocidade_asteroide))
  #(Objeto(tipo, posicao, velocidade), sorteio_tipo)
}

fn move_objeto(objeto: Objeto) -> Objeto {
  let novo_x = objeto.pos.x +. objeto.vel.x
  let novo_y = objeto.pos.y +. objeto.vel.y
  Objeto(..objeto, pos: Vetor(novo_x, novo_y))
}

fn ainda_visivel(objeto: Objeto) -> Bool {
  let altura_do_objeto = case objeto.tipo {
    Geodo -> altura_geodo
    Destroco -> altura_destroco
    _ -> raio_orb
  }
  objeto.pos.y <. int.to_float(altura_tela + altura_do_objeto)
}

fn espaco_entre_vidas() -> image.Image {
  image.rectangle(4, 1, fill.none)
}

fn imagem_vida(vida_disponivel: Bool) -> image.Image {
  case vida_disponivel {
    True -> image.circle(raio_vida, fill.green)
    False -> image.circle(raio_vida, fill.dimgray)
  }
}

fn imagem_vidas(vidas: List(Bool)) -> image.Image {
  let comeco = image.rectangle(1, 1, fill.none)
  list.fold(vidas, comeco, fn(imagem_ate_agora, vida_disponivel) {
    imagem_ate_agora
    |> image.beside(espaco_entre_vidas())
    |> image.beside(imagem_vida(vida_disponivel))
  })
}

fn texto_branco(conteudo: String) -> image.Image {
  image.text(conteudo, tamanho_texto, fill.white)
}

fn imagem_hud(jogador: Jogador) -> image.Image {
  let apelido = texto_branco(mworld.player_nickname(jogador.jogador))
  let pontos = texto_branco("Pontos: " <> int.to_string(jogador.pontos))
  apelido
  |> image.above_align(xplace.Left, pontos)
  |> image.above_align(xplace.Left, imagem_vidas(jogador.vidas))
}

fn posiciona_hud(
  cena: image.Image,
  hud: image.Image,
  numero_do_jogador: Int,
) -> image.Image {
  let topo = int.to_float(margem_hud)
  case numero_do_jogador {
    1 ->
      image.place_image_alignf(cena, topo, topo, xplace.Left, yplace.Top, hud)
    _ -> {
      let direita = int.to_float(largura_tela - margem_hud)
      image.place_image_alignf(
        cena,
        direita,
        topo,
        xplace.Right,
        yplace.Top,
        hud,
      )
    }
  }
}

fn com_hud(cena: image.Image, jogadores: List(Jogador)) -> image.Image {
  list.fold(jogadores, cena, fn(cena_ate_agora, jogador) {
    let numero_do_jogador = mworld.player_index(jogador.jogador)
    posiciona_hud(cena_ate_agora, imagem_hud(jogador), numero_do_jogador)
  })
}

fn nome_do_participante(participante: Player) -> String {
  case mworld.player_nickname(participante) {
    "" -> "Jogador " <> int.to_string(mworld.player_index(participante))
    apelido -> apelido
  }
}

fn fundo() -> image.Image {
  image.rectangle(largura_tela, altura_tela, fill.black)
}

fn triangulo(participante: Player, opacidade: Float) -> image.Image {
  let cor = case mworld.player_index(participante) {
    1 -> fill.blue
    _ -> fill.red
  }
  image.triangle(40, style.join([cor, fill.opacityf(opacidade)]))
}

fn imagem_da_nave(jogador: Jogador, opacidade: Float) -> image.Image {
  image.rotate(triangulo(jogador.jogador, opacidade), jogador.angulo)
}

fn pertence_a(jogador: Jogador, participante: Player) -> Bool {
  mworld.player_index(jogador.jogador) == mworld.player_index(participante)
}

fn imagem_objeto(objeto: Objeto) -> image.Image {
  case objeto.tipo {
    OrbVerde -> image.circle(raio_orb, fill.green)
    OrbVermelho -> image.circle(raio_orb, fill.red)
    Geodo -> image.rectangle(largura_geodo, altura_geodo, fill.brown)
    Destroco -> image.rectangle(largura_destroco, altura_destroco, fill.grey)
    Inimigo -> image.rectangle(30, 20, fill.red)
  }
}

fn com_objetos(cena: image.Image, objetos: List(Objeto)) -> image.Image {
  list.fold(objetos, cena, fn(cena_ate_agora, objeto) {
    image.place_imagef(cena_ate_agora, objeto.pos.x, objeto.pos.y, imagem_objeto(objeto))
  })
}

fn imagem_tiro(participante: Player) -> image.Image {
  case mworld.player_index(participante) {
    1 -> image.circle(raio_tiro, fill.blue)
    _ -> image.circle(raio_tiro, fill.red)
  }
}

fn com_tiros(cena: image.Image, jogadores: List(Jogador)) -> image.Image {
  list.fold(jogadores, cena, fn(cena_ate_agora, jogador) {
    list.fold(jogador.tiros, cena_ate_agora, fn(cena_com_tiros, tiro) {
      let imagem = imagem_tiro(jogador.jogador)
      image.place_imagef(cena_com_tiros, tiro.pos.x, tiro.pos.y, imagem)
    })
  })
}

fn desenha_nave(
  cena: image.Image,
  jogador: Jogador,
  opacidade: Float,
) -> image.Image {
  let nave = imagem_da_nave(jogador, opacidade)
  image.place_imagef(cena, jogador.pos.x, jogador.pos.y, nave)
}

fn com_aviso_de_morte(
  cena: image.Image,
  jogadores: List(Jogador),
  participante: Player,
) -> image.Image {
  let esta_morto =
    list.any(jogadores, fn(jogador) {
      pertence_a(jogador, participante) && !esta_vivo(jogador)
    })
  case esta_morto {
    True -> {
      let aviso =
        image.text("Você morreu", 36, fill.white)
        |> image.above(texto_branco("Aguardando o outro jogador terminar..."))
      let centro_x = int.to_float(largura_tela) /. 2.0
      let centro_y = int.to_float(altura_tela) /. 2.0
      image.place_imagef(cena, centro_x, centro_y, aviso)
    }
    False -> cena
  }
}

fn linha_do_placar(jogador: Jogador) -> image.Image {
  let nome = nome_do_participante(jogador.jogador)
  texto_branco(nome <> ": " <> int.to_string(jogador.pontos) <> " pontos")
}

fn tela_fim(jogadores: List(Jogador)) -> image.Image {
  let linhas = list.map(jogadores, linha_do_placar)
  let placar = list.fold(linhas, image.empty, image.above)
  let conteudo = image.text("Fim de jogo", 40, fill.white) |> image.above(placar)
  let centro_x = int.to_float(largura_tela) /. 2.0
  let centro_y = int.to_float(altura_tela) /. 2.0
  image.place_imagef(fundo(), centro_x, centro_y, conteudo)
}

pub fn desenhar(estado: Estado, participante: Player) -> image.Image {
  case estado {
    Jogando(jogadores, _, _, objetos) -> {
      let jogador_local =
        list.filter(jogadores, fn(jogador) { pertence_a(jogador, participante) })
      let jogadores_oponentes =
        list.filter(jogadores, fn(jogador) { !pertence_a(jogador, participante) })

      let cena_com_objetos_e_tiros =
        com_tiros(com_objetos(fundo(), objetos), jogadores)
      let cena_com_oponentes =
        list.fold(
          jogadores_oponentes,
          cena_com_objetos_e_tiros,
          fn(cena, oponente) {
            desenha_nave(cena, oponente, opacidade_do_oponente)
          },
        )

      list.fold(jogador_local, cena_com_oponentes, fn(cena, jogador) {
        desenha_nave(cena, jogador, 1.0)
      })
      |> com_hud(jogadores)
      |> com_aviso_de_morte(jogadores, participante)
    }
    FimDeJogo(jogadores) -> tela_fim(jogadores)
    _ -> fundo()
  }
}

fn atualiza_entrada(
  teclas: Entrada,
  numero_do_jogador: Int,
  tecla: key.Event,
  apertada: Bool,
) -> Entrada {
  case #(numero_do_jogador, tecla) {
    #(1, key.Char("w")) | #(1, key.Char("W")) -> Entrada(..teclas, cima: apertada)
    #(1, key.Char("s")) | #(1, key.Char("S")) -> Entrada(..teclas, baixo: apertada)
    #(1, key.Char("a")) | #(1, key.Char("A")) -> Entrada(..teclas, esquerda: apertada)
    #(1, key.Char("d")) | #(1, key.Char("D")) -> Entrada(..teclas, direita: apertada)
    #(1, key.Char(" ")) -> Entrada(..teclas, atirar: apertada)
    #(2, key.Char("w")) | #(2, key.Char("W")) -> Entrada(..teclas, cima: apertada)
    #(2, key.Char("s")) | #(2, key.Char("S")) -> Entrada(..teclas, baixo: apertada)
    #(2, key.Char("a")) | #(2, key.Char("A")) -> Entrada(..teclas, esquerda: apertada)
    #(2, key.Char("d")) | #(2, key.Char("D")) -> Entrada(..teclas, direita: apertada)
    #(2, key.Char(" ")) -> Entrada(..teclas, atirar: apertada)
    _ -> teclas
  }
}

fn registra_tecla(
  estado: Estado,
  participante: Player,
  tecla: key.Event,
  apertada: Bool,
) -> Estado {
  case estado {
    Jogando(jogadores, tique, semente, objetos) -> {
      let numero_do_jogador = mworld.player_index(participante)
      let jogadores_atualizados =
        list.map(jogadores, fn(jogador) {
          case pertence_a(jogador, participante) {
            True -> {
              let teclas =
                atualiza_entrada(jogador.entrada, numero_do_jogador, tecla, apertada)
              Jogador(..jogador, entrada: teclas)
            }
            False -> jogador
          }
        })
      Jogando(jogadores_atualizados, tique, semente, objetos)
    }
    _ -> estado
  }
}

pub fn tecla_pressionada(
  estado: Estado,
  participante: Player,
  tecla: key.Event,
) -> Estado {
  registra_tecla(estado, participante, tecla, True)
}

pub fn tecla_solta(
  estado: Estado,
  participante: Player,
  tecla: key.Event,
) -> Estado {
  registra_tecla(estado, participante, tecla, False)
}

pub fn limita_entre(valor: Float, minimo: Float, maximo: Float) -> Float {
  float.max(minimo, float.min(valor, maximo))
}

fn sentido_do_eixo(tecla_para_menos: Bool, tecla_para_mais: Bool) -> Int {
  case tecla_para_menos, tecla_para_mais {
    True, False -> -1
    False, True -> 1
    _, _ -> 0
  }
}

fn angulo_da_direcao(sentido_x: Int, sentido_y: Int) -> Int {
  case sentido_x, sentido_y {
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

fn move_jogador(jogador: Jogador) -> Jogador {
  let teclas = jogador.entrada
  let sentido_x = sentido_do_eixo(teclas.esquerda, teclas.direita)
  let sentido_y = sentido_do_eixo(teclas.cima, teclas.baixo)
  let esta_parado = sentido_x == 0 && sentido_y == 0

  case esta_parado {
    True -> jogador
    False -> {
      let velocidade_base = int.to_float(velocidade_jogador)
      let velocidade = case sentido_x != 0 && sentido_y != 0 {
        True -> velocidade_base *. fator_diagonal
        False -> velocidade_base
      }
      let novo_x = jogador.pos.x +. int.to_float(sentido_x) *. velocidade
      let novo_y = jogador.pos.y +. int.to_float(sentido_y) *. velocidade

      let x_maximo = int.to_float(largura_tela) -. margem_da_nave
      let y_maximo = int.to_float(altura_tela) -. margem_da_nave
      let x_final = limita_entre(novo_x, margem_da_nave, x_maximo)
      let y_final = limita_entre(novo_y, margem_da_nave, y_maximo)

      Jogador(
        ..jogador,
        pos: Vetor(x_final, y_final),
        angulo: angulo_da_direcao(sentido_x, sentido_y),
      )
    }
  }
}

fn move_se_estiver_vivo(jogador: Jogador) -> Jogador {
  case esta_vivo(jogador) {
    False -> jogador
    True -> move_jogador(jogador)
  }
}

fn esta_vivo(jogador: Jogador) -> Bool {
  list.contains(jogador.vidas, True)
}

fn troca_primeiro(
  lista: List(Bool),
  valor_antigo: Bool,
  valor_novo: Bool,
) -> List(Bool) {
  case lista {
    [] -> []
    [primeiro, ..resto] if primeiro == valor_antigo -> [valor_novo, ..resto]
    [primeiro, ..resto] -> [
      primeiro,
      ..troca_primeiro(resto, valor_antigo, valor_novo)
    ]
  }
}

pub fn perde_vida(jogador: Jogador) -> Jogador {
  let vidas =
    jogador.vidas
    |> list.reverse
    |> troca_primeiro(True, False)
    |> list.reverse
  Jogador(..jogador, vidas: vidas)
}

pub fn ganha_vida(jogador: Jogador) -> Jogador {
  Jogador(..jogador, vidas: troca_primeiro(jogador.vidas, False, True))
}

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

fn novo_tiro(jogador: Jogador) -> Tiro {
  let #(sentido_x, sentido_y) = direcao_do_angulo(jogador.angulo)
  let fator_da_direcao = case sentido_x != 0 && sentido_y != 0 {
    True -> fator_diagonal
    False -> 1.0
  }
  let direcao_x = int.to_float(sentido_x) *. fator_da_direcao
  let direcao_y = int.to_float(sentido_y) *. fator_da_direcao

  let x_da_ponta = jogador.pos.x +. direcao_x *. raio_jogador
  let y_da_ponta = jogador.pos.y +. direcao_y *. raio_jogador
  let velocidade =
    Vetor(direcao_x *. velocidade_tiro, direcao_y *. velocidade_tiro)

  Tiro(pos: Vetor(x_da_ponta, y_da_ponta), vel: velocidade)
}

fn move_tiro(tiro: Tiro) -> Tiro {
  let novo_x = tiro.pos.x +. tiro.vel.x
  let novo_y = tiro.pos.y +. tiro.vel.y
  Tiro(..tiro, pos: Vetor(novo_x, novo_y))
}

fn dentro_da_tela(tiro: Tiro) -> Bool {
  let x_valido = tiro.pos.x >=. 0.0 && tiro.pos.x <=. int.to_float(largura_tela)
  let y_valido = tiro.pos.y >=. 0.0 && tiro.pos.y <=. int.to_float(altura_tela)
  x_valido && y_valido
}

fn avanca_tiros_e_atira(jogador: Jogador) -> Jogador {
  let tiros_avancados =
    jogador.tiros
    |> list.map(move_tiro)
    |> list.filter(dentro_da_tela)
  let pode_atirar = jogador.entrada.atirar && jogador.recarga == 0

  case pode_atirar {
    True ->
      Jogador(
        ..jogador,
        tiros: [novo_tiro(jogador), ..tiros_avancados],
        recarga: intervalo_tiro,
      )
    False ->
      Jogador(
        ..jogador,
        tiros: tiros_avancados,
        recarga: int.max(0, jogador.recarga - 1),
      )
  }
}

fn atualiza_tiros_se_vivo(jogador: Jogador) -> Jogador {
  case esta_vivo(jogador) {
    False -> Jogador(..jogador, tiros: [])
    True -> avanca_tiros_e_atira(jogador)
  }
}

fn diminui_efeito(jogador: Jogador) -> Jogador {
  Jogador(..jogador, efeito: int.max(0, jogador.efeito - 1))
}

fn colide(
  centro_a: Vetor,
  raio_a: Float,
  centro_b: Vetor,
  raio_b: Float,
) -> Bool {
  let diferenca_x = centro_a.x -. centro_b.x
  let diferenca_y = centro_a.y -. centro_b.y
  let soma_dos_raios = raio_a +. raio_b
  let distancia_ao_quadrado =
    diferenca_x *. diferenca_x +. diferenca_y *. diferenca_y
  distancia_ao_quadrado <=. soma_dos_raios *. soma_dos_raios
}

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

fn sao_jogadores_diferentes(jogador_a: Jogador, jogador_b: Jogador) -> Bool {
  mworld.player_index(jogador_a.jogador) != mworld.player_index(jogador_b.jogador)
}

fn efeito_do_contato(jogador: Jogador, tipo: TipoObjeto) -> Jogador {
  case tipo {
    OrbVerde -> ganha_vida(jogador)
    OrbVermelho -> Jogador(..jogador, efeito: duracao_efeito)
    Geodo | Destroco | Inimigo -> perde_vida(jogador)
  }
}

fn jogador_contra_objetos(
  jogador: Jogador,
  objetos: List(Objeto),
) -> #(Jogador, List(Objeto)) {
  case esta_vivo(jogador) {
    False -> #(jogador, objetos)
    True -> {
      let #(jogador_final, objetos_que_ficam_ao_contrario) =
        list.fold(objetos, #(jogador, []), fn(situacao, objeto) {
          let #(jogador_atual, objetos_que_ficam) = situacao
          let encostou =
            colide(
              jogador_atual.pos,
              raio_jogador,
              objeto.pos,
              raio_objeto(objeto.tipo),
            )
          case encostou {
            True -> #(
              efeito_do_contato(jogador_atual, objeto.tipo),
              objetos_que_ficam,
            )
            False -> #(jogador_atual, [objeto, ..objetos_que_ficam])
          }
        })
      #(jogador_final, list.reverse(objetos_que_ficam_ao_contrario))
    }
  }
}

fn colisoes_jogadores(
  jogadores: List(Jogador),
  objetos: List(Objeto),
) -> #(List(Jogador), List(Objeto)) {
  let #(processados_ao_contrario, objetos_que_sobraram) =
    list.fold(jogadores, #([], objetos), fn(situacao, jogador) {
      let #(processados, objetos_atuais) = situacao
      let #(jogador_depois, objetos_depois) =
        jogador_contra_objetos(jogador, objetos_atuais)
      #([jogador_depois, ..processados], objetos_depois)
    })
  #(list.reverse(processados_ao_contrario), objetos_que_sobraram)
}

fn tiro_contra_objetos(
  tiro: Tiro,
  objetos: List(Objeto),
) -> #(Result(Objeto, Nil), List(Objeto)) {
  case objetos {
    [] -> #(Error(Nil), [])
    [objeto, ..demais] -> {
      let encostou =
        colide(tiro.pos, raio_do_tiro(), objeto.pos, raio_objeto(objeto.tipo))
      case encostou {
        True -> #(Ok(objeto), demais)
        False -> {
          let #(atingido, demais_sem_o_atingido) =
            tiro_contra_objetos(tiro, demais)
          #(atingido, [objeto, ..demais_sem_o_atingido])
        }
      }
    }
  }
}

fn pontos_do_asteroide(pontuacao_reduzida: Bool) -> Int {
  case pontuacao_reduzida {
    True -> pontos_asteroide_reduzido
    False -> pontos_asteroide
  }
}

fn tiros_do_jogador(
  jogador: Jogador,
  jogadores: List(Jogador),
  objetos: List(Objeto),
) -> #(Jogador, List(Objeto)) {
  let pontuacao_reduzida =
    list.any(jogadores, fn(outro) {
      sao_jogadores_diferentes(outro, jogador) && outro.efeito > 0
    })

  let #(tiros_que_continuam_ao_contrario, objetos_depois, pontos_ganhos) =
    list.fold(jogador.tiros, #([], objetos, 0), fn(situacao, tiro) {
      let #(continuam, objetos_atuais, pontos) = situacao
      case tiro_contra_objetos(tiro, objetos_atuais) {
        #(Ok(objeto), objetos_sem_o_atingido) ->
          case objeto.tipo {
            OrbVerde | OrbVermelho -> #(continuam, objetos_atuais, pontos)
            Inimigo -> #(
              continuam,
              objetos_sem_o_atingido,
              pontos + pontos_inimigo,
            )
            Geodo | Destroco -> #(
              continuam,
              objetos_sem_o_atingido,
              pontos + pontos_do_asteroide(pontuacao_reduzida),
            )
          }
        #(Error(_), _) -> {
          let acertou_outro_jogador =
            list.any(jogadores, fn(outro) {
              sao_jogadores_diferentes(outro, jogador)
              && esta_vivo(outro)
              && colide(tiro.pos, raio_do_tiro(), outro.pos, raio_jogador)
            })
          case acertou_outro_jogador {
            True -> #(continuam, objetos_atuais, pontos)
            False -> #([tiro, ..continuam], objetos_atuais, pontos)
          }
        }
      }
    })

  let jogador_atualizado =
    Jogador(
      ..jogador,
      tiros: list.reverse(tiros_que_continuam_ao_contrario),
      pontos: jogador.pontos + pontos_ganhos,
    )
  #(jogador_atualizado, objetos_depois)
}

fn colisoes_tiros(
  jogadores: List(Jogador),
  objetos: List(Objeto),
) -> #(List(Jogador), List(Objeto)) {
  let #(processados_ao_contrario, objetos_que_sobraram) =
    list.fold(jogadores, #([], objetos), fn(situacao, jogador) {
      let #(processados, objetos_atuais) = situacao
      let #(jogador_depois, objetos_depois) =
        tiros_do_jogador(jogador, jogadores, objetos_atuais)
      #([jogador_depois, ..processados], objetos_depois)
    })
  #(list.reverse(processados_ao_contrario), objetos_que_sobraram)
}

pub fn tick(estado: Estado) -> Estado {
  case estado {
    Jogando(jogadores, tique, semente, objetos) -> {
      let jogadores =
        jogadores
        |> list.map(move_se_estiver_vivo)
        |> list.map(atualiza_tiros_se_vivo)
        |> list.map(diminui_efeito)

      let objetos_na_tela =
        objetos
        |> list.map(move_objeto)
        |> list.filter(ainda_visivel)

      let #(jogadores, objetos_na_tela) =
        colisoes_tiros(jogadores, objetos_na_tela)
      let #(jogadores, objetos_na_tela) =
        colisoes_jogadores(jogadores, objetos_na_tela)

      let #(com_asteroide, semente) =
        gera_a_cada(
          intervalo_asteroide,
          tique,
          semente,
          objetos_na_tela,
          gera_asteroide,
        )
      let #(objetos_finais, semente) =
        gera_a_cada(intervalo_orb, tique, semente, com_asteroide, gera_orb)

      case list.any(jogadores, esta_vivo) {
        True -> Jogando(jogadores, tique + 1, semente, objetos_finais)
        False -> FimDeJogo(jogadores)
      }
    }
    _ -> estado
  }
}

pub fn smain() {
  mworld.create_from(
    fn(_, participantes) { inicial(participantes) },
    min: 2,
    max: 2,
    to_image: desenhar,
  )
  |> mworld.on_key_down(tecla_pressionada)
  |> mworld.on_key_up(tecla_solta)
  |> mworld.on_tick(tick)
}