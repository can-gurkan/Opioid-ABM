;; This is version 3.001 of the narcan model for Pinellas county FL
;; goal of this model is to show the long term impact (or lack thereof) of increased narcan distribution

extensions [ csv nw py rnd gis profiler]

breed [ people person ]
breed [ care-centers care-center]
breed [ narcan-distributors narcan-distributor]
breed [ EMS EMSP]
breed [red-boxes red-box]

;; assigning characteristics to the different agents
people-own [
  ;; Demographics
  age                              ; the age of the individual in years
  race                             ; the race of the individual, categorical it will either be ( )
  gender                           ; a indicator if the gender of the individual
  region                           ; indicator of the region one lives in
  residence-location
  in-jail?

  ;; Oppioid use related
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
narcan-distributors-own [
  supply
]
red-boxes-own [
  supply
]
EMS-own[
  base-location
  region
  narcan-equiped?
]
care-centers-own[
  treatment-capacity
  narcan-equiped?
  supply
]
patches-own[
 patch-region
]
globals[
  ;; spatial attributes
  county-border
  care-locations
  narcan-locations
  cors
  region-polygons
  pop-data

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

;;;;;;;;;;;;;; 0) code to set up the model ;;;;;;;;;;;;;;;;;;;;;
to setup
  clear-all
  reset-ticks
  import-drawing "Pinellas_Opioid_Setup/local_image.jpg"
  setup-intervention
  setup-map
  setup-population
  setup-EMS
  distribute-narcan
  set burn-in-time 350
end

to setup-intervention
  ( ifelse
    intervention-package = "0" [                                                                 ; 0) no interventions
      set percent-narcan-added 0
      set add-location? FALSE
      set narcan-boxes? "none"
      set MAT-set "MAT-only"
      set isolated-user-percentage 50
    ]
    intervention-package = "1" [                                                                 ; 1) ADD 25% more narcan using additional locations and add targeted RED boxes
      set percent-narcan-added 50
      set add-location? TRUE
      set narcan-boxes? "random"
      set MAT-set "MAT-only"
      set isolated-user-percentage 50
    ]
    intervention-package = "2" [                                                                 ; 2) ADD Reduce use in isolation by 25%
      set percent-narcan-added 0
      set add-location? FALSE
      set narcan-boxes? "none"
      set MAT-set "MAT-only"
      set isolated-user-percentage 30
    ]
    intervention-package = "3" [                                                                 ; 3) ADD 2 OTP treatment locations
      set percent-narcan-added 0
      set add-location? FALSE
      set narcan-boxes? "none"
      set MAT-set "MAT-extra100-loc"
      set isolated-user-percentage 50
    ]
    intervention-package = "4" [                                                                 ; 4) ADD increase waivered phys clients to 10
      set percent-narcan-added 0
      set add-location? FALSE
      set narcan-boxes? "none"
      set MAT-set "MAT-and-BUP50"
      set isolated-user-percentage 50
    ]
    intervention-package = "5" [                                                                 ; 5) [1+2] ADD 25% more narcan and additional locations, add targeted RED boxes, and reduce use in isolation by 25%
      set percent-narcan-added 50
      set add-location? TRUE
      set narcan-boxes? "random"
      set MAT-set "MAT-only"
      set isolated-user-percentage 30
    ]
    intervention-package = "6" [                                                                 ; 6) [1+2+3] ADD 25% more narcan and additional location, add targeted RED boxes, Reduce use in isolation by 25%, and add 2 OTP treatment locations
      set percent-narcan-added 50
      set add-location? TRUE
      set narcan-boxes? "random"
      set MAT-set "MAT-extra100-loc"
      set isolated-user-percentage 30
    ]
    intervention-package = "7" [                                                                 ; 7) [1+2+3+4] ADD 25% more narcan and additional location, add targeted RED boxes, Reduce use in isolation by 25%, add 2 OTP treatment locations, and increase waivered phys clients to 10
      set percent-narcan-added 25
      set add-location? TRUE
      set narcan-boxes? "random"
      set MAT-set "intervention combo 7"
      set isolated-user-percentage 30
    ]
    []
    )
end



