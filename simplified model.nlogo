extensions [csv array table]
globals [meat-hab-list meat-color-list meat-attr-list ; List of [influence frequency] pairs for meat friends
  nonmeat-attr-list  ; List for non-meat friends
  unknown-attr-list friend-attributes-dict avg-intention-meat-eaters
  avg-intention-reduced-eaters
  avg-intention-non-eaters
  agent0-history  ; 用于存储Agent 0的历史数据
  agent0-tick-data  ; 当前tick的数据
  ; ===== 分析用全局变量 =====
  ;; 构念贡献追踪
  attitude-contribution    ; 态度对意图变化的平均贡献
  norm-contribution        ; 规范对意图变化的平均贡献
  exp-contribution-list    ; 每个tick的体验性态度贡献
  inst-contribution-list   ; 每个tick的工具性态度贡献
  inj-contribution-list    ; 每个tick的指令性规范贡献
  desc-contribution-list   ; 每个tick的描述性规范贡献

  ;; 异质性分析
  early-adopter-ids        ; 早期改变者的ResponseId列表
  resister-ids             ; 顽固派的ResponseId列表
  adopter-profile          ; 早期改变者特征 [age, gender, initial-intention, friend-count]

  ;; 路径分析
  transition-paths         ; 所有转变路径 [[agent-id, from-hab, to-hab, tick], ...]
  relapse-count            ; 回弹次数
  total-transitions        ; 总转变次数

  ;; 时间分析
  tipping-point-tick       ; 引爆点tick（转变加速的拐点）
  stabilization-tick       ; 稳定tick（连续N个tick无变化）
  tick-distribution        ; 每个tick的饮食分布 [[tick, no-meat%, reduced%, meat%], ...]
  ;; 个人追踪
  tracked-agents           ; 追踪的agent列表（用于个体分析）

] ;; Declare global variables

breed [persons person]
undirected-link-breed [ mutual-links mutual-link ]    ; mutual friends
directed-link-breed [ one-way-links one-way-link ]    ; one way friends



persons-own
[
  ResponseId
  gender
  age
  meat-hab ;; 0 = no meat, 1 = less meat, 2 = meat
  inertia-list
  Experiential_Meat ;RAA construct - Attitude
  Instrumental_Meat ;RAA construct - Attitude
  Injunctive_meat ;RAA construct - Norm
  Descriptive_meat ;RAA construct - Norm
  capacity_meat  ;RAA construct - PBC
  autonomy_meat ;RAA construct - PBC
  Intention_Regression ; overall intention value caculated by each construct*weight
  w_Injunctive_M ;weight derived from regression
  w_Descriptive_M
  w_Capacity_M
  w_Autonomy_M
  w_Experiential_M
  w_Instrumental_M
  w_Injunctive_R
  w_Descriptive_R
  w_Capacity_R
  w_Autonomy_R
  w_Instrumental_R
  w_Experiential_R
  w_Injunctive_N
  w_Descriptive_N
  w_Capacity_N
  w_Autonomy_N
  w_Instrumental_N
  w_Experiential_N
  Instrumental_All ;questionnaire items
  Experiential_All ;questionnaire items
  diet-duration  ; Duration of maintaining the current diet (number of cycles)
  current-meat-friends
  current-nonmeat-friends
  total-friends-created
  needed-meat-friends
  needed-nonmeat-friends
  my-friend-attributes-list  ; Store this person's friends' requirements list
  prev-Experiential_Meat  ; 上一次的Experiential_Meat值
  prev-Instrumental_Meat  ; 上一次的Instrumental_Meat值
  prev-Injunctive_meat    ; 上一次的Injunctive_meat值
  prev-Descriptive_meat   ; 上一次的Descriptive_meat值
  prev-meat-hab           ; 上一次的饮食习惯
  initial-intention      ; 初始意图（用于异质性分析）
  initial-meat-hab       ; 初始饮食（用于比较）
]

;;; LINK Variables
links-own [
  influence
  frequency
  friend-diet-type ;; add a variable to save friend's diet type
]
to setup
  clear-all
  ;random-seed 12345  ; set random seed
  file-close-all
  reset-ticks
  setup-globals
  load-friend-attributes ;; make sure to load friend attribute before create persons
  setup-persons
  clean-link-data
  calculate-thresholds
  ;visualize-agent0-network
; 添加初始意图记录
  ask persons [
    set initial-intention Intention_Regression
    set initial-meat-hab meat-hab
  ]

  setup-analysis  ; 初始化分析变量
end




to setup-analysis
  set attitude-contribution 0
  set norm-contribution 0
  set exp-contribution-list []
  set inst-contribution-list []
  set inj-contribution-list []
  set desc-contribution-list []

  set early-adopter-ids []
  set resister-ids []
  set adopter-profile []

  set transition-paths []
  set relapse-count 0
  set total-transitions 0

  set tipping-point-tick -1
  set stabilization-tick -1
  set tick-distribution []


  ; 追踪几个代表性agent
  set tracked-agents (list
    person 0                                      ; 第一个agent
    one-of persons with [meat-hab = 2]            ; 随机一个肉食者
    one-of persons with [meat-hab = 1]            ; 随机一个减肉者
    one-of persons with [meat-hab = 0]            ; 随机一个不吃肉者
  )
end


to setup-globals
  set meat-hab-list ["no meat" "less meat" "meat"]
  set meat-color-list [green orange red]
  set friend-attributes-dict [] ;; Initialize the dictionary

end


to setup-persons
  create-persons-from-data
  ask persons
  [
    set shape "person"
    set size 0.7
    set color item meat-hab meat-color-list
        ; 初始化历史变量
    set prev-Experiential_Meat Experiential_Meat
    set prev-Instrumental_Meat Instrumental_Meat
    set prev-Injunctive_meat Injunctive_meat
    set prev-Descriptive_meat Descriptive_meat
    set prev-meat-hab meat-hab

  ]

  create-friendships             ; Call the procedure to create friendships (links)
  layout-circle persons 322
    ; 初始化Agent 0历史记录
  set agent0-history []
  record-agent0-initial-state

print "=== DATA CHECK ==="
ask persons [
  if who < 20 [  ; 检查前5个人
    print (word "Agent " who ": Exp_All=" Experiential_All " Inst_All=" Instrumental_All)
  ]
]

end

; 记录Agent 0的初始状态
to record-agent0-initial-state
  let agent0 person 0
  if agent0 != nobody [
    ask agent0 [
      let initial-data (list
        (list "Tick" 0)
        (list "Meat_Hab" meat-hab)
        (list "Experiential_Meat" Experiential_Meat)
        (list "Instrumental_Meat" Instrumental_Meat)
        (list "Injunctive_meat" Injunctive_meat)
        (list "Descriptive_meat" Descriptive_meat)
        (list "Intention" Intention_Regression)
        (list "Total_Friends" count my-links)
        (list "Meat_Friends" current-meat-friends)
        (list "NonMeat_Friends" current-nonmeat-friends)
      )

      set agent0-history lput initial-data agent0-history

      print "=== AGENT 0 INITIAL STATE ==="
      print (word "ResponseId: " ResponseId)
      print (word "Meat Habit: " meat-hab " (" item meat-hab meat-hab-list ")")
      print (word "Experiential_Meat: " Experiential_Meat)
      print (word "Instrumental_Meat: " Instrumental_Meat)
      print (word "Injunctive_meat: " Injunctive_meat)
      print (word "Descriptive_meat: " Descriptive_meat)
      print (word "Intention_Regression: " Intention_Regression)
      print (word "Total Friends: " count my-links)
      print (word "Meat Friends: " current-meat-friends)
      print (word "Non-Meat Friends: " current-nonmeat-friends)
      print "=============================="

      ; 打印朋友详细信息
      print "--- FRIEND DETAILS ---"
      let friend-num 1
      ask my-links [
        let friend other-end
        print (word "Friend " friend-num ": " [ResponseId] of friend)
        print (word "  Influence: " influence " Frequency: " frequency)
        print (word "  Friend Diet Type: " friend-diet-type)
        print (word "  Friend's Meat Hab: " [meat-hab] of friend " (" item [meat-hab] of friend meat-hab-list ")")
        set friend-num friend-num + 1
      ]
    ]
  ]
end


