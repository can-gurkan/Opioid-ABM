;; goal of this model is to show the long term impact (or lack thereof) of increased narcan distribution

extensions [csv rnd gis fp]

globals[

  ;; input data arrays
  gis-dataset
  ct-index
  ct-pop-data
  ct-sex-data
  ct-age-data
  ct-race-data
  care-center-data
  narcan-dist-data

  ;; output counters
  burn-in-time
  rescue-counter
  rescue-by-EMS
  rescue-by-friend
  OD-counter
  OD-counter-today
  OD-deaths
  OD-deaths-today
  OD-death-of-untreated
  OD-death-of-recently-treated
  total-narcan-available
  total-treatment-capacity
  treatment-utilization
  narcan-penetration
]

breed [people person]
breed [care-centers care-center]
breed [narcan-distributors narcan-distributor]
breed [red-boxes red-box]

;; assigning characteristics to the different agents
people-own [
  ;; Demographics
  census-tract
  age                              ; the age of the individual in years
  race                             ; the race of the individual, categorical it will either be ( )
  gender                           ; a indicator if the gender of the individual
  region                           ; indicator of the region one lives in
  residence-location
  in-jail?

  ;; Opioid use related
  craving
  tolerance
  potency
  use-location-pref
  use-isolation-rate
  use-recent-week
  desire-today
  use-today?
  intent-to-use?
  use-in-isolation?
  use-at
  rescued-today?

  ;; treatment related
  care-seeking-duration
  care-seeking?
  personal-motivation
  treatment-today?
  last-treated
  in-treatment?
  days-in-treatment
  treatment-options
  my-treatment-provider
  treatment-distances
  my-treatment-distance

  ;; OD related
  OD-today?
  OD-count
  OD-recent-week

  ;; narcan related
  carrying-narcan?
  aware-of-narcan?
  narcan-closeby?
  narcan-available?
]

care-centers-own[
  treatment-capacity
  current-usage
  waitlist
  narcan-equiped?
  supply

  OTP?
  detox?
  res?
  OP?
  FQHC?
  SPC?
  PCP?
  emergency?
]

narcan-distributors-own [
  supply
]

red-boxes-own [
  supply
]


;;;;;;;;;;;;;; 0) code to set up the model ;;;;;;;;;;;;;;;;;;;;;
to setup
  clear-all

  read-in-data
  setup-map
  setup-pop
  setup-care-centers
  setup-narcan-distributors
  reset-ticks
end

to setup-map
  gis:load-coordinate-system "regional_input_files/Pinellas-County-FL/pinellas_gis/pinellas_census_tract.prj"
  set gis-dataset gis:load-dataset "regional_input_files/Pinellas-County-FL/pinellas_gis/pinellas_census_tract.shp"
  gis:set-world-envelope gis:envelope-of gis-dataset
  if show-background-map? [
    gis:import-wms-drawing "https://ows.terrestris.de/osm/service?" "EPSG:4326" "OSM-WMS" 0
  ]
  gis:set-drawing-color magenta
  gis:draw gis-dataset 1
end

to read-in-data
  read-demographics-data
  read-care-center-data
  read-narcan-dist-data
end

to read-demographics-data
  ;; obtained from https://data.census.gov/table?t=Age+and+Sex&g=040XX00US12_050XX00US12103$1400000&d=DEC+Demographic+Profile
  file-open "regional_input_files/Pinellas-County-FL/cleaned-pinellas-demographics-by-census-tract.csv"
  set ct-index but-first csv:from-row file-read-line
  set ct-index replace-item 0 ct-index 0
  ;print ct-index
  let row file-read-line
  set ct-pop-data (but-first csv:from-row file-read-line)
  ;print ct-pop-data
  repeat 24 [set row file-read-line]
  set ct-sex-data []
  set ct-sex-data lput (but-first csv:from-row file-read-line) ct-sex-data
  ;print ct-sex-data
  let male-ct-age-data []
  repeat 18 [set male-ct-age-data lput (but-first csv:from-row file-read-line) male-ct-age-data]
  ;print male-ct-age-data
  repeat 6 [set row file-read-line]
  set ct-sex-data lput (but-first csv:from-row file-read-line) ct-sex-data
  ;print item 1 ct-sex-data
  let female-ct-age-data []
  repeat 18 [set female-ct-age-data lput (but-first csv:from-row file-read-line) female-ct-age-data]
  ;print female-ct-age-data
  repeat 34 [set row file-read-line]
  let hisp-ct-race-data but-first csv:from-row file-read-line
  ;print hisp-ct-race-data
  repeat 8 [set row file-read-line]
  let white-ct-race-data but-first csv:from-row file-read-line
  ;print white-ct-race-data
  let aa-ct-race-data but-first csv:from-row file-read-line
  ;print aa-ct-race-data
  let other-ct-race-data map [i -> (item i ct-pop-data) - ((item i hisp-ct-race-data) + (item i white-ct-race-data) + (item i aa-ct-race-data)) ] range length ct-pop-data
  ;print other-ct-race-data
  file-close-all
  set ct-age-data list male-ct-age-data female-ct-age-data
  set ct-race-data (list aa-ct-race-data white-ct-race-data hisp-ct-race-data other-ct-race-data)
