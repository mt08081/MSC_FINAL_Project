extensions [ gis ]

globals [
  pak-dataset
  max-pop
  ; added just now
  ; viz-mode       ; "Religion" or "Language"
  ; rel-focus      ; "Muslim", "Hindu", or "Christian"
  ; lang-focus     ; "Urdu", "Sindhi", or "Pashto"

  agent-scale    ; How many people 1 agent equals (e.g., 10000)

  region-names-list ; Store ADM3 region names
]

; added just now
breed [ households household ]

households-own [
  religion       ; "Muslim", "Hindu", "Christian"
  language       ; "Urdu", "Sindhi", "Pashto"
  my-region      ; The name of the region (ADM3) I belong to
]

patches-own [
  p-region-name  ; The region this patch belongs to (for fast lookups)
  is-habitable?  ; True if inside a region
]

;;;;; end new additions

to setup
  ca
  ; 1. Load the dataset
  set pak-dataset gis:load-dataset "karachi_census_merged_fixed.shp"
  gis:set-world-envelope (gis:envelope-of pak-dataset)

  ; 2. Calculate Max Population
  let all-pops []
  foreach gis:feature-list-of pak-dataset [ f ->
    let p gis:property-value f "Total_Pop"
    if is-number? p [ set all-pops lput p all-pops ]
  ]


  ; Damn this took way to long to figure out... Had to try every kind of thing...
  let color-buffer 250000

  ifelse length all-pops > 0
    [
      ; DYNAMIC SCALING FIX
      ; We add a buffer so the largest town isn't rendered as "Black-Red".
      ; Your manual test of 3,000,000 worked well, so we add a solid buffer here.
      set max-pop (max all-pops) + color-buffer
    ]
    [ set max-pop 100000 ]

  ; 3. DRAW THE MAP
  foreach gis:feature-list-of pak-dataset [ feature ->
    let population gis:property-value feature "Total_Pop"

    ; --- STEP A: FILL THE INSIDE ---
    ifelse is-number? population [
      ; Valid Data: Scale from White (0) to Dark Red (max-pop)
      gis:set-drawing-color scale-color red population max-pop 0
      gis:fill feature 255
    ] [
      ; Missing Data: Cyan
      gis:set-drawing-color cyan
      gis:fill feature 255
    ]

    ; --- STEP B: DRAW THE BORDER ---
    ; White borders look much cleaner on the red map
    gis:set-drawing-color white
    gis:draw feature 1
  ]
end

;; Issue: The summation of language OR religion based population is less than the total population of the region
;; The reason for this is that we are not accounting for all the data inside the census data which includes minorities etc

to mouse-click-action
  if mouse-down? [
    let x mouse-xcor
    let y mouse-ycor
    let found-polygon? false

    foreach gis:feature-list-of pak-dataset [ f ->
      ; Check if the feature contains the click point
      if gis:contains? f (patch x y) [
        set found-polygon? true

        let name gis:property-value f "ADM3_EN"
        let total gis:property-value f "Total_Pop"
        let urdu gis:property-value f "Urdu_Pop"
        let sindhi gis:property-value f "Sindhi_Pop"
        let pashto gis:property-value f "Pashto_Pop"
        let muslim gis:property-value f "Muslim_Pop"
        let hindu gis:property-value f "Hindu_Pop"
        let christian gis:property-value f "ChristianP"
        let district gis:property-value f "District"

        ifelse is-number? total [
          ; SUCCESS CLICK
          user-message (word
            "Town: " name "\n"
            "Population: " total "\n"
            "Urdu Speakers: " urdu "\n"
            "Sindhi Speakers: " sindhi "\n"
            "Pashto Speakers: " pashto "\n"
            "Muslims: " muslim "\n"
            "Hindus: " hindu "\n"
            "Christians: " christian "\n"
            "District: " district)
        ] [
          ; EMPTY CLICK (Cyan Area)
          user-message (word
            "Region: " name "\n"
            "Status: Shapefile exists, but Data is Missing.")
        ]

        ; stop ; (Commented out per your preference)
      ]
    ]

    ; VOID CLICK (Black Area)
    if not found-polygon? [
       user-message "Zone: Void / Cantonment (No Shapefile Data)"
    ]

    wait 0.5
  ]
