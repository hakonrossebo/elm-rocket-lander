import Html.App as Html
import Char
import Color
-- import Element exposing (..)
-- import Collage exposing (..)
import Text exposing (..)
import AnimationFrame
import Window
import Keyboard exposing (KeyCode)
import Html exposing (..)
import Html.Attributes exposing (..)
import String
import Time exposing (Time)
import Random
import List
import Key exposing (..)
import Graphics.Render as Render


type alias Radians = Float

type GameState = PreRunning | Running | Won | Lost

type alias KeyArrows = 
  { x: Float
  , y: Bool
  }

type alias Ship =
  { x: Float
  , y: Float
  , vx: Float
  , vy: Float
  , roll: Radians
  , boosting: Bool
  , fuel: Float
  , controls: KeyArrows
  }

type alias Game =
  { gravity: Float
  , ship: Ship
  , state: GameState
  , platformPos: Float
  , height: Int
  , width: Int
  }

makeGame : Game
makeGame = { gravity = 0.000078
           , ship = (Ship 0.9 0.4 0 0 0 False 1000 {x=0, y=False})
           , state = PreRunning
           , platformPos = 0.5
           , height = 440
           , width = 640
           }

speedCutoff : Float
speedCutoff = 0.002

rollCutoff : Float
rollCutoff = 0.19



-------------------------------------------------------------------
main =  
  Html.program
    { init = init
    , update = update
    , view = paint
    , subscriptions = subscriptions
    }
-------------------------------------------------------------------

subscriptions : Game -> Sub Msg
subscriptions model =
    Sub.batch
        [ AnimationFrame.diffs TimeUpdate
        , Keyboard.downs KeyDown
        , Keyboard.ups KeyUp
        , Window.resizes (\{height, width} -> Resize height width)
        ]

init : ( Game, Cmd Msg )
init =
    ( makeGame, Cmd.none )

type Msg
    = TimeUpdate Time
    | KeyDown KeyCode
    | KeyUp KeyCode
    | Resize Int Int

update : Msg -> Game -> ( Game, Cmd Msg )
update msg game =
  case game.state of
    PreRunning -> case msg of
          KeyDown keyCode -> ( keyDownPreRunning keyCode game, Cmd.none )
          Resize h w      -> ({game | height = h, width = w} , Cmd.none)
          _               -> (game, Cmd.none) 
    Running -> case msg of
          TimeUpdate dt   -> ( updateRunning game, Cmd.none )
          KeyDown keyCode -> ( keyDownRunning keyCode game, Cmd.none )
          KeyUp keyCode   -> ( keyUpRunning keyCode game, Cmd.none )            
          Resize h w      -> ({game | height = h, width = w} , Cmd.none)
    Lost -> case msg of
          KeyDown keyCode -> ( keyDownIdle keyCode game, Cmd.none )
          Resize h w      -> ({game | height = h, width = w} , Cmd.none)
          _               -> (game, Cmd.none) 
    Won -> case msg of
          KeyDown keyCode -> ( keyDownIdle keyCode game, Cmd.none )
          Resize h w      -> ({game | height = h, width = w} , Cmd.none)
          _               -> (game, Cmd.none) 



keyDownPreRunning : KeyCode -> Game -> Game
keyDownPreRunning keyCode game =
    case Key.fromCode keyCode of
        Space ->
            { game | state = Running }
        _ ->
            game


keyDownIdle : KeyCode -> Game -> Game
keyDownIdle keyCode game =
    case Key.fromCode keyCode of
        Space ->
            { makeGame | state = Running }
        _ ->
            game

keyDownRunning : KeyCode -> Game -> Game
keyDownRunning keyCode game =
    case Key.fromCode keyCode of
        ArrowLeft ->
            let 
              controls = game.ship.controls
              newControls = {controls | x = -1.0}
              ship = game.ship
              newShip =  {ship | controls = newControls}
            in
              { game | ship = newShip }
        ArrowRight ->
            let 
              controls = game.ship.controls
              newControls = {controls | x = 1.0}
              ship = game.ship
              newShip =  {ship | controls = newControls}
            in
              { game | ship = newShip }
        ArrowUp ->
            let 
              controls = game.ship.controls
              newControls = {controls | y = True}
              ship = game.ship
              newShip =  {ship | controls = newControls}
            in
              { game | ship = newShip }
        _ ->
            game

