;; This is version 7.001 of the opioid treatment model for ... county in LA
extensions [ csv nw py rnd gis profiler]

breed [ people person]
breed [ EMS Emergency-service]
breed [ Police police-officer ]
breed [ care-centers care-center]
breed [ narcan-distributors narcan-distributor]
breed [ crosses cross ]

people-own [
  ;; Demographics
  age                              ; the age of the individual in years
  race                             ; the race of the individual, categorical it will either be ( )
  gender                           ; a indicator if the gender of the individual
  region                         ; indicator of the region one lives in
  isolated-user?
  within-narcan-range?
  narcan-kits
  residence-location
  homeless?
  use-partner
  used-today?
]

EMS-own[
  ;; treatment classification characteristics
  Base-location
  region
  narcan-kits
]

Police-own[
 Base-location
 region
 narcan-kits
 narcan-carrier?
]

patches-own[
 narcan
 patch-region
]

narcan-distributors-own [
  supply
]

globals[
  county-border
  rescue-counter
  narcan-by-police
  narcan-by-EMS
  narcan-by-friend
  OD-count
  OD-death-counter
  max-narcan

  care-locations
  narcan-locations
  total-narcan-available
  cors
  region-polygons
  pop-data
]


;;;;;;;;;;;;;;;;;;;;;;;;;
; 0 setup procedures
;;;;;;;;;;;;;;;;;;;;;;;;;

; 0.0 set up the model

to setup
  clear-all
  reset-ticks
  import-drawing "Pinellas_Opioid_Setup/local_image.jpg"
  setup-map
  setup-population
  setup-EMS
  setup-police
  distribute-narcan
end

; 0.1 setup the spacial environment
to setup-map
  set region-polygons []
  read-data
  read-patch-regions
  set cors find-corners
  if show-boundaries? [draw-boundaries]
  place-care-centers
  place-narcan-providers
end

;0.1.1
to read-data
  read-care-locations
  read-narcan-locations
  read-region-boundaries
  read-population-data
end

;0.1.1.1
to read-care-locations
  file-open "Pinellas_Opioid_Setup/care_providers/List_of_care_providers_PinellasCounty.csv"
  set care-locations []
  let row file-read-line
  while [not file-at-end?][
    set row csv:from-row file-read-line
    set care-locations  lput (map [i -> item i row] range 15) care-locations
  ]
  file-close-all
end

to read-narcan-locations
  file-open "Pinellas_Opioid_Setup/NarcanProviders.csv"
  set narcan-locations []
  let row file-read-line
  while [not file-at-end?][
    set row csv:from-row file-read-line
    set narcan-locations  lput (map [i -> item i row] range 4) narcan-locations
  ]
  file-close-all
end


;0.1.1.2
to read-region-boundaries
  let region-files ["pinellas" "clearwater" "largo" "stpetersburg"]
  if boundaries = "county" [set region-files (list item 0 region-files)]
  foreach region-files [ reg ->
    file-open (word "Pinellas_Opioid_Setup/polygons/" reg "Poly.txt")
    let row ""
    let poly []
    while [not file-at-end?][
      set row (csv:from-row file-read-line "	")
      set poly lput (map [i -> item i row] [2 1]) poly
    ]
    set region-polygons lput poly region-polygons
  ]
end

;0.1.1.2
to read-population-data
  set pop-data []
  file-open "Pinellas_Opioid_Setup/pinellas_pop_data.csv"
  let header file-read-line                                                                        ;; take the first row in the file (consisting of headers) and store it
  while [not file-at-end?][                                                                        ;; for all consequative (so skipping the first line) row read in the data from the file in the prespecified variable
    set pop-data lput (csv:from-row file-read-line " ") pop-data
  ]
  file-close-all
end

;0.1.2
to read-patch-regions
  file-open "Pinellas_Opioid_Setup/patch-region-file.csv"
  while [not file-at-end?][
    let row csv:from-row file-read-line
    ask patch (item 0 row) (item 1 row) [set patch-region (item 2 row)]
  ]
  file-close-all
