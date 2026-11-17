import sgleam/fill
import sgleam/image
import sgleam/world

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
  image.empty_scene(800, 600) |> image.place_image(50, tick, ovni)
}

pub fn smain() {
  world.animation(cena_ovni)
}
