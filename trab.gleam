import sgleam/fill
import sgleam/image
import sgleam/world

const largura_tela = 800
const altura_tela = 600
const deslocamento = 5
const q_x = 400
const q_y = 300

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

// Teste ovni


fn cena_ovni(tick: Int) -> image.Image {
  let ovni =
    image.circle(10, fill.green)
    |> image.overlay(image.rectangle(40, 4, fill.green))
  image.empty_scene(largura_tela, altura_tela) |> image.place_image(50, tick, ovni)
}

pub fn smain() {
  world.animation(cena_ovni)
}

// quadrado do fundo do game teste
image.rectangle(800, 600, fill.black)


// jogador 1 e 2.


image.rectangle(800, 600, fill.black)
|> image.place_image(250, 300, image.triangle(40, fill.blue))
|> image.place_image(550, 300, image.triangle(40, fill.red))