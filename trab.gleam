import sgleam/fill
import sgleam/image
import sgleam/mworld

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
  Jogador(
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
  OrbVerde
  OrbVermelho
}

pub type Inimigo {
  Inimigo1(pos: Vetor, recarga: Int, tiros: List(Tiro)),
  Inimigo2(pos: Vetor)
}

pub type Objeto {
  Objeto(tipo: TipoObjeto, pos: Vetor, vel: Vetor)
}

pub type Tiro {
  Tiro(pos: Vetor, vel: Vetor)
}

// Teste ovni


// quadrado do fundo do game teste
image.rectangle(800, 600, fill.black)


// jogador 1 e 2.

image.rectangle(800, 600, fill.black)
|> image.place_image(250, 300, image.triangle(40, fill.blue))
|> image.place_image(550, 300, image.triangle(40, fill.red))

pub fn smain(){
  mworld.create_from()
} 