end

to read-care-center-data
  file-open "regional_input_files/Pinellas-County-FL/care_providers/List_of_care_providers_PinellasCounty.csv"
  let row file-read-line
  set care-center-data []
  while [ not file-at-end? ] [
    set row sublist (csv:from-row file-read-line) 0 11
    set care-center-data lput row care-center-data
  ]
  ;print care-center-data
  file-close-all
end

to read-narcan-dist-data
  file-open "regional_input_files/Pinellas-County-FL/NarcanProviders.csv"
  set narcan-dist-data []
  let row file-read-line
  while [not file-at-end?][
    set row csv:from-row file-read-line
    set narcan-dist-data  lput but-last row narcan-dist-data
  ]
  file-close-all
end

to setup-care-centers
  foreach care-center-data [ data-row ->
    create-care-centers 1 [
      let loc gis:project-lat-lon item 0 data-row item 1 data-row
      setxy item 0 loc item 1 loc

      set OTP?       item 2 data-row
      set detox?     item 3 data-row
      set res?       item 4 data-row
      set OP?        item 5 data-row
      set FQHC?      item 6 data-row
      set SPC?       item 7 data-row
      set PCP?       item 8 data-row
      set emergency? item 9 data-row
      set treatment-capacity item 10 data-row

      set color get-care-color data-row
      set shape "house"
      set size .5
      if not care-centers-visible? [hide-turtle]
    ]
  ]
end

to-report get-care-color [ row ]
  let c filter [r -> r != 0] (map [i -> ifelse-value ((item i row) = 1) [item (i + 3) base-colors][0]] (range 2 10))
  report ifelse-value (empty? c) [red] [item 0 c]
end

to setup-narcan-distributors
  foreach narcan-dist-data [ data-row ->
    create-narcan-distributors 1 [
      let loc gis:project-lat-lon item 0 data-row item 1 data-row
      setxy item 0 loc item 1 loc
      set supply item 2 data-row
      set color green
      set shape "pentagon"
      set size 0.5
      if not narcan-providers-visible? [hide-turtle]
    ]
  ]
  set total-narcan-available sum [supply] of narcan-distributors
end


;;; 0.2 setup of the individuals in the simulation

to setup-pop
  create-people population [
    ;demographics
    set census-tract assign-ct
    ;print census-tract
    let ct-num item 0 fp:find-indices [x -> x = census-tract] ct-index
    set gender assign-sex ct-num
    ;print gender
    set age assign-age ct-num
    ;print age
    set race assign-race ct-num
    ;print race

    ;use parameters
    set craving random-float 100
    set tolerance personal-tolerance
    set use-location-pref personal-location-pref
    set use-isolation-rate personal-isolation-rate
    set use-recent-week  map [-> use-flip] range 7
    set use-today? use-flip

    ; treatment parameters
    set treatment-today? false
    set in-treatment? false
    set care-seeking-duration 0
    set care-seeking? false
    set personal-motivation random 100

    ;OD parameters
    set OD-today? false
    set OD-count 0
    set OD-recent-week (list 0 0 0 0 0 0 0 )

    ;visualization
    set size 0.5
    set shape "person"
    set color blue
    if not people-visible? [hide-turtle]
  ]
  place-population
end

to-report assign-ct
  let zip-list fp:zip (but-first ct-pop-data) (but-first ct-index)
  report last rnd:weighted-one-of-list zip-list [[p] -> first p]
end

to-report assign-sex [ct-num]
  let prob-list map [i -> item ct-num item i ct-sex-data] range 2
  ;print prob-list
  let zip-list fp:zip prob-list ["MALE" "FEMALE"]
  report last rnd:weighted-one-of-list zip-list [[p] -> first p]
end