to create-persons-from-data
  file-close-all
  file-open "clean_data_1.csv"
  let var-names csv:from-row file-read-line


  ;; ===== read the data and random shuffle =====
  let all-rows []
  while [not file-at-end?] [
    set all-rows lput csv:from-row file-read-line all-rows
  ]

  file-close-all

  random-seed 42  ;; ← set the seed to make sure the outcome is the same
  set all-rows shuffle all-rows  ;; ← random shuffle

  let person-count 0
  let no-meat-count 0
  let less-meat-count 0
  let meat-count 0

  let target-no-meat no-meat-slider
  let target-less-meat less-meat-slider
  let target-meat meat-slider

 foreach all-rows [ row ->

    let no-meat? item (position "no_meat" var-names) row
    let reduced? item (position "reduced" var-names) row
    let this-meat-hab 2
    if no-meat? [ set this-meat-hab 0 ]
    if reduced? [ set this-meat-hab 1 ]

    ; Only create this person if we still need this diet type
    if (this-meat-hab = 0 and no-meat-count < target-no-meat) or
       (this-meat-hab = 1 and less-meat-count < target-less-meat) or
       (this-meat-hab = 2 and meat-count < target-meat) [

      create-persons 1 [
        set ResponseId item (position "ResponseId" var-names) row
        set gender item (position "Q4" var-names) row
        set age item (position "Q6" var-names) row
        set Experiential_Meat item (position "Experiential_Meat" var-names) row
        set Instrumental_Meat item (position "Instrumental_Meat" var-names) row
        set Experiential_All item (position "Experiential_All" var-names) row
        set Instrumental_All item (position "Instrumental_All" var-names) row
        set Injunctive_meat item (position "Injunctive_meat" var-names) row
        set Descriptive_meat item (position "Descriptive_meat" var-names) row
        set capacity_meat item (position "capacity_meat" var-names) row
        set autonomy_meat item (position "autonomy_meat" var-names) row
        set w_Injunctive_M item (position "w_Injunctive_M" var-names) row
        set w_Descriptive_M item (position "w_Descriptive_M" var-names) row
        set w_Capacity_M item (position "w_Capacity_M" var-names) row
        set w_Autonomy_M item (position "w_Autonomy_M" var-names) row
        set w_Experiential_M item (position "w_Experiential_M" var-names) row
        set w_Instrumental_M item (position "w_Instrumental_M" var-names) row
        set w_Injunctive_R item (position "w_Injunctive_R" var-names) row
        set w_Descriptive_R item (position "w_Descriptive_R" var-names) row
        set w_Capacity_R item (position "w_Capacity_R" var-names) row
        set w_Autonomy_R item (position "w_Autonomy_R" var-names) row
        set w_Instrumental_R item (position "w_Instrumental_R" var-names) row
        set w_Experiential_R item (position "w_Experiential_R" var-names) row
        set w_Injunctive_N item (position "w_Injunctive_N" var-names) row
        set w_Descriptive_N item (position "w_Descriptive_N" var-names) row
        set w_Capacity_N item (position "w_Capacity_N" var-names) row
        set w_Autonomy_N item (position "w_Autonomy_N" var-names) row
        set w_Instrumental_N item (position "w_Instrumental_N" var-names) row
        set w_Experiential_N item (position "w_Experiential_N" var-names) row
        set Intention_Regression item (position "Intention_Regression" var-names) row
        set meat-hab this-meat-hab
      ]

      ; Update counters OUTSIDE the create-persons block (in observer context)
      if this-meat-hab = 0 [ set no-meat-count no-meat-count + 1 ]
      if this-meat-hab = 1 [ set less-meat-count less-meat-count + 1 ]
      if this-meat-hab = 2 [ set meat-count meat-count + 1 ]
      set person-count person-count + 1

      ; Debug output
      if (person-count mod 50 = 0) [
        print (word "Created " person-count " persons - no-meat: " no-meat-count " less-meat: " less-meat-count " meat: " meat-count)
      ]
    ]
  ]
  file-close

  print (word "Created " person-count " persons for testing")
  print "=== DIET DISTRIBUTION ==="
  print (word "Total persons created: " person-count)
  print (word "No meat (0): " no-meat-count " agents")
  print (word "Less meat (1): " less-meat-count " agents")
  print (word "Meat eater (2): " meat-count " agents")
  print (word "Percentages - No meat: " precision (no-meat-count / person-count * 100) 1 "%")
  print (word "              Less meat: " precision (less-meat-count / person-count * 100) 1 "%")
  print (word "              Meat eater: " precision (meat-count / person-count * 100) 1 "%")
  print "=========================="
end



to load-friend-attributes
  file-close-all
  file-open "friend_data.csv" ; Open your second file with friend info
  set friend-attributes-dict [] ; Initialize the global dictionary

  let var-names csv:from-row file-read-line
 ; print column names
  print (word "Column names in friend_data.csv: " var-names)

  ; Loop through every row of the file
  while [not file-at-end?] [
    let row csv:from-row file-read-line
    ; Extract the data from the row using the column names
    let source-id item (position "ResponseId" var-names) row
    let friend-num item (position "Friends_Number" var-names) row
    let friend-freq item (position "frequency" var-names) row ; Convert to number
    let friend-diet item (position "diet" var-names) row ; e.g., "meat", "nonmeat", "unknown"
    let friend-inf  item (position "influence" var-names) row ; Convert to number

    ; Debug each row for the specific ResponseId we're interested in
    if source-id = "R_2WWm1oc6kX35SBr" [
      print (word "DEBUG: Processing row for " source-id " - Friend#: " friend-num " freq: " friend-freq " diet: " friend-diet " inf: " friend-inf)
    ]
      ; Create a list for this friend's attributes: [influence frequency diet]
    let friend-attr-list (list friend-inf friend-freq friend-diet)

    ; Check if we already have an entry for this source-id in the dictionary
    let existing-entry false  ; Will store the found entry if it exists
    let entry-index -1  ; Will store the position (index) of the found entry
    let idx 0 ; Counter to loop through the list

    ; look up existing entry
    while [idx < length friend-attributes-dict and not existing-entry] [
      let entry item idx friend-attributes-dict ; Get the item at current index
      if (is-list? entry and length entry > 0 and item 0 entry = source-id) [
        set existing-entry entry  ; Store the entire found entry
        set entry-index idx   ; Remember its position in the big list
      ]
      set idx idx + 1 ; Increment the counter
    ]

    ifelse (existing-entry != false) [
      ; If entry exists, append the new friend attributes to its list
      let updated-entry (lput friend-attr-list existing-entry)
      set friend-attributes-dict replace-item entry-index friend-attributes-dict updated-entry
    ]
    [
      ; If no entry exists, create a new one: [source-id [friend-attr-list]]
      set friend-attributes-dict lput (list source-id friend-attr-list) friend-attributes-dict
    ]
  ]
  file-close
  print (word "Loaded friend attributes for " length friend-attributes-dict " respondents.")

  ; Upon completion of loading, conduct a thorough inspection.
  print (word "=== LOADING COMPLETE ===")
  print (word "Total entries in dictionary: " length friend-attributes-dict)

  ; check top 10 items
  let i 0
  while [i < min (list 10 length friend-attributes-dict)] [
    let entry item i friend-attributes-dict
    if (is-list? entry and length entry > 0) [
      let source-id item 0 entry
      let friend-count length but-first entry
      print (word "Entry " i ": " source-id " has " friend-count " friends")
    ]
    set i i + 1
  ]

  ; check if specific person exist
  let test-ids ["R_24UniyXllZYHYJP" "R_8alxRdcikRgMuwU" "R_2jwAiOblkyZWHNQ"]
  foreach test-ids [
    [test-id] ->
    let found false
    foreach friend-attributes-dict [
      [entry] ->
      if (is-list? entry and length entry > 0 and item 0 entry = test-id) [
        set found true
      ]
    ]
    ifelse found [
      print (word "✓ Found data for: " test-id)
    ]
    [
      print (word "✗ MISSING data for: " test-id)
    ]
  ]
end


