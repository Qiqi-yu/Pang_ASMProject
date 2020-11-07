    ; __UNICODE__ equ 1           ; uncomment to enable UNICODE build

    .686p                       ; create 32 bit code
    .mmx                        ; enable MMX instructions
    .xmm                        ; enable SSE instructions
    .model flat, stdcall        ; 32 bit memory model
    option casemap :none        ; case sensitive

    bColor   equ  <00999999h>   ; client area brush colour
    include	game.inc			; local includes for this file
	

.code
start:  ;程序入口点
    ; 获得模块句柄
	invoke GetModuleHandle, NULL
	mov hInstance, eax

	; 可能不需要命令行参数
	invoke GetCommandLine
	mov  CommandLine, eax
	; 得到图标和光标
    mov hIcon,       rv(LoadIcon,hInstance,103)
    mov hCursor,     rv(LoadCursor,NULL,IDC_ARROW)
	; 得到整个屏幕的尺寸
    mov sWid,        rv(GetSystemMetrics,SM_CXSCREEN)
    mov sHgt,        rv(GetSystemMetrics,SM_CYSCREEN)
	; 调用主函数
    call Main
    invoke ExitProcess, eax

Main proc
    LOCAL Wwd:DWORD,Wht:DWORD,Wtx:DWORD,Wty:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL icce:INITCOMMONCONTROLSEX

  ; --------------------------------------
  ; comment out the styles you don't need.
  ; --------------------------------------
    mov icce.dwSize, SIZEOF INITCOMMONCONTROLSEX            ; set the structure size
    xor eax, eax                                            ; set EAX to zero
    or eax, ICC_WIN95_CLASSES
    or eax, ICC_BAR_CLASSES                                 ; comment out the rest
    mov icce.dwICC, eax
    invoke InitCommonControlsEx,ADDR icce                   ; initialise the common control library
  ; --------------------------------------

    STRING szClassName,   "GameClass"
    STRING szDisplayName, "Happy Game"

  ; ---------------------------------------------------
  ; set window class attributes in WNDCLASSEX structure
  ; ---------------------------------------------------
    mov wc.cbSize,         sizeof WNDCLASSEX
    mov wc.style,          CS_BYTEALIGNCLIENT or CS_BYTEALIGNWINDOW
    m2m wc.lpfnWndProc,    OFFSET WndProc
    mov wc.cbClsExtra,     NULL
    mov wc.cbWndExtra,     NULL
    m2m wc.hInstance,      hInstance
    m2m wc.hbrBackground,  NULL                 ;COLOR_BTNFACE+1 不需要background
    mov wc.lpszMenuName,   NULL
    mov wc.lpszClassName,  OFFSET szClassName  ;;
    m2m wc.hIcon,          hIcon
    m2m wc.hCursor,        hCursor
    m2m wc.hIconSm,        hIcon

  ; ------------------------------------
  ; register class with these attributes
  ; ------------------------------------
    invoke RegisterClassEx, ADDR wc

  ; ---------------------------------------------
  ; set width and height abosulte length
  ; ---------------------------------------------
    mov Wwd, my_window_width
    mov Wht, my_window_height

  ; ------------------------------------------------
  ; Top X and Y co-ordinates for the centered window
  ; ------------------------------------------------
    mov eax, sWid
    sub eax, Wwd                ; sub window width from screen width
    shr eax, 1                  ; divide it by 2
    mov Wtx, eax                ; copy it to variable

    mov eax, sHgt
    sub eax, Wht                ; sub window height from screen height
    shr eax, 1                  ; divide it by 2
    mov Wty, eax                ; copy it to variable

  ; -----------------------------------------------------------------
  ; create the main window with the size and attributes defined above
  ; -----------------------------------------------------------------
    invoke CreateWindowEx,WS_EX_LEFT or WS_EX_ACCEPTFILES,
                          ADDR szClassName,
                          ADDR szDisplayName,
                          WS_OVERLAPPED or WS_SYSMENU,
                          Wtx,Wty,Wwd,Wht,
                          NULL,NULL,
                          hInstance,NULL
    mov hWnd,eax
    invoke ShowWindow,hWnd, SW_SHOWNORMAL
    invoke UpdateWindow,hWnd

	; 消息循环
    call MsgLoop
    ret
