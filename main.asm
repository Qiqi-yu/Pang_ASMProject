    ; __UNICODE__ equ 1           ; uncomment to enable UNICODE build

    .686p                       ; create 32 bit code
    .mmx                        ; enable MMX instructions
    .xmm                        ; enable SSE instructions
    .model flat, stdcall        ; 32 bit memory model
    option casemap :none        ; case sensitive

    bColor   equ  <00999999h>   ; client area brush colour
    include	game.inc			; local includes for this file
	

.code
start:  ;������ڵ�
    ; ���ģ����
	invoke GetModuleHandle, NULL
	mov hInstance, eax

	; ���ܲ���Ҫ�����в���
	invoke GetCommandLine
	mov  CommandLine, eax
	; �õ�ͼ��͹��
    mov hIcon,       rv(LoadIcon,hInstance,103)
    mov hCursor,     rv(LoadCursor,NULL,IDC_ARROW)
	; �õ�������Ļ�ĳߴ�
    mov sWid,        rv(GetSystemMetrics,SM_CXSCREEN)
    mov sHgt,        rv(GetSystemMetrics,SM_CYSCREEN)
	; ����������
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
    m2m wc.hbrBackground,  NULL                 ;COLOR_BTNFACE+1 ����Ҫbackground
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

	; ��Ϣѭ��
    call MsgLoop
    ret
Main endp

; ��Ϣѭ��
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
	; �����ڴ������һЩ����
	.IF uMsg == WM_CREATE
		invoke startGame

	.ELSEIF uMsg == WM_DESTROY
		; �˳��߳�
		invoke PostQuitMessage, NULL

	.ELSEIF uMsg == WM_PAINT
		; ���ø��³���������WM_PAINT��paintThread��InvalidateRect����
		invoke updateScene

	.ELSEIF uMsg == WM_CHAR
		; ����enter�������¼�
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
		; ����esc�������¼�
		.IF wParam == 27
			invoke PostQuitMessage, NULL
		.ENDIF

	.ELSEIF uMsg == WM_KEYUP
		invoke processKeyUp, wParam
		; �������̧���¼�

	.ELSEIF uMsg == WM_KEYDOWN
		invoke processKeyDown, wParam
		; ������̰����¼�

	.ELSE
		; Ĭ����Ϣ������
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
		ret
	.ENDIF
	xor eax, eax
	ret
WndProc endp

startGame proc
		; ����λͼ��Դ
		invoke loadGameImages
		; �����߼��߳�
		mov eax, OFFSET logicThread
		invoke CreateThread, NULL, NULL, eax, 0, 0, addr thread1
		invoke CloseHandle, eax
		; ��������߳�
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
	; ���ؿ�ʼ�����λͼ
	invoke LoadBitmap, hInstance, 500
	mov h_startpage, eax

    ; ������Ϸ�����λͼ
	invoke LoadBitmap, hInstance, 501
	mov h_gamepage, eax

	; ���ؽ��������λͼ
	invoke LoadBitmap, hInstance, 502
	mov h_endpage, eax

	; ������������λͼ
	invoke LoadBitmap, hInstance, 504
	mov player_left_bitmap, eax

	; ����������ҵ�λͼ
	invoke LoadBitmap, hInstance, 505
	mov player_right_bitmap, eax

	; ������ͨש���λͼ
	invoke LoadBitmap, hInstance, 141
	mov brick_normal_bitmap, eax

	; ���ع⻬ש���λͼ
	invoke LoadBitmap, hInstance, 142
	mov brick_icy_bitmap, eax

	; ���ط���ש���λͼ
	invoke LoadBitmap, hInstance, 143
	mov brick_sharp_bitmap, eax

	; ��������ש���λͼ
	invoke LoadBitmap, hInstance, 144
	mov brick_fragile_bitmap, eax

	; ���ش���ש���λͼ
	invoke LoadBitmap, hInstance, 145
	mov brick_conveyor_bitmap, eax

	; �����컨��ש���λͼ
	invoke LoadBitmap, hInstance, 146
	mov brick_ceiling_bitmap, eax

	ret
loadGameImages endp

; һ���̺߳��������ݳ�����״̬����ѭ������Ϸ״̬ʱ�򣬲��Ͻ�����ײ�жϵȵ�
logicThread proc p:DWORD
	;LOCAL area:RECT
	game:
	; ��ʼ���棬��Ҫͨ��enter����
	.WHILE game_status == 0
		invoke Sleep, 1000
	.ENDW

	; ��Ϸ����
	.WHILE game_status == 1


		invoke Sleep, 30
		; ���ü�����
		.IF game_counter >= brick_y_gap
			mov game_counter, 0
		.ENDIF
		; �ı������������ש��
		inc game_counter
		invoke changeBricks

		; ��ײ���
		invoke colliDetect

		; ��ɫ�ƶ�
		invoke movePlayer, addr player1

		.IF game_over == 1
			mov game_status, 2
		.ENDIF
	.ENDW

	; ��������
	.WHILE game_status == 2
		invoke Sleep, 30
		mov game_over, 0
	.ENDW

	jmp game

	ret
logicThread endp

; ���Ͻ��л�������
paintThread proc p:DWORD
	.WHILE 1
		invoke Sleep, 10
		invoke InvalidateRect, hWnd, NULL, FALSE
	.ENDW
	ret
