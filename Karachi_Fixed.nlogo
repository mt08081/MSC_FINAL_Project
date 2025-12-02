extensions [ gis ]

globals [
  pak-dataset
  max-pop
  num-moves
  avg-satisfaction
  segregation-index
]

breed [ households household ]

patches-own [
  town-name
  is-habitable?
]

households-own [
  religion
  language
  is-satisfied?
  satisfaction-score
]

to setup
  clear-all
  load-map
  create-agents
  reset-ticks
end

to load-map
  set pak-dataset gis:load-dataset "karachi_census_merged.shp"
  gis:set-world-envelope gis:envelope-of pak-dataset
  
  let all-pops []
  foreach gis:feature-list-of pak-dataset [ f ->
    let p gis:property-value f "Total_Pop"
    if is-number? p [ set all-pops lput p all-pops ]
  ]
  
  ifelse length all-pops > 0
  [ set max-pop max all-pops + 250000 ]
  [ set max-pop 100000 ]
  
  foreach gis:feature-list-of pak-dataset [ feature ->
    let population gis:property-value feature "Total_Pop"
    
    ifelse is-number? population
    [ gis:set-drawing-color scale-color red population max-pop 0
      gis:fill feature 1 ]
    [ gis:set-drawing-color gray
      gis:fill feature 1 ]
    
    gis:set-drawing-color white
    gis:draw feature 1
  ]
  
  ask patches [
    set is-habitable? false
    set town-name "Unknown"
    
    foreach gis:feature-list-of pak-dataset [ feature ->
      if gis:contains? feature self [
        set is-habitable? true
        set town-name gis:property-value feature "ADM3_EN"
      ]
    ]
  ]
end

to create-agents
  let habitable-patches patches with [ is-habitable? ]
  
  ask n-of num-agents habitable-patches [
    sprout-households 1 [
      set religion one-of [ "Muslim" "Christian" "Hindu" ]
      set language one-of [ "Urdu" "Punjabi" "Sindhi" ]
      set-appearance
      check-satisfaction
    ]
  ]
end

to set-appearance
  if religion = "Muslim" [ set shape "circle" ]
  if religion = "Christian" [ set shape "square" ]
  if religion = "Hindu" [ set shape "triangle" ]
  
  if language = "Urdu" [ set color blue ]
  if language = "Punjabi" [ set color green ]
  if language = "Sindhi" [ set color yellow ]
  
  set size 1.5
end

to go
  if ticks >= 500 [ stop ]
  
  set num-moves 0
  
  ask households [
    check-satisfaction
    if not is-satisfied? [ try-move ]
  ]
  
  calculate-metrics
  tick
  
  if num-moves = 0 and ticks > 20 [ stop ]
end

to check-satisfaction
  let nearby households in-radius 3
  
  ifelse count nearby > 1
  [ let same-religion count nearby with [ religion = [ religion ] of myself ]
    let same-language count nearby with [ language = [ language ] of myself ]
    
    let religion-pct same-religion / count nearby * 100
    let language-pct same-language / count nearby * 100
    
    set satisfaction-score (religion-pct + language-pct) / 2
    set is-satisfied? satisfaction-score >= tolerance-level ]
  [ set satisfaction-score 100
    set is-satisfied? true ]
end

to try-move
  let empty-patches patches with [ is-habitable? and not any? households-here ]
  
  if any? empty-patches [
    let candidates n-of min list 10 count empty-patches empty-patches
    let best-patch max-one-of candidates [ expected-satisfaction-at myself ]
    
    if [ expected-satisfaction-at myself ] of best-patch > satisfaction-score [
      move-to best-patch
      set num-moves num-moves + 1
    ]
  ]
end

to-report expected-satisfaction-at [ hh ]
  let nearby households in-radius 3
  
  if count nearby = 0 [ report 100 ]
  
  let same-religion count nearby with [ religion = [ religion ] of hh ]
  let same-language count nearby with [ language = [ language ] of hh ]
  
  let religion-pct same-religion / count nearby * 100
  let language-pct same-language / count nearby * 100
  
  report (religion-pct + language-pct) / 2
end

to calculate-metrics
  ifelse any? households
  [ set avg-satisfaction mean [ satisfaction-score ] of households ]
  [ set avg-satisfaction 0 ]
  
  calculate-segregation
end

to calculate-segregation
  if not any? households [ 
    set segregation-index 0
    stop 
  ]
  
  let muslims households with [ religion = "Muslim" ]
  let christians households with [ religion = "Christian" ]
  
  if not any? muslims or not any? christians [
    set segregation-index 0
    stop
  ]
  
  let towns remove-duplicates [ town-name ] of patches with [ is-habitable? ]
  let dissim-sum 0
  
  let total-muslims count muslims
  let total-christians count christians
  
  foreach towns [ t ->
    let town-muslims count muslims with [ [ town-name ] of patch-here = t ]
    let town-christians count christians with [ [ town-name ] of patch-here = t ]
    
    let prop-muslim town-muslims / total-muslims
    let prop-christian town-christians / total-christians
    
    set dissim-sum dissim-sum + abs (prop-muslim - prop-christian)
  ]
  
  set segregation-index dissim-sum / 2 * 100
end

to-report percent-satisfied
  ifelse any? households
  [ report count households with [ is-satisfied? ] / count households * 100 ]
  [ report 0 ]
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
15
25
95
58
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
110
25
190
58
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
15
100
190
133
num-agents
num-agents
50
500
200.0
50
1
NIL
HORIZONTAL

SLIDER
15
150
190
183
tolerance-level
tolerance-level
0
100
40.0
10
1
%
HORIZONTAL

SLIDER
15
200
190
233
religion-weight
religion-weight
0
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
15
250
190
283
language-weight
language-weight
0
10
5.0
1
1
NIL
HORIZONTAL

MONITOR
15
310
105
355
% Satisfied
percent-satisfied
1
1
11

MONITOR
110
310
190
355
Avg Score
avg-satisfaction
1
1
11

MONITOR
15
370
105
415
Segregation
segregation-index
1
1
11

MONITOR
110
370
190
415
Moves
num-moves
0
1
11

PLOT
15
440
190
620
Satisfaction
Time
%
0.0
10.0
0.0
100.0
true
false
"" ""
PENS
"satisfied" 1.0 0 -13345367 true "" "plot percent-satisfied"

PLOT
15
640
190
820
Segregation
Time
Index
0.0
10.0
0.0
100.0
true
false
"" ""
PENS
"index" 1.0 0 -2674135 true "" "plot segregation-index"

TEXTBOX
20
850
190
900
SHAPES:\nCircle = Muslim\nSquare = Christian\nTriangle = Hindu
11
0.0
1

TEXTBOX
20
910
190
960
COLORS:\nBlue = Urdu\nGreen = Punjabi\nYellow = Sindhi
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

Simple segregation model for Karachi with religion and language.

## HOW TO USE IT

1. Click SETUP
2. Click GO
3. Watch segregation emerge

## PARAMETERS

- **num-agents**: Number of households (more = slower)
- **tolerance-level**: % similarity needed to be happy
- **religion-weight**: How much religion matters
- **language-weight**: How much language matters
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

circle
false
0
Circle -7500403 true true 0 0 300

square
false
0
Rectangle -7500403 true true 30 30 270 270

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255
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