;;; 0.1 setup the spatial environment
to setup-map
  ; read in various data
  read-care-locations                        ;; see 0.1.1
  read-narcan-locations                      ;; see 0.1.2
  read-population-data                       ;; see 0.1.3
  read-region-boundaries                     ;; see 0.1.4
  read-patch-regions                         ;; see 0.1.5
  ; place locations on the map
  place-care-centers                         ;; see 0.1.6
  place-narcan-providers                     ;; see 0.1.7
end
;;; 0.1.1
to read-care-locations
  (ifelse
    MAT-set = "MAT-only" [file-open "Pinellas_Opioid_Setup/care_providers/List_of_MAT_providers_PinellasCounty_simple.csv"]
    MAT-set = "MAT-extra25-cap" [file-open "Pinellas_Opioid_Setup/care_providers/List_of_MAT_providers_PinellasCounty_extended-cap25.csv"]
    MAT-set = "MAT-extra50-cap" [file-open "Pinellas_Opioid_Setup/care_providers/List_of_MAT_providers_PinellasCounty_extended-cap50.csv"]
    MAT-set = "MAT-extra100-cap" [file-open "Pinellas_Opioid_Setup/care_providers/List_of_MAT_providers_PinellasCounty_extended-cap100.csv"]
    MAT-set = "MAT-and-BUP25" [file-open "Pinellas_Opioid_Setup/care_providers/List_of_MAT_providers_PinellasCounty_long25.csv"]
    MAT-set = "MAT-and-BUP50" [file-open "Pinellas_Opioid_Setup/care_providers/List_of_MAT_providers_PinellasCounty_long50.csv"]
    MAT-set = "MAT-and-BUP100" [file-open "Pinellas_Opioid_Setup/care_providers/List_of_MAT_providers_PinellasCounty_long100.csv"]
    MAT-set = "MAT-extra25-loc" [file-open "Pinellas_Opioid_Setup/care_providers/List_of_MAT_providers_PinellasCounty_extended-loc25.csv"]
    MAT-set = "MAT-extra50-loc" [file-open "Pinellas_Opioid_Setup/care_providers/List_of_MAT_providers_PinellasCounty_extended-loc50.csv"]
    MAT-set = "MAT-extra100-loc" [file-open "Pinellas_Opioid_Setup/care_providers/List_of_MAT_providers_PinellasCounty_extended-loc100.csv"]
    MAT-set = "intervention combo 7" [file-open "Pinellas_Opioid_Setup/care_providers/List_of_MAT_providers_PinellasCounty_extended-loc100-and-long50.csv"]
    []
  )

  set care-locations []
  let row file-read-line
  while [not file-at-end?][
    set row csv:from-row file-read-line
    set care-locations  lput (map [i -> item i row] range 15) care-locations
  ]
  file-close-all
end
;;; 0.1.2
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
;;; 0.1.3
to read-population-data
  set pop-data []
  file-open "Pinellas_Opioid_Setup/pinellas_pop_data.csv"
  let header file-read-line                                                                        ;; take the first row in the file (consisting of headers) and store it
  while [not file-at-end?][                                                                        ;; for all consequative (so skipping the first line) row read in the data from the file in the prespecified variable
    set pop-data lput (csv:from-row file-read-line " ") pop-data
  ]
  file-close-all
end
;;; 0.1.4
to read-region-boundaries
  set region-polygons []
  let region-files ["pinellas" "clearwater" "largo" "stpetersburg"]
  if boundaries = "county" [set region-files (list item 0 region-files)]
  foreach region-files [ reg ->
    file-open (word "Pinellas_Opioid_Setup/polygons/" reg "Poly.txt")
    let row ""
    let poly []
    while [not file-at-end?][
      set row (csv:from-row file-read-line "	")
      set poly lput (map [i -> item i row] [1 0]) poly
    ]
    set region-polygons lput poly region-polygons
  ]
end
;;; 0.1.5
to read-patch-regions
  set region-polygons []
  file-open "Pinellas_Opioid_Setup/patch-region-file.csv"
  while [not file-at-end?][
    let row csv:from-row file-read-line
    ask patch (item 0 row) (item 1 row) [set patch-region (item 2 row)]
  ]
  file-close-all
  set cors find-corners
  if show-boundaries? [draw-boundaries]
end
to-report find-corners
  let longs map [i -> item 0 i] care-locations
  let lats  map [i -> item 1 i] care-locations
  report (list (max longs) (max lats) (min longs) (min lats))