end

;0.1.3
to-report find-corners
  let longs map [i -> item 0 i] care-locations
  let lats  map [i -> item 1 i] care-locations
  report (list (max longs) (max lats) (min longs) (min lats))
end

;0.1.4
to draw-boundaries
  let poly-color-num 0
  foreach region-polygons [poly ->
    crt 1 [
      set color item poly-color-num [red magenta brown orange]
      set poly-color-num poly-color-num + 1
      let iloc item 0 poly
      setxy lon-to-xcor (item 1 iloc) (item 0 iloc) lat-to-ycor (item 0 iloc)
      pen-down
      foreach poly [loc ->
        setxy lon-to-xcor (item 1 loc) (item 0 loc) lat-to-ycor (item 0 loc)
      ]
      die
    ]
  ]
end

;0.1.5
to place-care-centers
  foreach care-locations [loc -> create-care-centers 1 [
    set color get-care-color loc
    set shape "house"
    set size .5
    setxy lon-to-xcor (item 1 loc) (item 0 loc) lat-to-ycor (item 0 loc)
    if not care-centers-visible? [hide-turtle]
    ]
  ]
end

; 0.1.5.1
to-report get-care-color [ row ]
  let c filter [r -> r != 0] (map [i -> ifelse-value ((item i row) = 1) [item (i + 3) base-colors][0]] (range 2 10))
  report ifelse-value (empty? c) [red] [item 0 c]
end

;0.1.6
to place-narcan-providers
  set max-narcan ifelse-value narcan-sharing? [ 4 ][ 2 ]
  foreach narcan-locations [loc -> create-narcan-distributors 1 [
    set color green
    set shape "house"
    set size .5
    setxy lon-to-xcor (item 1 loc) (item 0 loc) lat-to-ycor (item 0 loc)
    set supply item 2 loc + ( additional-narcan * item 2 loc )
    if not narcan-providers-visible? [hide-turtle]
    ]
  ]
  let mean-narcan mean [supply] of narcan-distributors
  set total-narcan-available sum [supply] of narcan-distributors
  if add-location? [
    ask patch -2 -0 [ sprout-narcan-distributors 1 [
      set color green
      set shape "house"
      set size .5
      set supply total-narcan-available * 0.25
      if not narcan-providers-visible? [hide-turtle]
      ]
    ]
  ]
  set total-narcan-available sum [supply] of narcan-distributors
end

; 0.2 setup a population of people

to setup-population
  let init-population n-of population pop-data
  foreach init-population [ row ->
    create-people 1 [
      set race item 0 row
      set gender item 1 row
      set age int (item 2 row)
      set region item 3 row
      set size 0.2
      set shape "person"
      set color get-person-color
      ;use parameters
      set isolated-user? report-isolation
      set used-today? FALSE
      set use-partner nobody
      if not people-visible? [hide-turtle]
      place-people
      set residence-location patch-here
    ]
  ]
end

to-report get-person-color
  let person-color (ifelse-value color-people-on = "race" [
    (ifelse-value race = "white" [white]
      race = "black" [black]
      race = "hisp" [red]
      [yellow])]
    color-people-on = "age" [scale-color orange age 0 100]
    color-people-on = "sex" [ifelse-value gender = "Male" [blue][red]])
  let transparency 160
  set person-color ifelse-value is-list? person-color
    [ lput transparency sublist person-color 0 3 ]
  [ lput transparency extract-rgb person-color ]
  report person-color
end

to-report report-isolation
  let p random 100
  ifelse p < isolated-user-precentage [report TRUE] [report FALSE]
end

to place-people
  let perturb 1
  if region = "rural" or region = "palmharbor" [set region "pinellas"]
  let coors [list pxcor pycor] of one-of patches with [patch-region = [region] of myself]
  setxy (item 0 coors + (random-float perturb) - perturb / 2) (item 1 coors + (random-float perturb) - perturb / 2)