to create-friendships
    clear-links

  ;  Consider diet=3 situation recalculate the number of friends needed

    ; Initialize friend counters for all persons
  ask persons [
    set current-meat-friends 0
    set current-nonmeat-friends 0
    set total-friends-created 0
    set my-friend-attributes-list []
  ]

  ;;; Step One: Load each individual's friends attribute list
  ask persons [
    ; Find the entry for this agent in the dictionary
    let my-entry false
    let idx 0

    ; Find the entry for the current agent
    while [idx < length friend-attributes-dict and my-entry = false] [
      let entry item idx friend-attributes-dict
      if (is-list? entry and length entry > 0 and item 0 entry = ResponseId) [
        set my-entry entry
      ]
      set idx idx + 1
    ]

    ; If found, get the list of friend attributes
    if (is-list? my-entry) [
      set my-friend-attributes-list but-first my-entry ; Removes the ResponseId, leaves the list of attributes
      print (word "Agent " ResponseId " has " length my-friend-attributes-list " friends to create.")


    ; check the original needs
    let temp-meat-needs 0
    let temp-nonmeat-needs 0
    let temp-unknown-needs 0

    foreach my-friend-attributes-list [
      [attr-list] ->
      let diet item 2 attr-list
      if (diet = 1) [ set temp-meat-needs temp-meat-needs + 1 ]
      if (diet = 2) [ set temp-nonmeat-needs temp-nonmeat-needs + 1 ]
      if (diet = 3) [ set temp-unknown-needs temp-unknown-needs + 1 ]
    ]

    ; randomly assign unknown needs
    repeat temp-unknown-needs [
      if (random 2 = 0) [ ; 50% possibilities
        set temp-meat-needs temp-meat-needs + 1
      ]
        set temp-nonmeat-needs temp-nonmeat-needs + 1

    ]

    set needed-meat-friends temp-meat-needs
    set needed-nonmeat-friends temp-nonmeat-needs

    print (word " Agent " ResponseId " needs total: " length my-friend-attributes-list
           " (meat: " needed-meat-friends " non-meat: " needed-nonmeat-friends ")")
  ]
  ]
  ;;;  First attempt mutual connections; if unsuccessful, proceed to one-way connections.
  print "=== FRIENDSHIP MATCHING ==="
  ask persons [
    ; Address each friend's request individually
    foreach my-friend-attributes-list [
      [attr-list] ->

      ; If the maximum number of friends has been reached, skip.
      if (total-friends-created < length my-friend-attributes-list) [

        ; Extract friend attributes
        let diet-type item 2 attr-list
        let required-inf item 0 attr-list
        let required-freq item 1 attr-list

        ; Handling unknown dietary types
        if (diet-type = 3) [
          set diet-type random 2 + 1  ; Randomly converted to either 1 or 2
        ]

        ; Check whether this type of friend is still needed
        let need-this-type? false
        if (diet-type = 1) [ set need-this-type? (current-meat-friends < needed-meat-friends) ]
        if (diet-type = 2) [ set need-this-type? (current-nonmeat-friends < needed-nonmeat-friends) ]

        if need-this-type? [
          print (word "Agent " ResponseId " seeking " (ifelse-value (diet-type = 1) ["meat"] ["non-meat"]) " friend")

          ;;; Step One: Attempt two-way matching
          let mutual-candidates other persons with [
            ; not linked with me
            link-with myself = nobody
            ; Dietary Type Matching
            and (
              (diet-type = 1 and (meat-hab = 1 or meat-hab = 2)) or
              (diet-type = 2 and meat-hab = 0)
            )
            ; The other party also requires friends and has not yet reached their maximum number of friends.
            and (total-friends-created < length my-friend-attributes-list)
            ; The other person also needs a friend like me.
            and (
              (([meat-hab] of myself = 1 or [meat-hab] of myself = 2) and
               [current-meat-friends] of myself < [needed-meat-friends] of myself) or
              ([meat-hab] of myself = 0 and
               [current-nonmeat-friends] of myself < [needed-nonmeat-friends] of myself)
            )
          ]

          ifelse (count mutual-candidates > 0) [
            ; Identify mutual candidates and establish two way connections
            let new-friend one-of mutual-candidates

            create-mutual-link-with new-friend [
              set influence required-inf
              set frequency required-freq
              set friend-diet-type diet-type
              ;set label (word "Mutual: Inf:" influence " Freq:" frequency " Diet:" diet-type)
              set color yellow
            ]

            ; update my counts
            if (diet-type = 1) [ set current-meat-friends current-meat-friends + 1 ]
            if (diet-type = 2) [ set current-nonmeat-friends current-nonmeat-friends + 1 ]
            set total-friends-created total-friends-created + 1

            ; update friend's counts
            let i-am-meat-eater? (meat-hab > 0)
            ask new-friend [
              set total-friends-created total-friends-created + 1
              if i-am-meat-eater? [ set current-meat-friends current-meat-friends + 1 ]
              if (not i-am-meat-eater?) [ set current-nonmeat-friends current-nonmeat-friends + 1 ]
            ]

            print (word "Created MUTUAL link: " ResponseId " <-> " [ResponseId] of new-friend " diet:" diet-type)
          ]
          [
            ;;; Step Two: If no mutual candidates exist, attempt a unilateral match.
            let one-way-candidates other persons with [
              ; not my friend
              link-with myself = nobody
              ; dietary type matching
              and (
                (diet-type = 1 and (meat-hab = 1 or meat-hab = 2)) or
                (diet-type = 2 and meat-hab = 0)
              )
            ]

            ifelse (count one-way-candidates > 0) [
              ; Identify unidirectional candidates and establish unidirectional connections
              let new-friend one-of one-way-candidates

              create-one-way-link-to new-friend [
                set influence required-inf
                set frequency required-freq
                set friend-diet-type diet-type
                ;set label (word "One-way: Inf:" influence " Freq:" frequency " Diet:" diet-type)
                set color blue
              ]

              ; update my counts only
              if (diet-type = 1) [ set current-meat-friends current-meat-friends + 1 ]
              if (diet-type = 2) [ set current-nonmeat-friends current-nonmeat-friends + 1 ]
              set total-friends-created total-friends-created + 1

              print (word "Created ONE-WAY link: " ResponseId " -> " [ResponseId] of new-friend " diet:" diet-type)
            ]
            [

              print (word "No candidate found for " ResponseId " requiring diet " diet-type)
            ]
          ]

          ; print my status
          print (word "Agent " ResponseId " now has " total-friends-created "/" length my-friend-attributes-list " friends")
        ]

      ]
    ]
  ]

  print "=== FINAL RESULTS ==="
  let total-persons count persons
  let MutualLinks count mutual-links
  let Oneway-links count one-way-links
  let total-links MutualLinks + Oneway-links
  let avg-links total-links / total-persons

  let unsatisfied-persons persons with [total-friends-created < length my-friend-attributes-list]
  let no-friends-persons persons with [total-friends-created = 0]

  print (word "Total persons: " total-persons)
  print (word "Mutual friendships: " MutualLinks)
  print (word "One-way friendships: " Oneway-links)
  print (word "Total links created: " total-links)
  print (word "Average links per person: " precision avg-links 2)
  print (word "Persons with incomplete friends: " count unsatisfied-persons)
  print (word "Persons with no friends: " count no-friends-persons)

  ask persons [
    if total-friends-created > 10 [
      print (word "WARNING: Agent " ResponseId " has " total-friends-created " friends")
    ]
  ]
end



to debug-friends-count
  let agent0 person 0
  if agent0 != nobody [
    print "=== DEBUG Agent 0 Friends ==="
    print (word "Total links: " count [my-links] of agent0)
    print (word "ResponseId: " [ResponseId] of agent0)
    ; List all friends and their relationship strengths
    ask agent0 [
      print "Friends details:"
      ask my-links [
        let friend other-end
        print (word "  Friend " [who] of friend ": influence=" influence " frequency=" frequency
)
      ]
    ]

;    ; Check for duplicate links
;    let unique-friends remove-duplicates [other-end] of [my-links] of agent0
;    print (word "Unique friends: " count unique-friends)
;    print "============================="
  ]
end

to calculate-thresholds
  ; calculate thresholds of different diet groups
  set avg-intention-meat-eaters mean [Intention_Regression] of persons with [meat-hab = 2]
  set avg-intention-reduced-eaters mean [Intention_Regression] of persons with [meat-hab = 1]
  set avg-intention-non-eaters mean [Intention_Regression] of persons with [meat-hab = 0]

  print (word "avg - meat eater: " avg-intention-meat-eaters)
  print (word "avg - reduced meat eater: " avg-intention-reduced-eaters)
  print (word "avg - non meat eater: " avg-intention-non-eaters)
end