end
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
;;; 0.1.6
to place-care-centers
  foreach care-locations [loc -> create-care-centers 1 [
    set color get-care-color loc
    set shape "house"
    set size .5
    setxy lon-to-xcor (item 1 loc) (item 0 loc) lat-to-ycor (item 0 loc)
    set treatment-capacity item 10 loc
    if not care-centers-visible? [hide-turtle]
    ]
  ]
  set total-treatment-capacity sum [treatment-capacity] of care-centers
end
to-report get-care-color [ row ]
  let c filter [r -> r != 0] (map [i -> ifelse-value ((item i row) = 1) [item (i + 3) base-colors][0]] (range 2 10))
  report ifelse-value (empty? c) [red] [item 0 c]
end
;;; 0.1.7
to place-narcan-providers
  foreach narcan-locations [loc -> create-narcan-distributors 1 [
    set color green
    set shape "house"
    set size .5
    setxy lon-to-xcor (item 1 loc) (item 0 loc) lat-to-ycor (item 0 loc)
    set supply item 2 loc
    if not narcan-providers-visible? [hide-turtle]
    ]
  ]
  if percent-narcan-added != 0 [
    ifelse add-location? [

      foreach (list (list 27.97691	-82.78833) (list 27.76446	-82.68671)) [loc -> create-narcan-distributors 1 [
        set color green
        set shape "house"
        set size .5
        setxy lon-to-xcor (item 1 loc) (item 0 loc) lat-to-ycor (item 0 loc)
        set supply 1400
        if not narcan-providers-visible? [hide-turtle]
        ]
      ]



;
;      let mean-narcan mean [supply] of narcan-distributors
;      set total-narcan-available sum [supply] of narcan-distributors
;      ask patch -2 -0 [ sprout-narcan-distributors 1 [
;        set color green
;        set shape "house"
;        set size .5
;        set supply total-narcan-available * percent-narcan-added
;        if not narcan-providers-visible? [hide-turtle]
;        ]
;      ]
    ][
      ask narcan-distributors [ set supply supply + ( supply * (percent-narcan-added / 100 )) ]
    ]
  ]
  set total-narcan-available sum [supply] of narcan-distributors
end

;;; 0.2 setup of the individuals in the simulation
to setup-population
  let init-population n-of population pop-data
  foreach init-population [ row ->
    create-people 1 [
     ;demographics
      set race item 0 row
      set gender item 1 row
      set age int (item 2 row)
      set region item 3 row
      find-residence-location
      set in-jail? false

      ;use parameters
      set craving random-float 100
      set tolerance personal-tolerance
      set use-location-pref personal-location-pref
      set use-isolation-rate personal-isolation-rate
      set use-recent-week  (list use-flip use-flip use-flip use-flip use-flip use-flip use-flip )
      set use-today? use-flip

      ; treatment parameters
      set treatment-today? false
      set in-treatment? false
      set care-seeking-duration 0
      set care-seeking? false
      set personal-motivation random 100
      set treatment-options care-centers with [treatment-capacity > 0]
      set treatment-distances ( list [distance myself] of treatment-options)

      ;OD parameters
      set OD-today? false
      set OD-count 0
      set OD-recent-week (list 0 0 0 0 0 0 0 )

      ; narcan info
      set carrying-narcan? false
      set narcan-closeby? any? red-boxes in-radius 0.5 or any? narcan-distributors in-radius 0.5
      set narcan-available?  any? red-boxes in-radius 1 or any? narcan-distributors in-radius 1
      set aware-of-narcan? false

      ;visualization
      set size 0.2
      set shape "person"
      set color blue
      if not people-visible? [hide-turtle]
    ]
  ]
end
to find-residence-location
  let perturb 1
  if region = "rural" or region = "palmharbor" [set region "pinellas"]
  let coors [list pxcor pycor] of one-of patches with [patch-region = [region] of myself]
  setxy (item 0 coors + (random-float perturb) - perturb / 2) (item 1 coors + (random-float perturb) - perturb / 2)
  set residence-location patch-here
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

;;; 0.3 setup of the emergency services in the simulation
to setup-EMS
  create-EMS round population / 100 [
    set shape "car"
    set color red
    set size 0.3
    let perturb 1
    let coors [list pxcor pycor] of one-of patches with [ patch-region != 0]
    setxy (item 0 coors + (random-float perturb) - perturb / 2) (item 1 coors + (random-float perturb) - perturb / 2)
    set Base-location patch-here
    if not EMS-visible? [hide-turtle]
  ]
