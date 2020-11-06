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
				mov player1.dir, dir_right
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
	invoke LoadBitmap, hInstance, 500
	mov h_startpage, eax

    ; 加载游戏界面的位图
	invoke LoadBitmap, hInstance, 501
	mov h_gamepage, eax

	; 加载玩家向左的位图
	invoke LoadBitmap, hInstance, 504
	mov player_left_bitmap, eax

	; 加载玩家向右的位图
	invoke LoadBitmap, hInstance, 505
	mov player_right_bitmap, eax

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
	; 开始界面，需要通过enter键进入
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
		mov		[esi].boundary.left, eax
		add		eax, brick_width
		mov		[esi].boundary.right, eax
		add		edi, brick_y_gap_in
		mov		[esi].boundary.top, edi
		add		edi, brick_height
		mov		[esi].boundary.bottom, edi
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
		
		;add		edi, type bricks
		mov		[edi].boundary.left, eax
		add		eax, brick_width
		mov		[edi].boundary.right, eax
		mov		eax, my_window_height
		mov		[edi].boundary.top, eax
		add		eax, brick_height
		mov		[edi].boundary.bottom, eax

	.ELSE
		mov		ebx, brick_y_gap_in
		sub		ebx, game_counter
	L4:
		mov		[edi].boundary.top, ebx
		add		ebx, brick_height
		mov		[edi].boundary.bottom, ebx
		add		ebx, brick_y_gap_in
		add		edi, TYPE bricks
		loop	L4
	.ENDIF
	ret
changeBricks endp

colliDetect proc uses eax ebx ecx esi edi edx
	assume esi: PTR player, edi: PTR collision, ecx: PTR brick
	LOCAL cur_left:SDWORD
	LOCAL cur_right:SDWORD
	LOCAL cur_bottom:SDWORD
	LOCAL next_left:SDWORD
	LOCAL next_right:SDWORD
	LOCAL next_bottom:SDWORD
	LOCAL cur_block:DWORD
	LOCAL next_block:DWORD 

	mov	edi, offset	cur_collision
	mov	esi, offset player1
	mov ecx, offset bricks 

	; 计算当前左、右、下
	mov eax, [esi].pos.x
	mov cur_left, eax 
	mov eax, [esi].pos.x
	add eax, [esi].psize.x
	mov cur_right, eax
	mov eax, [esi].pos.y
	add eax, [esi].psize.y
	mov cur_bottom, eax

	; 计算考虑速度后的左、右、下
	mov eax, [esi].pos.x
	add eax, [esi].speed.x
	mov next_left, eax
	mov eax, cur_right
	add eax, [esi].speed.x
	mov next_right, eax
	mov eax, cur_bottom
	add eax, [esi].speed.y
	inc eax
	mov next_bottom, eax

	; 除数为32位时，被除数为EDX:EAX
	; cur_collision.cur_block = player1.boundary.bottom / brick_y_gap
	mov edx, 0
	mov eax, cur_bottom
	mov ebx, brick_y_gap
	idiv ebx				
	mov cur_block, eax
	mov eax, SIZEOF brick
	mul cur_block
	mov cur_block, eax
	

	; cur_collision.next_block = ( player1.boundary.bottom + player1.speed.y ) / brick_y_gap
	mov edx, 0
	mov eax, next_bottom
	mov ebx, brick_y_gap
	idiv ebx
	mov next_block, eax
	mov eax, SIZEOF brick
	mul next_block
	mov next_block, eax

	; 检测y
	; 优先级：如果当前块碰到了，就不会碰触到下一区块，
	; 因此应该先检测下一区块再检查当前区块，
	; 这样当前区块碰撞信息可以覆盖上一块的碰撞
	; 先检测下一区块是否碰撞
	; .ENDIF
	; 检测当前区块是否碰撞

	mov [edi].is_y_collide, 0
	mov eax, next_block
	mov edx, cur_block
	sub eax, cur_block
	push ecx
	.IF eax > 0
		add ecx, next_block
		mov eax, [ecx].boundary.top
		inc eax
		.IF cur_bottom <= eax && next_bottom >= eax
			mov ebx, [ecx].boundary.left
			mov edx, [ecx].boundary.right
			; TODO
			.IF (cur_right > ebx && cur_left < edx)
				mov [edi].is_y_collide, 1
				sub eax, cur_bottom			; 移动距离为 brick.boundary.top - cur_bottom
				dec eax
				mov [edi].y_need_move, eax
			;.ELSEIF (next_right > ebx && next_left < edx)
			;	mov [edi].is_y_collide, 1
			;	sub eax, cur_bottom			; 移动距离为 brick.boundary.top - cur_bottom
			;	mov [edi].y_need_move, eax
			.ENDIF
		.ENDIF
	.ENDIF
	pop ecx

	add ecx, cur_block
	mov eax, [ecx].boundary.top
	inc eax
	.IF cur_bottom <= eax && next_bottom >= eax
		mov ebx, [ecx].boundary.left
		mov edx, [ecx].boundary.right
		; TODO
		.IF cur_right > ebx && cur_left < edx
			mov [edi].is_y_collide, 1
			sub eax, cur_bottom			; 移动距离为 brick.boundary.top - cur_bottom
			dec eax
			mov [edi].y_need_move, eax
			; mov eax, [ecx].brick_type
			; mov [edi].collision_type, eax 
		.ENDIF
	.ENDIF

	; 检测x
	; 优先级：侧撞到砖块就不会撞到墙壁了
	; 因此应该先检测墙壁再检测砖块
	; 撞到左墙：player1.boundary.left + speed.x <(=) 0
	; 撞到右墙：player1.boundary.right + speed.x >(=) 450
	; 
	cmp next_left, 0
	jge right_wall
	mov [edi].is_x_collide, 1
	mov eax, 0
	sub eax, cur_left
	mov [edi].x_need_move, eax
right_wall:
	cmp next_right, my_window_width
	jle return_main
	mov [edi].is_x_collide, 1
	mov eax, my_window_width
	sub eax, cur_right
	mov [edi].x_need_move, eax

	; TODO：检测砖块
return_main:
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
	.IF game_status == 1
		.IF wParam == VK_LEFT
			mov player1.speed.x,-6
		.ELSEIF wParam == VK_RIGHT
			mov player1.speed.x,6
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
			invoke	TransparentBlt, member_hdc1, [edi].boundary.left, [edi].boundary.top,\
				brick_width, brick_height, member_hdc2, 0, 0, 150, 30, 16777215
			add		edi, type bricks
			pop		ecx
			loop L2
	.ENDIF
	ret
paintBricks endp

end start