to clean-link-data
  ask links [
    if (is-string? frequency) [
      ifelse (frequency = " " or frequency = "") [
        set frequency 0
      ] [
        set frequency read-from-string frequency
      ]
    ]
    if (is-string? influence) [
      ifelse (influence = " " or influence = "") [
        set influence 0
      ] [
        set influence read-from-string influence
      ]
    ]
  ]
end

to interact-with-friends
  ask persons [
    ; Initialise the total impact received in this round
    let total-experiential-influence 0
    let total-instrumental-influence 0
    let total-injunctive-influence 0
    let influence-count 0

    ; Save the current agent's values before entering the link context
    let my-experiential-all Experiential_All
    let my-instrumental-all Instrumental_All
    let my-experiential-meat Experiential_Meat
    let my-instrumental-meat Instrumental_Meat
    let my-injunctive-meat Injunctive_meat
    let my-friends count my-links
    let my-who who  ; ← 保存自己的who


    ; interact with each friend
    ask my-links [
      let friend other-end
      ;let interaction-strength (influence * frequency / 100) this was wrong
      ; frequency 1-5（1=high frequency，5=low frequency）
      ; influence: 1-10（10=strong 1=weak）

      let normalized-influence (influence / 10)
      let normalized-frequency ((6 - frequency) / 5)
      let interaction-strength (normalized-influence * normalized-frequency)

       ; ===== Agent 0 的朋友信息 =====
       ; 检查这条link是否连接Agent 0
      let end1-who [who] of end1
      let end2-who [who] of end2

      if my-who = 0 [
        print (word "  Friend " [ResponseId] of friend " (who=" [who] of friend "):")
        print (word "    influence: " influence " freq: " frequency " strength: " interaction-strength)
        print (word "    Friend Exp_Meat: " [Experiential_Meat] of friend " (vs my " my-experiential-meat ")")
        print (word "    Friend Exp_All: " [Experiential_All] of friend " (vs my " my-experiential-all ")")
        print (word "    mutual? " is-mutual-link? self)
        print (word "    end1: " end1-who " end2: " end2-who)
      ]



      ; Determine whether this connection will influence me
      let can-influence-me? false

      ifelse (is-mutual-link? self) [
        ; Two-way connection: We influence each other, so the other person can always affect me.
        set can-influence-me? true
      ]
      [
        ; Unidirectional connection: The starting point is influenced by the endpoint!
        ; If I am the starting point (end1) of this one-way connection, then I shall be influenced by the endpoint.
        if (myself = end1) [
          set can-influence-me? true
        ]
      ]

; Only when the other party can influence me does the influence count.
;The division by 6 serves as a normalization factor:
;Attitudes are measured on a 1-7 scale
;Maximum possible difference = 7 - 1 = 6
;abs(difference) / 6 converts the difference to a 0-1 range
;1 - (difference/6) converts it to a similarity score (1 = identical, 0 = completely opposite)
;This creates a linear similarity function where:
;Same attitude (difference=0) → similarity=1.0
;Moderate difference (difference=3) → similarity=0.5
;Opposite attitudes (difference=6) → similarity=0.0
      if can-influence-me? [
        ; experiential influence
        if (my-experiential-all > 0 and [Experiential_All] of friend > 0) [
          let similarity 1 - (abs (my-experiential-all - [Experiential_All] of friend) / 6)
          let weighted-influence ([Experiential_Meat] of friend - my-experiential-meat) * similarity * interaction-strength
          set total-experiential-influence (total-experiential-influence + weighted-influence)
        ]

        ; instrumental influence
        if (my-instrumental-all > 0 and [Instrumental_All] of friend > 0) [
          let similarity 1 - (abs (my-instrumental-all - [Instrumental_All] of friend) / 6)
          let weighted-influence ([Instrumental_Meat] of friend - my-instrumental-meat) * similarity * interaction-strength
          set total-instrumental-influence (total-instrumental-influence + weighted-influence)
        ]

        ; injunctive norm
        let inj-difference ([Injunctive_meat] of friend - my-injunctive-meat) * interaction-strength
        set total-injunctive-influence (total-injunctive-influence + inj-difference)

        set influence-count (influence-count + 1)
      ]
    ]

; apply influence.
;Experiential influence × 0.15: Only 15% of the calculated experiential influence is applied
;Instrumental influence × 0.15: Only 15% of the calculated instrumental influence is applied
;Injunctive influence × 0.25: 25% of the injunctive norm influence is applied
;Rationale:
;Realistic gradual change: In reality, people don't completely change their attitudes after one interaction
;Cognitive resistance: People have some resistance to attitude change
;Different susceptibility: Normative influence (0.25) is stronger because people are more sensitive to social acceptance and rejection
;Prevents overshooting: Without damping, attitudes could swing wildly between extremes

    if (influence-count > 0) [
      let exp-influence total-experiential-influence * social-influence-rate
      let inst-influence total-instrumental-influence * social-influence-rate
      let inj-influence total-injunctive-influence * social-influence-rate

      set Experiential_Meat bound-value (Experiential_Meat + exp-influence) 1 7
      set Instrumental_Meat bound-value (Instrumental_Meat + inst-influence) 1 7
      set Injunctive_meat bound-value (Injunctive_meat + inj-influence) 1 7
    ]



    ; ===== 添加调试 =====
    if who = 0 [  ; 只检查 Agent 0
      print (word "Agent 0 influence_count: " influence-count)
      print (word "  exp_influence: " total-experiential-influence)
      print (word "  inst_influence: " total-instrumental-influence)
      print (word "  inj_influence: " total-injunctive-influence)
    ]
    ; ===== 调试结束 =====

    if (influence-count > 0) [
      let exp-influence total-experiential-influence * social-influence-rate
      let inst-influence total-instrumental-influence * social-influence-rate
      let inj-influence total-injunctive-influence * social-influence-rate

      ; ===== 调试 =====
      if who = 0 [
        print (word "  AFTER rate: exp=" exp-influence " inst=" inst-influence " inj=" inj-influence)
        print (word "  BEFORE: Exp_Meat=" Experiential_Meat " Inst_Meat=" Instrumental_Meat " Inj_meat=" Injunctive_meat)
      ]

      set Experiential_Meat bound-value (Experiential_Meat + exp-influence) 1 7
      set Instrumental_Meat bound-value (Instrumental_Meat + inst-influence) 1 7
      set Injunctive_meat bound-value (Injunctive_meat + inj-influence) 1 7

      ; ===== 调试 =====
      if who = 0 [
        print (word "  AFTER: Exp_Meat=" Experiential_Meat " Inst_Meat=" Instrumental_Meat " Inj_meat=" Injunctive_meat)
      ]
    ]

     ; update descriptive norm
    update-descriptive-norms
  ]
end


to update-descriptive-norms
  ; Only counting friends I can observe (mutual friends + people I follow)
  let observable-friends my-links with [
    is-mutual-link? self or  ; mutual friends
    (is-one-way-link? self and myself = end1)  ; People I follow (I am the starting point)
  ]

  let meat-eater-friends count observable-friends with [[meat-hab] of other-end = 2]
  let reduced-eater-friends count observable-friends with [[meat-hab] of other-end = 1]
  let total-observable-friends count observable-friends

  ; Store old value for debugging
  let old-desc Descriptive_meat

  if (total-observable-friends > 0) [
    let meat-eater-ratio meat-eater-friends / total-observable-friends
    ; Convert ratio to 1-7 scale
    let social-norm-value (1 + (meat-eater-ratio * 6))

    ; To avoid overreacting to every new piece of information,
    ;people are naturally cautious.
    ;For example, giving new data only 30% importance means
    ;they need to see the same pattern 3 or 4 times before they significantly update their beliefs.
    let norm-difference (social-norm-value - Descriptive_meat) * social-influence-rate

    set Descriptive_meat bound-value (Descriptive_meat + norm-difference) 1 7

    ; Debug individual agent if needed
    if (who = 0) [
      print (word "Agent " who " descriptive norms update:")
      print (word "  total friends : " total-observable-friends ", Meat-eater friends: " meat-eater-friends ", Reduced Meat-eater friends: " reduced-eater-friends)
      print (word "  Meat ratio: " meat-eater-ratio " Social norm value: " social-norm-value)
      print (word "  Desc norm: " old-desc " -> " Descriptive_meat " (change: " norm-difference ")")
    ]
  ]
end


; Helper function to bound values between min and max
to-report bound-value [value min-val max-val]
  let bounded-value max list min-val (min list max-val value)
  report bounded-value