end

;;; 0.4 setup the distribution of narcan among EMS and red-boxes
to distribute-narcan
  ask EMS [
    ifelse random 1000 < 900 [ set narcan-equiped? true ] [ set narcan-equiped? false ]
  ]
  if narcan-boxes? = "random" [
    create-red-boxes nr-narcan-boxes [
      set shape "circle"
      set size 0.2
      set color red
      set supply 25
      let coors [list pxcor pycor] of one-of patches with [ patch-region != 0]
      let perturb 1
      setxy (item 0 coors + (random-float perturb) - perturb / 2) (item 1 coors + (random-float perturb) - perturb / 2)
    ]
  ]
  if narcan-boxes? = "targeted" [
    create-red-boxes nr-narcan-boxes [
      set shape "circle"
      set size 0.2
      set color red
      set supply 25
      let box-region one-of (list "region1" "region2" "region3")
      if box-region = "region1" [ setxy (random-float 2 - 3.5) (random-float 4 - 3) ]
      if box-region = "region2" [ setxy (random-float 2 + 2) (random-float 4 - 4) ]
      if box-region = "region3" [ setxy (random-float 1 - 1.5) (random-float 3 + 7) ]
    ]
  ]
end


;;;;;;;;;;;;;; 1) code to run the model ;;;;;;;;;;;;;;;;;;;;;
to go
  reset-daily-counts
  ask people [
    determine-use
    aquire-drugs
    consume-drugs
    rescue-or-die
    seek-treatment
    if in-treatment? [consume-treatment]
    aquire-narcan
  ]
  track-outputs
  tick
  if ticks = 8760 [ stop ]
end

to reset-daily-counts
  set OD-counter-today 0
  set OD-deaths-today 0
  set narcan-penetration (count people with [ carrying-narcan? ] / count people) * 100
  ; update reporters
  set treatment-utilization 100 - ((sum [treatment-capacity] of care-centers / total-treatment-capacity) * 100)

  ; resupply red-boxes
  ask red-boxes [ set supply 25 ]
end


;;; 1.1 a procedure that specifies how individuals determine their use for a given day
to determine-use
  ; update the history of use
  ifelse use-today? [ set use-recent-week insert-item 0 use-recent-week 1 ][set use-recent-week insert-item 0 use-recent-week 0]   ;; add a 0/1 to recent usage
  set use-recent-week remove-item 7 use-recent-week                                                                                ;; remove the last item from the list
  set use-today? false                                                                                                             ;; reset the indicator
  ; update the history of OD
  if OD-today? [ set OD-count OD-count + 1 ]                                                                                       ;; update the count of ODs for the individual
  ifelse OD-today? [ set OD-recent-week insert-item 0 OD-recent-week 1 ][set OD-recent-week insert-item 0 OD-recent-week 0 ]       ;; add a 0/1 to recent OD
  set OD-recent-week remove-item 7 OD-recent-week                                                                                  ;; remove the last item from the list
  set OD-today? false                                                                                                              ;; reset the indicator

  set potency 0
  set use-at 0
  set use-in-isolation? 0
  set rescued-today? false
  set intent-to-use? false

  set desire-today random-normal craving (craving / 3)
  ifelse in-treatment? [set intent-to-use? false] [set intent-to-use? random-float 100 < desire-today]
end

;;; 1.2 a procedure that specifies how individuals aquire what they intend to consume on a given day
to aquire-drugs
    if intent-to-use? [
    set use-today? true
    set potency (craving / 100 ) * random-gamma ( 2.5 * 2.5 / 50) (1 / (50 / 2.5))
  ]
end

;;; 1.3 a procedure that specifies how individuals consume drugs, and potentially OD
to consume-drugs
  ifelse use-today? [
    set use-at selected-use-location
    set use-in-isolation? selected-way-of-using

    set tolerance min (list (tolerance + 2) 100)
    set craving min (list ( craving + 1 + sum use-recent-week) 100)
    set OD-today? check-for-overdose
    if OD-today? [
      set OD-counter-today OD-counter-today + 1
      set OD-counter OD-counter + 1
    ]
  ][
   ifelse in-treatment? [
      set craving max (list (craving - 2) 1)
      set tolerance max (list (tolerance - 1) 5)
    ][
      set craving max (list (craving - 1) 10)
      set tolerance max (list (tolerance - 1) 5)]
  ]