end

to map-regions-to-patches
  ; redundant procedures unless map is changed
  let regions ["pinellas" "clearwater" "largo" "stpetersburg"]
  py:setup py:python
  py:run "from py_scripts import raycast as rc"
  ask patches [
    let lat ycor-to-lat pycor
    let lon xcor-to-lon pxcor lat
    py:set "x0" lon
    py:set "y0" lat
    foreach regions [ loc ->
      py:set "r0" loc
      let inside? py:runresult "rc.is_inside(x0,y0,r0)"
      if inside? [set patch-region loc]
    ]
  ]
  write-patch-regions
end

to write-patch-regions
  let csv-list [(list pxcor pycor patch-region)] of patches with [patch-region != 0]
  csv:to-file "Pinellas_Opioid_Setup/patch-region-file.csv" csv-list
end


; 0.3 setup a populcation of EMS
to setup-EMS
  create-EMS round ( 250 / scalar) [
    set shape "car"
    set color red
    set size 0.3
    let perturb 1
    let coors [list pxcor pycor] of one-of patches with [ patch-region != 0]
    setxy (item 0 coors + (random-float perturb) - perturb / 2) (item 1 coors + (random-float perturb) - perturb / 2)
    set Base-location patch-here
  ]

end

; 0.4 setup a populcation of police
to setup-police
    create-police round (500 / scalar) [
    set shape "car"
    set color blue
    set size 0.3
    let perturb 1
    let coors [list pxcor pycor] of one-of patches with [ patch-region != 0]
    setxy (item 0 coors + (random-float perturb) - perturb / 2) (item 1 coors + (random-float perturb) - perturb / 2)
    set Base-location patch-here
    set narcan-carrier? FALSE
  ]
end