keyUpRunning : KeyCode -> Game -> Game
keyUpRunning keyCode game =
    case Key.fromCode keyCode of
        ArrowLeft ->
            let 
              controls = game.ship.controls
              newControls = {controls | x = 0.0}
              ship = game.ship
              newShip =  {ship | controls = newControls}
            in
              { game | ship = newShip }
        ArrowRight ->
            let 
              controls = game.ship.controls
              newControls = {controls | x = 0.0}
              ship = game.ship
              newShip =  {ship | controls = newControls}
            in
              { game | ship = newShip }
        ArrowUp ->
            let 
              controls = game.ship.controls
              newControls = {controls | y = False}
              ship = game.ship
              newShip =  {ship | controls = newControls}
            in
              { game | ship = newShip }
        _ ->
            game

updateRunning : Game -> Game
updateRunning game =
  let
    controls = game.ship.controls
    ship = shipUpdate
           game.gravity
           (if game.ship.fuel > 0 then controls.y else False)
           (if game.ship.fuel > 0 then round controls.x else 0)
           game.ship
    (platformPos, landscape) = generateLandscape
  in
    case (isShipAlive (ship.x, ship.y) landscape, isShipLanded ship platformPos) of
      (True, False)  -> {game | ship = ship}
      (True, True)   -> {game | state = Won}
      (False, True)  -> {game | state = Lost}
      (False, False) -> {game | state = Lost}



shipUpdate : Float -> Bool -> Int -> Ship -> Ship
shipUpdate g boosting roll ship =
  let
    accell = { x = if boosting then -3.0 * g * sin(ship.roll) else 0
             , y = if boosting then 3.0 * g * cos(ship.roll) else 0
             }
    fuel' = if boosting then ship.fuel - 3 else ship.fuel
    fuel'' = if abs roll > 0 then fuel' - 1 else fuel'
  in
    { ship | vy = ship.vy + g - accell.y
           , vx = ship.vx - accell.x
           , y = ship.y + ship.vy
           , x = ship.x + ship.vx
           , boosting = boosting
           , fuel = fuel''
           , roll = ship.roll - ( (toFloat roll) / 20.0)
           }

shipSpeed : Ship -> Float
shipSpeed ship = clamp 0.0 1.0 (sqrt (ship.vx * ship.vx + ship.vy * ship.vy))

isShipLanded : Ship -> Float -> Bool
isShipLanded ship platformPos =
  abs ship.y < 0.01
    && abs (ship.x - platformPos) < 0.1
    && shipSpeed ship < speedCutoff
    && abs ship.roll < rollCutoff

{- check whether the ship is below a list of half-planes -}
isShipAlive : (Float, Float) -> List (Float, Float) -> Bool
isShipAlive (sx, sy) landscape =
  let hits = List.foldl (isHit (sx, sy)) (False, (0, 0)) landscape
  in
    fst hits

isHit : (Float, Float) -> (Float, Float) -> (Bool, (Float, Float)) ->  (Bool, (Float, Float))
isHit (shipX, shipY) (newX, newY) (hitSoFar, (prevX, prevY)) =
  let nx = newY - prevY
      ny = prevX - newX  {- normal vector -}
      sx = shipX - prevX
      sy = shipY - prevY  {- urg give me some vector maths .. -}
  in
    {- half plane intersection -}
    (hitSoFar || (nx * sx + ny * sy < 0 && shipX >= prevX && shipX < newX), (newX, newY))

toScreenCoords : (Int, Int) -> (Float, Float) -> (Float, Float)
toScreenCoords (w, h) (x, y)=
  ((x - 0.5) * (toFloat w), (y - 0.5) * (toFloat h))

------------------------------------
-- VIEW
------------------------------------

paint : Game -> Html Msg
paint game =
  let 
    (w', h') = (game.width, game.height)
    (w, h) = (toFloat w', toFloat h')  in
    case game.state of
      PreRunning -> Render.svg w h 
        (Render.group
        [ paintGame game (w', h')
        , Render.move -200 -100 <| Render.html startScreen
        ])
      Running -> Render.svg w h 
        (Render.group
        [ paintGame game (w', h')])
      Lost -> Render.svg w h
        (Render.group
        [ paintGame game (w', h')
        , Render.move -200 -100 <| Render.html lostScreen
        ])
      Won -> Render.svg w h
        (Render.group
        [ paintGame game (w', h')
        , Render.move -200 -100 <| Render.html wonScreen
        ])


