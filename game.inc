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


; ���Ա�ʾ���ꡢ�ٶȡ���״��δ�������ٶȣ�����ȡ��ֵ
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

; ��ҽṹ��
player struct
	pos           point <>    ; ��ҵĴ�������λ��
	psize         point <>    ; ��ҵ���״�����ȺͿ��ȣ�����ı�ʱ������������
	speed         point <>    ; ��ҵ�x,y�ٶ� x�ٶ�����Ϊ����y�ٶ�����Ϊ��
	boundary      box <>	  ;��ҵĴ��ڱ߽�
	dir           BYTE  1     ; ��8 ��4 ��2 ��1
	bmp_dir       BYTE  0     ; λͼ�ķ���4��bit��ֻ��ͬʱ��1λΪ1��ȡ�����˶�ʱ�ĸ����ȱ�����
	score         DWORD 0     ; ��ҵ÷֣����Ϊ0�����Ϊ3
	is_y_collide  BYTE  0     ; y�����Ƿ���ײ����ש���ϣ�
	is_static     BYTE  0     ; �Ƿ��ھ�ֹ״̬
	cur_frame     BYTE  0     ; �����˶�״̬ʱ����ǰ֡����ȡֵΪ1��2
	frame_counter BYTE  0     ; �ۼƱ�����ÿ�μӵ�5�͸����˶�֡�����Ѹñ�������
player ends

; ש����
brick struct
	boundary			box		 <>	 ; ש��ı߽�
	brick_type          DWORD    0   ; ש������
brick ends

; ��ײ��
collision struct
	collide_type		DWORD	0	; 1: ��ͨש�������ǽ�� 2: ��̺��컨��
	collide_index		DWORD	0	; ������ײש��index��0-11���ǵ�ȡַʱMUL TYPE bricks��
	is_x_collide		BYTE	0	; x�����Ƿ���ײ
	x_need_move			SDWORD	0	; ���x�Ѿ�Ҫ�����ˣ�is_x_collide==1����Ӧ���ƶ�����
	is_y_collide		BYTE	0	; y�����Ƿ���ײ����ש����
	y_need_move			SDWORD	0	; ���y�Ѿ�Ҫ�����ˣ�is_y_collide==1����Ӧ���ƶ�����
collision ends

; ��Ϸ�г���
.const
	my_window_width  EQU   490       ; ����ˮƽ����
	my_window_height EQU   675       ; ������ֱ�߶�
	brick_width		 EQU   120       ; ש��ˮƽ����
	brick_height	 EQU   24        ; ש����ֱ�߶�
	brick_x_gap		 EQU   60
	brick_y_gap		 EQU   64		 ; ��Ļ��ֱ�ָ��߶�
	brick_y_gap_in	 EQU   40

	dir_top          EQU   8          ; ����������������������
	dir_down         EQU   4
	dir_left         EQU   2
	dir_right        EQU   1

	player_speed     EQU   4          ; �˵�ÿ������ĳ�ʼ�ٶ�


	wall_top_y       EQU   160         ; ����߽��λ�ã�������������������������һ��
	wall_down_y      EQU   775
	wall_left_x      EQU   120
	wall_right_x     EQU   1080

	door_top_y       EQU   358          ; �������±߽��yֵ
	door_down_y      EQU   582
	door_left_x      EQU   180        ; ���������x
	door_right_x     EQU   1010		  ; �ұ�������x



	; initialized data allocation
.data
	game_status      BYTE     0          ; 0 ��ʼ���� 1 �������� 2 ��Ϸ���� 3 ���1ʤ�� 4 ���2ʤ��
	h_startpage      DWORD    0          ; ��ʼ����
	h_gamepage       DWORD    0          ; ��Ϸ����
	h_endpage        DWORD    0          ; ��������
	player_left_bitmap    DWORD    0          ; ��������λͼ
	player_right_bitmap   DWORD    0          ; ������ҵ�λͼ
	brick_bitmap     DWORD    0          ; ש���λͼ
	game_counter     DWORD    0          ; ��Ϸ�еļ����� ÿ����80����player1          player <<0, 10>, <40, 40>,<0,0>,0,1,0,1,1,1,0>                     ; ���1
	player1          player	  <<0, 10>, <32,32>,<0,0>,<0,32,0,32>,1,1,0,0,1,1,0>         ; ���1
	bricks			 brick 	  11 DUP (<<0, 0, 0, 0>, 0>)   ; ͼ�������11��ש��
	cur_collision	 collision	<0, 0, 0, 0, 0, 0>				; ��ײ��Ϣ
	game_over		 DWORD    0


	h_winpage1       DWORD    0          ; ���1ʤ������
	h_winpage2       DWORD    0          ; ���2ʤ������
	h_guidepage      DWORD    0          ; ָ��ҳ��
	player2_bitmap   DWORD    0          ; ���2�ľ���ͼ
	score_bitmap     DWORD    0          ; ����λͼ
	;gravity		     REAL4   0.03

	
	
	player2          player <<760, 420>, <42, 77>,<0,0>,<0,32,0,32>,0,2,0,1,1,0>                     ; ���2
	paintstruct      PAINTSTRUCT <>   ; ���ƽṹ��


  ; -----------------------------
  ; uninitialised data allocation
  ; -----------------------------
    .data?
        hInstance   DWORD ?          ; ���ڼ�¼����ʵ��
        hWnd        DWORD ?          ; ���
        hIcon       DWORD ?
        hCursor     DWORD ?
        CommandLine DWORD ?

        sWid        DWORD ?          ; ���ڵĿ��Ⱥ͸߶�
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

