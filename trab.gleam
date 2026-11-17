import sgleam/fill
import sgleam/image
import sgleam/world
import gleam/int 
import sgleam/key



const largura_tela = 800
const altura_tela = 600
const deslocamento = 5
const q_x = 0
const q_y = -300

pub type Vetor {
  Vetor(x: Float, y: Float)
}

pub type Estado {

  Menu  
  Lobby(jogador1_pronto: Bool, jogador2_pronto: Bool)
  Contagem(segundos: Int)

  Jogando(partida: Partida)
  Pausado(partida: Partida)

  FimDeJogo(pontos_jogador1: Int, pontos_jogador2: Int)
}

pub type Partida {
  Partida(
    jogador1: Jogador,
    jogador2: Jogador,
    objetos: List(Objeto),
    tiros: List(Tiro),
  )
}

pub type Jogador {
  Jogador(x: Int, y: Int, vida: Int, pontos: Int, sob_efeito: Bool)
}


pub type Inimigo {

    
}
pub type TipoObjeto {
 
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
  image.empty_scene(100, 80) |> image.place_image(50, tick, ovni)
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



// jogador 2: setas (a sua move, com cima e baixo)
pub fn move(q: Jogador, tecla: key.Event) -> Jogador {
  case tecla {
    key.ArrowLeft -> Jogador(..q, x: q.x - deslocamento)
    key.ArrowRight -> Jogador(..q, x: q.x + deslocamento)
    key.ArrowUp -> Jogador(..q, y: q.y - deslocamento)
    key.ArrowDown -> Jogador(..q, y: q.y + deslocamento)
    _ -> q
  }
}

// jogador 1: WASD
pub fn move_wasd(q: Jogador, tecla: key.Event) -> Jogador {
  case tecla {
    key.Char("a") | key.Char("A") -> Jogador(..q, x: q.x - deslocamento)
    key.Char("d") | key.Char("D") -> Jogador(..q, x: q.x + deslocamento)
    key.Char("w") | key.Char("W") -> Jogador(..q, y: q.y - deslocamento)
    key.Char("s") | key.Char("S") -> Jogador(..q, y: q.y + deslocamento)
    _ -> q
  }
}

// recebe a Partida inteira, que é o estado do world
pub fn tecla(p: Partida, evento: key.Event) -> Partida {

  Partida(..p,  jogador1: move_wasd(p.jogador1, evento),  jogador2: move(p.jogador2, evento),)

}


/// Estado inicial do Game:

fn inicial() -> Partida {
  Partida(
    jogador1: Jogador(250, 300, 100, 0, False),
    jogador2: Jogador(550, 300, 100, 0, False),
    objetos: [],
    tiros: [],
  )
}

fn desenhar(p: Partida) -> image.Image {

  image.rectangle(largura_tela, altura_tela, fill.black)
  |> image.place_image(p.jogador1.x, p.jogador1.y, image.triangle(40, fill.blue))
  |> image.place_image(
    p.jogador2.x,
    p.jogador2.y,
    image.triangle(40, fill.red),

  )
}