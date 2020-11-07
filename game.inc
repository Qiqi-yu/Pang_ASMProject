;     include files
;     
	  
      include windows.inc
      include masm32.inc
      include gdi32.inc
      include user32.inc
      include kernel32.inc
      include Comctl32.inc
      include comdlg32.inc
      include shell32.inc
      include oleaut32.inc
      include msvcrt.inc
	  include msimg32.inc
      include C:\masm32\macros\macros.asm

;     libraries
;     ~~~~~~~~~
      includelib masm32.lib
      includelib gdi32.lib
      includelib user32.lib
      includelib kernel32.lib
      includelib Comctl32.lib
      includelib comdlg32.lib
      includelib shell32.lib
      includelib oleaut32.lib
      includelib msvcrt.lib
	  includelib msimg32.lib
	  

      ; -----------------
      ; Local prototypes
      ; -----------------


; 可以表示坐标、速度、形状，未来兼容速度，可以取负值
point struct
	x SDWORD 0
	y SDWORD 0
point ends

coef  struct
	x real4 0.0
	y real4 0.0
coef  ends

box struct
	top		SDWORD 0
	bottom	SDWORD 0
	left	SDWORD 0
	right	SDWORD 0
box ends

COMMENT !
playerSpeed struct
	x SDWORD 0
	y real4 0.0
playerSpeed ends
!

; 玩家结构体
player struct
	pos           point <>    ; 玩家的窗口坐标位置
	psize         point <>    ; 玩家的形状，长度和宽度，方向改变时，这个变量会变
	speed         point <>    ; 玩家的x,y速度 x速度向左为正，y速度向下为正
	boundary      box <>	  ;玩家的窗口边界
	hp            DWORD 0     ;玩家的生命值  
	dir           BYTE  1     ; 上8 下4 左2 右1
	score         DWORD 0     ; 玩家得分，起初为0，最多为3
player ends

; 砖块类
brick struct
	boundary			box		 <>	 ; 砖块的边界
	brick_type          DWORD    0   ; 砖块类型
brick ends

; 碰撞类
collision struct
	collide_type		DWORD	0	; 1: 普通砖块和左右墙面 2: 尖刺和天花板
	collide_index		DWORD	0	; 返回碰撞砖块index（0-11，记得取址时MUL TYPE bricks）
	is_x_collide		BYTE	0	; x方向是否碰撞
	x_need_move			SDWORD	0	; 如果x已经要碰上了（is_x_collide==1），应该移动多少
	is_y_collide		BYTE	0	; y方向是否碰撞（在砖块上
	y_need_move			SDWORD	0	; 如果y已经要碰上了（is_y_collide==1），应该移动多少
collision ends

; 游戏中常量
.const
	my_window_width  EQU   480       ; 窗体水平宽度
	my_window_height EQU   675       ; 窗体竖直高度
	brick_width		 EQU   120       ; 砖块水平宽度
	brick_height	 EQU   24        ; 砖块竖直高度
	brick_x_gap		 EQU   60
	brick_y_gap		 EQU   64		 ; 屏幕竖直分隔高度
	brick_y_gap_in	 EQU   40

	dir_top          EQU   8          ; 我们正常见到的上下左右
	dir_down         EQU   4
	dir_left         EQU   2
	dir_right        EQU   1
	
	player_height    EQU   32
	player_x_speed   EQU   6          ;玩家x方向的速度
	prick_lose_hp	 EQU   10          ;尖刺导致玩家失血

	; initialized data allocation
.data
	game_status      BYTE     0          ; 0 开始界面 1 帮助界面 2 游戏界面 3 玩家1胜利 4 玩家2胜利
	h_startpage      DWORD    0          ; 开始界面
	h_gamepage       DWORD    0          ; 游戏界面
	h_endpage        DWORD    0          ; 结束界面
	player_left_bitmap    DWORD    0          ; 玩家向左的位图
	player_right_bitmap   DWORD    0          ; 玩家向右的位图
	brick_bitmap     DWORD    0          ; 砖块的位图
	game_counter     DWORD    0          ; 游戏中的计数器 每计满80清零player1          player <<0, 10>, <40, 40>,<0,0>,0,1,0,1,1,1,0>                     ; 玩家1
	player1          player	  <<0, 24>, <32,32>,<0,0>,<0,32,0,32>,100,1,0>         ; 玩家1 初始生命值设为100
	bricks			 brick 	  11 DUP (<<0, 0, 0, 0>, 0>)   ; 图内最多有11行砖块
	cur_collision	 collision	<0, 0, 0, 0, 0, 0>				; 碰撞信息
	game_over		 DWORD    0


	h_winpage1       DWORD    0          ; 玩家1胜利界面
	h_winpage2       DWORD    0          ; 玩家2胜利界面
	h_guidepage      DWORD    0          ; 指南页面
	player2_bitmap   DWORD    0          ; 玩家2的精灵图
	score_bitmap     DWORD    0          ; 分数位图
	;gravity		     REAL4   0.03

	
	
	;player2          player <<760, 420>, <42, 77>,<0,0>,<0,32,0,32>,0,2,0,1,1,0>                     ; 玩家2
	paintstruct      PAINTSTRUCT <>   ; 绘制结构体


  ; -----------------------------
  ; uninitialised data allocation
  ; -----------------------------
    .data?
        hInstance   DWORD ?          ; 用于记录程序实例
        hWnd        DWORD ?          ; 句柄
        hIcon       DWORD ?
        hCursor     DWORD ?
        CommandLine DWORD ?

        sWid        DWORD ?          ; 窗口的宽度和高度
        sHgt        DWORD ?

		thread1     DWORD ?
		thread2     DWORD ?


      ; -----------------
      ; Local prototypes
      ; -----------------

        WndProc          PROTO :DWORD,:DWORD,:DWORD,:DWORD
        MsgLoop          PROTO
        Main             PROTO
		loadGameImages   PROTO
		paintBackground  PROTO :DWORD,:DWORD
		updateScene      PROTO
		logicThread      PROTO :DWORD
		paintThread      PROTO :DWORD
		paintPlayers     PROTO :DWORD,:DWORD
		paintBricks		 PROTO :DWORD,:DWORD
		initialBricks	 PROTO 
		changeBricks 	 PROTO
		colliDetect		 PROTO
		;time             PROTO C
		clock			 PROTO C

		isColliding      PROTO :DWORD
		paintScore       PROTO :DWORD,:DWORD
		movePlayer       PROTO :DWORD
		getScore         PROTO
		gameOver         PROTO 
		resetGame        PROTO
		processKeyUp     PROTO :DWORD
		processKeyDown   PROTO :DWORD
		processCollide   PROTO