end

to-report selected-use-location
  let answers (list "home" "public" "other")
  let pairs (map list answers use-location-pref)
  let loc first rnd:weighted-one-of-list pairs [ [p] -> last p ]
  report loc
end

to-report selected-way-of-using
  let isolated? random-float 100
  ifelse isolated? < use-isolation-rate [ report true][report false]
end

;;; sensitivity to OD is determined in this procedure, both the tolerance inflation factor (below) and the potency calculation in the the aquire drug procedure (1.2) have a huge impact on the daily number of overdoses
to-report check-for-overdose
  report ifelse-value potency > tolerance [ true ][ false ]
end


;;; 1.4
to rescue-or-die
  if OD-today? [
    ifelse Rescue-event? [
      set rescued-today? true
      set rescue-counter rescue-counter + 1
    ][
      let info one-of pop-data
      hatch-people 1 [
        ;demographics
        set race item 0 info
        set gender item 1 info
        set age int (item 2 info)
        set region item 3 info
        find-residence-location

        ;use parameters
        set craving random-float 100
        set tolerance personal-tolerance
        set use-location-pref personal-location-pref
        set use-isolation-rate personal-isolation-rate
        set use-recent-week  (list use-flip use-flip use-flip use-flip use-flip use-flip use-flip )
        set use-today? use-flip

        ; treatment parameters
        set treatment-today? false
        set personal-motivation random 100

        ;OD parameters
        set OD-today? false
        set OD-count 0
        set OD-recent-week (list 0 0 0 0 0 0 0 )

        ; narcan info
        set carrying-narcan? false
        set narcan-closeby? any? red-boxes in-radius 0.5 or any? narcan-distributors in-radius 0.5
        set narcan-available?  any? red-boxes in-radius 1 or any? narcan-distributors in-radius 1
        set aware-of-narcan? false

        ;visualization
        set size 0.2
        set shape "person"
        set color blue
        if not people-visible? [hide-turtle]
      ]

      set OD-deaths-today OD-deaths-today + 1
      ( ifelse
        last-treated = 0 [set OD-death-of-untreated OD-death-of-untreated + 1]
        last-treated > (ticks - 30) [set OD-death-of-recently-treated OD-death-of-recently-treated + 1]
        []
        )

      set OD-deaths OD-deaths + 1
      die
    ]
  ]
end

to-report Rescue-event?
  let rescued? FALSE
  let EMS-available? FALSE
  if any? EMS with [narcan-equiped?] in-radius 0.75 [ set EMS-available? TRUE ]
  ifelse use-in-isolation? [
    if use-at = "home" []
    if use-at = "public" [
      if EMS-available? and random 100 < 30 [
        set rescued? true
        set rescue-by-EMS rescue-by-EMS + 1
      ]
    ]
    if use-at = "other"[
      if EMS-available? and random 100 < 15 [
        set rescued? true
        set rescue-by-EMS rescue-by-EMS + 1
      ]
    ]
  ][
    if use-at = "home" [
      if carrying-narcan? or random 100 < narcan-penetration [ set rescued? true
       set rescue-by-friend rescue-by-friend + 1
      ]
      if EMS-available? [
        set rescued? true
        set rescue-by-EMS rescue-by-EMS + 1
      ]
    ]
    if use-at = "public" [
      ifelse carrying-narcan? and random 100 < 30 or random 100 < narcan-penetration [
        set rescued? true
        set rescue-by-friend rescue-by-friend + 1
      ][
        if EMS-available? [
          set rescued? true
          set rescue-by-EMS rescue-by-EMS + 1
        ]
      ]
    ]
    if use-at = "other"[
      ifelse carrying-narcan? and random 100 < 15 or random 100 < narcan-penetration [
        set rescued? true
        set rescue-by-friend rescue-by-friend + 1
      ][
        if EMS-available? and random 100 < 50 [
          set rescued? true
          set rescue-by-EMS rescue-by-EMS + 1
        ]
      ]
    ]
  ]
report rescued?
end