Main endp

; 消息循环
MsgLoop proc
    LOCAL msg:MSG
    push ebx
    lea ebx, msg
    jmp getmsg
  msgloop:
    invoke TranslateMessage, ebx
    invoke DispatchMessage,  ebx
  getmsg:
    invoke GetMessage,ebx,0,0,0
    test eax, eax
    jnz msgloop
    pop ebx
    ret
MsgLoop endp

WndProc proc hWin:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
	; 处理窗口创建后的一些操作
	.IF uMsg == WM_CREATE
		invoke startGame

	.ELSEIF uMsg == WM_DESTROY
		; 退出线程
		invoke PostQuitMessage, NULL

	.ELSEIF uMsg == WM_PAINT
		; 调用更新场景函数，WM_PAINT由paintThread的InvalidateRect发出
		invoke updateScene

	.ELSEIF uMsg == WM_CHAR
		; 处理enter键按下事件
		.IF wParam == 13
			.IF game_status == 0
				mov game_status, 1
				mov player1.dir, dir_right
				invoke initialBricks
				invoke initPlayer
			.ELSEIF game_status == 2
				mov game_status, 0
			.ENDIF
		.ENDIF
		; 处理esc键按下事件
		.IF wParam == 27
			invoke PostQuitMessage, NULL
		.ENDIF

	.ELSEIF uMsg == WM_KEYUP
		invoke processKeyUp, wParam
		; 处理键盘抬起事件

	.ELSEIF uMsg == WM_KEYDOWN
		invoke processKeyDown, wParam
		; 处理键盘按下事件

	.ELSE
		; 默认消息处理函数
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
		ret
	.ENDIF
	xor eax, eax
	ret
WndProc endp

startGame proc
		; 加载位图资源
		invoke loadGameImages
		; 创造逻辑线程
		mov eax, OFFSET logicThread
		invoke CreateThread, NULL, NULL, eax, 0, 0, addr thread1
		invoke CloseHandle, eax
		; 创造绘制线程
		mov eax, OFFSET paintThread
		invoke CreateThread, NULL, NULL, eax, 0, 0, addr thread2
		invoke CloseHandle, eax
		ret
startGame endp

initPlayer proc
	mov player1.pos.x,224
	mov player1.pos.y,200
	mov player1.speed.x,0
	mov player1.speed.y,0
	mov player1.hp,100
	mov player1.score,0
	mov player1.on_ice,0
	mov player1.on_conveyor,0

	ret
initPlayer endp

loadGameImages proc
	; 加载开始界面的位图
	invoke LoadBitmap, hInstance, 500
	mov h_startpage, eax

    ; 加载游戏界面的位图
	invoke LoadBitmap, hInstance, 501
	mov h_gamepage, eax

	; 加载结束界面的位图
	invoke LoadBitmap, hInstance, 502
	mov h_endpage, eax

	; 加载玩家向左的位图
	invoke LoadBitmap, hInstance, 504
	mov player_left_bitmap, eax

	; 加载玩家向右的位图
	invoke LoadBitmap, hInstance, 505
	mov player_right_bitmap, eax

	; 加载普通砖块的位图
	invoke LoadBitmap, hInstance, 141
	mov brick_normal_bitmap, eax

	; 加载光滑砖块的位图
	invoke LoadBitmap, hInstance, 142
	mov brick_icy_bitmap, eax

	; 加载锋利砖块的位图
	invoke LoadBitmap, hInstance, 143
	mov brick_sharp_bitmap, eax

	; 加载易碎砖块的位图
	invoke LoadBitmap, hInstance, 144
	mov brick_fragile_bitmap, eax

	; 加载传送砖块的位图
	invoke LoadBitmap, hInstance, 145
	mov brick_conveyor_bitmap, eax

	; 加载天花板砖块的位图
	invoke LoadBitmap, hInstance, 146
	mov brick_ceiling_bitmap, eax

	ret
loadGameImages endp