end


;to check-link-direction
;  let agent0 person 0
;  if agent0 != nobody [
;    print "=== DEBUG Link Direction ==="
;
;    ; Check if links are directed or undirected
;    ask agent0 [
;      let outgoing-links my-links
;      let incoming-links link-neighbors
;
;      print (word "Outgoing links: " count outgoing-links)
;      print (word "Incoming links: " count incoming-links)
;
;      ; Check if this is a directed network
;      if count outgoing-links != count incoming-links [
;        print "NETWORK IS DIRECTED - links are one-way"
;      ]
;    ]
;    print "============================"
;  ]
;end

to debug-friend-creation
  let agent0 person 0
  if agent0 != nobody [
    let agent0-response-id [ResponseId] of agent0
    print (word "=== DEBUG Agent " [who] of agent0 " (ResponseId: " agent0-response-id ") ===")

    ; Find this agent's entry in the friend dictionary
    let my-entry false
    foreach friend-attributes-dict [
      entry ->
      if (is-list? entry and length entry > 0 and item 0 entry = agent0-response-id) [
        set my-entry entry
      ]
    ]

    ifelse my-entry != false [
      let friend-data but-first my-entry
      print (word "Friend data entries in dictionary: " length friend-data)
      print "Friend attributes:"
      let i 0
      foreach friend-data [
        attr-list ->
        print (word "  Friend " i ": inf=" item 0 attr-list " freq=" item 1 attr-list " diet=" item 2 attr-list)
        set i i + 1
      ]

      ; Check actual links created
      print (word "Actual links created: " count [my-links] of agent0)
      ask agent0 [
        let link-count 0
        ask my-links [
          let friend other-end
          print (word "  Link " link-count ": to " [ResponseId] of friend " inf=" influence " freq=" frequency)
          set link-count link-count + 1
        ]
      ]
    ]
    [
      print "No friend data found in dictionary for this agent!"
    ]
    print "=========================================="
  ]
end


to update-diet-behaviour

  let total-changes 0
  let attempted-changes 0
  let hab-changes [0 0 0]

  ask persons [
    calculate-intention
    let current-hab meat-hab
    let new-hab current-hab
    let intention-gap 0

    ; ===== change direction =====
    ifelse (current-hab = 0) [
      set intention-gap (Intention_Regression - avg-intention-reduced-eaters)
      if (intention-gap > 0) [ set new-hab 1 ]
    ] [
      ifelse (current-hab = 1) [
        let up-gap (Intention_Regression - avg-intention-meat-eaters)
        let down-gap (avg-intention-non-eaters - Intention_Regression)
        ifelse (up-gap > 0 and up-gap >= down-gap) [
          set intention-gap up-gap
          set new-hab 2
        ] [
          if (down-gap > 0) [
            set intention-gap down-gap
            set new-hab 0
          ]
        ]
      ] [
        set intention-gap (avg-intention-reduced-eaters - Intention_Regression)
        if (intention-gap > 0) [ set new-hab 1 ]
      ]
    ]

    ; ===== try to change =====
    if (new-hab != current-hab) [
      let base-prob intention-gap / 6
      let habit-factor exp(- diet-duration / habit-formation-weeks)
      let change-probability base-prob * habit-factor

      set attempted-changes attempted-changes + 1

      if (random-float 1.0 < change-probability) [
         ; ===== 记录转变路径 =====
        set transition-paths lput (list
          ResponseId
          current-hab
          new-hab
          ticks
          Intention_Regression
          diet-duration
        ) transition-paths

        set total-transitions total-transitions + 1

        ; ===== 检测回弹 =====
        ; 回弹：之前改变过，现在又改回去了
        let previous-change filter [ [path] -> item 0 path = ResponseId ] transition-paths

        if length previous-change > 1 [  ; 至少是第二次改变
          let last-change last previous-change
          let last-new-hab item 2 last-change
          if last-new-hab = current-hab [  ; 改回了之前的状态
            set relapse-count relapse-count + 1
          ]
        ]

        set meat-hab new-hab
        set prev-meat-hab current-hab
        set diet-duration 0
        set total-changes total-changes + 1
        set hab-changes (replace-item current-hab hab-changes (item current-hab hab-changes + 1))

        ; ===== 记录早期改变者 =====
        if ticks <= 20 and not member? ResponseId early-adopter-ids [
          set early-adopter-ids lput ResponseId early-adopter-ids
        ]
      ]
    ]

    set diet-duration (diet-duration + 1)
  ]

  ; ===== 记录顽固派 =====
  if ticks = 200 [
    set resister-ids [ResponseId] of persons with [
      meat-hab = 2 and                   ; 始终吃肉
      diet-duration > 180                ; 持续很久
    ]
  ]
end





to calculate-intention

  ; Calculate intention using different weightings based on the current dietary group

  ifelse (meat-hab = 0) [  ; non meat eater
    set Intention_Regression (
      Experiential_Meat *  w_Experiential_N +
      Instrumental_Meat * w_Instrumental_N +
      Injunctive_meat * w_Injunctive_N +
      Descriptive_meat * w_Descriptive_N +
      capacity_meat *  w_Capacity_N +
      autonomy_meat * w_Autonomy_N
    )
  ]
  [ ifelse (meat-hab = 1) [  ; reduced meat eater
      set Intention_Regression (
        Experiential_Meat * w_Experiential_R +
        Instrumental_Meat * w_Instrumental_R +
        Injunctive_meat * w_Injunctive_R +
        Descriptive_meat *  w_Descriptive_R +
        capacity_meat * w_Capacity_R +
        autonomy_meat *  w_Autonomy_R
      )
    ]
    [ if (meat-hab = 2) [  ; meat eater
        set Intention_Regression (
          Experiential_Meat * w_Experiential_M +
          Instrumental_Meat *   w_Instrumental_M +
          Injunctive_meat * w_Injunctive_M +
          Descriptive_meat * w_Descriptive_M +
          capacity_meat *  w_Capacity_M +
          autonomy_meat *  w_Autonomy_M
        )
      ]
    ]
  ]

  ; Add debugging output to verify weight application
  if (who = 0) [  ; Output debug information only to the first agent.
    print (word "Agent " who " (diet: " meat-hab ") intention: " Intention_Regression)
  ]
end

to go
;  if ticks >= 200 [
;    finalize-analysis
;    stop
;  ]
  tick ;1 social interaction cycle
  ; ===== 在互动前记录构念值 =====
  let pre-exp mean [Experiential_Meat] of persons
  let pre-inst mean [Instrumental_Meat] of persons
  let pre-inj mean [Injunctive_meat] of persons
  let pre-desc mean [Descriptive_meat] of persons
  let pre-intention mean [Intention_Regression] of persons
  ; update every tick
  interact-with-friends    ; The mutual influence between friends
  record-agent0-changes
  update-diet-behaviour
  debug-hab-change
  ; 记录Agent 0的变化

;   if debug-mode? [
;    debug-friends-count
;    debug-friend-creation
;  ]

  ;check-link-direction

 ; ===== 在互动后记录构念值 =====
  let post-exp mean [Experiential_Meat] of persons
  let post-inst mean [Instrumental_Meat] of persons
  let post-inj mean [Injunctive_meat] of persons
  let post-desc mean [Descriptive_meat] of persons
  let post-intention mean [Intention_Regression] of persons

  ; ===== 构念贡献分析 =====
  ; 记录每个构念的变化量
  let exp-change post-exp - pre-exp
  let inst-change post-inst - pre-inst
  let inj-change post-inj - pre-inj
  let desc-change post-desc - pre-desc

  set exp-contribution-list lput (list ticks exp-change) exp-contribution-list
  set inst-contribution-list lput (list ticks inst-change) inst-contribution-list
  set inj-contribution-list lput (list ticks inj-change) inj-contribution-list
  set desc-contribution-list lput (list ticks desc-change) desc-contribution-list

  ; ===== 时间分析：记录饮食分布 =====
  let total count persons
  let pct-no-meat count persons with [meat-hab = 0] / total * 100
  let pct-reduced count persons with [meat-hab = 1] / total * 100
  let pct-meat count persons with [meat-hab = 2] / total * 100

  set tick-distribution lput (list ticks pct-no-meat pct-reduced pct-meat) tick-distribution

  ; ===== 检测引爆点 =====
  if tipping-point-tick = -1 and pct-no-meat > 20 [
    set tipping-point-tick ticks
    print (word "TIPPING POINT at tick " ticks ": no-meat% reached " pct-no-meat "%")
  ]

  ; ===== 检测稳定 =====
  if stabilization-tick = -1 [
    ; 检查最近10个tick的分布是否稳定
    if length tick-distribution >= 10 [
      let recent sublist tick-distribution (length tick-distribution - 10) length tick-distribution
      let max-no-meat max map [ [row] -> item 1 row ] recent
      let min-no-meat max map [ [row] -> item 1 row ] recent


      if (max-no-meat - min-no-meat) < 1.0 [  ; 波动小于1%
        set stabilization-tick ticks
        print (word "STABILIZED at tick " ticks)
      ]
    ]
  ]