;;; 1.5 a procedure that specifies how individuals potentially seek to connect to treatment
to seek-treatment
  set personal-motivation one-of (list (personal-motivation - 1) personal-motivation (personal-motivation + 1))
  if personal-motivation > 100 [set personal-motivation 100]
  if personal-motivation < 0 [set personal-motivation 0]

  if not in-treatment? [
    if care-seeking-duration = 0 [
      set care-seeking? FALSE
    ]
    if care-seeking? [
      set care-seeking-duration care-seeking-duration - 1
    ]
    ; PART 1:
    ; For those not in jail, there is a chance of becoming ready for change
    ; with 7 days of staying ready, and 20% of the population being ready at any time, the daily rate of newly ready people is 2.8571% which should come from 80% non-ready folks, equaling 3.571% of that population
    ; !!! potentially this rate will need to be made conditional on use frequency, craving, drug type, etc !!!
    if not care-seeking? and not in-jail? and random-float 100 < 3.571 [
      set care-seeking? TRUE
      set care-seeking-duration 7
    ]

    ; PART 2: Jail interactions
    ; For those in jail there could be an extra high chance of becoming ready for change while the default in florida remains unchange in our default
    if not care-seeking? and in-jail? and random-float 100 < (3.571 * 1) [
      set care-seeking? TRUE
      set care-seeking-duration 7
    ]
    ; PART 3: Primary care interactions
    ; for those that interact with the care system there is an additional probability of starting to seek treatment
    ; based on 82% of adults having a yearly doctor visit, we determine the daily probability of a docs visits to be 0.00469
    if not care-seeking? and not in-jail? and random-float 1 < 0.00469 [
      if random 100 < 25 and random 100 < 20[                                             ; with a 25% chance a visit results in a diagnosis, and 20% will be ready to change
        set care-seeking? TRUE
        set care-seeking-duration 7
      ]
    ]
    ; PART 4: ED visits
    ; for those that interact with the Emergency Departments there is an additional probability of starting to seek treatment
    ; based on 19% of adults having a yearly ED visit, we determine the daily probability of a ED visits to be 0.00058
    if not care-seeking? and not in-jail? and random-float 1 < 0.00058 [
      if random 100 < 50 and random 100 < 20 [                                             ; with a 50% chance a visit results in a diagnosis, and 20% will be ready to change
        set care-seeking? TRUE
        set care-seeking-duration 7
      ]
    ]

    ; PART 5: rescue events
    ; for those that experience a rescue event, there is an additional probability of starting to seek treatment
    if rescued-today? [
      if random 100 < 10 [                                             ; with a 10% chance a rescue event will results in a desire to seek treatment
        set care-seeking? TRUE
        set care-seeking-duration 7
      ]
    ]
  ]

  ; once intend to start care is obtained those that want to initiate treatment will attempt to do so
  if care-seeking? and random personal-motivation > 25 [
    set my-treatment-provider rnd:weighted-one-of treatment-options [(1 / distance myself) * treatment-capacity]
    set my-treatment-distance [distance myself] of my-treatment-provider
    if [treatment-capacity] of my-treatment-provider > 0 [
      ask my-treatment-provider [ set treatment-capacity treatment-capacity - 1]
      set in-treatment? true
      set care-seeking? false
    ]
  ]


end





;;; 1.6 a procedure that specifies how individuals consume treatment, are retained or drop out, and adjusts their tolerance and cravings because of it
to consume-treatment
  potentially-drop-out
  if in-treatment? [
    get-dose-MAT
    set treatment-today? true
    set last-treated ticks
  ]
end

to potentially-drop-out
  let drop-out-chance max (list (max (list (20 / ( 1 + days-in-treatment)) 0) + craving * 0.2 + my-treatment-distance - (days-in-treatment / 20)) 1 )
  if random 100 < drop-out-chance [
    set in-treatment? false
    set days-in-treatment 0
    set treatment-today? false
    ask my-treatment-provider [ set treatment-capacity treatment-capacity + 1]
    set my-treatment-provider nobody
  ]
end

to get-dose-MAT
  set days-in-treatment days-in-treatment + 1
  set craving craving * 0.5
end