; 一个线程函数，根据场景的状态不断循环，游戏状态时候，不断进行碰撞判断等等
logicThread proc p:DWORD
	;LOCAL area:RECT
	game:
	; 开始界面，需要通过enter进入
	.WHILE game_status == 0
		invoke Sleep, 1000
	.ENDW

	; 游戏界面
	.WHILE game_status == 1


		invoke Sleep, 30
		; 重置计数器
		.IF game_counter >= brick_y_gap
			mov game_counter, 0
		.ENDIF
		; 改变计数器并上移砖块
		inc game_counter
		invoke changeBricks

		; 碰撞检测
		invoke colliDetect

		; 角色移动
		invoke movePlayer, addr player1

		.IF game_over == 1
			mov game_status, 2
		.ENDIF
	.ENDW

	; 结束界面
	.WHILE game_status == 2
		invoke Sleep, 30
		mov game_over, 0
	.ENDW

	jmp game

	ret
logicThread endp

; 不断进行绘制流程
paintThread proc p:DWORD
	.WHILE 1
		invoke Sleep, 10
		invoke InvalidateRect, hWnd, NULL, FALSE
	.ENDW
	ret
paintThread endp

; 初始化砖块函数
initialBricks proc uses esi edx ecx eax ebx edi
	LOCAL empty_line_num:DWORD
	assume esi:ptr brick

	mov	   esi, offset bricks
	mov    edi, 0

	; 将前三个砖块置于窗口外
	mov	   empty_line_num, 3
	mov	   ecx, empty_line_num
emptyLine:
		mov	    eax, my_window_width
		mov		[esi].boundary.left, eax
		add		eax, brick_width
		mov		[esi].boundary.right, eax
		add		edi, brick_y_gap_in
		mov		[esi].boundary.top, edi
		add		edi, brick_height
		mov		[esi].boundary.bottom, edi
		add		esi, TYPE bricks
		mov		[esi].brick_kind, 0
		mov		[esi].brick_type, 1
		loop	emptyLine

	;生成第一个在中央的砖块
	mov		eax, my_window_width
	sub		eax, brick_width
	shr     eax, 1
	mov		[esi].boundary.left, eax
	add		eax, brick_width
	mov		[esi].boundary.right, eax
	add		edi, brick_y_gap_in
	mov		[esi].boundary.top, edi
	add		edi, brick_height
	mov		[esi].boundary.bottom, edi
	mov		[esi].brick_kind, 0
	mov		[esi].brick_type, 1
	add		esi, TYPE bricks

	mov	   ecx, lengthof bricks
	dec	   ecx
	sub    ecx, empty_line_num
L1:
	    push	ecx
		push	esi
		invoke	Sleep, 10
		invoke	clock
		pop		esi
		pop		ecx
		push	ecx
		mov		edx, 0
		mov		ecx, 7
		div		ecx
		; edx为所在列数
		mov		ebx, edx		; 乘数 砖块的列数
		mov		eax, brick_x_gap  ; 被乘数  75
		mul		ebx
		mov		[esi].boundary.left, eax
		add		eax, brick_width
		mov		[esi].boundary.right, eax
		add		edi, brick_y_gap_in
		mov		[esi].boundary.top, edi
		add		edi, brick_height
		mov		[esi].boundary.bottom, edi

		push	ecx
		push	esi
		invoke	Sleep, 10
		invoke	clock
		pop		esi
		pop		ecx
		mov		edx, 0
		mov		ecx, 12
		div		ecx
		mov		[esi].brick_kind, edx

		.IF [esi].brick_kind >= 0 && [esi].brick_kind <= 3
			mov [esi].brick_type, 1
		.ELSEIF [esi].brick_kind == 4 || [esi].brick_kind == 5
			mov [esi].brick_type, 3
		.ELSEIF [esi].brick_kind == 6 || [esi].brick_kind == 7
			mov [esi].brick_type, 2
		.ELSEIF [esi].brick_kind == 8 || [esi].brick_kind == 9
			mov [esi].brick_type, 6
		.ELSEIF [esi].brick_kind == 10
			mov [esi].brick_type, 4
		.ELSEIF [esi].brick_kind == 11
			mov [esi].brick_type, 5
		.ENDIF

		add		esi, TYPE bricks
		pop		ecx
		dec     ecx
		cmp		ecx, 0
		jne 	L1
	ret
initialBricks endp