end


to debug-hab-change
  let agent0 person 0
  ask agent0 [
    print (word "DEBUG at Tick " ticks ":")
    print (word "  meat-hab: " meat-hab)
    print (word "  prev-meat-hab: " prev-meat-hab)
    print (word "  Are they equal? " (meat-hab = prev-meat-hab))

    ; 检查update-diet-behavior中的old-hab
    let current-hab meat-hab
    print (word "  current-hab (local): " current-hab)
  ]
end



; 记录Agent 0的变化
to record-agent0-changes
  let agent0 person 0
  if agent0 != nobody [
    ask agent0 [
      ;先检查变化，然后再更新prev变量
      let hab-change? (meat-hab != prev-meat-hab)

      ; 计算变化量
      let exp-change Experiential_Meat - prev-Experiential_Meat
      let inst-change Instrumental_Meat - prev-Instrumental_Meat
      let inj-change Injunctive_meat - prev-Injunctive_meat
      let desc-change Descriptive_meat - prev-Descriptive_meat


      ; 如果有显著变化，记录
      if (abs exp-change > 0.01 or abs inst-change > 0.01 or
          abs inj-change > 0.01 or abs desc-change > 0.01 or hab-change?) [

        print (word "=== AGENT 0 CHANGES at Tick " ticks " ===")

        if hab-change? [
          print (word "*** DIET CHANGE: " prev-meat-hab " -> " meat-hab
                 " (" item prev-meat-hab meat-hab-list " -> " item meat-hab meat-hab-list ")")
        ]

        print (word "Experiential_Meat: " prev-Experiential_Meat " -> " Experiential_Meat
               " (Δ: " precision exp-change 3 ")")
        print (word "Instrumental_Meat: " prev-Instrumental_Meat " -> " Instrumental_Meat
               " (Δ: " precision inst-change 3 ")")
        print (word "Injunctive_meat: " prev-Injunctive_meat " -> " Injunctive_meat
               " (Δ: " precision inj-change 3 ")")
        print (word "Descriptive_meat: " prev-Descriptive_meat " -> " Descriptive_meat
               " (Δ: " precision desc-change 3 ")")
        print (word "Intention: " Intention_Regression)

        ; 记录当前tick数据
        let tick-data (list
          (list "Tick" ticks)
          (list "Meat_Hab" meat-hab)
          (list "Experiential_Meat" Experiential_Meat)
          (list "Instrumental_Meat" Instrumental_Meat)
          (list "Injunctive_meat" Injunctive_meat)
          (list "Descriptive_meat" Descriptive_meat)
          (list "Intention" Intention_Regression)
          (list "Exp_Change" exp-change)
          (list "Inst_Change" inst-change)
          (list "Inj_Change" inj-change)
          (list "Desc_Change" desc-change)
          (list "Hab_Changed" hab-change?)
        )

        set agent0-history lput tick-data agent0-history
        set agent0-tick-data tick-data

        ; 更新历史变量
        set prev-Experiential_Meat Experiential_Meat
        set prev-Instrumental_Meat Instrumental_Meat
        set prev-Injunctive_meat Injunctive_meat
        set prev-Descriptive_meat Descriptive_meat
        set prev-meat-hab meat-hab
      ]
    ]
  ]
end

; 添加新的监控程序
to monitor-agent0-interactions
  let agent0 person 0
  if agent0 != nobody [
    ask agent0 [
      print "=== AGENT 0 INTERACTION ANALYSIS ==="

      ; 分析每个朋友的影响
      let total-exp-influence 0
      let total-inst-influence 0
      let total-inj-influence 0

      ask my-links [
        let friend other-end
        let friend-id [ResponseId] of friend
        let friend-hab [meat-hab] of friend

        ; 计算互动强度
        let norm-influence (influence / 10)
        let norm-frequency ((6 - frequency) / 5)
        let interaction-strength (norm-influence * norm-frequency)

        ; 计算各项影响
        let exp-influence ([Experiential_Meat] of other-end - [Experiential_Meat] of myself) * interaction-strength * social-influence-rate
        let inst-influence ([Instrumental_Meat] of other-end - [Instrumental_Meat] of myself) * interaction-strength * social-influence-rate
        let inj-influence ([Injunctive_meat] of other-end - [Injunctive_meat] of myself) * interaction-strength * social-influence-rate

        set total-exp-influence total-exp-influence + exp-influence
        set total-inst-influence total-inst-influence + inst-influence
        set total-inj-influence total-inj-influence + inj-influence

        print (word "Friend: " friend-id " (Diet: " friend-hab ")")
        print (word "  Influence: " influence " Freq: " frequency " Strength: " precision interaction-strength 3)
        print (word "  Experiential Δ: " precision exp-influence 4)
        print (word "  Instrumental Δ: " precision inst-influence 4)
        print (word "  Injunctive Δ: " precision inj-influence 4)
      ]

      print (word "Total Expected Changes:")
      print (word "  Experiential: " precision total-exp-influence 4)
      print (word "  Instrumental: " precision total-inst-influence 4)
      print (word "  Injunctive: " precision total-inj-influence 4)

      ; 预测下一个tick的值
      let next-exp (Experiential_Meat + total-exp-influence)
      let next-inst (Instrumental_Meat + total-inst-influence)
      let next-inj (Injunctive_meat + total-inj-influence)

      print (word "Predicted next tick:")
      print (word "  Experiential: " precision (bound-value next-exp 1 7) 3)
      print (word "  Instrumental: " precision (bound-value next-inst 1 7) 3)
      print (word "  Injunctive: " precision (bound-value next-inj 1 7) 3)
    ]
  ]
end

; 添加一个函数来显示Agent 0的完整历史
to show-agent0-history
  let agent0 person 0
  if agent0 != nobody [
    print "=== AGENT 0 COMPLETE HISTORY ==="

    foreach agent0-history [
      tick-data ->
      print (word "Tick: " item 1 (item 0 tick-data))

      foreach but-first tick-data [
        data-item  ->
        let key item 0 data-item
        let value item 1 data-item

        ifelse (is-number? value) [
          print (word "  " key ": " precision value 4)
        ]
        [
          print (word "  " key ": " value)
        ]
      ]
      print ""
    ]
  ]
end

; 添加一个函数来导出Agent 0数据到CSV
to export-agent0-data
  let agent0 person 0
  if agent0 != nobody [
    ; 准备数据列表
    let data-to-export []

    ; 添加标题行作为第一个项目
    let headers ["Tick" "Meat_Hab" "Experiential_Meat" "Instrumental_Meat"
                 "Injunctive_meat" "Descriptive_meat" "Intention"
                 "Exp_Change" "Inst_Change" "Inj_Change" "Desc_Change" "Hab_Changed"]
    set data-to-export lput headers data-to-export

    ; 收集所有数据行
    foreach agent0-history [
      tick-data ->
      let tick1 item 1 (item 0 tick-data)
      let meat-hab-val item 1 (item 1 tick-data)
      let exp-meat item 1 (item 2 tick-data)
      let inst-meat item 1 (item 3 tick-data)
      let inj-meat item 1 (item 4 tick-data)
      let desc-meat item 1 (item 5 tick-data)
      let intention item 1 (item 6 tick-data)

      ; 检查是否有变化数据
      let exp-change ifelse-value (length tick-data > 7) [item 1 (item 7 tick-data)] [0]
      let inst-change ifelse-value (length tick-data > 8) [item 1 (item 8 tick-data)] [0]
      let inj-change ifelse-value (length tick-data > 9) [item 1 (item 9 tick-data)] [0]
      let desc-change ifelse-value (length tick-data > 10) [item 1 (item 10 tick-data)] [0]
      let hab-changed ifelse-value (length tick-data > 11) [item 1 (item 11 tick-data)] [false]

      ; 创建数据行
      let data-row (list tick1 meat-hab-val exp-meat inst-meat
                        inj-meat desc-meat intention
                        exp-change inst-change inj-change desc-change hab-changed)

      set data-to-export lput data-row data-to-export
    ]

    ; 一次性写入CSV文件
    csv:to-file "agent0_history.csv" data-to-export

    print "Agent 0 data exported to agent0_history.csv"
  ]