end


;;;;;; New additions (spawning of agents etc)

to mouse-click-action-v2
  if mouse-down? [
    ; Identify where we clicked
    let clicked-patch patch mouse-xcor mouse-ycor

    ifelse [ is-habitable? ] of clicked-patch [
      let r-name [ p-region-name ] of clicked-patch

      ; Count LIVE agents
      let region-agents households with [ my-region = r-name ]
      let total-agents count region-agents

      let msg (word "Region: " r-name "\n"
                    "------------------------\n"
                    "Total Agents: " total-agents "\n"
                    "Est. Population: " (total-agents * agent-scale) "\n"
                    "\n")

      ; Based on Choosers
      if viz-mode = "Religion" [
        let focus-count count region-agents with [ religion = rel-focus ]
        let pct 0
        if total-agents > 0 [ set pct (focus-count / total-agents) * 100 ]

        set msg (word msg
          "VIEW MODE: RELIGION\n"
          "Focus Group: " rel-focus "\n"
          "Group Count: " focus-count " (" (focus-count * agent-scale) ")\n"
          "Regional Share: " precision pct 2 "%"
        )
      ]

      if viz-mode = "Language" [
        let focus-count count region-agents with [ language = lang-focus ]
        let pct 0
        if total-agents > 0 [ set pct (focus-count / total-agents) * 100 ]

        set msg (word msg
          "VIEW MODE: LANGUAGE\n"
          "Focus Group: " lang-focus "\n"
          "Group Count: " focus-count " (" (focus-count * agent-scale) ")\n"
          "Regional Share: " precision pct 2 "%"
        )
      ]

      user-message msg
    ]
    [
      ; Clicked on black/void space
      user-message "Zone: Void / Cantonment (No Data)"
    ]

    wait 0.5
  ]
end

to setup2
  ca
  ; Adjust this: Lower = More agents (Laggy), Higher = Fewer agents (Abstract)
  set agent-scale 5000

  ; Data
  set pak-dataset gis:load-dataset "karachi_census_merged_fixed.shp"
  gis:set-world-envelope (gis:envelope-of pak-dataset)

  ; Map patches to map (region) for household plotting
  print "Mapping patches to regions..."
  map-patches-to-regions

  ; Build the region name list
  set region-names-list remove-duplicates [p-region-name] of patches with [is-habitable?]

  print "Spawning agents..."
  ;spawn-agents
  spawn-agents-v2

  update-visualization
  reset-ticks
end

to go
  ; Simulation runs for 100 years
  if ticks >= 100 [ stop ]

  ; Birth and Death Handling
  vital-dynamics

  ; Migration part (based on tolerance)
  ask households [
    check-happiness-and-move
  ]

  update-visualization
  tick
end

to check-happiness-and-move
  ; --- STEP 1: GATHER DATA ---
  ; Optimization: We filter households ONLY in my region
  let neighbors-in-region households with [ my-region = [my-region] of myself ]
  let total-in-region count neighbors-in-region

  ; Avoid division by zero if region is empty
  if total-in-region = 0 [ stop ]

  ; --- STEP 2: CALCULATE RATIOS ---
  let my-rel-count count neighbors-in-region with [ religion = [religion] of myself ]
  let my-lang-count count neighbors-in-region with [ language = [language] of myself ]

  let rel-percentage (my-rel-count / total-in-region) * 100
  let lang-percentage (my-lang-count / total-in-region) * 100

  ; --- STEP 3: DECIDE ---
  ; We are unhappy if EITHER religion OR language share is below tolerance
  let unhappy-religion? (rel-percentage < religious-tolerance)
  let unhappy-language? (lang-percentage < linguistic-tolerance)

  ; --- STEP 4: ACT ---
  if unhappy-religion? or unhappy-language? [
    relocate
  ]