paintThread endp

; ��ʼ��ש�麯��
initialBricks proc uses esi edx ecx eax ebx edi
	LOCAL empty_line_num:DWORD
	assume esi:ptr brick

	mov	   esi, offset bricks
	mov    edi, 0

	; ��ǰ����ש�����ڴ�����
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

	;���ɵ�һ���������ש��
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
		; edxΪ��������
		mov		ebx, edx		; ���� ש�������
		mov		eax, brick_x_gap  ; ������  75
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

; ש����º���
changeBricks proc uses ecx esi edi ebx edx
	assume edi:ptr brick

	mov	   edi, offset bricks

	.IF game_counter >= brick_y_gap
		cld
		mov		esi, edi
		add		esi, type bricks
		mov		ebx, 10			  ; ����    ש������
		mov		eax, type bricks  ; ������  20
		mul		ebx
		mov		ecx, eax
		rep		movsb
		;����һ���µ�ש��
		push	edi
		invoke	clock
		pop		edi
		mov		edx, 0
		mov		ecx, 7
		div		ecx
		; edxΪ��������
		mov		ebx, edx		; ���� ש�������
		mov		eax, brick_x_gap  ; ������  75
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

	; ���㵱ǰ���ҡ���
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

	; ���㿼���ٶȺ�����ҡ���
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

	; ���x
	; ���ȼ�����ײ��ש��Ͳ���ײ��ǽ����
	; ���Ӧ���ȼ��ǽ���ټ��ש��
	; ײ����ǽ��next_left < 0
	; ײ����ǽ��next_right > my_window_width
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



	; ��ǰ����ѭ������Ƿ��ש����ײ
	mov ecx, 11
	mov [edi].is_y_collide, 0

collide_y:
	push ecx
	mov ebx, ecx
	mov eax, SIZEOF brick
	mul ebx			; eax ��ƫ��
	; mul �ı� edx�������Ҫ����edx = offset bricks
	mov edx, offset bricks
	add edx, eax
	mov ecx, [edx].boundary.top
	inc ecx
	mov ebx, [edx].boundary.left
	mov eax, [edx].boundary.right
	; ����Ƿ�Խש��
	.IF (cur_bottom <= ecx && next_bottom >= ecx) && ((cur_right > ebx && cur_left < eax) ||  (next_right > ebx && next_left < eax))
		mov [edi].is_y_collide, 1
		sub ecx, cur_bottom
		dec ecx							; �ƶ�����Ϊ brick.boundary.top - cur_bottom - 1
		mov [edi].y_need_move, ecx
		mov ecx, [edx].brick_type
		mov [edi].collide_type, ecx		; ��¼��ײש������
		pop ecx
		mov [edi].collide_index, ecx	; ��¼��ײש��index
		push ecx
		; jmp endgame_detect
	.ENDIF
	pop ecx
	loop collide_y

	mov ecx, 11

	; ��ײש��
collide_x:
	push ecx
	mov ebx, ecx
	mov eax, SIZEOF brick
	mul ebx			; eax ��ƫ��
	; mul �ı� edx�������Ҫ����edx = offset bricks
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

	; ���y
	; ����Ƿ������Ϸ���̣�cur_top <= brick_height��
	; �Ϸ�������̺��Զ�����
	;.IF cur_top <= brick_height
	.IF cur_top <= brick_height
		mov [edi].is_y_collide, 0
		mov [edi].collide_type, 2		; 2��ʾ�������
	.ENDIF

; ����Ƿ��������(next_top > my_window_height)
endgame_detect:
	.IF next_top > my_window_height
		mov [edi].is_y_collide, 1
		mov [edi].collide_type, 7			; 7���������
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
			;�������ҵĴ��ʹ���ʱ��������ٶȼ���
			.ELSEIF player1.on_conveyor == 2
			mov player1.speed.x,conveyor_speed_left
			.ENDIF
		.ELSEIF wParam == VK_RIGHT
			.IF player1.on_conveyor == 0
			mov player1.speed.x,player_x_speed
			.ELSEIF player1.on_conveyor == 1
			;��������Ĵ��ʹ���ʱ�����ҵ��ٶȼ���
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


; �������º���
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

	;��λͼѡ�񵽼���DC��
	invoke SelectObject, member_hdc, h_bitmap

	;���Ʊ���
	invoke paintBackground, member_hdc, member_hdc2

    ;����ש��
	invoke paintBricks, member_hdc, member_hdc2

	;�����컨��
	invoke paintCeiling, member_hdc, member_hdc2

    ;��������
	invoke paintPlayers, member_hdc, member_hdc2

	;���Ʒ���
	invoke paintScore, member_hdc

	; BitBlt��hDestDC, x, y, nWidth, nheight, hSrcDC, xSrc, ySrc, dwRop��
	; ��Դ��������ֱ�ӿ�����Ŀ������SRCCOPY
	invoke BitBlt, hdc, 0, 0, my_window_width, my_window_height, member_hdc, 0, 0, SRCCOPY


	invoke DeleteDC, member_hdc
	invoke DeleteDC, member_hdc2
	invoke DeleteObject, h_bitmap
	invoke EndPaint, hWnd, ADDR paintstruct
	ret
updateScene endp




; ����ͼƬ���ƺ���
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

; ��Ϸ���ǻ��ƺ���
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

; ש����ƺ���
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