paintGame : Game -> (Int, Int) -> Render.Form Msg
paintGame game (w, h) =
  let fw = toFloat w
      fh = toFloat h
  in
  Render.group --w h
  [ Render.solidFill Color.black(Render.rectangle fw fh)
  , paintLandscape generateLandscape (w, h)
  , paintPlatform game.platformPos (w, h)
  , paintShip game.ship (w, h)
  , Render.move 260 -(toFloat h / 2) <| Render.html <| (statsScreen (w, h) game)
  ]

paintShip : Ship -> (Int, Int) -> Render.Form Msg
paintShip ship (w, h) =
  let
    color = Color.rgba 255 0 0 255
    screenCoords = (toScreenCoords (w, h) (ship.x, ship.y))
  in
  Render.rotate (ship.roll) <|
  Render.move 0 -20 <| {- Paint a bit higher so it looks like the ship dies on contact, not when deep in the land -}
  Render.move (fst screenCoords) (snd screenCoords)<|
  Render.solidFill color (Render.polygon [(0, 0), (10, -10), (10, -20), (-10, -20), (-10, -10)])

paintLandscape : (Float, List (Float, Float)) -> (Int, Int) -> Render.Form Msg
paintLandscape (platformPos, heights) (w, h) =
  let closedLoop = heights ++ [(0.0, 1.0), (1.0, 1.0)]
  in
  Render.solidFill (Color.rgba 0 255 0 255)
    (Render.polygon (List.map  (toScreenCoords (w, h)) closedLoop))

paintPlatform : Float -> (Int, Int) -> Render.Form Msg
paintPlatform platformPos (w, h) =
  let 
    xpos = (toFloat w) * (platformPos - 0.5)
    ypos = (toFloat h / 2) - 5
  in
    Render.move xpos ypos <|
    Render.solidFill (Color.rgba 255 0 0 255) (Render.rectangle 80 10)



genericScreen : String -> String -> Html Msg
genericScreen borderColor heading = 
  -- toElement 400 300 <|
  div [ Html.Attributes.style [("background", "#eee")
              , ("box-shadow", "5px 5px 0px 0px #888")
              , ("padding", "10px")
              , ("width", "400px")
              , ("border", "2px solid")
              , ("border-color", borderColor)
              ]]
  [ h2 [Html.Attributes.style [("margin", "0")]] [Html.text heading]
  , p [] [Html.text "Land gently on the red platform before running out of fuel."]
  , p [] [Html.text "Use < and > to roll the ship, ^ to boost."]
  , p [] [Html.text "Press SPACE to start."]
  ]

startScreen = genericScreen "#eee" "Rocket lander in Elm."
lostScreen = genericScreen "#a00" "Ouch!"
wonScreen = genericScreen "#0a0" "Good job, commander."

statsScreen : (Int, Int) -> Game -> Html Msg
statsScreen (w, h) game = 
  let
    speedColor = ("color", if shipSpeed game.ship < speedCutoff then "#0a0" else "#f00")
    rollColor = ("color", if abs(game.ship.roll) < rollCutoff then "#0a0" else "#f00")
  in
  -- container w h topRight <| toElement 200 100 <|
  div [Html.Attributes.style [("font-family", "monospace"), ("color", "#fff")]]
  [ p [] [ Html.text ("Fuel: " ++ toString game.ship.fuel) ]
  , p [Html.Attributes.style [speedColor]] [ Html.text ("Speed: " ++ String.slice 0 6 (toString (shipSpeed game.ship))) ]
  , p [Html.Attributes.style [rollColor]] [ Html.text ("Roll: " ++ String.slice 0 6 (toString (game.ship.roll))) ]
  ]


{- Make a landscape with a platform position and some mountain-looking
   things -}
generateLandscape : (Float, List (Float, Float))
generateLandscape =
  let
    platformIndex = Random.int 0 2
    mainValues = [Random.float 0.1 0.2, Random.float 0.4 0.5, Random.float 0.7 0.9]
  in
   (0.5, [(1.0, 0.8), (0.8, 0.6), (0.7, 0.4), (0.6, 0.9), (0.52, 1.0), (0.5, 1.0), (0.48, 1.0), (0.4, 0.8), (0.2, 0.4), (0.0, 0.3)])
