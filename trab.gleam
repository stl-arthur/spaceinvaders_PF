import sgleam/fill
import sgleam/image
import sgleam/world

const largura_tela = 800
const altura_tela = 600
const deslocamento = 5
const q_x = 0
const q_y = -300

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
  image.empty_scene(largura_tela, altura_tela) |> image.place_image(50, tick, ovni)
}

pub fn smain() {
  world.animation(cena_ovni)
}

/// quadrado do fundo do game teste
image.rectangle(800, 600, fill.black)


/// jogador 1 e 2.


image.rectangle(800, 600, fill.black)
|> image.place_image(250, 300, image.triangle(40, fill.blue))
|> image.place_image(550, 300, image.triangle(40, fill.red))