end

to relocate
  ; Pick a random region that is NOT my current region
  let potential-destinations remove my-region region-names-list

  ; if there are places to go (i.e potential region list isn't empty)
  if not empty? potential-destinations [
    let target-region one-of potential-destinations

    ; Find a habitable spot in that region
    let target-patch one-of patches with [ p-region-name = target-region ]

    if target-patch != nobody [
      move-to target-patch
      set my-region target-region
    ]
  ]
end

to vital-dynamics
  ask households [
    ; DEATH LOGIC
    ; death-rate is per 1000
    if random-float 1.0 < (death-rate / 1000) [
      die
    ]

    ; BIRTH LOGIC
    ; birth-rate is per 1000
    if random-float 1.0 < (birth-rate / 1000) [
      hatch 1 [
        ; hatching copies all properties from parent to child
        set my-region [my-region] of myself
      ]
    ]
  ]
end


to map-patches-to-regions
  ; clear previous state --- Make everything inhabited and nameless regions for replotting and reassigmnent of agents... behaves like clear-all
  ask patches [
    set is-habitable? false
    set p-region-name ""
  ]

  foreach gis:feature-list-of pak-dataset [ f ->
    let region-name gis:property-value f "ADM3_EN"

    ; Asks patches covered by the polygon to identify themselves
    ask patches gis:intersecting f [
      set is-habitable? true
      set p-region-name region-name
    ]
    gis:set-drawing-color white
    gis:draw f 1
  ]
end

to spawn-agents-v2
  foreach gis:feature-list-of pak-dataset [ f ->
    let region-name gis:property-value f "ADM3_EN"
    let total-pop gis:property-value f "Total_Pop"

    if is-number? total-pop [
      let num-agents floor (total-pop / agent-scale)

      ; Calculate Probabilities for this region
      let p-muslim (gis:property-value f "Muslim_Pop") / total-pop
      let p-hindu  (gis:property-value f "Hindu_Pop") / total-pop
      let p-christian (gis:property-value f "ChristianP") / total-pop
      ; Others would be the remainder of the population (can be added in the choices)

      let p-urdu   (gis:property-value f "Urdu_Pop") / total-pop
      let p-sindhi (gis:property-value f "Sindhi_Pop") / total-pop
      let p-pashto (gis:property-value f "Pashto_Pop") / total-pop
      ; Others would be the remainder of the population (can be added in the choices)

      let region-patches patches with [ p-region-name = region-name ]

      ; This is done so that households don't sprout at the edges
      let interior-patches region-patches with [
        count neighbors with [ p-region-name = region-name ] = 8
      ]

      ; If space is full then we need a fallback strat
      let valid-patches interior-patches

      if count valid-patches < num-agents [
        set valid-patches region-patches
      ]

      if any? valid-patches [
        ask n-of (min list num-agents count valid-patches) valid-patches [
           sprout-households 1 [
             set size 1.5
             set my-region region-name
             set shape "circle"

             ; Probabilistic Assignment (based on the data embedded in the shapefile)
             let r-rnd random-float 1.0
             ifelse r-rnd < p-muslim [ set religion "Muslim" ]
             [ ifelse r-rnd < (p-muslim + p-hindu) [ set religion "Hindu" ]
              [ ifelse r-rnd < (p-muslim + p-hindu + p-christian) [ set religion "Christian" ] [ set religion "Other" ] ] ]

             let l-rnd random-float 1.0
             ifelse l-rnd < p-urdu [ set language "Urdu" ]
             [ ifelse l-rnd < (p-urdu + p-sindhi) [ set language "Sindhi" ]
               [ ifelse l-rnd < (p-urdu + p-sindhi + p-pashto) [ set language "Pashto" ] [ set language "Other" ] ]
             ]
           ]
        ]
      ]
    ]
  ]
end

to update-visualization
  ; Agents
  ask households [
    ifelse viz-mode = "Religion" [
      ; In Religion Mode
      ifelse religion = rel-focus
        [ show-turtle set color get-color-for-religion religion ]
        [ hide-turtle ]
    ]
    [
      ; In Language Mode
      ifelse language = lang-focus
        [ show-turtle set color get-color-for-language language ]
        [ hide-turtle ]
    ]
  ]

  ; Map Recoloring
  foreach gis:feature-list-of pak-dataset [ f ->
    let region-name gis:property-value f "ADM3_EN"

    ; Count agents (at any tick)
    let total-here count households with [ my-region = region-name ]

    let focus-count 0
    if viz-mode = "Religion" [
       set focus-count count households with [ my-region = region-name and religion = rel-focus ]
    ]
    if viz-mode = "Language" [
       set focus-count count households with [ my-region = region-name and language = lang-focus ]
    ]

    ; let color-buffer 10

    ifelse total-here > 0 [
      ; let ratio focus-count / ( total-here + color-buffer)
      let ratio focus-count / total-here

      ; Scale White -> Chosen Color
      ;; Christian and Hindu population is very small so we have to use a shifted color-scale ratio for visual enhancement!!!
      ifelse viz-mode = "Religion" and rel-focus != "Muslim" [
        gis:set-drawing-color scale-color red ratio 0.15 0
      ]
      [
        gis:set-drawing-color scale-color red ratio 1 0
      ]

      ; Note: You can change 'red' to a variable base-color if you want different maps for diff choices
      gis:fill f 255
    ] [
      ; Fill empty spaces (insignificant number of a certain population in a region)
      gis:set-drawing-color white
      gis:fill f 255
    ]

    ; Muslim population is extremely dominant... It is necessary to perform this for visual clarity
    ifelse viz-mode = "Religion" and rel-focus = "Muslim" [
      gis:set-drawing-color white
      gis:draw f 1.5
    ]
    [
      ; Boundaries of the regions
      gis:set-drawing-color black
      gis:draw f 1.5
    ]
  ]
end

;; We can edit these colors... we can also keep just one color for all agents regardless of choosen factors so that the visual contrast is right
to-report get-color-for-religion [ r ]
  if r = "Muslim" [ report green ]
  if r = "Hindu" [ report orange ]
  if r = "Christian" [ report blue ]
  ; default case for others
  report grey
end

to-report get-color-for-language [ l ]
  if l = "Urdu" [ report blue ]
  if l = "Sindhi" [ report yellow ]
  if l = "Pashto" [ report red ]
  ; default case for others
  report grey
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
1223
1024
-1
-1
5.0
1
10
1
1
1
0
0
0
1
-100
100
-100
100
0
0
1
ticks
30.0

BUTTON
8
15
133
50
Setup2 (Testing)
setup2
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
1266
80
1369
125
viz-mode
viz-mode
"Religion" "Language"
0

CHOOSER
1269
173
1408
218
rel-focus
rel-focus
"Muslim" "Hindu" "Christian" "Other"
1

CHOOSER
1276
272
1415
317
lang-focus
lang-focus
"Urdu" "Sindhi" "Pashto" "Other"
1

BUTTON
9
76
134
111
Mouse Clicker v2
mouse-click-action-v2
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
140
15
203
48
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
9
145
181
178
religious-tolerance
religious-tolerance
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
9
204
181
237
linguistic-tolerance
linguistic-tolerance
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
8
260
180
293
birth-rate
birth-rate
0
50
27.0
1
1
NIL
HORIZONTAL

SLIDER
8
318
180
351
death-rate
death-rate
0
50
7.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
