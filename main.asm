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
				invoke initialBricks
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

loadGameImages proc
	; 加载开始界面的位图
	invoke LoadBitmap, hInstance, 501
	mov h_startpage, eax

    ; 加载游戏界面的位图
	invoke LoadBitmap, hInstance, 501
	mov h_gamepage, eax

	; 加载玩家1的位图
	invoke LoadBitmap, hInstance, 502
	mov player1_bitmap, eax

	; 加载砖块的位图
	invoke LoadBitmap, hInstance, 503
	mov brick_bitmap, eax

	; 加载结束界面的位图
	invoke LoadBitmap, hInstance, 501
	mov h_endpage, eax


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
		invoke Sleep, 50
		; 重置计数器
		.IF game_counter >= brick_y_gap
			mov game_counter, 0
		.ENDIF
		; 改变计数器并上移砖块
		inc game_counter
		invoke changeBricks

		; 角色移动
		invoke movePlayer, addr player1

		.IF game_over == 1
			mov game_status, 2
		.ENDIF
	.ENDW

	; 结束界面
	.WHILE game_status == 2
		invoke Sleep, 30

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
	assume esi:ptr brick

	mov	   ecx, lengthof bricks
	mov	   esi, offset bricks
	mov    edi, 0
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
		mov		[esi].pos_left_top.x, eax
		mov		[esi].pos_left_bottom.x, eax
		add		eax, brick_width
		mov		[esi].pos_right_top.x, eax
		mov		[esi].pos_right_bottom.x, eax
		add		edi, brick_y_gap_in
		mov		[esi].pos_left_top.y, edi
		mov		[esi].pos_right_top.y, edi
		add		edi, brick_height
		mov		[esi].pos_left_bottom.y, edi
		mov		[esi].pos_right_bottom.y, edi
		add		esi, TYPE bricks
		pop		ecx
		loop	L1
	ret
initialBricks endp

; 砖块更新函数
changeBricks proc uses ecx esi edi ebx edx
	assume edi:ptr brick

	mov	   ecx, lengthof bricks
	mov	   edi, offset bricks

	.IF game_counter >= brick_y_gap
		cld
		mov		esi, edi
		add		esi, type bricks
		mov		ecx, 360
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
		;add		edi, type bricks
		mov		[edi].pos_left_top.x, eax
		mov		[edi].pos_left_bottom.x, eax
		add		eax, brick_width
		mov		[edi].pos_right_top.x, eax
		mov		[edi].pos_right_bottom.x, eax
		mov		eax, my_window_height
		mov		[edi].pos_left_top.y, eax
		mov		[edi].pos_right_top.y, eax
		add		eax, brick_height
		mov		[edi].pos_left_bottom.y, eax
		mov		[edi].pos_right_bottom.y, eax

	.ELSE
		mov		ebx, brick_y_gap_in
		sub		ebx, game_counter
	L4:
		mov		[edi].pos_left_top.y, ebx
		mov		[edi].pos_right_top.y, ebx
		add		ebx, brick_height
		mov		[edi].pos_left_bottom.y, ebx
		mov		[edi].pos_right_bottom.y, ebx
		add		ebx, brick_y_gap_in
		add		edi, TYPE bricks
		loop	L4
	.ENDIF
	ret
changeBricks endp


movePlayer proc uses eax ebx ecx, addrPlayer1:DWORD
	assume eax: PTR player
	mov eax,addrPlayer1

	.IF [eax].is_y_collide == 0
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
	dec [eax].pos.y
	.ENDIF

	mov ebx,[eax].speed.x
	add [eax].pos.x,ebx

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
	.IF game_status == 2
		.IF wParam == VK_LEFT
			mov player1.speed.x,-6
		.ELSEIF wParam == VK_RIGHT
			mov player1.speed.x,6
		.ENDIF
	.ENDIF
	ret
processKeyDown endp

processKeyUp proc wParam:WPARAM
	.IF game_status == 2
		.IF wParam == VK_LEFT
			mov player1.speed.x,0
		.ELSEIF wParam == VK_RIGHT
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

    ;绘制人物
	invoke paintPlayers, member_hdc, member_hdc2

    ;绘制分数

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

; 游戏主角绘制函数
paintPlayers proc member_hdc1: HDC, member_hdc2:HDC
	.IF game_status == 1
		invoke SelectObject, member_hdc2, player1_bitmap
		invoke TransparentBlt, member_hdc1, player1.pos.x, player1.pos.y,\
				player1.psize.x, player1.psize.y, member_hdc2, 0, 0, 40, 40, 16777215
	.ENDIF
	ret
paintPlayers endp

; 砖块绘制函数
paintBricks proc uses esi edi ebx edx eax, member_hdc1:HDC, member_hdc2:HDC
	assume edi:ptr brick
	.IF game_status == 1
		mov	   ecx, lengthof bricks
		mov    edi, offset bricks

		L2:
			push	ecx
			push	edi
			invoke	SelectObject, member_hdc2, brick_bitmap
			pop		edi
			invoke	TransparentBlt, member_hdc1, [edi].pos_left_top.x, [edi].pos_left_top.y,\
				brick_width, brick_height, member_hdc2, 0, 0, 150, 30, 16777215
			add		edi, type bricks
			pop		ecx
			loop L2
	.ENDIF
	ret
paintBricks endp

end start