; 砖块更新函数
changeBricks proc uses ecx esi edi ebx edx
	assume edi:ptr brick

	mov	   edi, offset bricks

	.IF game_counter >= brick_y_gap
		cld
		mov		esi, edi
		add		esi, type bricks
		mov		ebx, 10			  ; 乘数    砖块数量
		mov		eax, type bricks  ; 被乘数  20
		mul		ebx
		mov		ecx, eax
		rep		movsb
		;生成一个新的砖块
		push	edi
		invoke	clock
		pop		edi
		mov		edx, 0
		mov		ecx, 7
		div		ecx
		; edx为所在列数
		mov		ebx, edx		; 乘数 砖块的列数
		mov		eax, brick_x_gap  ; 被乘数  75
		mul		ebx

		mov		[edi].boundary.left, eax
		add		eax, brick_width
		mov		[edi].boundary.right, eax
		mov		eax, my_window_height
		mov		[edi].boundary.top, eax
		add		eax, brick_height
		mov		[edi].boundary.bottom, eax

		push	ecx
		push	edi
		invoke	clock
		pop		edi
		pop		ecx
		mov		edx, 0
		mov		ecx, 12
		div		ecx
		mov		[edi].brick_kind, edx
		.IF [edi].brick_kind >= 0 && [edi].brick_kind <= 3
			mov [edi].brick_type, 1
		.ELSEIF [edi].brick_kind == 4 || [edi].brick_kind == 5
			mov [edi].brick_type, 3
		.ELSEIF [edi].brick_kind == 6 || [edi].brick_kind == 7
			mov [edi].brick_type, 2
		.ELSEIF [edi].brick_kind == 8 || [edi].brick_kind == 9
			mov [edi].brick_type, 6
		.ELSEIF [edi].brick_kind == 10
			mov [edi].brick_type, 4
		.ELSEIF [edi].brick_kind == 11
			mov [edi].brick_type, 5
		.ENDIF
	.ENDIF

	mov	   ecx, lengthof bricks
	mov	   edi, offset bricks

UP_BRICK:
	dec		[edi].boundary.top
	dec		[edi].boundary.bottom
	add		edi, TYPE bricks
	loop	UP_BRICK

	ret
changeBricks endp

colliDetect proc uses eax ebx ecx esi edi edx
	assume esi: PTR player, edi: PTR collision, edx: PTR brick
	LOCAL cur_top:SDWORD
	LOCAL cur_left:SDWORD
	LOCAL cur_right:SDWORD
	LOCAL cur_bottom:SDWORD
	LOCAL next_top:SDWORD
	LOCAL next_left:SDWORD
	LOCAL next_right:SDWORD
	LOCAL next_bottom:SDWORD

	mov	edi, offset	cur_collision
	mov	esi, offset player1

	mov [edi].collide_type,0

	; 计算当前左、右、下
	mov eax, [esi].pos.x
	mov cur_left, eax
	add eax, [esi].psize.x
	mov cur_right, eax
	mov eax, [esi].pos.y
	mov cur_top, eax
	add eax, [esi].psize.y
	mov cur_bottom, eax

	.IF [edi].is_y_collide == 1
		dec cur_top
		dec cur_bottom
	.ENDIF

	; 计算考虑速度后的左、右、下
	mov eax, cur_left
	add eax, [esi].speed.x
	mov next_left, eax
	add eax, [esi].psize.x
	mov next_right, eax
	mov eax, cur_top
	add eax, [esi].speed.y
	inc eax
	mov next_top, eax
	add eax, [esi].psize.y
	mov next_bottom, eax

	; 检测x
	; 优先级：侧撞到砖块就不会撞到墙壁了
	; 因此应该先检测墙壁再检测砖块
	; 撞到左墙：next_left < 0
	; 撞到右墙：next_right > my_window_width
	mov [edi].is_x_collide, 0
	.IF next_left < 0
		mov [edi].is_x_collide, 1
		mov eax, 0
		sub eax, cur_left
		mov [edi].x_need_move, eax
		; mov [edi].collide_type, 1
	.ELSEIF next_right > my_window_width
		mov [edi].is_x_collide, 1
		mov eax, my_window_width
		sub eax, cur_right
		mov [edi].x_need_move, eax
		; mov [edi].collide_type, 1
	.ENDIF



	; 由前往后循环检测是否和砖块碰撞
	mov ecx, 11
	mov [edi].is_y_collide, 0