;;; 1.7 a procedure that specifies how individuals potentially attempt to aquire narcan kits to carry on them
to aquire-narcan
  ; random chance of losing narcan-kits 1/20, rougly 3 weeks
  if carrying-narcan? and random 100 < 5 [ set carrying-narcan? false]
  if not carrying-narcan? [
    ; obtain narcan through leave-behind program
    if rescued-today? and leave-behind-narcan? [
      set carrying-narcan? true
      set aware-of-narcan? true
    ]
    ; obtain narcan through care-contact
    if treatment-today? [
      if random 100 < treatment-narcan-supply-likelihood [
        set carrying-narcan? true
      ]
      set aware-of-narcan? true
    ]
    ; obtain narcan through proximity opportunity
    if narcan-closeby? and random 30 < 1 [
      set aware-of-narcan? true
      ifelse any? narcan-distributors with [supply > 0] in-radius 0.5 [
        ask one-of narcan-distributors with [supply > 0] in-radius 0.5 [
          provide-narcan ]
        set carrying-narcan? true
      ][
        if any? red-boxes in-radius 0.5 with [supply > 0] [
          ask one-of red-boxes in-radius 0.5 with [supply > 0] [
            provide-narcan ]
          set carrying-narcan? true
        ]
      ]
    ]
    ; obtain narcan through seeking it out
    if narcan-closeby? and aware-of-narcan? and random 30 < 1 [
      set aware-of-narcan? true
      ifelse any? narcan-distributors with [supply > 0] in-radius 1 [
        ask one-of narcan-distributors with [supply > 0] in-radius 1 [
          provide-narcan ]
        set carrying-narcan? true
      ][
        if any? red-boxes in-radius 1 with [supply > 0] [
          ask one-of red-boxes in-radius 1 with [supply > 0] [
            provide-narcan ]
          set carrying-narcan? true
        ]
      ]
    ]
  ]

end
to provide-narcan
  set supply supply - 1
end
;;; 1.8 a procedure that tracks/measures all desired outputs over time
to track-outputs
  if ticks = burn-in-time or ticks = burn-in-time + 366 [
    set rescue-counter 0
    set rescue-by-EMS 0
    set rescue-by-friend 0
    set OD-deaths 0
    set OD-counter 0
    set OD-death-of-recently-treated 0
    set OD-death-of-untreated 0
  ]
end






















;;;;;;;;;;;;;; X) supporting procedures ;;;;;;;;;;;;;;;;;;;;;

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
@#$#@#$#@
GRAPHICS-WINDOW
146
10
879
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
911
16
1083
49
population
population
5000
20000
18000.0
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
40.0
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
57
74
120
107
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

PLOT
1291
523
1491
673
mean tolerance
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [tolerance] of people"

PLOT
1495
522
1695
672
mean craving
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [craving] of people"

BUTTON
58
120
121
153
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

PLOT
1694
522
1894
672
desire to use
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot (count people with [intent-to-use?]) / 120"

PLOT
1292
354
1492
504
daily-ODs
NIL
NIL
50.0
1000.0
0.0
20.0
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot OD-counter-today"

MONITOR
934
350
1031
395
NIL
rescue-counter
0
1
11

MONITOR
934
395
1031
440
NIL
OD-deaths
17
1
11

MONITOR
1031
372
1101
417
Rescue %
(rescue-counter / OD-counter) * 100
1
1
11

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

PLOT
1496
354
1696
504
% carrying narcan
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot narcan-penetration"

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

PLOT
1696
354
1896
504
% in-treatment
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot (count people with [treatment-today?] / count people ) * 100"

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

MONITOR
1134
455
1258
500
treatment utilization
treatment-utilization
2
1
11

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
48
175
130
208
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

PLOT
1072
523
1272
673
% of users daily
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot (count people with [use-today?] / count people) * 100"

MONITOR
934
439
1047
484
NIL
OD-death-of-recently-treated
0
1
11

MONITOR
934
483
1047
528
NIL
OD-death-of-untreated
17
1
11

BUTTON
48
215
139
248
go-another year
repeat 365 [go]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1047
439
1105
484
% death among recent treatment
(OD-death-of-recently-treated / od-deaths) * 100
2
1
11

CHOOSER
910
78
1312
123
Intervention-package
Intervention-package
"0" "1" "2" "3" "4" "5" "6" "7" "8" "9"
7

MONITOR
1144
351
1249
396
NIL
rescue-by-friend
0
1
11

MONITOR
1144
396
1249
441
NIL
rescue-by-EMS
17
1
11

MONITOR
1496
309
1590
354
% with narcan
narcan-penetration
2
1
11

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
NetLogo 6.2.1
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
0
@#$#@#$#@