end
;to export-agent0-data
;  let agent0 person 0
;  if agent0 != nobody [
;    ; 创建文件
;    file-open "agent0_history.csv"
;
;    ; 写入标题行
;    let headers ["Tick" "Meat_Hab" "Experiential_Meat" "Instrumental_Meat"
;                 "Injunctive_meat" "Descriptive_meat" "Intention"
;                 "Exp_Change" "Inst_Change" "Inj_Change" "Desc_Change" "Hab_Changed"]
;        file-print headers
;
;    ; 写入数据
;    foreach agent0-history [
;      tick-data ->
;      let tick1 item 1 (item 0 tick-data)
;      let meat-hab-val item 1 (item 1 tick-data)
;      let exp-meat item 1 (item 2 tick-data)
;      let inst-meat item 1 (item 3 tick-data)
;      let inj-meat item 1 (item 4 tick-data)
;      let desc-meat item 1 (item 5 tick-data)
;      let intention item 1 (item 6 tick-data)
;
;      ; 检查是否有变化数据
;      let exp-change ifelse-value (length tick-data > 7) [item 1 (item 7 tick-data)] [0]
;      let inst-change ifelse-value (length tick-data > 8) [item 1 (item 8 tick-data)] [0]
;      let inj-change ifelse-value (length tick-data > 9) [item 1 (item 9 tick-data)] [0]
;      let desc-change ifelse-value (length tick-data > 10) [item 1 (item 10 tick-data)] [0]
;      let hab-changed ifelse-value (length tick-data > 11) [item 1 (item 11 tick-data)] [false]
;
;      file-print (word tick1 "," meat-hab-val "," exp-meat "," inst-meat ","
;                      inj-meat "," desc-meat "," intention ","
;                      exp-change "," inst-change "," inj-change "," desc-change "," hab-changed)
;    ]
;
;    file-close
;    print "Agent 0 data exported to agent0_history.csv"
;  ]
;end
;


; 在setup中添加一个按钮来显示Agent 0的初始网络
to visualize-agent0-network
  clear-all
  setup-globals
  load-friend-attributes
  setup-persons

  ; 只显示Agent 0和它的朋友
  ask persons [
    ifelse (self = person 0 or link-neighbor? person 0) [
      set size 1.5
      set label (word ResponseId "\nDiet:" meat-hab)
      set label-color white
    ]
    [
      set hidden? true
    ]
  ]

  ; 高亮Agent 0
  ask person 0 [
    set size 2.5
    set color green
    set label (word "AGENT 0\n" ResponseId "\nDiet:" meat-hab)
  ]

  ; 设置连接标签
  ask links [
    if [who] of end1 = 0 or [who] of end2 = 0 [
      set label (word "Inf:" influence "\nFreq:" frequency)
      set label-color blue
    ]
  ]

  layout-spring persons links 0.3 5 1
end

; 添加一个简单的仪表板显示
to show-agent0-dashboard
  let agent0 person 0
  if agent0 != nobody [
    ask agent0 [
      print "┌─────────────────────────────────────────────┐"
      print (word "│ AGENT 0 DASHBOARD - Tick: " ticks "       │")
      print "├─────────────────────────────────────────────┤"
      print (word "│ Diet: " meat-hab " (" item meat-hab meat-hab-list ")")
      print (word "│ Intention: " precision Intention_Regression 4)
      print "├─────────────────────────────────────────────┤"
      print (word "│ Attitudes:                            │")
      print (word "│   Experiential: " precision Experiential_Meat 3)
      print (word "│   Instrumental: " precision Instrumental_Meat 3)
      print "├─────────────────────────────────────────────┤"
      print (word "│ Norms:                                │")
      print (word "│   Injunctive: " precision Injunctive_meat 3)
      print (word "│   Descriptive: " precision Descriptive_meat 3)
      print "├─────────────────────────────────────────────┤"
      print (word "│ Friends: " count my-links "              │")
      print (word "│   Meat friends: " current-meat-friends)
      print (word "│   Non-meat friends: " current-nonmeat-friends)
      print "└─────────────────────────────────────────────┘"
    ]
  ]
end


to finalize-analysis
  print "=== FINAL ANALYSIS ==="

  ; ===== 1. 构念贡献分析 =====
  analyze-construct-contributions

  ; ===== 2. 异质性分析 =====
  analyze-early-adopters

  ; ===== 3. 路径分析 =====
  analyze-transition-paths

  ; ===== 4. 时间分析 =====
  analyze-temporal-patterns

  ; ===== 5. 导出所有数据 =====
  export-all-analysis-data
end

to analyze-construct-contributions
  print "=== CONSTRUCT CONTRIBUTIONS ==="

  ; 计算每个构念的平均变化

  let avg-exp-change mean map [ [row] -> item 1 row ] exp-contribution-list
  let avg-inst-change mean map [ [row] -> item 1 row ] inst-contribution-list
  let avg-inj-change mean map [ [row] -> item 1 row ] inj-contribution-list
  let avg-desc-change mean map [ [row] -> item 1 row ] desc-contribution-list



  ; 计算总变化量
  let total-change abs avg-exp-change + abs avg-inst-change + abs avg-inj-change + abs avg-desc-change

  if total-change > 0 [
    set attitude-contribution (abs avg-exp-change + abs avg-inst-change) / total-change * 100
    set norm-contribution (abs avg-inj-change + abs avg-desc-change) / total-change * 100
  ]

  print (word "Attitude contribution: " precision attitude-contribution 1 "%")
  print (word "Norm contribution: " precision norm-contribution 1 "%")
  print (word "  Experiential: " precision avg-exp-change 4)
  print (word "  Instrumental: " precision avg-inst-change 4)
  print (word "  Injunctive: " precision avg-inj-change 4)
  print (word "  Descriptive: " precision avg-desc-change 4)
end

to analyze-early-adopters
  print "=== EARLY ADOPTER PROFILE ==="

  let early-adopters persons with [member? ResponseId early-adopter-ids]
  let resisters persons with [member? ResponseId resister-ids]
  let others persons with [not member? ResponseId early-adopter-ids and not member? ResponseId resister-ids]

  if any? early-adopters [
    let n count early-adopters  ; ← n 在这里定义

    print (word "Early adopters (n=" count early-adopters "):")
    print (word "  Avg age: " precision mean [age] of early-adopters 1)
    print (word "  Avg initial intention: " precision mean [initial-intention] of early-adopters 2)
    print (word "  Avg friends: " precision mean [count my-links] of early-adopters 1)
    ; 性别（0=女, 1=男）
    let female-count count early-adopters with [gender = 0]
    let male-count count early-adopters with [gender = 1]

    print (word "  Female: " female-count " Male: " male-count)
    if male-count > 0 [
      print (word "  Gender ratio (F/M): " precision (female-count / male-count) 2)
    ]
    print (word "  Female ratio: " precision (female-count / n * 100) 1 "%")
  ]


  if any? resisters [
    print (word "Resisters (n=" count resisters "):")
    print (word "  Avg age: " precision mean [age] of resisters 1)
    print (word "  Avg initial intention: " precision mean [initial-intention] of resisters 2)
    print (word "  Avg friends: " precision mean [count my-links] of resisters 1)
  ]
end

to analyze-transition-paths
  print "=== TRANSITION PATHS ==="

  ; 统计不同路径（对列表用 length，不是 count）
  let meat-to-reduced length filter [ [path] -> item 1 path = 2 and item 2 path = 1 ] transition-paths
  let meat-to-none length filter [ [path] -> item 1 path = 2 and item 2 path = 0 ] transition-paths
  let reduced-to-meat length filter [ [path] -> item 1 path = 1 and item 2 path = 2 ] transition-paths
  let reduced-to-none length filter [ [path] -> item 1 path = 1 and item 2 path = 0 ] transition-paths
  let none-to-reduced length filter [ [path] -> item 1 path = 0 and item 2 path = 1 ] transition-paths

  print (word "Meat → Reduced: " meat-to-reduced)
  print (word "Meat → None: " meat-to-none)
  print (word "Reduced → Meat (relapse): " reduced-to-meat)
  print (word "Reduced → None: " reduced-to-none)
  print (word "None → Reduced: " none-to-reduced)
  print (word "Total transitions: " total-transitions)

  if total-transitions > 0 [
    print (word "Relapse rate: " precision (relapse-count / total-transitions * 100) 1 "%")
  ]