collide_y:
	push ecx
	mov ebx, ecx
	mov eax, SIZEOF brick
	mul ebx			; eax 存偏移
	; mul 改变 edx，因此需要先求edx = offset bricks
	mov edx, offset bricks
	add edx, eax
	mov ecx, [edx].boundary.top
	inc ecx
	mov ebx, [edx].boundary.left
	mov eax, [edx].boundary.right
	; 检测是否穿越砖块
	.IF (cur_bottom <= ecx && next_bottom >= ecx) && ((cur_right > ebx && cur_left < eax) ||  (next_right > ebx && next_left < eax))
		mov [edi].is_y_collide, 1
		sub ecx, cur_bottom
		dec ecx							; 移动距离为 brick.boundary.top - cur_bottom - 1
		mov [edi].y_need_move, ecx
		mov ecx, [edx].brick_type
		mov [edi].collide_type, ecx		; 记录碰撞砖块类型
		pop ecx
		mov [edi].collide_index, ecx	; 记录碰撞砖块index
		push ecx
		; jmp endgame_detect
	.ENDIF
	pop ecx
	loop collide_y

	mov ecx, 11

	; 侧撞砖块
collide_x:
	push ecx
	mov ebx, ecx
	mov eax, SIZEOF brick
	mul ebx			; eax 存偏移
	; mul 改变 edx，因此需要先求edx = offset bricks
	mov edx, offset bricks
	add edx, eax
	mov ebx, [edx].boundary.top
	mov eax, [edx].boundary.bottom
	.IF [esi].speed.x < 0
		 mov ecx, [edx].boundary.right
		.IF (cur_left >= ecx && next_left < ecx) && ((cur_bottom <= eax && next_bottom > eax) || (cur_top <= ebx && next_top > ebx))
			mov [edi].is_x_collide, 1
			sub ecx, cur_left
			mov [edi].x_need_move, ecx
		.ENDIF
	.ELSEIF [esi].speed.x > 0
		mov ecx, [edx].boundary.left
		.IF (cur_right <= ecx && next_right > ecx) && ((cur_bottom <= eax && next_bottom > eax) || (cur_top <= ebx && next_top > ebx))
			mov [edi].is_x_collide, 1
			sub ecx, cur_right
			mov [edi].x_need_move, ecx
		.ENDIF
	.ENDIF
	pop ecx
	loop collide_x

	; 检测y
	; 检测是否碰到上方尖刺（cur_top <= brick_height）
	; 上方碰到尖刺后将自动下落
	;.IF cur_top <= brick_height
	.IF cur_top <= brick_height
		mov [edi].is_y_collide, 0
		mov [edi].collide_type, 2		; 2表示碰到尖刺
	.ENDIF

; 检测是否掉出画面(next_top > my_window_height)
endgame_detect:
	.IF next_top > my_window_height
		mov [edi].is_y_collide, 1
		mov [edi].collide_type, 7			; 7表掉出画面
	.ENDIF
	ret
colliDetect endp