to-report assign-age [ct-num]
  let age-groups get-age-groups
  let sex-num ifelse-value gender = "MALE" [0][1]
  let prob-list map [i -> item ct-num item i item sex-num ct-age-data] range length age-groups
  let zip-list fp:zip prob-list age-groups
  let age-range last rnd:weighted-one-of-list zip-list [[p] -> first p]
  report (item 0 age-range) + random ((item 1 age-range) - (item 0 age-range) + 1)
end

to-report get-age-groups
  let age-groups []
  let age-count 0
  foreach range 17 [i ->
    let lb age-count
    foreach range 4 [j ->
      set age-count age-count + 1
    ]
    let ub age-count
    set age-groups lput (list lb ub) age-groups
    set age-count age-count + 1
  ]
  set age-groups lput (list 85 100) age-groups
  report age-groups
end

to-report assign-race [ct-num]
  let prob-list map [i -> item ct-num item i ct-race-data] range 4
  ;print prob-list
  let zip-list fp:zip prob-list ["AA" "WHITE" "HISP" "OTHER"]
  report last rnd:weighted-one-of-list zip-list [[p] -> first p]
end

to place-population
  foreach gis:feature-list-of gis-dataset [vector-feature ->
    let ct-name gis:property-value vector-feature "NAME"
    ask people with [(word census-tract) = ct-name] [
      ;print who
      let loc gis:location-of gis:random-point-inside vector-feature
      set xcor item 0 loc
      set ycor item 1 loc
    ]
  ]
end

to-report personal-tolerance
  report random-float 100
end

to-report personal-location-pref
  let pref (list 0 0 0)
  ;;; the following rates should be based on observed death data, while this might not be representative of where people use, it is the only data we have relating to use
  set pref replace-item 0 pref ((50 + random 50) - random 50) ;; 50% chance of prefering to use at home
  set pref replace-item 1 pref ((30 + random 30) - random 30) ;; 30% chance of prefering to use in public space
  set pref replace-item 2 pref ((20 + random 20) - random 20) ;; 20% chance of prefering to use in other location
  report pref
end

to-report personal-isolation-rate
  let perc isolated-user-percentage
  report random-normal isolated-user-percentage (0.2 * isolated-user-percentage )
end

to-report use-flip
  report ifelse-value random 100 < 30 [TRUE][FALSE]
end





to go
  if ticks = 8760 [ stop ]

  tick
end





;;;;;;;;;;;;;; X) supporting procedures ;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
295
10
839
727
-1
-1
21.455
1
10
1
1
1
0
0
0
1
-12
12
-16
16
1
1
1
ticks
30.0

SLIDER
911
174
1101
207
percent-narcan-added
percent-narcan-added
0
100
25.0
1
1
%
HORIZONTAL

CHOOSER
1435
21
1628
66
boundaries
boundaries
"county" "cities"
1

SWITCH
1435
68
1629
101
show-boundaries?
show-boundaries?
1
1
-1000

SWITCH
1435
102
1629
135
care-centers-visible?
care-centers-visible?
0
1
-1000

SWITCH
1435
138
1629
171
narcan-providers-visible?
narcan-providers-visible?
0
1
-1000

SWITCH
911
212
1102
245
add-location?
add-location?
0
1
-1000

SLIDER
20
25
192
58
population
population
5000
20000
20000.0
500
1
NIL
HORIZONTAL

SLIDER
1106
127
1311
160
isolated-user-percentage
isolated-user-percentage
0
100
30.0
5
1
%
HORIZONTAL

SWITCH
1434
177
1570
210
people-visible?
people-visible?
1
1
-1000

BUTTON
20
100
83
133
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

SWITCH
1576
177
1699
210
EMS-visible?
EMS-visible?
1
1
-1000

CHOOSER
911
249
1103
294
narcan-boxes?
narcan-boxes?
"none" "random" "targeted"
1

BUTTON
95
100
158
133
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

SWITCH
1106
163
1311
196
leave-behind-narcan?
leave-behind-narcan?
1
1
-1000

SLIDER
1106
201
1311
234
nr-narcan-boxes
nr-narcan-boxes
1
500
200.0
1
1
NIL
HORIZONTAL

SLIDER
1106
238
1312
271
treatment-narcan-supply-likelihood
treatment-narcan-supply-likelihood
0
100
10.0
1
1
%
HORIZONTAL