end

to analyze-temporal-patterns
  print "=== TEMPORAL PATTERNS ==="
  print (word "Tipping point tick: " tipping-point-tick)
  print (word "Stabilization tick: " stabilization-tick)

  ; 计算转变速率
  if length tick-distribution > 1 [
    let first-dist item 0 tick-distribution
    let last-dist last tick-distribution
    let no-meat-change (item 1 last-dist - item 1 first-dist)
    print (word "Total no-meat% change: " precision no-meat-change 1 "%")
  ]
end



to export-all-analysis-data
  ; ===== 1. 导出饮食分布时间序列 =====
  let dist-data [["tick" "no_meat_pct" "reduced_pct" "meat_pct"]]
  foreach tick-distribution [
    [row] ->
    set dist-data lput row dist-data
  ]
  csv:to-file "diet_distribution.csv" dist-data

  ; ===== 2. 导出构念贡献时间序列 =====
  let construct-data [["tick" "experiential_change" "instrumental_change" "injunctive_change" "descriptive_change"]]
  let n length exp-contribution-list
  let i 0
  while [i < n] [
    let tick-val item 0 (item i exp-contribution-list)
    let exp-val item 1 (item i exp-contribution-list)
    let inst-val item 1 (item i inst-contribution-list)
    let inj-val item 1 (item i inj-contribution-list)
    let desc-val item 1 (item i desc-contribution-list)
    set construct-data lput (list tick-val exp-val inst-val inj-val desc-val) construct-data
    set i i + 1
  ]
  csv:to-file "construct_contributions.csv" construct-data

  ; ===== 3. 导出转变路径 =====
  let path-data [["agent_id" "from_hab" "to_hab" "tick" "intention" "diet_duration"]]
  foreach transition-paths [
    [path] ->
    set path-data lput path path-data
  ]
  csv:to-file "transition_paths.csv" path-data

  ; ===== 4. 导出异质性数据 =====
  let agent-data [["agent_id" "age" "gender" "initial_meat_hab" "final_meat_hab"
                   "initial_intention" "final_intention" "friend_count"
                   "meat_friend_count" "nonmeat_friend_count" "total_changes"
                   "is_early_adopter" "is_resister"]]

  ask persons [
    let is-early member? ResponseId early-adopter-ids
    let is-res member? ResponseId resister-ids
    let changes length  filter [ [path] -> item 0 path = ResponseId ] transition-paths
; 性别转换为可读格式
  let gender-label ifelse-value (gender = 0) ["Female"] ["Male"]


    set agent-data lput (list
      ResponseId age gender
      initial-meat-hab meat-hab
      initial-intention Intention_Regression
      count my-links current-meat-friends current-nonmeat-friends
      changes is-early is-res
    ) agent-data
  ]
  csv:to-file "agent_profiles.csv" agent-data

  ; ===== 5. 导出汇总统计 =====

  let summary-data (list
    (list "metric" "value")
    (list "attitude_contribution_pct" precision attitude-contribution 1)
    (list "norm_contribution_pct" precision norm-contribution 1)
    (list "tipping_point_tick" tipping-point-tick)
    (list "stabilization_tick" stabilization-tick)
    (list "total_transitions" total-transitions)
    (list "relapse_count" relapse-count)
    (list "relapse_rate" precision (relapse-count / max (list 1 total-transitions) * 100) 1)
    (list "early_adopter_count" length early-adopter-ids)
    (list "resister_count" length resister-ids)
  )

  csv:to-file "summary_statistics.csv" summary-data

  print "All analysis data exported to CSV files"
end







;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 敏感性分析输出指标 (Reporters)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; 1. 最终饮食分布
to-report final-meat-eater-count
  report count persons with [meat-hab = 2]
end

to-report final-non-eater-count
  report count persons with [meat-hab = 0]
end

to-report final-reduced-eater-count
  report count persons with [meat-hab = 1]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
14
10
77
43
setup
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

PLOT
688
282
997
446
Diet Trends
Tick
Number
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Meat Eaters" 1.0 0 -5298144 true "plot count persons with [meat-hab = 2]" "plot count persons with [meat-hab = 2]"
"Reduced Meat Eaters" 1.0 0 -955883 true "plot count persons with [meat-hab = 1]" "plot count persons with [meat-hab = 1]"
"Non-meat Eaters" 1.0 0 -10899396 true "plot count persons with [meat-hab = 0]" "plot count persons with [meat-hab = 0]"

BUTTON
99
10
162
43
go
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
664
18
757
51
no-meat-slider
no-meat-slider
0
142
27.0
1
1
NIL
HORIZONTAL

SLIDER
875
19
968
52
less-meat-slider
less-meat-slider
0
61
61.0
1
1
NIL
HORIZONTAL

SLIDER
769
18
862
51
meat-slider
meat-slider
0
119
119.0
1
1
NIL
HORIZONTAL

SLIDER
666
144
868
177
habit-formation-weeks
habit-formation-weeks
2
34
10.0
1
1
NIL
HORIZONTAL

SLIDER
666
92
868
125
social-influence-rate
social-influence-rate
0
1
0.3
0.01
1
NIL
HORIZONTAL

BUTTON
15
59
140
92
Show Dashboard
show-agent0-dashboard
NIL
1
T
OBSERVER
NIL
1
NIL
NIL
1

BUTTON
12
116
155
149
Monitor Interactions
monitor-agent0-interactions
NIL
1
T
OBSERVER
NIL
1
NIL
NIL
1

BUTTON
22
167
126
200
Show History
show-agent0-history
NIL
1
T
OBSERVER
NIL
1
NIL
NIL
1

BUTTON
24
221
122
254
Export Data
export-agent0-data
NIL
1
T
OBSERVER
NIL
1
NIL
NIL
1

BUTTON
0
277
197
310
NIL
export-all-analysis-data
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

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
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Experiment5_updated" repetitions="30" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks &gt;= 200</exitCondition>
    <metric>count persons with [meat-hab = 0] / count persons * 100</metric>
    <metric>count persons with [meat-hab = 1] / count persons * 100</metric>
    <metric>count persons with [meat-hab = 2] / count persons * 100</metric>
    <metric>mean [Intention_Regression] of persons</metric>
    <metric>attitude-contribution</metric>
    <metric>norm-contribution</metric>
    <metric>total-transitions</metric>
    <metric>relapse-count</metric>
    <steppedValueSet variable="social-influence-rate" first="0" step="0.1" last="1"/>
    <enumeratedValueSet variable="habit-formation-weeks">
      <value value="2"/>
      <value value="6"/>
      <value value="10"/>
      <value value="14"/>
      <value value="18"/>
      <value value="22"/>
      <value value="26"/>
      <value value="30"/>
      <value value="34"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Experiment6_single" repetitions="30" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks &gt;= 200</exitCondition>
    <metric>count persons with [meat-hab = 0] / count persons * 100</metric>
    <metric>count persons with [meat-hab = 1] / count persons * 100</metric>
    <metric>count persons with [meat-hab = 2] / count persons * 100</metric>
    <metric>mean [Intention_Regression] of persons</metric>
    <metric>attitude-contribution</metric>
    <metric>norm-contribution</metric>
    <metric>total-transitions</metric>
    <metric>relapse-count</metric>
    <enumeratedValueSet variable="social-influence-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="habit-formation-weeks">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Experiment7_single" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks &gt;= 200</exitCondition>
    <metric>count persons with [meat-hab = 0] / count persons * 100</metric>
    <metric>count persons with [meat-hab = 1] / count persons * 100</metric>
    <metric>count persons with [meat-hab = 2] / count persons * 100</metric>
    <metric>mean [Intention_Regression] of persons</metric>
    <metric>attitude-contribution</metric>
    <metric>norm-contribution</metric>
    <metric>total-transitions</metric>
    <metric>relapse-count</metric>
    <enumeratedValueSet variable="social-influence-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="habit-formation-weeks">
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