movePlayer proc uses eax ebx ecx edi, addrPlayer1:DWORD
	assume eax: PTR player
	assume edi: PTR collision
	mov eax,addrPlayer1
	mov edi,offset cur_collision

	.IF [edi].is_y_collide == 0
	add [eax].speed.y,1
	;fld [eax].speed.y
	;fadd gravity
	;fstp [eax].speed.y
	;fadd [eax].speed.y,0.03
	mov ebx,[eax].speed.y
	add [eax].pos.y,ebx

	.ELSE
	;fldz
	;fstp [eax].speed.y
    ;mov [eax].speed.y,0.0
	mov [eax].speed.y,0
	push ebx
	mov ebx,[edi].y_need_move
	add [eax].pos.y,ebx
	pop ebx

	.ENDIF

	.IF [edi].is_x_collide == 0
	mov ebx,[eax].speed.x
	add [eax].pos.x,ebx
	.ELSE
	mov [eax].speed.x,0
	mov ebx,[edi].x_need_move
	add [eax].pos.x,ebx
	.ENDIF

	.IF [edi].collide_type == 2
	sub [eax].hp,prick_lose_hp
	mov [eax].on_ice,0
	mov [eax].on_conveyor,0

	.ELSEIF [edi].collide_type == 3
	mov [eax].on_ice,1
	mov [eax].on_conveyor,0

	.ELSEIF [edi].collide_type==4 
	mov [eax].speed.x, conveyor_speed_left
	;add [eax].speed.x,conveyor_speed_left
	mov [eax].on_conveyor,1
	mov [eax].on_ice,0

	.ELSEIF [edi].collide_type==5
	mov [eax].speed.x,conveyor_speed_right
	;add [eax].speed.x,conveyor_speed_right
	mov [eax].on_conveyor,2
	mov [eax].on_ice,0

	.ELSEIF [edi].collide_type==7
	mov [eax].on_ice,0
	mov [eax].on_conveyor,0
	mov [eax].hp,0

	.ELSE
	mov [eax].on_ice,0
	mov [eax].on_conveyor,0
	.ENDIF

	.IF [eax].hp <= 0
	mov game_status,2
	.ENDIF

	m2m [eax].boundary.left,[eax].pos.x
	m2m [eax].boundary.top,[eax].pos.y
	mov ecx,[eax].pos.x
	add ecx,[eax].psize.x
	mov [eax].boundary.right,ecx
	mov ecx,[eax].pos.y
	add ecx,[eax].psize.y
	mov [eax].boundary.bottom,ecx

	ret

movePlayer endp

processKeyDown proc wParam:WPARAM
	.IF game_status == 1
		.IF wParam == VK_LEFT 
			.IF player1.on_conveyor == 0
			mov player1.speed.x,player_x_speed
			neg player1.speed.x
			;当在向右的传送带上时，向左的速度减缓
			.ELSEIF player1.on_conveyor == 2
			mov player1.speed.x,conveyor_speed_left
			.ENDIF
		.ELSEIF wParam == VK_RIGHT
			.IF player1.on_conveyor == 0
			mov player1.speed.x,player_x_speed
			.ELSEIF player1.on_conveyor == 1
			;当在向左的传送带上时，向右的速度减缓
			mov player1.speed.x,conveyor_speed_right
			.ENDIF
		.ENDIF
		;.IF player1.speed.x < 0
		;	mov player1.dir, dir_left
		;.ELSEIF player1.speed.x > 0
		;	mov player1.dir, dir_right
		;.ENDIF
	.ENDIF
	ret
processKeyDown endp

processKeyUp proc wParam:WPARAM
	.IF game_status == 1
		.IF wParam == VK_LEFT && (player1.on_ice == 0)
			mov player1.speed.x,0
		.ELSEIF wParam == VK_RIGHT  && (player1.on_ice == 0)
			mov player1.speed.x,0
		.ENDIF
	.ENDIF
	ret
processKeyUp endp


; 场景更新函数
updateScene proc uses eax
	LOCAL member_hdc:HDC
	LOCAL member_hdc2:HDC
	LOCAL h_bitmap:HDC
	LOCAL hdc: HDC

	invoke BeginPaint, hWnd, ADDR paintstruct
	mov hdc, eax

	invoke CreateCompatibleDC, hdc
	mov member_hdc, eax
	invoke CreateCompatibleDC, hdc
	mov member_hdc2, eax
	invoke CreateCompatibleBitmap, hdc, my_window_width, my_window_height
	mov h_bitmap, eax

	;将位图选择到兼容DC中
	invoke SelectObject, member_hdc, h_bitmap

	;绘制背景
	invoke paintBackground, member_hdc, member_hdc2

    ;绘制砖块
	invoke paintBricks, member_hdc, member_hdc2

	;绘制天花板
	invoke paintCeiling, member_hdc, member_hdc2

    ;绘制人物
	invoke paintPlayers, member_hdc, member_hdc2

	;绘制分数
	invoke paintScore, member_hdc

	; BitBlt（hDestDC, x, y, nWidth, nheight, hSrcDC, xSrc, ySrc, dwRop）
	; 将源矩形区域直接拷贝到目标区域：SRCCOPY
	invoke BitBlt, hdc, 0, 0, my_window_width, my_window_height, member_hdc, 0, 0, SRCCOPY


	invoke DeleteDC, member_hdc
	invoke DeleteDC, member_hdc2
	invoke DeleteObject, h_bitmap
	invoke EndPaint, hWnd, ADDR paintstruct
	ret