CHOOSER
910
127
1101
172
MAT-set
MAT-set
"MAT-only" "MAT-extra25-cap" "MAT-extra50-cap" "MAT-extra100-cap" "MAT-and-BUP25" "MAT-and-BUP50" "MAT-and-BUP100" "MAT-extra25-loc" "MAT-extra50-loc" "MAT-extra100-loc" "intervention combo 7"
10

BUTTON
20
140
160
173
go-1year
setup\nrepeat 365 + burn-in-time [go]
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
910
78
1312
123
Intervention-package
Intervention-package
"0" "1" "2" "3" "4" "5" "6" "7" "8" "9"
0

SWITCH
1445
275
1652
308
show-background-map?
show-background-map?
1
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
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="615"/>
    <metric>count people with [treatment-today?]</metric>
    <metric>count people with [use-today?]</metric>
    <metric>count people with [intent-to-use?]</metric>
    <metric>count people with [last-treated = 0]</metric>
    <metric>mean [tolerance] of people</metric>
    <metric>mean [craving] of people</metric>
    <metric>mean [days-in-treatment] of people</metric>
    <metric>mean [days-in-treatment] of people with [in-treatment?]</metric>
    <metric>mean [my-treatment-distance] of people with [in-treatment?]</metric>
    <metric>OD-counter</metric>
    <metric>rescue-counter</metric>
    <metric>rescue-by-EMS</metric>
    <metric>rescue-by-friend</metric>
    <metric>OD-deaths</metric>
    <metric>OD-death-of-untreated</metric>
    <metric>OD-death-of-recently-treated</metric>
    <metric>treatment-utilization</metric>
    <metric>total-treatment-capacity</metric>
    <enumeratedValueSet variable="nr-narcan-boxes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EMS-visible?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="18000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolated-user-percentage">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-boundaries?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="narcan-boxes?">
      <value value="&quot;none&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percent-narcan-added">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boundaries">
      <value value="&quot;cities&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="leave-behind-narcan?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="narcan-providers-visible?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="care-centers-visible?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MAT-set">
      <value value="&quot;MAT-only&quot;"/>
      <value value="&quot;MAT-extra25-cap&quot;"/>
      <value value="&quot;MAT-extra50-cap&quot;"/>
      <value value="&quot;MAT-extra100-cap&quot;"/>
      <value value="&quot;MAT-and-BUP25&quot;"/>
      <value value="&quot;MAT-and-BUP50&quot;"/>
      <value value="&quot;MAT-and-BUP100&quot;"/>
      <value value="&quot;MAT-extra25-loc&quot;"/>
      <value value="&quot;MAT-extra50-loc&quot;"/>
      <value value="&quot;MAT-extra100-loc&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="add-location?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people-visible?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-narcan-supply-likelihood">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Intervention combinations" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="715"/>
    <metric>count people with [treatment-today?]</metric>
    <metric>count people with [use-today?]</metric>
    <metric>count people with [intent-to-use?]</metric>
    <metric>count people with [last-treated = 0]</metric>
    <metric>mean [tolerance] of people</metric>
    <metric>mean [craving] of people</metric>
    <metric>mean [days-in-treatment] of people</metric>
    <metric>mean [days-in-treatment] of people with [in-treatment?]</metric>
    <metric>mean [my-treatment-distance] of people with [in-treatment?]</metric>
    <metric>OD-counter</metric>
    <metric>rescue-counter</metric>
    <metric>rescue-by-EMS</metric>
    <metric>rescue-by-friend</metric>
    <metric>OD-deaths</metric>
    <metric>OD-death-of-untreated</metric>
    <metric>OD-death-of-recently-treated</metric>
    <metric>treatment-utilization</metric>
    <metric>total-treatment-capacity</metric>
    <metric>narcan-penetration</metric>
    <enumeratedValueSet variable="nr-narcan-boxes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EMS-visible?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="18000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-boundaries?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isolated-user-percentage">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="narcan-boxes?">
      <value value="&quot;none&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percent-narcan-added">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boundaries">
      <value value="&quot;cities&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Intervention-package">
      <value value="&quot;0&quot;"/>
      <value value="&quot;1&quot;"/>
      <value value="&quot;2&quot;"/>
      <value value="&quot;3&quot;"/>
      <value value="&quot;4&quot;"/>
      <value value="&quot;5&quot;"/>
      <value value="&quot;6&quot;"/>
      <value value="&quot;7&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="leave-behind-narcan?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="narcan-providers-visible?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="care-centers-visible?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MAT-set">
      <value value="&quot;MAT-only&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="add-location?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people-visible?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-narcan-supply-likelihood">
      <value value="10"/>
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
1
@#$#@#$#@
