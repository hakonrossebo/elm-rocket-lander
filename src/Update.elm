module Update exposing (..)

import Keyboard exposing (KeyCode)
import Random
import Models exposing (..)
import Messages exposing (..)
import Commands exposing (..)
import Key exposing (..)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model.state of
        PreRunning ->
            case msg of
                KeyDown keyCode ->
                    ( keyDownPreRunning keyCode model, Cmd.none )

                Resize w h ->
                    ( { model | height = h, width = w }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Running ->
            case msg of
                TimeUpdate dt ->
                    ( updateRunning model, Cmd.none )

                KeyDown keyCode ->
                    ( keyDownRunning keyCode model, Cmd.none )

                KeyUp keyCode ->
                    ( keyUpRunning keyCode model, Cmd.none )

                Resize w h ->
                    ( { model | height = h, width = w }, Cmd.none )

                NoOp ->
                    ( model, Cmd.none )

        Lost ->
            case msg of
                KeyDown keyCode ->
                    ( keyDownIdle keyCode model, initialSizeCmd )

                Resize w h ->
                    ( { model | height = h, width = w }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Won ->
            case msg of
                KeyDown keyCode ->
                    ( keyDownIdle keyCode model, initialSizeCmd )

                Resize w h ->
                    ( { model | height = h, width = w }, Cmd.none )

                _ ->
                    ( model, Cmd.none )


keyDownPreRunning : KeyCode -> Model -> Model
keyDownPreRunning keyCode model =
    case Key.fromCode keyCode of
        Space ->
            { model | state = Running }

        _ ->
            model


keyDownIdle : KeyCode -> Model -> Model
keyDownIdle keyCode model =
    case Key.fromCode keyCode of
        Space ->
            { makeGame | state = Running }

        _ ->
            model


keyDownRunning : KeyCode -> Model -> Model
keyDownRunning keyCode model =
    case Key.fromCode keyCode of
        ArrowLeft ->
            let
                controls =
                    model.ship.controls

                newControls =
                    { controls | x = -1.0 }

                ship =
                    model.ship

                newShip =
                    { ship | controls = newControls }
            in
                { model | ship = newShip }

        ArrowRight ->
            let
                controls =
                    model.ship.controls

                newControls =
                    { controls | x = 1.0 }

                ship =
                    model.ship

                newShip =
                    { ship | controls = newControls }
            in
                { model | ship = newShip }

        ArrowUp ->
            let
                controls =
                    model.ship.controls

                newControls =
                    { controls | y = True }

                ship =
                    model.ship

                newShip =
                    { ship | controls = newControls }
            in
                { model | ship = newShip }

        _ ->
            model


keyUpRunning : KeyCode -> Model -> Model
keyUpRunning keyCode model =
    case Key.fromCode keyCode of
        ArrowLeft ->
            let
                controls =
                    model.ship.controls

                newControls =
                    { controls | x = 0.0 }

                ship =
                    model.ship

                newShip =
                    { ship | controls = newControls }
            in
                { model | ship = newShip }

        ArrowRight ->
            let
                controls =
                    model.ship.controls

                newControls =
                    { controls | x = 0.0 }

                ship =
                    model.ship

                newShip =
                    { ship | controls = newControls }
            in
                { model | ship = newShip }

        ArrowUp ->
            let
                controls =
                    model.ship.controls

                newControls =
                    { controls | y = False }

                ship =
                    model.ship

                newShip =
                    { ship | controls = newControls }
            in
                { model | ship = newShip }

        _ ->
            model


updateRunning : Model -> Model
updateRunning model =
    let
        controls =
            model.ship.controls

        ship =
            shipUpdate
                model.gravity
                (if model.ship.fuel > 0 then
                    controls.y
                 else
                    False
                )
                (if model.ship.fuel > 0 then
                    round controls.x
                 else
                    0
                )
                model.ship

        ( platformPos, landscape ) =
            generateLandscape
    in
        case ( isShipAlive ( ship.x, ship.y ) landscape, isShipLanded ship platformPos ) of
            ( True, False ) ->
                { model | ship = ship }

            ( True, True ) ->
                { model | state = Won }

            ( False, True ) ->
                { model | state = Lost }

            ( False, False ) ->
                { model | state = Lost }


shipUpdate : Float -> Bool -> Int -> Ship -> Ship
shipUpdate g boosting roll ship =
    let
        accell =
            { x =
                if boosting then
                    -3.0 * g * sin (ship.roll)
                else
                    0
            , y =
                if boosting then
                    3.0 * g * cos (ship.roll)
                else
                    0
            }

        fuel_ =
            if boosting then
                ship.fuel - 3
            else
                ship.fuel

        fuel__ =
            if abs roll > 0 then
                fuel_ - 1
            else
                fuel_
    in
        { ship
            | vy = ship.vy + g - accell.y
            , vx = ship.vx - accell.x
            , y = ship.y + ship.vy
            , x = ship.x + ship.vx
            , boosting = boosting
            , fuel = fuel__
            , roll = ship.roll + ((toFloat roll) / 20.0)
        }


shipSpeed : Ship -> Float
shipSpeed ship =
    clamp 0.0 1.0 (sqrt (ship.vx * ship.vx + ship.vy * ship.vy))


isShipLanded : Ship -> Float -> Bool
isShipLanded ship platformPos =
    abs ship.y
        > 0.97
        && abs (ship.x - platformPos)
        < 0.1
        && shipSpeed ship
        < speedCutoff
        && abs ship.roll
        < rollCutoff



{- check whether the ship is below a list of half-planes -}
isShipAlive : ( Float, Float ) -> List ( Float, Float ) -> Bool
isShipAlive ( sx, sy ) landscape =
    let
        hits =
            List.foldl (isHit ( sx, sy )) ( False, ( 1, 1 ) ) landscape
    in
        Tuple.first hits


isHit : ( Float, Float ) -> ( Float, Float ) -> ( Bool, ( Float, Float ) ) -> ( Bool, ( Float, Float ) )
isHit ( shipX, shipY ) ( newX, newY ) ( hitSoFar, ( prevX, prevY ) ) =
    let
        nx =
            newY - prevY

        ny =
            prevX - newX

        {- normal vector -}
        sx =
            shipX - prevX

        sy =
            shipY - prevY

        {- urg give me some vector maths .. -}
    in
        {- half plane intersection -}
        ( hitSoFar
            || (nx
                    * sx
                    + ny
                    * sy
                    < 0
                    && shipX
                    < prevX
                    && shipX
                    > newX
               )
        , ( newX, newY )
        )


toScreenCoords : ( Int, Int ) -> ( Float, Float ) -> ( Float, Float )
toScreenCoords ( w, h ) ( x, y ) =
    ( (x ) * (toFloat w), (y ) * (toFloat h) )



{- Make a landscape with a platform position and some mountain-looking
   things
-}
generateLandscape : ( Float, List ( Float, Float ) )
generateLandscape =
    let
        platformIndex =
            Random.int 0 2

        mainValues =
            [ Random.float 0.1 0.2, Random.float 0.4 0.5, Random.float 0.7 0.9 ]
    in
        ( 0.5
        , [ ( 1.0, 0.8 )
          , ( 0.8, 0.6 )
          , ( 0.7, 0.4 )
          , ( 0.6, 0.9 )
          , ( 0.52, 1.0 )
          , ( 0.5, 1.0 )
          , ( 0.48, 1.0 )
          , ( 0.4, 0.8 )
          , ( 0.2, 0.4 )
          , ( 0.0, 0.3 )
          ]
        )