updateScene endp




; 背景图片绘制函数
paintBackground proc  member_hdc1:HDC, member_hdc2:HDC
	
	.IF game_status == 0
		invoke SelectObject, member_hdc2,  h_startpage
		invoke BitBlt, member_hdc1, 0, 0, my_window_width, my_window_height, member_hdc2, 0, 0, SRCCOPY
	.ELSEIF game_status == 1
		invoke SelectObject, member_hdc2,  h_gamepage
		invoke BitBlt, member_hdc1, 0, 0, my_window_width, my_window_height, member_hdc2, 0, 0, SRCCOPY
		
	.ELSEIF game_status == 2
		invoke SelectObject, member_hdc2,  h_endpage
		invoke BitBlt, member_hdc1, 0, 0, my_window_width, my_window_height, member_hdc2, 0, 0, SRCCOPY
	.ENDIF
	ret
paintBackground endp

paintCeiling proc uses ecx, member_hdc1:HDC, member_hdc2:HDC
	.IF game_status == 1
		invoke SelectObject, member_hdc2, brick_ceiling_bitmap
		mov	eax, 0
		mov ecx, 4
	paint:
		pushad
		invoke TransparentBlt, member_hdc1, eax, 0, brick_width, brick_height, member_hdc2, 0, 0, brick_width, brick_height, 16777215
		popad
		add	   eax, brick_width
		loop paint
	.ENDIF
	ret
paintCeiling endp

; 游戏主角绘制函数
paintPlayers proc member_hdc1: HDC, member_hdc2:HDC
	.IF game_status == 1
		.IF player1.dir == dir_left
			invoke SelectObject, member_hdc2, player_left_bitmap
		.ELSEIF player1.dir == dir_right
			invoke SelectObject, member_hdc2, player_right_bitmap
		.ENDIF
		invoke TransparentBlt, member_hdc1, player1.pos.x, player1.pos.y,\
				player1.psize.x, player1.psize.y, member_hdc2, 0, 0, player1.psize.x, player1.psize.y, 16777215
	.ENDIF
	ret
paintPlayers endp

; 砖块绘制函数
paintBricks proc uses edi edx ecx, member_hdc1:HDC, member_hdc2:HDC
	assume edi:ptr brick
	.IF game_status == 1
		mov	   ecx, lengthof bricks
		mov    edi, offset bricks

		L2:
			push	ecx
			push	edi
			.IF [edi].brick_type == 1
				invoke	SelectObject, member_hdc2, brick_normal_bitmap
			.ELSEIF [edi].brick_type == 3
				invoke	SelectObject, member_hdc2, brick_icy_bitmap
			.ELSEIF [edi].brick_type == 2
				invoke	SelectObject, member_hdc2, brick_sharp_bitmap
			.ELSEIF [edi].brick_type == 6
				invoke	SelectObject, member_hdc2, brick_fragile_bitmap
			.ELSEIF [edi].brick_type == 4 || [edi].brick_type == 5
				invoke	SelectObject, member_hdc2, brick_conveyor_bitmap
			.ENDIF
			pop		edi
			invoke	TransparentBlt, member_hdc1, [edi].boundary.left, [edi].boundary.top,\
				brick_width, brick_height, member_hdc2, 0, 0, brick_width, brick_height, 16777215
			add		edi, type bricks
			pop		ecx
			dec		ecx
			cmp		ecx, 0
			jne L2
	.ENDIF
	ret
paintBricks endp

paintScore proc member_hdc:HDC
    LOCAL rect :RECT
	;mov rect.left, 0
	;mov rect.right, 480
	;mov rect.top, 0
	;mov rect.bottom, 40

	;mov eax, score
	;invoke wsprintf, addr scoreStr, addr qwq, eax
	mov    eax, offset text
	invoke TextOutA,member_hdc,40,90,addr text,4
	;invoke DrawText, member_hdc, addr text, -1,  addr rect,  DT_SINGLELINE or DT_CENTER or DT_VCENTER

	ret
paintScore endp

end start