; 0.5 ditribute narcan kits in the world
to distribute-narcan
 ask police [
  if random 1000 < Police-Narcan-probability [
    set narcan-carrier? TRUE
      set narcan-kits 200
  ]]
 ask EMS [
  set narcan-kits 1000
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 1 main model steps
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; 1.0 the high level model flow
to go
  reset-usage
  ask EMS [ roam ]
  ask police [ patrol ]
  ask narcan-distributors [ determine-range ]
  ask people [
    move
    if within-narcan-range? = TRUE [
      acquire-narcan
    ]
    consume-drugs
  ]
  track-outputs
  replenish-narcan
  tick
  if ticks = 8760 [ stop ]
end

to reset-usage
  ask people [ set used-today? FALSE]
end


; 1.1 EMS procedure , describing the movement of the EMS services
to roam
  fd 1 / scalar
  if distance Base-location > (4 / scalar) [
    face Base-location
    rt random 180
    lt random 180
  ]
end

; 1.2 Plocie procedure, describing the movement of police officers
to patrol
  fd 1 / scalar
  if distance Base-location > (4 / scalar) [
    face Base-location
    rt random 180
    lt random 180
  ]
end

to determine-range
  ask people in-radius (1 / scalar) with [ isolated-user? = FALSE] [ set within-narcan-range? TRUE ]
end

; 1.3 person procedure, describing how individuals move in the world
to move
  fd 1 / scalar
  if distance residence-location > (4 / scalar) [
    face residence-location
    rt random 180
    lt random 180
  ]
end

; 1.4 person procedure, describing how individuals acquire narcan kits
to acquire-narcan
  if not isolated-user? and narcan-kits <= (max-narcan / 2) and any? narcan-distributors with [supply > max-narcan] in-radius (1 / scalar) [
    let source one-of narcan-distributors with [supply > max-narcan] in-radius (1 / scalar)
      let resupply ifelse-value random 4 = 0 [max-narcan - narcan-kits][ 2 ]
      ask source [ set supply supply - resupply ]
      set narcan-kits narcan-kits + resupply
  ]
end

to share-narcan
  if narcan-sharing? [
    if use-partner != nobody and narcan-kits > 1 [
      let total-narcan [narcan-kits] of self + [narcan-kits] of use-partner
      let spare total-narcan mod 2
      set narcan-kits round (total-narcan / 2 )
      ask use-partner [ set narcan-kits round (total-narcan / 2) - spare ]
  ]
  ]
end

; 1.5 person procedure, descibing how individuals use opioids
to consume-drugs
  if not used-today? and random 24 < 1 [
    set used-today? true
    find-partner
    share-narcan
    OD-event?
  ]
end

; 1.5.1 individual level procedure indicating how non-isolated users find partners
to find-partner
  if not isolated-user? and use-partner = nobody [
    ifelse any? other people in-radius (4 / scalar) with [ not isolated-user? and use-partner = nobody ]
    [
      set use-partner one-of other people in-radius (4 / scalar) with [ not isolated-user? and use-partner = nobody]
      ;ask use-partner [set use-partner myself]
    ][
      set use-partner nobody
    ]
  ]
end


; 1.5.2 indivudual level procedure indicating an if and how an OD occurs
to OD-event?
  if random 100000 < OD-rate [
    set OD-count OD-count + 1
    ifelse Rescue-event? [
      set rescue-counter rescue-counter + 1
    ][
      hatch-people 1
      set OD-death-counter OD-death-counter + 1
      hatch-crosses 1 [
        set shape "x"
        set color black
        set size 0.4
      ]
      die
    ]
  ]
end

; 1.5.3 indivudual level procedure indicating an if and how an rescue occurs
to-report Rescue-event?
  let rescued? FALSE
  ifelse isolated-user? [
    ( ifelse
      any? EMS in-radius ((emergency-radius / scalar) / 2) [
        ask one-of EMS in-radius ((emergency-radius / scalar) / 2) [
          move-to myself
          if [narcan-kits] of self > 0 [
            set narcan-kits narcan-kits - 1
            set narcan-by-EMS narcan-by-EMS + 1
            set rescued? TRUE
          ]
        ]
      ]
      any? police in-radius (emergency-radius / scalar) [
        ask one-of police in-radius (emergency-radius / scalar) [
          move-to myself
          ifelse [narcan-kits] of self > 0 [
            set narcan-kits narcan-kits - 1
            set narcan-by-police narcan-by-police + 1
            set rescued? TRUE
          ][
            place-EMS-call
            if any? EMS-here [
              ask one-of EMS-here [
                if [narcan-kits] of self > 0 [
                  set narcan-kits narcan-kits - 1
                  set narcan-by-EMS narcan-by-EMS + 1
                  set rescued? TRUE
                ]
              ]
            ]
          ]
        ]
      ]
      []
    )
  ][
    ( ifelse
      narcan-kits > 0 [
        set narcan-kits narcan-kits - 1
        set narcan-by-friend narcan-by-friend + 1
        set rescued? TRUE
      ]
      use-partner != nobody and [narcan-kits] of use-partner > 0 [
        ask use-partner [ set narcan-kits narcan-kits - 1 ]
        set narcan-by-friend narcan-by-friend + 1
        set rescued? TRUE
      ]
      any? EMS in-radius ((emergency-radius / scalar) / 2) [
          ask one-of EMS in-radius ((emergency-radius / scalar) / 2) [
          move-to myself
          if narcan-kits > 0 [
            set narcan-kits narcan-kits - 1
            set narcan-by-EMS narcan-by-EMS + 1
            set rescued? TRUE
          ]
        ]
      ]
      [
        place-EMS-call
        if any? EMS-here [
          ask one-of EMS-here [
            if [narcan-kits] of self > 0 [
              set narcan-kits narcan-kits - 1
              set narcan-by-EMS narcan-by-EMS + 1
              set rescued? TRUE
            ]
          ]
        ]
      ]
    )
  ]
  report rescued?

end

to place-EMS-call
  if any? EMS in-radius (emergency-radius / scalar) [
    ask one-of EMS in-radius (emergency-radius / scalar) [
      move-to myself
    ]
  ]
end



; 1.6 global procedure, keeping track of output measures
to track-outputs
end

; 1.7 global procedure, describing how narcan is made available in the system
to replenish-narcan
  ask people [ set within-narcan-range? false ]
  ask people with [narcan-kits > 0 ] [ if random 720 < 1 [ set narcan-kits narcan-kits - 1 ]] ; lose a kit once every month (30 days)
  ask EMS [ set narcan-kits 10]
  ask police with [narcan-carrier?] [ set narcan-kits 2 ]
end




;;; GEOGRAPHIC REPORTERS

to-report image-dim
  report 500
end

to-report center-zoom
  ;py:run "from py_scripts import draw_map as dw"
  ;py:set "cor_list" cors
  ;report py:runresult "dw.get_center_zoom(cor_list)"
  report [[27.900778149999997 -82.7314389] 10]
end

to-report center-lat
  report item 0 (item 0 center-zoom)
end

to-report center-lon
  report item 1 (item 0 center-zoom)
end

to-report zoom-level
  report item 1 center-zoom
end

to-report image-px-to-km
  ; from https://gis.stackexchange.com/a/127949
  report 156.54303392 * (cos center-lat) / (2 ^ zoom-level)
end

to-report km-to-dist [ km ]
  report (km / image-px-to-km) * world-width / image-dim
end

to-report dist-to-km [ d ]
  report image-px-to-km * d * image-dim / world-width
end

to-report km-to-lat [ y ]
  report y / 110.574
end

to-report km-to-lon [ x la ]
  report x / (111.320 * cos la)
end

to-report lat-to-km [ la ]
  report 110.574 * la
end

to-report lon-to-km [ lo la ]
  report lo * 111.320 * cos la
end

to-report xcor-to-lon [ x lat ]
  report km-to-lon dist-to-km (x - (max-pxcor + min-pxcor) / 2) lat + center-lon
end

to-report ycor-to-lat [ y ]
  report km-to-lat dist-to-km (y - (max-pycor + min-pycor) / 2) + center-lat
end

to-report lon-to-xcor [ lon lat ]
  report (km-to-dist lon-to-km (lon - center-lon) lat) + (max-pxcor + min-pxcor) / 2
end

to-report lat-to-ycor [ lat ]
  report (km-to-dist lat-to-km (lat - center-lat)) + (max-pycor + min-pycor) / 2
end

to profile-behaviors
  setup                  ;; set up the model
  profiler:start         ;; start profiling
  repeat 20 [ go ]       ;; run something you want to measure
  profiler:stop          ;; stop profiling
  print profiler:report  ;; view the results
  profiler:reset         ;; clear the data
end
@#$#@#$#@
GRAPHICS-WINDOW
390
10
1123
976
-1
-1
29.0
1
10
1
1
1
0
1
1
1
-12
12
-16
16
0
0
1
ticks
30.0

BUTTON
17
367
334
400
NIL
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
17
410
80
443
NIL
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
4
630
182
663
OD-rate
OD-rate
0
100000
10.0
5
1
* 0.001 %
HORIZONTAL

MONITOR
1317
111
1415
156
Narcan rescues
rescue-counter
17
1
11

MONITOR
1341
43
1413
88
OD deaths
OD-death-counter
17
1
11

SLIDER
16
15
188
48
Population
Population
1000
15000
12000.0
1000
1
NIL
HORIZONTAL

SLIDER
1145
374
1391
407
Police-Narcan-probability
Police-Narcan-probability
0
1000
250.0
50
1
 * 0.1 %
HORIZONTAL

SLIDER
1145
412
1350
445
isolated-user-precentage
isolated-user-precentage
0
100
50.0
1
1
%
HORIZONTAL

MONITOR
1318
160
1423
205
NIL
narcan-by-police
17
1
11

MONITOR
1318
208
1415
253
NIL
narcan-by-EMS
17
1
11

MONITOR
1318
258
1424
303
NIL
narcan-by-friend
17
1
11

SLIDER
6
671
182
704
emergency-radius
emergency-radius
0
5
3.0
1
1
NIL
HORIZONTAL

MONITOR
1267
42
1333
87
NIL
OD-count
17
1
11

MONITOR
1424
43
1505
88
Fatality %
(OD-death-counter / OD-count ) * 100
2
1
11

SWITCH
18
58
190
91
show-boundaries?
show-boundaries?
1
1
-1000

SWITCH
19
94
190
127
people-visible?
people-visible?
0
1
-1000

CHOOSER
197
15
335
60
boundaries
boundaries
"county" "cities"
0

CHOOSER
197
62
335
107
color-people-on
color-people-on
"race" "age" "sex"
0

SLIDER
197
110
335
143
scalar
scalar
1
10
5.0
1
1
NIL
HORIZONTAL

SWITCH
19
129
189
162
care-centers-visible?
care-centers-visible?
1
1
-1000

SWITCH
19
164
189
197
narcan-providers-visible?
narcan-providers-visible?
0
1
-1000

SWITCH
96
410
240
443
narcan-sharing?
narcan-sharing?
0
1
-1000

MONITOR
1196
509
1330
554
% people with narcan
count people with [narcan-kits > 0 ] / count people * 100
2
1
11

SLIDER
19
320
157
353
additional-narcan
additional-narcan
0
100
25.0
1
1
%
HORIZONTAL

MONITOR
1352
509
1471
554
narcan remaining (%)
(sum [supply] of narcan-distributors / total-narcan-available) * 100
0
1
11

MONITOR
1353
563
1471
608
time remaining (%)
(1 - (ticks / ( 365 * 24))) * 100
0
1
11

BUTTON
5
535
209
568
hide agents without narcan kits
ask people with [narcan-kits = 0][ set hidden? true]\nask EMS [ set hidden? true ]\nask police [ set hidden? true ]\nask narcan-distributors [ set hidden? true]
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
218
535
335
568
show all agents
ask people [set hidden? false]\nask EMS [ set hidden? false ]\nask police [ set hidden? false ]\nask narcan-distributors [ set hidden? false]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
167
320
352
353
add-location?
add-location?
0
1
-1000

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
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Toy-model sensitivity" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="8760"/>
    <metric>rescue-counter</metric>
    <metric>narcan-by-police</metric>
    <metric>narcan-by-EMS</metric>
    <metric>narcan-by-friend</metric>
    <metric>OD-count</metric>
    <metric>OD-death-counter</metric>
    <metric>OD-death-counter / OD-count</metric>
    <enumeratedValueSet variable="Population">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="OD-rate">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emergency-radius">
      <value value="3"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Narcan-locations" first="0" step="20" last="100"/>
    <steppedValueSet variable="Police-Narcan-probability" first="0" step="200" last="1000"/>
    <steppedValueSet variable="isolated-user-precentage" first="0" step="20" last="100"/>
  </experiment>
  <experiment name="experiment" repetitions="40" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="8760"/>
    <metric>rescue-counter</metric>
    <metric>narcan-by-police</metric>
    <metric>narcan-by-EMS</metric>
    <metric>narcan-by-friend</metric>
    <metric>OD-count</metric>
    <metric>OD-death-counter</metric>
    <metric>OD-death-counter / OD-count</metric>
    <metric>count people with [narcan-kits &gt; 0 ] / count people * 100</metric>
    <metric>(sum [supply] of narcan-distributors / total-narcan-available) * 100</metric>
    <enumeratedValueSet variable="Population">
      <value value="12000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emergency-radius">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolated-user-precentage">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Police-Narcan-probability">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scalar">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="OD-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="add-location?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="narcan-sharing?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="additional-narcan">
      <value value="0"/>
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
